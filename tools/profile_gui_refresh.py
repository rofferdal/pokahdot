#!/usr/bin/env python3
"""Profile real native/Web GUI refresh without changing product widget lifetime.

Example (Web mode needs requirements-web-test.txt + Playwright Chromium):
  python3 tools/profile_gui_refresh.py --mode native --output localtmp/gui-native
  PLAYWRIGHT_BROWSERS_PATH=... python tools/profile_gui_refresh.py --mode web ...

Raw samples, isolated exports and logs live only in the requested output folder.
No timing threshold is a correctness gate; 16.7 ms flags a case for investigation.
"""
from __future__ import annotations

import argparse
import functools
import hashlib
import http.server
import json
import math
import os
import platform
import re
import signal
import subprocess
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIZES = {"phone": (390, 844), "tablet": (1024, 768), "desktop": (1920, 1080)}
SCENARIOS = ("turns", "runouts", "resize")
REPLACEMENT_FIXTURE_FILES = (
    "tests/performance/profiled_replacement_table.gd",
    "tests/performance/gui_replacement_refresh_fixture.gd",
    "tests/performance/gui_replacement_refresh_fixture.tscn",
)


def fixture_paths(implementation: str) -> tuple[str, str, tuple[str, ...]]:
    """Select the live replacement observer; historical reports remain data only."""
    if implementation != "replacement":
        raise ValueError("Only the replacement GUI can be profiled: " + implementation)
    return ("tests/performance/gui_replacement_refresh_native.gd",
            "res://tests/performance/gui_replacement_refresh_fixture.tscn",
            REPLACEMENT_FIXTURE_FILES)


class WebErrorLog:
    """Keep strict failure reporting bounded while retaining raw diagnostics."""

    def __init__(self, path: Path | None = None):
        self.count = 0
        self.messages: list[str] = []
        self._distinct: set[str] = set()
        self.path = path

    def add(self, message: str) -> None:
        self.count += 1
        if self.path is not None:
            with self.path.open("a") as output:
                output.write(message + "\n")
        if message not in self._distinct and len(self.messages) < 12:
            self._distinct.add(message)
            self.messages.append(message[:500])

    def __bool__(self) -> bool:
        return self.count > 0


def summarize(values: list[float]) -> dict:
    """Nearest-rank percentiles; empty/unavailable metrics remain explicit."""
    if not values:
        return {"n": 0, "p50": None, "p95": None, "max": None}
    ordered = sorted(values)
    return {"n": len(values), "p50": ordered[math.ceil(len(values) * .5) - 1],
            "p95": ordered[math.ceil(len(values) * .95) - 1], "max": ordered[-1]}


def source_identity() -> dict:
    def git(*args: str) -> str:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

    files: dict[str, Path] = {}
    for directory in ("scripts", "scenes", "resources", "assets", "tests/performance"):
        for path in (ROOT / directory).rglob("*"):
            if path.is_file() and path.name != ".DS_Store":
                files[str(path.relative_to(ROOT))] = path
    for name in ("project.godot", "export_presets.cfg", "tools/profile_gui_refresh.py", "tools/run_web_input_tests.py"):
        files[name] = ROOT / name
    dirty = set(git("diff", "--name-only", "HEAD").splitlines())
    dirty.update(git("ls-files", "--others", "--exclude-standard").splitlines())

    def digest(paths: list[str]) -> str:
        checksum = hashlib.sha256()
        for name in sorted(paths):
            checksum.update(name.encode() + b"\0" + files[name].read_bytes() + b"\0")
        return checksum.hexdigest()

    return {"git_revision": git("rev-parse", "HEAD"),
            "execution_source_sha256": digest(list(files)),
            "dirty_execution_source_sha256": digest([name for name in dirty if name in files]),
            "fingerprint_scope": "scripts/scenes/resources/assets/tests/performance + config + profiling/export launchers",
            "dirty_execution_paths": sorted(name for name in dirty if name in files)}


def enrich(result: dict) -> dict:
    metrics = {name: summarize(result[name]) for name in
               ("refresh_usec", "widget_refresh_usec", "layout_usec")}
    for name in ("settled_latency_usec", "operation_cpu_usec"):
        if name in result:
            metrics[name] = summarize(result[name])
    if "settled_frames" in result:
        result["settled_frames_summary"] = summarize(result["settled_frames"])
    for phase in ("idle", "active"):
        for name, values in result[phase].items():
            metrics[f"{phase}.{name}"] = summarize(values)
    result["summary_usec"] = metrics
    result["census_summary"] = summarize([row["new_node_ids"] for row in result["node_census"]])
    samples = result["counter_samples"]
    result["counter_high_water"] = {
        name: max((row[name] for row in samples), default=None)
        for name in result["counters_before"]}
    result["counter_change"] = {
        name: result["counters_after"][name] - value
        for name, value in result["counters_before"].items()}
    result["engine_object_counters_available"] = result["counters_before"]["nodes"] > 0
    result["allocator_monitor_available"] = result["counters_before"]["static_memory_bytes"] > 0
    result["quarter_counter_high_water"] = []
    for quarter in range(4):
        part = samples[len(samples) * quarter // 4:len(samples) * (quarter + 1) // 4]
        result["quarter_counter_high_water"].append({
            name: max((row[name] for row in part), default=None)
            for name in ("objects", "nodes", "static_memory_bytes")})
    result["investigate_refresh_over_16_7ms"] = bool(
        metrics["refresh_usec"]["p95"] is not None and metrics["refresh_usec"]["p95"] > 16700)
    if result.get("implementation") == "replacement":
        presentations = result["presentation_samples"]
        deferred = result.get("deferred_counter_samples", [])
        metrics["deferred.engine_process_frame_usec"] = summarize([
            row["engine_process_frame_usec"] for row in deferred])
        result["deferred_counter_high_water"] = {
            name: max((row["objects"][name] for row in deferred), default=None)
            for name in result["counters_before"]}
        result["presentation_summary"] = {
            outcome: {
                "samples": sum(row["outcome"] == outcome for row in presentations),
                "settled_latency_usec": summarize([
                    result["settled_latency_usec"][index]
                    for index, row in enumerate(presentations) if row["outcome"] == outcome]),
                "operation_cpu_usec": summarize([
                    result["operation_cpu_usec"][index]
                    for index, row in enumerate(presentations) if row["outcome"] == outcome]),
            } for outcome in ("ready", "guidance")}
        result["render_counter_change"] = {
            name: result["render_counters_after"][name] - value
            for name, value in result["render_counters_before"].items()}
    return result


def validate_result(result: dict, samples: int) -> None:
    if result["failures"]:
        raise RuntimeError("GUI profiling privacy/core failures: " + repr(result["failures"]))
    if len(result["active"]["step_to_post_draw_usec"]) != samples:
        raise RuntimeError("Profiling fixture returned incomplete samples")
    if result.get("implementation", "reference") == "replacement":
        validate_replacement_result(result, samples)
    if result["scenario"] == "resize":
        guidance_only = (result.get("implementation") == "replacement" and
                         all(row["outcome"] == "guidance" for row in result["presentation_samples"]))
        if not result["layout_usec"] or (not guidance_only and
                len({row["profile"] for row in result["selected_layouts"]}) < 2):
            raise RuntimeError("Resize fixture did not measure actual profile transitions")
        if len({tuple(row["requested"]) for row in result["selected_layouts"]}) < 3:
            raise RuntimeError("Resize fixture did not visit all three requested sizes")
        if not result.get("node_census"):
            raise RuntimeError("Resize fixture did not observe any layout census operations")
    elif len(result["refresh_usec"]) < samples:
        raise RuntimeError("Action workload did not measure every refresh")
    if result["scenario"] == "runouts":
        if not {"flop", "turn", "river"} <= set(result["streets_observed"]):
            raise RuntimeError("Runout fixture did not observe every dealt street")
        if result["completed_hands_observed"] < 1:
            raise RuntimeError("Runout fixture did not complete a real hand")


def validate_replacement_result(result: dict, samples: int) -> None:
    """Do not confuse deferred readiness, guidance and synchronous CPU cost."""
    if result.get("input_modality") not in ("keypad", "keyboard"):
        raise RuntimeError("Replacement profiling omitted its input modality")
    for name in ("settled_latency_usec", "settled_frames", "operation_cpu_usec", "presentation_samples"):
        if len(result.get(name, [])) != samples:
            raise RuntimeError("Replacement profiling omitted settled samples: " + name)
    for name in ("settled_latency_usec", "settled_frames", "operation_cpu_usec"):
        if any(not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0
               for value in result[name]):
            raise RuntimeError("Replacement profiling returned invalid timing values: " + name)
    for row in result["presentation_samples"]:
        if row.get("pending") or row.get("outcome") not in ("ready", "guidance"):
            raise RuntimeError("Replacement sample did not settle to content or guidance")
        if row["outcome"] == "guidance" and not row.get("fit_guidance"):
            raise RuntimeError("Guidance sample omitted its truthful reason")
    required = {"composition_mounts", "probe_created", "probe_freed", "probe_live", "probe_peak_live"}
    counters = result.get("render_counters_after", {})
    if not required <= counters.keys() or any(not isinstance(counters[key], int) or counters[key] < 0
                                              for key in required):
        raise RuntimeError("Replacement render/probe counters are missing or invalid")
    if counters["probe_created"] - counters["probe_freed"] != counters["probe_live"]:
        raise RuntimeError("Replacement probe counters do not reconcile")
    if counters["probe_peak_live"] < counters["probe_live"]:
        raise RuntimeError("Replacement probe peak is below its live count")


def native_case(godot: str, work: Path, profile: str, scenario: str, samples: int,
                implementation: str = "replacement", players: int | None = None,
                viewport: tuple[int, int] | None = None) -> dict:
    name = f"native-{profile}-{scenario}"
    output = work / f"{name}.json"
    script, _, _ = fixture_paths(implementation)
    arguments = [godot, "--path", str(ROOT), "--rendering-method", "gl_compatibility",
                 "--rendering-driver", "opengl3", "--audio-driver", "Dummy",
                 "--script", script, "--",
                 "--profile", profile, "--scenario", scenario, "--samples", str(samples),
                 "--output", str(output)]
    if players is not None:
        arguments.extend(["--players", str(players)])
    if viewport is not None:
        arguments.extend(["--width", str(viewport[0]), "--height", str(viewport[1])])
    time_flag = "-l" if platform.system() == "Darwin" else "-v"
    with (work / f"{name}.log").open("w") as log:
        process = subprocess.Popen(["/usr/bin/time", time_flag, *arguments], cwd=ROOT,
                                   stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            returncode = process.wait(timeout=180)
        except subprocess.TimeoutExpired as error:
            terminate_owned_process_group(process)
            raise RuntimeError(f"Native profiling timed out: {name}.log; owned process group stopped") from error
        except BaseException:
            terminate_owned_process_group(process)
            raise
    log_text = (work / f"{name}.log").read_text()
    if returncode or "ERROR:" in log_text:
        raise RuntimeError(f"Native profiling failed: {name}.log")
    result = json.loads(output.read_text())
    process = re.search(r"([\d.]+) real\s+([\d.]+) user\s+([\d.]+) sys", log_text)
    rss = re.search(r"(\d+)\s+maximum resident set size", log_text)
    result["native_process_accounting"] = {
        "whole_process_seconds": list(map(float, process.groups())) if process else None,
        "whole_process_peak_rss_bytes": int(rss[1]) if rss else None,
        "scope": "Whole fresh process including startup/warmup/idle/census/I/O; not per-frame CPU."}
    return result


def terminate_owned_process_group(process: subprocess.Popen, grace_seconds: float = 2.0) -> None:
    """Stop the session created by native_case, including the time wrapper's child."""
    # start_new_session makes the launched PID its own PGID. Never look up or
    # signal another Godot process (the user's editor may be running alongside).
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.wait(timeout=grace_seconds)
        return
    started = time.monotonic()
    try:
        process.wait(timeout=grace_seconds)
    except subprocess.TimeoutExpired:
        pass
    # The wrapper can exit first while Godot remains alive. Allow its children
    # the rest of the grace period, then kill only this same owned group.
    remaining = grace_seconds - (time.monotonic() - started)
    if remaining > 0:
        time.sleep(remaining)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=grace_seconds)


def renderer_process_sample(session, phase: str) -> dict:
    """Browser renderer-pool RSS/CPU accounting, not Godot allocator/GPU memory."""
    processes = [row for row in session.send("SystemInfo.getProcessInfo")["processInfo"]
                 if row["type"] == "renderer"]
    ids = [str(row["id"]) for row in processes]
    rss = {}
    if ids:
        captured = subprocess.run(["ps", "-o", "pid=,rss=", "-p", ",".join(ids)],
                                  capture_output=True, text=True, check=False)
        for line in captured.stdout.splitlines():
            process_id, kib = line.split()
            rss[int(process_id)] = int(kib) * 1024
    return {"monotonic_seconds": time.monotonic(), "phase": phase,
            "renderer_pool_rss_bytes": sum(rss.values()),
            "processes": [{"pid": row["id"], "cpu_seconds": row["cpuTime"],
                           "rss_bytes": rss.get(row["id"])} for row in processes]}


def profile_url(port: int, profile: str, scenario: str, samples: int,
                players: int | None, viewport: tuple[int, int] | None) -> str:
    """Build the same explicit workload options consumed by the native fixture."""
    result = f"http://127.0.0.1:{port}/index.html?profile={profile}&scenario={scenario}&samples={samples}"
    if players is not None:
        result += f"&players={players}"
    if viewport is not None:
        result += f"&width={viewport[0]}&height={viewport[1]}"
    return result


def web_cases(godot: str, work: Path, profiles: list[str], scenarios: list[str], samples: int,
              implementation: str = "replacement", players: int | None = None,
              viewport: tuple[int, int] | None = None) -> list[dict]:
    from playwright.sync_api import sync_playwright
    from run_web_input_tests import QuietHandler, export_fixture

    export_work = work / "web-fixture"
    export_work.mkdir()
    _, scene, fixture_files = fixture_paths(implementation)
    exported = export_fixture(godot, export_work, scene, fixture_files)
    handler = functools.partial(QuietHandler, directory=str(exported))
    results: list[dict] = []
    with http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True)
            accounting = browser.new_browser_cdp_session()
            for profile in profiles:
                for scenario in scenarios:
                    width, height = viewport if viewport is not None else SIZES[profile]
                    context = browser.new_context(viewport={"width": width, "height": height},
                                                  device_scale_factor=1)
                    page = context.new_page()
                    errors = WebErrorLog(work / f"web-{profile}-{scenario}-errors.log")
                    page.on("pageerror", lambda error: errors.add(str(error)))
                    page.on("console", lambda message: errors.add(message.text)
                            if message.type == "error" else None)
                    page.goto(profile_url(server.server_port, profile, scenario, samples,
                                          players, viewport))
                    deadline = time.monotonic() + 180
                    result = None
                    memory_samples = []
                    next_memory_sample = 0.0
                    while time.monotonic() < deadline:
                        state = page.evaluate("({resize:window.pokahdotProfileResize,"
                                              "result:window.pokahdotProfileResult,"
                                              "failure:window.pokahdotProfileFailure,phase:window.pokahdotProfilePhase})")
                        if time.monotonic() >= next_memory_sample:
                            memory_samples.append(renderer_process_sample(accounting, state.get("phase", "loading")))
                            next_memory_sample = time.monotonic() + .1
                        if state.get("failure"):
                            raise RuntimeError(state["failure"])
                        if state.get("result"):
                            result = state["result"]
                            break
                        if state.get("resize"):
                            x, y = state["resize"]
                            page.set_viewport_size({"width": x, "height": y})
                            page.evaluate("window.pokahdotProfileResize = null")
                        page.wait_for_timeout(10)
                    if result is None or errors:
                        raise RuntimeError(
                            f"Web profiling failed {profile}/{scenario}: {errors.count} errors; "
                            f"first distinct messages: {errors.messages}; raw log: {errors.path}")
                    result["browser_renderer_process_samples"] = memory_samples
                    active_memory = [row["renderer_pool_rss_bytes"] for row in memory_samples
                                     if row["phase"] == "active"]
                    result["browser_active_renderer_pool_rss"] = summarize(active_memory)
                    result["browser_process_accounting_scope"] = (
                        "OS RSS for all Chromium renderer processes in this browser, sampled at 100ms; "
                        "includes Wasm/JS/renderer overhead and spare renderers; excludes GPU process. "
                        "CDP CPU seconds are whole-process totals, not per-frame CPU. "
                        "Fresh context per case; browser process pool reused.")
                    result["browser"] = page.evaluate("navigator.userAgent")
                    result["browser_geometry"] = page.evaluate(
                        "({css:[innerWidth,innerHeight],dpr:devicePixelRatio,"
                        "canvas:[document.querySelector('canvas').width,document.querySelector('canvas').height]})")
                    result["browser_version"] = browser.version
                    result["exported_project_source_sha256"] = (export_work / "source.sha256").read_text()
                    results.append(result)
                    (work / f"web-{profile}-{scenario}.json").write_text(json.dumps(result, indent=2) + "\n")
                    context.close()
            browser.close()
        server.shutdown()
        thread.join()
    return results


def argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("native", "web", "both"), default="both")
    parser.add_argument("--implementation", choices=("replacement",), default="replacement")
    parser.add_argument("--players", type=int, choices=range(2, 10), default=None,
                        help="Explicit matched roster; omitted preserves profile defaults (phone7, other9)")
    parser.add_argument("--viewport", type=int, nargs=2, metavar=("WIDTH", "HEIGHT"), default=None,
                        help="Override the initial phone viewport in logical pixels")
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=120)
    parser.add_argument("--profiles", nargs="+", choices=tuple(SIZES), default=list(SIZES))
    parser.add_argument("--scenarios", nargs="+", choices=SCENARIOS, default=list(SCENARIOS))
    return parser


def main() -> None:
    parser = argument_parser()
    arguments = parser.parse_args()
    if not 20 <= arguments.samples <= 2000:
        parser.error("--samples must be in 20..2000")
    if arguments.viewport is not None and (arguments.profiles != ["phone"] or
                                           any(value <= 0 for value in arguments.viewport)):
        parser.error("--viewport requires a single phone profile and positive dimensions")
    viewport = tuple(arguments.viewport) if arguments.viewport is not None else None
    work = arguments.output.resolve()
    work.mkdir(parents=True, exist_ok=False)
    identity = source_identity()
    results: list[dict] = []
    if arguments.mode in ("native", "both"):
        for profile in arguments.profiles:
            for scenario in arguments.scenarios:
                results.append(native_case(arguments.godot, work, profile, scenario, arguments.samples,
                                           arguments.implementation, arguments.players, viewport))
    if arguments.mode in ("web", "both"):
        results.extend(web_cases(arguments.godot, work, arguments.profiles, arguments.scenarios,
                                 arguments.samples, arguments.implementation, arguments.players, viewport))
    if source_identity()["execution_source_sha256"] != identity["execution_source_sha256"]:
        raise RuntimeError("Execution sources changed during profiling; repeat the measurement")
    for result in results:
        result.setdefault("implementation", arguments.implementation)
        validate_result(result, arguments.samples)
        enrich(result)
        result["source"] = identity
    report = {"schema_version": 1, "source": identity, "host": platform.platform(),
              "implementation": arguments.implementation, "requested_players": arguments.players,
              "requested_viewport_override": viewport,
              "investigation_threshold_usec": 16700,
              "percentile_method": "nearest rank", "results": results}
    (work / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    for result in results:
        mode = "web" if result["environment"]["web"] else "native"
        print(mode, result["profile"], result["scenario"], result["summary_usec"]["refresh_usec"],
              "layout", result["summary_usec"]["layout_usec"])


if __name__ == "__main__":
    main()
