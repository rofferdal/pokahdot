#!/usr/bin/env python3
"""Capture exploratory exported-browser layout evidence without accepting defects.

CSS sizes below are new test environments, not reconstructed capture metadata.
Report mode retains all invariant failures and returns success for a completed
measurement run. Browser/engine errors still fail. Artifacts remain in localtmp.
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

from playwright.sync_api import sync_playwright

from run_web_input_tests import ROOT, QuietHandler, export_fixture
from web_layout_assertions import check_snapshot, clockwise_order

# Includes classifier/legacy sizing boundaries and independently chosen controls.
EXPLORATORY_SIZES = (
    (950, 532), (1024, 600), (1099, 759), (1100, 759),
    (1194, 696), (1199, 800), (1200, 800), (1201, 800),
    (1247, 636), (1280, 720), (1300, 760), (1369, 724),
    (1377, 777), (1440, 900), (1855, 918), (1920, 1080),
    (768, 1024), (1024, 768),
)
DPR_CONTROLS = ((1280, 720), (1369, 724), (1440, 900), (1024, 768))
SUPPORT = (
    "tests/support/gui_browser_capture_fixture.gd",
    "tests/support/gui_invariant_assertions.gd",
    "tests/support/gui_snapshot_content_assertions.gd",
    "tests/support/gui_snapshot_region_assertions.gd",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def settle(page, width: int, height: int) -> dict:
    deadline = time.monotonic() + 30
    previous = None
    stable = 0
    previous_frame = -1
    while time.monotonic() < deadline:
        snapshot = page.evaluate("window.pokahdotLayout || null")
        if snapshot:
            table = snapshot["root_rect"]
            signature = json.dumps({key: snapshot[key] for key in (
                "profile", "root_rect", "usable_rect",
                "regions", "labels")}, sort_keys=True)
            correct_size = abs(table[2] - width) <= 1 and abs(table[3] - height) <= 1
            if correct_size and snapshot["ready"] and not snapshot["pending"] and snapshot["frame"] > previous_frame:
                stable = stable + 1 if signature == previous else 0
                previous = signature
                previous_frame = snapshot["frame"]
                if stable >= 2:
                    return snapshot
        page.wait_for_timeout(100)
    raise AssertionError(f"Layout did not settle at CSS {width}x{height}")


def measure(browser, url: str, work: Path, sizes, dpr: int) -> list[dict]:
    context = browser.new_context(viewport={"width": sizes[0][0], "height": sizes[0][1]},
                                  device_scale_factor=dpr)
    page = context.new_page()
    errors: list[str] = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)
    cases = []
    try:
        page.goto(url + "/index.html")
        for index, (width, height) in enumerate(sizes):
            page.set_viewport_size({"width": width, "height": height})
            snapshot = settle(page, width, height)
            environment = page.evaluate("""() => {
                const canvas = document.querySelector('canvas');
                const rect = canvas.getBoundingClientRect();
                const viewport = window.visualViewport;
                return {inner_width: innerWidth, inner_height: innerHeight,
                    device_pixel_ratio: devicePixelRatio, user_agent: navigator.userAgent,
                    platform: navigator.platform, max_touch_points: navigator.maxTouchPoints,
                    secure_context: isSecureContext,
                    canvas_css_rect: [rect.x, rect.y, rect.width, rect.height],
                    canvas_backing_size: [canvas.width, canvas.height],
                    visual_viewport: viewport ? {width: viewport.width, height: viewport.height,
                        offset_left: viewport.offsetLeft, offset_top: viewport.offsetTop,
                        scale: viewport.scale} : null,
                    screen: {width: screen.width, height: screen.height},
                    browser_zoom: 'not independently measured',
                    safe_area_insets: 'not independently measured',
                    browser_chrome: 'headless automation; physical chrome not measured'};
            }""")
            name = f"dpr{dpr}-{index:02d}-{width}x{height}"
            screenshot = work / (name + ".png")
            page.screenshot(path=str(screenshot))
            order = clockwise_order(snapshot)
            cases.append({"case": name, "environment_kind": "exploratory automation",
                          "environment": environment, "snapshot": snapshot,
                          "clockwise_order": order, "clockwise_expected": list(range(6)),
                          "clockwise_passed": order == list(range(6)),
                          "checks": check_snapshot(snapshot),
                          "screenshot": screenshot.name, "screenshot_sha256": sha256(screenshot)})
            print(f"{name}: {len(snapshot['invariant_failures'])} invariant failures; order {order}",
                  flush=True)
        if errors:
            raise AssertionError("Browser errors: " + "\n".join(errors))
        return cases
    finally:
        (work / f"dpr{dpr}-browser-errors.json").write_text(json.dumps(errors, indent=2))
        (work / f"dpr{dpr}-cases.json").write_text(json.dumps(cases, indent=2))
        context.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, default=ROOT / "localtmp" / "web-layout")
    parser.add_argument("--quick", action="store_true", help="Measure three exploratory sizes only")
    parser.add_argument("--strict", action="store_true",
                        help="Exit nonzero after retaining the complete report if selected checks fail")
    parser.add_argument("--check", choices=("all", "geometry", "content", "order"), default="all")
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    source_diff_sha256 = hashlib.sha256(
        subprocess.check_output(["git", "diff", "HEAD"], cwd=ROOT)).hexdigest()
    output = export_fixture(args.godot, args.output,
                            main_scene="res://tests/web/layout_fixture.tscn", support_files=SUPPORT)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
        functools.partial(QuietHandler, directory=str(output)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(args=["--enable-unsafe-swiftshader"])
            sizes = ((1280, 720), (1369, 724), (1920, 1080)) if args.quick else EXPLORATORY_SIZES
            # Same live state crosses profiles in both directions; repeated sizes are deliberate.
            sequence = tuple(sizes) + tuple(reversed(sizes[:-1]))
            cases = measure(browser, f"http://127.0.0.1:{server.server_port}", args.output,
                            sequence, 1)
            if not args.quick:
                cases += measure(browser, f"http://127.0.0.1:{server.server_port}", args.output,
                                 DPR_CONTROLS, 2)
            version = browser.version
            browser.close()
        document = {
            "suite": "exported_web_layout_evidence_v2",
            "mode": "strict" if args.strict else "report", "selected_check": args.check,
            "measurement_runner_sha256": sha256(Path(__file__)),
            "checker_sha256": sha256(ROOT / "tools/web_layout_assertions.py"),
            "acceptance": "not established; invariant/order failures retained",
            "captured_utc": datetime.now(timezone.utc).isoformat(), "browser": version,
            "historical_metadata": "Original builds, CSS viewports, DPR, zoom and iPad identity unknown",
            "source_sha": source_sha,
            "source_diff_sha256": source_diff_sha256,
            "fixture_files_sha256": {path: sha256(ROOT / path) for path in
                (*SUPPORT, "tests/web/layout_fixture.gd", "tests/web/layout_fixture.tscn")},
            "copied_project_sha256": (args.output / "source.sha256").read_text(),
            "exported_pack_sha256": sha256(output / "index.pck"),
            "cases": cases,
        }
        (args.output / "results.json").write_text(json.dumps(document, indent=2))
        failed = [case["case"] for case in cases if case["checks"][args.check]]
        print(f"Captured {len(cases)} environments/transitions; "
              f"{len(failed)} fail {args.check}; evidence: {args.output}")
        if args.strict and failed:
            raise SystemExit(1)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
