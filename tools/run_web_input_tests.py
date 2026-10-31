#!/usr/bin/env python3
"""Export an isolated production GUI fixture and exercise real browser input.

Requires requirements-web-test.txt, Playwright Chromium, and matching Godot Web
templates. All project copies, exports, logs and screenshots live in localtmp.
The observer is absent from the production export; it offers no input API.
"""

from __future__ import annotations

import argparse
import functools
import http.server
import hashlib
import json
import shutil
import subprocess
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]


def export_fixture(godot: str, work: Path,
                   main_scene: str = "res://tests/web/input_fixture.tscn",
                   support_files: tuple[str, ...] = ()) -> Path:
    project = work / "project"
    project.mkdir()
    for directory in ("scripts", "scenes", "resources", "assets"):
        shutil.copytree(ROOT / directory, project / directory)
    shutil.copytree(ROOT / "tests" / "web", project / "tests" / "web",
                    ignore=shutil.ignore_patterns("layout_fixture.*")
                    if main_scene != "res://tests/web/layout_fixture.tscn" else None)
    for relative_path in support_files:
        destination = project / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative_path, destination)
    shutil.copy2(ROOT / "icon.svg", project)
    config = (ROOT / "project.godot").read_text()
    config = config.replace('run/main_scene="res://scenes/main.tscn"',
                            f'run/main_scene="{main_scene}"')
    config = "\n".join(line for line in config.splitlines() if "boot_splash/image=" not in line)
    (project / "project.godot").write_text(config)
    preset = (ROOT / "export_presets.cfg").read_text()
    preset = preset.replace("tests/*,tests/**/*,", "")
    (project / "export_presets.cfg").write_text(preset)
    output = work / "export"
    output.mkdir()
    source_hash = hashlib.sha256()
    for path in sorted(project.rglob("*")):
        if path.is_file():
            source_hash.update(str(path.relative_to(project)).encode())
            source_hash.update(b"\0")
            source_hash.update(path.read_bytes())
    (work / "source.sha256").write_text(source_hash.hexdigest())
    with (work / "export.log").open("w") as log:
        for arguments in (("--import",), ("--export-release", "Web", str(output / "index.html"))):
            subprocess.run([godot, "--headless", "--path", str(project), *arguments],
                           stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
    log_text = (work / "export.log").read_text()
    if "ERROR:" in log_text or "SCRIPT ERROR:" in log_text:
        raise RuntimeError(f"Godot reported export/import errors; see {work / 'export.log'}")
    return output


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args: object) -> None:
        pass


def exercise(browser, base_url: str, work: Path, fixture: str, mobile: bool) -> dict:
    context = browser.new_context(viewport={"width": 390 if mobile else 1280,
                                           "height": 844 if mobile else 720},
                                  device_scale_factor=2 if mobile else 1,
                                  has_touch=mobile, is_mobile=mobile)
    page = context.new_page()
    errors: list[str] = []
    messages: list[str] = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
    page.on("console", lambda message: messages.append(message.type + ": " + message.text))
    name = f"{fixture}-{'touch' if mobile else 'pointer'}"
    page.set_default_timeout(20000)

    def wait(expression: str) -> dict:
        page.wait_for_function("window.pokahdotInput && (" + expression + ")")
        return page.evaluate("window.pokahdotInput")

    def click(key: str, touch: bool = mobile) -> None:
        state = wait(f"window.pokahdotInput.controls.{key}?.visible")
        x, y, width, height = state["controls"][key]["rect"]
        canvas = page.locator("canvas").bounding_box()
        assert canvas is not None
        point = (canvas["x"] + (x + width / 2) * canvas["width"] / state["viewport"][0],
                 canvas["y"] + (y + height / 2) * canvas["height"] / state["viewport"][1])
        if touch:
            page.touchscreen.tap(*point)
        else:
            page.mouse.click(*point)

    try:
        page.goto(base_url + "/index.html?" + fixture)
        wait("window.pokahdotInput.frame > 10")
        if fixture == "table-showdown":
            state = wait("window.pokahdotInput.hand_complete && window.pokahdotInput.result_visible")
            assert state["winner_names"], "Real settlement must identify at least one winner"
            for winner_name in state["winner_names"]:
                assert winner_name in state["result_text"], state["result_text"]
            assert state["result_button"] in ("More", "More / Pots", "…")
            assert not state["summary_open"], "Result must be visible with the cards"
            hand_number = state["hand_number"]
            click("PhoneMoreButton")
            wait("window.pokahdotInput.menu")
            click("PhoneMenuSummaryButton")
            state = wait("window.pokahdotInput.summary_open")
            for winner_name in state["winner_names"]:
                assert winner_name in state["summary_text"]
            click("PhoneShowdownCloseButton")
            state = wait("!window.pokahdotInput.summary_open && window.pokahdotInput.more_focus")
            assert state["hand_number"] == hand_number
            assert state["result_visible"]
        elif not mobile:
            click("input", False)
            wait("window.pokahdotInput.focus")
            page.keyboard.press("ControlOrMeta+A")
            page.keyboard.type("250")
            wait("window.pokahdotInput.input === '250' && !window.pokahdotInput.popup")
            if fixture == "table":
                page.keyboard.press("Enter")
                wait("window.pokahdotInput.hero_wager === 250")
        else:
            if fixture == "table":
                history = page.evaluate("window.pokahdotInput.history_count")
                click("PhoneMoreButton")
                wait("window.pokahdotInput.menu && window.pokahdotInput.modal_focus")
                click("FoldButton")
                assert page.evaluate("window.pokahdotInput.history_count") == history
                wait("!window.pokahdotInput.menu")
                click("PhoneMoreButton")
                wait("window.pokahdotInput.menu && window.pokahdotInput.modal_focus")
                for _ in range(6):
                    page.keyboard.press("Tab")
                    wait("window.pokahdotInput.modal_focus")
                click("PhoneMenuQuitButton")
                wait("window.pokahdotInput.quit_confirmation && !window.pokahdotInput.menu")
                page.keyboard.press("Escape")
                wait("!window.pokahdotInput.quit_confirmation && window.pokahdotInput.more_focus")
                assert page.evaluate("window.pokahdotInput.history_count") == history
            original = page.evaluate("window.pokahdotInput.input")
            click("open")
            wait("window.pokahdotInput.popup && !window.pokahdotInput.keypad_has_quit")
            click("KeyClear")
            click("Key2")
            wait("window.pokahdotInput.draft === '2'")
            assert page.evaluate("window.pokahdotInput.input") == original
            page.keyboard.press("Escape")
            wait("!window.pokahdotInput.popup")
            assert page.evaluate("window.pokahdotInput.input") == original
            if fixture == "table":
                # Explicitly discard keypad edits, then use the tournament menu.
                click("open")
                wait("window.pokahdotInput.popup && !window.pokahdotInput.keypad_has_quit")
                click("KeyClear")
                click("Key2")
                click("Cancel")
                wait("!window.pokahdotInput.popup")
                assert page.evaluate("window.pokahdotInput.input") == original
                click("PhoneMoreButton")
                wait("window.pokahdotInput.menu")
                click("PhoneMenuQuitButton")
                wait("window.pokahdotInput.quit_confirmation && !window.pokahdotInput.menu")
                page.keyboard.press("Escape")
                wait("!window.pokahdotInput.quit_confirmation && window.pokahdotInput.more_focus")
                assert page.evaluate("window.pokahdotInput.input") == original
                page.set_viewport_size({"width": 1280, "height": 720})
                wait("window.pokahdotInput.viewport[0] === 1280")
                click("open")
                wait("window.pokahdotInput.popup")
                click("KeyClear")
                click("Key2")
                history = page.evaluate("window.pokahdotInput.history_count")
                click("FoldButton")
                wait("window.pokahdotInput.frame > " + str(page.evaluate("window.pokahdotInput.frame") + 2))
                assert page.evaluate("window.pokahdotInput.history_count") == history
                assert page.evaluate("window.pokahdotInput.input") == original
                if page.evaluate("window.pokahdotInput.popup"):
                    click("Cancel")
                wait("!window.pokahdotInput.popup")
                page.set_viewport_size({"width": 390, "height": 844})
                wait("window.pokahdotInput.viewport[0] === 390")
            else:
                for original_text in ("invalid", "", "   "):
                    click("input", False)
                    wait("window.pokahdotInput.focus && !window.pokahdotInput.popup")
                    page.keyboard.press("ControlOrMeta+A")
                    page.keyboard.press("Backspace")
                    if original_text:
                        page.keyboard.type(original_text)
                    wait("window.pokahdotInput.input === " + json.dumps(original_text))
                    click("open")
                    wait("window.pokahdotInput.popup")
                    click("KeyClear")
                    click("Key2")
                    click("Cancel")
                    wait("!window.pokahdotInput.popup")
                    assert page.evaluate("window.pokahdotInput.input") == original_text
            click("open")
            wait("window.pokahdotInput.popup && !window.pokahdotInput.keypad_has_quit")
            click("KeyClear")
            click("Key2")
            click("Key5")
            wait("window.pokahdotInput.draft === '25'")
            click("Done")
            wait("!window.pokahdotInput.popup && window.pokahdotInput.input === '25'")
            if fixture == "table":
                wait("window.pokahdotInput.hero_wager === 25")
            else:
                # Switch from touch back to real pointer/keyboard editing.
                click("input", False)
                wait("window.pokahdotInput.focus && !window.pokahdotInput.popup")
                page.keyboard.press("ControlOrMeta+A")
                page.keyboard.type("250")
                wait("window.pokahdotInput.input === '250'")
        page.screenshot(path=str(work / (name + ".png")))
        assert not errors, "Browser errors: " + "\n".join(errors)
        return {"case": name, "passed": True, "snapshot": page.evaluate("window.pokahdotInput")}
    except Exception:
        page.screenshot(path=str(work / (name + "-failed.png")))
        (work / (name + "-errors.json")).write_text(json.dumps(errors, indent=2))
        (work / (name + "-console.json")).write_text(json.dumps(messages, indent=2))
        raise
    finally:
        context.close()


def exercise_tablet_presets(browser, base_url: str, work: Path,
                            portrait: bool, preset: str) -> dict:
    """Tap real inline presets after rotating a six-player tablet tournament."""
    target = {"width": 834, "height": 1030} if portrait else {"width": 1194, "height": 676}
    initial = {"width": 1194, "height": 676} if portrait else {"width": 834, "height": 1030}
    context = browser.new_context(viewport=initial, device_scale_factor=2,
                                  has_touch=True, is_mobile=True)
    page = context.new_page()
    errors: list[str] = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("console", lambda message: errors.append(message.text)
            if message.type == "error" else None)
    page.set_default_timeout(30000)
    name = f"tablet-{preset}-{'portrait' if portrait else 'landscape'}"

    def wait(expression: str) -> dict:
        page.wait_for_function("window.pokahdotInput && (" + expression + ")")
        return page.evaluate("window.pokahdotInput")

    try:
        page.goto(base_url + "/index.html?table-presets")
        state = wait("window.pokahdotInput.frame > 20 && "
                     "window.pokahdotInput.controls.MinimumButton?.visible && "
                     "window.pokahdotInput.controls.PotButton?.visible")
        assert state["avatar_count"] == 6
        history, draft, hand = state["history_count"], state["raw_draft"], state["hand_number"]
        page.set_viewport_size(target)
        state = wait(f"window.pokahdotInput.viewport[0] === {target['width']} && "
                     f"window.pokahdotInput.viewport[1] === {target['height']} && "
                     "window.pokahdotInput.controls.MinimumButton?.visible && "
                     "window.pokahdotInput.controls.PotButton?.visible")
        assert state["layout_mode"] == 3 and state["avatar_count"] == 6
        assert state["history_count"] == history and state["raw_draft"] == draft
        assert state["hand_number"] == hand
        control = state["controls"]["MinimumButton" if preset == "minimum" else "PotButton"]
        assert control["enabled"]
        x, y, width, height = control["rect"]
        assert width >= 48 and height >= 48
        canvas = page.locator("canvas").bounding_box()
        assert canvas is not None
        expected = state["minimum_total" if preset == "minimum" else "pot_total"]
        page.touchscreen.tap(canvas["x"] + (x + width / 2) * canvas["width"] / target["width"],
                             canvas["y"] + (y + height / 2) * canvas["height"] / target["height"])
        after = wait(f"window.pokahdotInput.hero_wager === {expected} && "
                     f"window.pokahdotInput.history_count === {history + 1}")
        assert not after["popup"] and not after["menu"]
        assert not errors, errors
        page.screenshot(path=str(work / (name + ".png")))
        return {"case": name, "passed": True, "submitted_street_total": expected}
    except Exception:
        page.screenshot(path=str(work / (name + "-failed.png")))
        (work / (name + "-errors.json")).write_text(json.dumps(errors, indent=2))
        raise
    finally:
        context.close()


def exercise_live_phone(browser, base_url: str, work: Path) -> dict:
    """Play through paced bots and settlement; the observer counts transient warnings."""
    context = browser.new_context(viewport={"width": 360, "height": 780},
                                  device_scale_factor=3, has_touch=True, is_mobile=True)
    page = context.new_page()
    page.set_default_timeout(30000)
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
    try:
        page.goto(base_url + "/index.html?table&phone-live")
        actions = 0
        while actions < 12:
            page.wait_for_function("window.pokahdotLive?.ready && "
                                   "!window.pokahdotLive.pending && window.pokahdotLive.human_turn")
            state = page.evaluate("window.pokahdotLive")
            assert state["warning_frames"] == 0, state
            if state["hand"] >= 2:
                break
            control = state["controls"]["check_call"]
            assert control["visible"] and control["enabled"], state
            x, y, width, height = control["rect"]
            canvas = page.locator("canvas").bounding_box()
            assert canvas is not None
            page.touchscreen.tap(canvas["x"] + (x + width / 2) * canvas["width"] / state["viewport"][0],
                                 canvas["y"] + (y + height / 2) * canvas["height"] / state["viewport"][1])
            page.wait_for_function("s => window.pokahdotLive.hand !== s.hand || "
                                   "window.pokahdotLive.history !== s.history", arg=state)
            actions += 1
        assert state["hand"] >= 2, state
        assert actions >= 4, actions
        # Ready bot frames depend on rendering speed versus pacing. Reaching
        # hand two proves bot progression; warning_frames observes every frame.
        assert not errors, errors
        page.screenshot(path=str(work / "phone-live-next-hand.png"))
        return {"case": "phone-live-inset-start-actions-next-hand", "passed": True,
                "human_actions": actions, "snapshot": state}
    except Exception:
        page.screenshot(path=str(work / "phone-live-failed.png"))
        (work / "phone-live-failed.json").write_text(json.dumps({
            "snapshot": page.evaluate("window.pokahdotLive || null"),
            "browser_errors": errors,
        }, indent=2) + "\n")
        raise
    finally:
        context.close()


def exercise_fullscreen(browser, base_url: str, work: Path, supported: bool, landscape: bool = False) -> dict:
    """Use actual Start/menu taps; the observer exposes no input API."""
    dimensions = {"width": 780, "height": 360} if landscape else {"width": 360, "height": 780}
    context = browser.new_context(viewport=dimensions,
                                  screen=dimensions,
                                  device_scale_factor=3, has_touch=True, is_mobile=True)
    if not supported:
        context.add_init_script("Object.defineProperty(Element.prototype, 'requestFullscreen', "
                                "{value: undefined}); "
                                "Object.defineProperty(Element.prototype, 'webkitRequestFullscreen', "
                                "{value: undefined}); "
                                "Object.defineProperty(document, 'webkitFullscreenEnabled', "
                                "{get: () => false}); "
                                "Object.defineProperty(document, 'fullscreenEnabled', "
                                "{get: () => false});")
    page = context.new_page()
    errors: list[str] = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.set_default_timeout(30000)

    def wait(expression: str) -> dict:
        page.wait_for_function("window.pokahdotFullscreen && (" + expression + ")")
        return page.evaluate("window.pokahdotFullscreen")

    def click(key: str) -> None:
        state = wait(f"window.pokahdotFullscreen.controls.{key}?.visible")
        x, y, width, height = state["controls"][key]["rect"]
        canvas = page.locator("canvas").bounding_box()
        assert canvas is not None
        page.touchscreen.tap(canvas["x"] + (x + width / 2) * canvas["width"] / state["viewport"][0],
                             canvas["y"] + (y + height / 2) * canvas["height"] / state["viewport"][1])

    try:
        page.goto(base_url + "/index.html?fullscreen")
        wait("window.pokahdotFullscreen.frame > 20 && window.pokahdotFullscreen.ready")
        click("start")
        state = wait("window.pokahdotFullscreen.playing && window.pokahdotFullscreen.ready && "
                     "!window.pokahdotFullscreen.pending && window.pokahdotFullscreen.human_turn")
        if supported:
            page.wait_for_function("!!document.fullscreenElement")
            page.evaluate("document.exitFullscreen()")
            page.wait_for_function("!document.fullscreenElement")
            wait(f"window.pokahdotFullscreen.frame > {state['frame'] + 8} && "
                 "window.pokahdotFullscreen.ready && !window.pokahdotFullscreen.pending")
            click("more")
            click("menu_fullscreen")
            page.wait_for_function("!!document.fullscreenElement")
            after = wait("window.pokahdotFullscreen.ready && !window.pokahdotFullscreen.pending")
            assert after["hand"] == state["hand"]
            assert after["history"] == state["history"]
            assert after["draft"] == state["draft"]
        else:
            assert not page.evaluate("!!document.fullscreenElement")
            click("more")
            click("menu_close")
        assert not errors, errors
        name = "phone-fullscreen" if supported else "phone-fullscreen-unavailable"
        if landscape:
            name += "-landscape"
        page.screenshot(path=str(work / (name + ".png")))
        return {"case": name, "passed": True}
    finally:
        context.close()


def exercise_replacement(browser, base_url: str, work: Path) -> dict:
    """Drive the replacement only through canvas input and its semantic observer."""
    context = browser.new_context(viewport={"width": 1000, "height": 1000},
                                  device_scale_factor=2, has_touch=True, is_mobile=True)
    page = context.new_page()
    errors: list[str] = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("console", lambda message: errors.append(message.text)
            if message.type == "error" else None)
    page.set_default_timeout(20000)

    def wait(expression: str) -> dict:
        page.wait_for_function("window.pokahdotReplacementCheck && (" + expression + ")")
        return page.evaluate("window.pokahdotReplacementCheck")

    def click(key: str) -> None:
        state = wait(f"window.pokahdotReplacementCheck.controls.{key}?.visible")
        x, y, width, height = state["controls"][key]["rect"]
        canvas = page.locator("canvas").bounding_box()
        assert canvas is not None
        page.touchscreen.tap(canvas["x"] + (x + width / 2) * canvas["width"] / 1000,
                             canvas["y"] + (y + height / 2) * canvas["height"] / 1000)

    try:
        page.goto(base_url + "/index.html")
        state = wait("window.pokahdotReplacementCheck.frame > 20 && "
                     "window.pokahdotReplacementCheck.ready && "
                     "!window.pokahdotReplacementCheck.pending")
        assert len(state["cards"]) == 4
        assert all(card["font_size"] >= 20 for card in state["cards"])
        assert state["back"]["rank"] == "" and state["back"]["suit"] == ""
        click("more")
        wait("window.pokahdotReplacementCheck.overlay === 'menu'")
        click("menu_close")
        wait("window.pokahdotReplacementCheck.overlay === ''")
        original = page.evaluate("window.pokahdotReplacementCheck.raw_draft")
        click("wager")
        wait("window.pokahdotReplacementCheck.overlay === 'number'")
        click("clear")
        click("key2")
        wait("window.pokahdotReplacementCheck.keypad_draft === '2'")
        assert page.evaluate("window.pokahdotReplacementCheck.raw_draft") == original
        click("cancel")
        wait("window.pokahdotReplacementCheck.overlay === ''")
        assert page.evaluate("window.pokahdotReplacementCheck.raw_draft") == original
        click("wager")
        click("clear")
        click("key2")
        click("done")
        wait("window.pokahdotReplacementCheck.overlay === '' && "
             "window.pokahdotReplacementCheck.raw_draft === '2'")
        page.screenshot(path=str(work / "replacement-touch.png"))
        assert not errors, "Browser errors: " + "\n".join(errors)
        return {"case": "replacement-touch", "passed": True,
                "snapshot": page.evaluate("window.pokahdotReplacementCheck")}
    except Exception:
        page.screenshot(path=str(work / "replacement-touch-failed.png"))
        (work / "replacement-touch-errors.json").write_text(json.dumps(errors, indent=2))
        raise
    finally:
        context.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, default=ROOT / "localtmp" / "web-input")
    args = parser.parse_args()
    # Refuse stale evidence instead of silently testing an older export.
    args.output.mkdir(parents=True, exist_ok=False)
    output = export_fixture(args.godot, args.output.resolve())
    replacement_work = args.output / "replacement-check"
    replacement_work.mkdir()
    replacement_output = export_fixture(
        args.godot,
        replacement_work.resolve(),
        "res://tests/performance/gui_replacement_web_check.tscn",
        (
            "tests/performance/gui_replacement_web_check.gd",
            "tests/performance/gui_replacement_web_check.tscn",
            "tests/performance/profiled_replacement_table.gd",
        ),
    )
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
        functools.partial(QuietHandler, directory=str(output)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(args=["--enable-unsafe-swiftshader"])
            version = browser.version
            results = [exercise(browser, f"http://127.0.0.1:{server.server_port}", args.output,
                                fixture, mobile)
                       for fixture in ("startup", "table") for mobile in (False, True)]
            results.append(exercise(browser, f"http://127.0.0.1:{server.server_port}", args.output,
                                    "table-showdown", True))
            results.append(exercise_live_phone(
                browser, f"http://127.0.0.1:{server.server_port}", args.output))
            results.extend(exercise_fullscreen(browser, f"http://127.0.0.1:{server.server_port}",
                                               args.output, supported)
                           for supported in (True, False))
            results.append(exercise_fullscreen(browser, f"http://127.0.0.1:{server.server_port}",
                                               args.output, True, True))
            results.extend(exercise_tablet_presets(
                browser, f"http://127.0.0.1:{server.server_port}", args.output, portrait, preset)
                for portrait in (False, True) for preset in ("minimum", "pot"))
            replacement_server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
                functools.partial(QuietHandler, directory=str(replacement_output)))
            replacement_thread = threading.Thread(
                target=replacement_server.serve_forever, daemon=True)
            replacement_thread.start()
            try:
                results.append(exercise_replacement(
                    browser,
                    f"http://127.0.0.1:{replacement_server.server_port}",
                    replacement_work,
                ))
            finally:
                replacement_server.shutdown()
                replacement_server.server_close()
            browser.close()
        result_document = {
            "suite": "exported_web_input_v2",
            "browser": version,
            "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
            "source_diff_sha256": hashlib.sha256(subprocess.check_output(["git", "diff", "HEAD"], cwd=ROOT)).hexdigest(),
            "fixture_sha256": hashlib.sha256((ROOT / "tests/web/input_fixture.gd").read_bytes()).hexdigest(),
            "replacement_fixture_sha256": hashlib.sha256(
                (ROOT / "tests/performance/gui_replacement_web_check.gd").read_bytes()
            ).hexdigest(),
            "copied_project_sha256": (args.output / "source.sha256").read_text(),
            "exported_pack_sha256": hashlib.sha256((output / "index.pck").read_bytes()).hexdigest(),
            "cases": results,
        }
        (args.output / "results.json").write_text(json.dumps(result_document, indent=2))
        print(f"Exported Web input: {len(results)} cases passed; evidence: {args.output}")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
