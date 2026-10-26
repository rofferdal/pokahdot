# Local Wi-Fi Web Testing Tasks

Status: Planned — implementation and device verification have not started.
Created: 2026-10-26.

## Goal

Build the current branch as the actual Pokahdot Web game, serve the exported
files on the development computer, and open a LAN URL from phones, tablets,
and other computers on the same Wi-Fi network. Testing must work before a
merge to `main` and without a GitHub Pages deployment.

The existing [`Web` export preset](../export_presets.cfg) is the starting
point. [`make web-release`](../Makefile) currently requires a clean tree and
runs the release gates; it is not a convenient development-server command.
The exported-input test runner builds an instrumented fixture for automation,
so its output must not become the manually tested LAN game.

Tasks are ordered. Mark a task complete only after its implementation and
verification evidence exist. Keep generated exports, logs, certificates and
screenshots under ignored `localtmp/`; do not commit them.

## Tasks

- [ ] **LAN-01 — Define the local development workflow.**
  Specify separate build, serve, rebuild and stop commands, with configurable
  Godot executable, export directory, network interface/bind address and port.
  Support feature branches and identify any uncommitted changes in the build
  record. Distinguish development testing from clean release acceptance.
  Done: a developer can follow the proposed workflow without committing,
  merging, pushing or deploying; the existing release/deployment policy stays
  intact.

- [ ] **LAN-02 — Build the production game for LAN testing.**
  Add a development export command using Godot 4.7.2, matching Web templates,
  Compatibility rendering and the existing single-threaded Web preset. Export
  the normal `scenes/main.tscn` game into a dedicated directory such as
  `localtmp/web-lan/<build-id>/`. Keep the production exclusions for tests,
  addons and temporary files. Run the required development checks and surface
  missing templates, import errors, export errors and incomplete payloads.
  Record the source commit, dirty-source fingerprint, engine version and
  build time. Done: the current branch opens as the playable game locally;
  a failed build cannot silently serve an older successful export.

- [ ] **LAN-03 — Serve the export and print usable URLs.**
  Add a static-server command that serves only the chosen export directory,
  with correct MIME types for JavaScript and WebAssembly. Support a selected
  LAN interface or `0.0.0.0`, a configurable port, clear port-in-use errors,
  and Ctrl+C shutdown. Print both the host smoke-test URL and the actual LAN
  URL; `localhost` and `0.0.0.0` are not device connection addresses. Make
  rebuild/reload behavior explicit and prevent stale browser caching during
  development. Done: a host request loads HTML, JavaScript, WebAssembly and
  the game pack, and stopping the server releases the port.

  A candidate static-server command, to verify during implementation, is:

  ```bash
  python3 -m http.server 8080 --bind 0.0.0.0 \
    --directory localtmp/web-lan/dev-001
  ```

  Replace `dev-001` with the exported build directory. The device would open
  `http://<development-computer-LAN-IP>:8080/`.

- [ ] **LAN-04 — Verify access from another Wi-Fi device.**
  Document how to find the development computer's active Wi-Fi/LAN address
  on macOS without assuming that a particular interface name is always Wi-Fi.
  Explain same-network access, the relevant local firewall permission, guest
  network/client isolation, VPN routing and a changed DHCP address. Verify
  connectivity from a second device rather than relying on a host-only
  `localhost` check. Done: a named phone or tablet loads the startup page and
  starts a tournament using the printed LAN URL; the computer and device
  addresses, port, OS and browser versions are recorded.

- [ ] **LAN-05 — Verify HTTP browser capabilities and provide HTTPS if needed.**
  Test the actual export over its LAN HTTP URL on the intended mobile
  browsers. Record `window.isSecureContext`, console errors, audio behavior,
  pointer/touch input, keypad entry and focus. Determine which features, if
  any, require a secure context on those browsers. If required for the tested
  flows, document a local HTTPS option with a certificate valid for the chosen
  LAN address/hostname and trusted on the test device; keep private keys local.
  Done: the supported HTTP or HTTPS route and any limitations are demonstrated
  on the named devices; insecure HTTP is not assumed equivalent to hosted
  HTTPS.

- [ ] **LAN-06 — Exercise the real game and the rebuild loop.**
  On the LAN-served build, test startup configuration, a normal hand, wager
  keypad Cancel/Done, pointer/keyboard focus where available, all-in runout,
  showdown, and Quit. Use supported phone portrait counts and representative
  tablet/desktop layouts. Check usable CSS size, device-pixel ratio, browser
  chrome changes and orientation changes; record deferred landscape support
  separately. Make a visible development change, rebuild, reload and verify
  the new build identity on the second device. Done: the flows and rebuild
  behavior pass, or concrete defects are linked to their owning task list.

- [ ] **LAN-07 — Automate the build/server regressions.**
  Add focused checks for export failure, missing payloads, an occupied port,
  server startup/shutdown, HTTP asset responses and stale-build prevention.
  Reuse the existing exported-browser input coverage where it fits the server
  workflow. Keep physical Wi-Fi reachability as explicit manual evidence;
  a loopback browser test cannot certify it. Done: automated failures return
  nonzero status and cleanup leaves no server running, with the manual device
  result recorded separately.

- [ ] **LAN-08 — Publish the verified runbook and evidence format.**
  Document prerequisites, exact build/serve/rebuild/stop commands, example LAN
  URLs, firewall/network troubleshooting and the tested HTTP/HTTPS route in
  [`OPTIONAL_WEB_SETUP.md`](OPTIONAL_WEB_SETUP.md) and the
  [running/testing guide](../devdocs/how-to/running-and-testing.md); link the
  workflow from the repository README. Include a compact evidence record with
  commit, dirty fingerprint, build ID, URL, date, device/browser versions,
  viewport/DPR, results and screenshot/defect locations. Done: another developer
  can reproduce the Wi-Fi test without merging to `main`, and all new local
  documentation links resolve.

## Acceptance and ownership

This workflow establishes local development and physical-device LAN evidence.
It does not by itself establish that the GitHub Pages build or an untested
browser/device passed. Use [`GUI_VISUAL_TESTING.md`](GUI_VISUAL_TESTING.md) for
visual evidence and [`templates/GUI_DEFECT.md`](templates/GUI_DEFECT.md) for
defects. Phone acceptance remains tracked in
[`OptimizingPhoneGuiTasks.md`](OptimizingPhoneGuiTasks.md); use LAN testing to
supply evidence there without duplicating or prematurely completing its tasks.
