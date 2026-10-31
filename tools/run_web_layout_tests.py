#!/usr/bin/env python3
"""Run strict exported replacement-layout checks and separate diagnostics.

The strict matrix uses real Chromium canvas/backing geometry and the production
viewport adapter. Report-only boundary cases retain failures without weakening
the supported phone, tablet and desktop gate. Browser automation is not
physical-device acceptance.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import functools
import hashlib
import http.server
import json
from pathlib import Path
import subprocess
import threading
import time
from urllib.parse import urlencode

from playwright.sync_api import sync_playwright

from run_web_input_tests import ROOT, QuietHandler, export_fixture
from web_geometry_assertions import (
    check_default_font_metrics,
    check_font_stress_copy,
    check_geometry,
)
from web_layout_assertions import check_snapshot

SUPPORT = (
    "tests/support/gui_browser_capture_fixture.gd",
    "tests/support/gui_visual_state_fixtures.gd",
    "tests/support/gui_replacement_invariant_assertions.gd",
    "tests/support/gui_snapshot_content_assertions.gd",
    "tests/support/gui_default_font_metrics.gd",
    "tests/web/layout_snapshot_json.gd",
    "tests/web/viewport_geometry_fixture_setup.gd",
)
DPRS = (1, 2, 2.625, 3)
MODES = {"phone": 1, "phone_landscape": 2, "wide_compact": 3, "wide": 4}
SUPPORTED = (
    ("phone-browser-portrait", 390, 744, "phone", 6),
    ("phone-browser-portrait-seven", 390, 744, "phone", 7),
    ("phone-portrait", 390, 844, "phone", 6),
    ("phone-portrait-seven", 390, 844, "phone", 7),
    ("phone-landscape-six", 844, 390, "phone_landscape", 6),
    ("phone-landscape-seven", 932, 430, "phone_landscape", 7),
    ("phone-landscape", 932, 430, "phone_landscape", 3),
    ("ipad", 1024, 768, "wide_compact", 6),
    ("ipad-browser", 1194, 676, "wide_compact", 6),
    ("ipad-browser-nine", 1194, 676, "wide_compact", 9),
    ("ipad-portrait-nine", 834, 1030, "wide_compact", 9),
    ("desktop-short", 1280, 720, "wide_compact", 6),
    ("desktop", 1920, 1080, "wide", 6),
)
DIAGNOSTICS = (
    ("boundary-short", 650, 360),
    ("boundary-medium", 1099, 759),
    ("boundary-expanded", 1100, 759),
    ("legacy-sample", 1280, 720),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native_default_font_metrics(godot: str) -> dict:
    prefix = "RG62_DEFAULT_FONT_METRICS="
    completed = subprocess.run(
        [godot, "--headless", "--path", str(ROOT), "--script",
         "res://tests/support/gui_default_font_metrics_runner.gd"],
        cwd=ROOT, text=True, capture_output=True, timeout=30, check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            "Native default-font probe failed:\n" + completed.stdout + completed.stderr
        )
    for line in completed.stdout.splitlines():
        if line.startswith(prefix):
            return json.loads(line.removeprefix(prefix))
    raise RuntimeError("Native default-font probe returned no metric document.")


def strict_cases(quick: bool) -> list[dict]:
    dprs = (1,) if quick else DPRS
    environments = SUPPORTED[:1] if quick else SUPPORTED
    cases = []
    for dpr in dprs:
        for name, width, height, expected, players in environments:
            for classification in ("automatic", "explicit"):
                cases.append({"id": f"strict-{name}-{classification}-dpr{dpr}",
                    "kind": "strict", "width": width, "height": height, "dpr": dpr,
                    "mode": "automatic" if classification == "automatic" else expected,
                    "expected_mode": MODES[expected], "geometry": "ordinary",
                    "players": players, "touch": name.startswith(("phone", "ipad"))})
    if not quick:
        cases.extend((
            {"id": "strict-narrow-phone-portrait-dpr3", "kind": "strict",
             "width": 360, "height": 780, "dpr": 3, "mode": "automatic",
             "expected_mode": MODES["phone"], "geometry": "ordinary", "players": 6, "touch": True},
            {"id": "strict-narrow-phone-browser-dpr3", "kind": "strict",
             "width": 360, "height": 720, "dpr": 3, "mode": "automatic",
             "expected_mode": MODES["phone"], "geometry": "ordinary", "players": 6, "touch": True},
            {"id": "strict-narrow-phone-landscape-dpr3", "kind": "strict",
             "width": 780, "height": 360, "dpr": 3, "mode": "automatic",
             "expected_mode": MODES["phone_landscape"], "geometry": "ordinary", "players": 6, "touch": True},
            {"id": "strict-ipad-asymmetric-auto-dpr2.625", "kind": "strict",
             "width": 1024, "height": 768, "dpr": 2.625, "mode": "automatic",
             "expected_mode": MODES["wide_compact"], "geometry": "asymmetric",
             "players": 6},
            {"id": "strict-desktop-safe-explicit-dpr3", "kind": "strict",
             "width": 1920, "height": 1080, "dpr": 3, "mode": "wide",
             "expected_mode": MODES["wide"], "geometry": "safe-and-visual", "players": 6},
            {"id": "strict-phone-font-stress-dpr2.625", "kind": "strict",
             "width": 1000, "height": 500, "dpr": 2.625, "mode": "phone_landscape",
             "expected_mode": MODES["phone_landscape"], "geometry": "ordinary",
             "players": 3, "stress": "font"},
        ))
    return cases


def diagnostic_cases(quick: bool) -> list[dict]:
    if quick:
        return []
    return [{"id": f"report-{name}-dpr1", "kind": "report_only", "width": width,
             "height": height, "dpr": 1, "mode": "automatic", "geometry": "ordinary"}
            for name, width, height in DIAGNOSTICS]


def resize_cases() -> list[dict]:
    """Keep one bound table through chrome-height changes and both rotations."""
    result = []
    sequences = (
        ("phone", 6, ((390, 844, "phone"), (390, 744, "phone"),
                      (844, 390, "phone_landscape"), (390, 844, "phone"))),
        ("ipad", 9, ((1194, 676, "wide_compact"), (834, 1030, "wide_compact"),
                     (1194, 676, "wide_compact"))),
    )
    for dpr in DPRS:
        for name, players, sizes in sequences:
            for step, (width, height, mode) in enumerate(sizes):
                result.append({"id": f"resize-{name}-{step}-dpr{dpr}",
                    "kind": "strict", "width": width, "height": height, "dpr": dpr,
                    "mode": "automatic", "expected_mode": MODES[mode], "touch": True,
                    "geometry": "ordinary", "players": players,
                    "sequence": name, "continuation": step > 0})
    return result


def settle(page, case: dict) -> tuple[dict, dict]:
    deadline = time.monotonic() + 30
    previous = None
    stable = 0
    previous_frame = -1
    while time.monotonic() < deadline:
        observed = page.evaluate("""() => {
            const state = window.pokahdotLayout;
            const canvas = document.querySelector('canvas');
            if (!state || !state.geometry || !canvas) return null;
            const rect = canvas.getBoundingClientRect(), viewport = window.visualViewport;
            return {snapshot: state, environment: {
                inner_size: [innerWidth, innerHeight], device_pixel_ratio: devicePixelRatio,
                max_touch_points: navigator.maxTouchPoints,
                user_agent: navigator.userAgent, platform: navigator.platform,
                canvas_css_rect: [rect.x, rect.y, rect.width, rect.height],
                canvas_backing_size: [canvas.width, canvas.height],
                visual_viewport: viewport ? {width: viewport.width, height: viewport.height,
                    offset_left: viewport.offsetLeft, offset_top: viewport.offsetTop,
                    scale: viewport.scale} : null}};
        }""")
        if observed:
            snapshot = observed["snapshot"]
            signature = json.dumps({key: snapshot[key] for key in (
                "layout_mode", "root_rect", "usable_rect", "regions", "labels",
                "fit_guidance")}, sort_keys=True)
            root = snapshot["root_rect"]
            correct = abs(root[2] - case["width"]) <= 1 and abs(root[3] - case["height"]) <= 1
            settled = snapshot["ready"] or bool(snapshot.get("fit_guidance"))
            if (correct and settled and not snapshot["pending"]
                    and snapshot["frame"] > previous_frame and signature == previous):
                stable += 1
            else:
                stable = 0
            previous = signature
            previous_frame = snapshot["frame"]
            if stable >= 2:
                return snapshot, observed["environment"]
        page.wait_for_timeout(100)
    raise AssertionError(f"Layout did not settle for {case['id']}")


def measure_case(page, base_url: str, work: Path, case: dict, native_font: dict) -> dict:
    page.set_viewport_size({"width": case["width"], "height": case["height"]})
    query = {"geometry": case["geometry"], "players": case.get("players", 6)}
    if case.get("stress"):
        query["stress"] = case["stress"]
    if case["mode"] != "automatic":
        query["mode"] = case["mode"]
    if not case.get("continuation"):
        page.goto(f"{base_url}/index.html?{urlencode(query)}")
    snapshot, environment = settle(page, case)
    failures = check_snapshot(snapshot)["all"]
    if case["kind"] == "strict" and len(snapshot.get("seats", [])) != case.get("players", 6):
        failures.append("fixture: actual seat count differs from requested player count")
    if case["kind"] == "strict" and case.get("expected_mode") in (3, 4):
        for seat in snapshot.get("seats", []):
            if not seat.get("avatar", {}).get("visible"):
                failures.append(f"avatar: seat {seat['seat']} omits its assigned avatar")
    failures.extend(check_geometry(snapshot, environment, case["geometry"]))
    failures.extend(check_default_font_metrics(snapshot, native_font))
    if case.get("stress") == "font":
        failures.extend(check_font_stress_copy(snapshot))
    if snapshot.get("classified_mode") != case.get(
            "expected_mode", snapshot.get("classified_mode")):
        failures.append("classification: observed mode differs from requested/automatic mode")
    if abs(environment["device_pixel_ratio"] - case["dpr"]) > 0.0001:
        failures.append("environment: browser DPR differs from requested DPR")
    if case.get("touch") and environment["max_touch_points"] <= 0:
        failures.append("environment: phone/tablet fixture has no touch capability")
    failures = list(dict.fromkeys(failures))
    screenshot = work / f"{case['id']}.png"
    page.screenshot(path=str(screenshot))
    return {**case, "requested_css_size": [case["width"], case["height"]],
            "actual_dpr": environment["device_pixel_ratio"], "environment": environment,
            "snapshot": snapshot, "failures": failures, "screenshot": screenshot.name,
            "screenshot_sha256": sha256(screenshot)}


def measure(browser, base_url: str, work: Path, cases: list[dict],
            native_font: dict) -> tuple[list[dict], list[str]]:
    results = []
    browser_errors: list[str] = []
    for dpr, touch in sorted({(case["dpr"], case.get("touch", False)) for case in cases}):
        selected = [case for case in cases if case["dpr"] == dpr and case.get("touch", False) == touch]
        context = browser.new_context(viewport={"width": selected[0]["width"],
                                      "height": selected[0]["height"]},
                                      device_scale_factor=dpr, has_touch=touch)
        page = context.new_page()
        case_errors: list[str] = []
        page.on("pageerror", lambda error: case_errors.append(str(error)))
        page.on("console", lambda message: case_errors.append(message.text)
                if message.type == "error" else None)
        page.set_default_timeout(30000)
        sequence_identity = None
        try:
            for case in selected:
                before = len(case_errors)
                result = measure_case(page, base_url, work, case, native_font)
                if case.get("sequence"):
                    identity = {"seats": [(seat["seat"], seat["name"], seat["stack"], seat["wager"])
                                          for seat in result["snapshot"]["seats"]],
                                "draft": result["snapshot"].get("wager_draft")}
                    if case.get("continuation") and identity != sequence_identity:
                        result["failures"].append("resize: table state or wager draft changed")
                    sequence_identity = identity
                result["browser_errors"] = case_errors[before:]
                if result["browser_errors"]:
                    result["failures"].append("browser: console or page error")
                results.append(result)
                print(f"{case['id']}: {len(result['failures'])} failures", flush=True)
        finally:
            browser_errors.extend(case_errors)
            context.close()
    return results, browser_errors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, default=ROOT / "localtmp" / "web-layout")
    parser.add_argument("--quick", action="store_true", help="Run one strict phone case pair")
    parser.add_argument("--strict", action="store_true",
                        help="Fail when a supported strict case fails")
    parser.add_argument("--transitions-only", action="store_true",
                        help="Check retained table state across browser resize/rotation")
    args = parser.parse_args()
    work = args.output.resolve()
    work.mkdir(parents=True, exist_ok=False)
    source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                         text=True).strip()
    source_diff_sha256 = hashlib.sha256(
        subprocess.check_output(["git", "diff", "HEAD"], cwd=ROOT)).hexdigest()
    output = export_fixture(args.godot, work,
                            main_scene="res://tests/web/layout_fixture.tscn",
                            support_files=SUPPORT)
    native_font = native_default_font_metrics(args.godot)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
        functools.partial(QuietHandler, directory=str(output)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    cases = resize_cases() if args.transitions_only else (
        strict_cases(args.quick) + diagnostic_cases(args.quick)
        + ([] if args.quick else resize_cases()))
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(args=["--enable-unsafe-swiftshader"])
            browser_version = browser.version
            results, browser_errors = measure(
                browser, f"http://127.0.0.1:{server.server_port}", work, cases, native_font)
            browser.close()
        document = {"schema_version": 3, "suite": "exported_replacement_layout_v3",
            "mode": "strict" if args.strict else "report",
            "acceptance": "browser emulation only; not physical-device acceptance",
            "captured_utc": datetime.now(timezone.utc).isoformat(),
            "browser": browser_version,
            "engine": subprocess.check_output([args.godot, "--version"], text=True).strip(),
            "requested_dprs": list((1,) if args.quick else DPRS),
            "source_sha": source_sha, "source_diff_sha256": source_diff_sha256,
            "measurement_runner_sha256": sha256(Path(__file__)),
            "checker_sha256": sha256(ROOT / "tools/web_layout_assertions.py"),
            "geometry_checker_sha256": sha256(ROOT / "tools/web_geometry_assertions.py"),
            "native_default_font_metrics": native_font,
            "fixture_files_sha256": {path: sha256(ROOT / path) for path in
                (*SUPPORT, "tests/web/layout_fixture.gd", "tests/web/layout_fixture.tscn")},
            "copied_project_sha256": (work / "source.sha256").read_text().strip(),
            "exported_pack_sha256": sha256(output / "index.pck"),
            "browser_errors": browser_errors, "cases": results}
        (work / "results.json").write_text(json.dumps(document, indent=2) + "\n")
        failed = [case["id"] for case in results
                  if case["kind"] == "strict" and case["failures"]]
        diagnostic_failed = [case["id"] for case in results
                             if case["kind"] == "report_only" and case["failures"]]
        print(f"Checked {len(results)} exported cases; {len(failed)} strict failures; "
              f"{len(diagnostic_failed)} report-only failures; evidence: {work}")
        if args.strict and (failed or browser_errors):
            raise SystemExit(1)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
