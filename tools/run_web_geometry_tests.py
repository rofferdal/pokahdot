#!/usr/bin/env python3
"""Check real exported Window/CSS conversions, output floors and inset fixtures."""
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

from playwright.sync_api import sync_playwright

from run_web_input_tests import ROOT, QuietHandler, export_fixture
from run_web_layout_tests import SUPPORT
from web_geometry_assertions import check_geometry


def settle(page) -> tuple[dict, dict]:
    """Observe bounded stable snapshots, including inset-adjusted table roots."""
    previous = None
    stable = 0
    previous_frame = -1
    for _attempt in range(300):
        observed = page.evaluate("""() => {
            const state = window.pokahdotLayout;
            if (!state || !state.geometry) return null;
            const c = document.querySelector('canvas'), r = c.getBoundingClientRect();
            return {snapshot:state, environment:{canvas_css_rect:[r.x,r.y,r.width,r.height],
                canvas_backing_size:[c.width,c.height],inner_size:[innerWidth,innerHeight],
                device_pixel_ratio:devicePixelRatio,user_agent:navigator.userAgent}};
        }""")
        if observed:
            snapshot = observed["snapshot"]
            signature = json.dumps({key: snapshot[key] for key in
                                    ("geometry", "usable_rect", "regions", "labels")}, sort_keys=True)
            current_backing = observed["environment"]["canvas_backing_size"]
            window_current = snapshot["geometry"]["window"]["size"] == current_backing
            if (snapshot["ready"] and not snapshot["pending"] and window_current
                    and snapshot["frame"] > previous_frame and signature == previous):
                stable += 1
            else:
                stable = 0
            previous = signature
            previous_frame = snapshot["frame"]
            if stable >= 2:
                return snapshot, observed["environment"]
        page.wait_for_timeout(100)
    raise AssertionError("Exported geometry did not settle within 30 seconds")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, default=ROOT / "localtmp/web-geometry")
    args = parser.parse_args()
    work = args.output.resolve()
    work.mkdir(parents=True, exist_ok=False)
    output = export_fixture(args.godot, work,
                            main_scene="res://tests/web/layout_fixture.tscn", support_files=SUPPORT)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
        functools.partial(QuietHandler, directory=str(output)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    measurements = []
    errors = []
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(args=["--enable-unsafe-swiftshader"])
            browser_version = browser.version
            for dpr in (1, 2, 2.625, 3):
                context = browser.new_context(viewport={"width": 1280, "height": 720},
                                              device_scale_factor=dpr)
                page = context.new_page()
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)
                for preset in ("ordinary", "asymmetric", "safe-and-visual", "asymmetric-keypad"):
                    page.goto(f"http://127.0.0.1:{server.server_port}/index.html?geometry={preset}&players=2")
                    sizes = ((1280, 720), (1920, 1080), (390, 844)) if preset == "ordinary" else ((390, 844),)
                    for width, height in sizes:
                        page.set_viewport_size({"width": width, "height": height})
                        try:
                            snapshot, environment = settle(page)
                        except AssertionError:
                            (work / f"failure-dpr{dpr}-{preset}.json").write_text(json.dumps({
                                "browser_errors": errors,
                                "last_snapshot": page.evaluate("window.pokahdotLayout || null"),
                            }, indent=2) + "\n")
                            raise
                        failures = check_geometry(snapshot, environment, preset)
                        identity = f"dpr{dpr}-{preset}-{width}x{height}"
                        page.screenshot(path=str(work / f"{identity}.png"))
                        measurements.append({"id": identity, "preset": preset,
                            "requested_css_size": [width, height], "requested_dpr": dpr,
                            "environment": environment, "snapshot": snapshot, "failures": failures})
                        print(f"{identity}: {len(failures)} failures", flush=True)
                context.close()
            browser.close()
        report = {"schema_version": 1, "suite": "exported_viewport_geometry_v1",
            "captured_utc": datetime.now(timezone.utc).isoformat(), "browser": browser_version,
            "engine": subprocess.check_output([args.godot, "--version"], text=True).strip(),
            "measurement_runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "checker_sha256": hashlib.sha256((ROOT / "tools/web_geometry_assertions.py").read_bytes()).hexdigest(),
            "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
            "copied_project_sha256": (work / "source.sha256").read_text(),
            "exported_pack_sha256": hashlib.sha256((output / "index.pck").read_bytes()).hexdigest(),
            "limitations": "Headless browser automation; injected presets are not physical keyboard/safe-area evidence.",
            "browser_errors": errors, "measurements": measurements}
        (work / "results.json").write_text(json.dumps(report, indent=2) + "\n")
        failed = [case["id"] for case in measurements if case["failures"]]
        if errors or failed:
            raise SystemExit(f"Geometry failures: {failed}; browser errors: {errors}")
        print(f"All {len(measurements)} exported geometry cases passed; evidence: {work}")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
