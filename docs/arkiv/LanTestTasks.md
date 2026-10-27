# Local Wi-Fi Web Testing Tasks

Status: Complete — LAN-01–08 complete; resolution limitations accepted by the user.
Created: 2026-10-26.

## Goal

Build the current branch as the actual Pokahdot Web game, serve the exported
files on the development computer, and open a LAN URL from phones, tablets,
and other computers on the same Wi-Fi network. Testing must work before a
merge to `main` and without a GitHub Pages deployment.

The existing [`Web` export preset](../../export_presets.cfg) is the starting
point. [`make web-release`](../../Makefile) currently requires a clean tree and
runs the release gates; it is not a convenient development-server command.
The exported-input test runner builds an instrumented fixture for automation,
so its output must not become the manually tested LAN game.

Tasks are ordered. Mark a task complete only after its implementation and
verification evidence exist. Keep generated exports, logs, certificates and
screenshots under ignored `localtmp/`; do not commit them.

## Tasks

- [x] **LAN-01 — Define the local development workflow.**
  Specify separate build, serve, rebuild and stop commands, with configurable
  Godot executable, export directory, network interface/bind address and port.
  Support feature branches and identify any uncommitted changes in the build
  record. Distinguish development testing from clean release acceptance.
  Done: a developer can follow the proposed workflow without committing,
  merging, pushing or deploying; the existing release/deployment policy stays
  intact.
  Defined and reviewed on 2026-10-26: the command contract below separates
  validated development builds, foreground serving, authenticated shutdown and
  device evidence. Immutable build URLs prevent mixed assets during rebuilds;
  failed builds invalidate the latest entry point.

- [x] **LAN-02 — Build the production game for LAN testing.**
  Add a development export command using Godot 4.7.2, matching Web templates,
  Compatibility rendering and the existing single-threaded Web preset. Export
  the normal `scenes/main.tscn` game into a dedicated directory such as
  `localtmp/web-lan/<build-id>/`. Keep the production exclusions for tests,
  addons and temporary files. Run the required development checks and surface
  missing templates, import errors, export errors and incomplete payloads.
  Record the source commit, dirty-source fingerprint, engine version and
  build time. Done: the current branch opens as the playable game locally;
  a failed build cannot silently serve an older successful export.
  Verified on 2026-10-26: six builder regressions pass; a real production
  export passed its complete checks (591 GUT, 89 profile-evolution Python and
  six LAN tests), import, payload verification and release export. Chromium
  opened the normal startup scene and started a six-player tournament with
  no console errors. Evidence: `localtmp/lan/build-smoke.json` and screenshots;
  initial build ID `06898da7f19c473c9ce32449b373a276`.

- [x] **LAN-03 — Serve the export and print usable URLs.**
  Add a static-server command that serves only the chosen export directory,
  with correct MIME types for JavaScript and WebAssembly. Support a selected
  LAN interface or `0.0.0.0`, a configurable port, clear port-in-use errors,
  and Ctrl+C shutdown. Print both the host smoke-test URL and the actual LAN
  URL; `localhost` and `0.0.0.0` are not device connection addresses. Make
  rebuild/reload behavior explicit and prevent stale browser caching during
  development. Done: a host request loads HTML, JavaScript, WebAssembly and
  the game pack, and stopping the server releases the port.
  Verified on 2026-10-26: 20 builder/network/server tests pass, including
  concurrent asset verification, MIME/cache headers, occupied ports, traversal,
  authenticated stop and port release. The full suite remains green. A live
  wildcard listener served all four production payloads through the Mac's
  Wi-Fi address with matching hashes (`localtmp/lan/http-smoke.json`).
  Review fixes verified: payloads are checked on every response, HTTPS stop
  honors its bind address/CA, and setup failures close their listeners.
  HTTPS certificate-chain/hostname verification succeeds against the Wi-Fi
  address. The current 30 LAN regressions pass, including certificate and CLI
  tests. Plain HTTP at the LAN address produced the user's Secure Context
  error; the CLI now selects managed HTTPS by default.
  Final verification: 591 GUT tests, 95,281 assertions, 89 profile-evolution
  Python tests and 30 LAN Python tests pass
  (`localtmp/lan/tls-stall-fix-check.log`).
  Runtime follow-up: an unfinished TLS handshake could block the listening
  thread. Handshakes now run independently in bounded request workers; a
  regression verifies that an idle TCP client cannot block HTTPS requests or
  authenticated shutdown. The restarted Wi-Fi game and certificate page both
  return 200, including with an idle client connected.

  The implemented server command is:

  ```bash
  python3 tools/web-lan serve --output localtmp/web-lan --bind 0.0.0.0 --port 8080
  ```

  Prepare the local certificate first and trust its CA on test devices, as
  described in the [LAN how-to](../../devdocs/how-to/local-wifi-web-testing.md#https-certificates-and-test-device-trust).
  The device opens `https://<development-computer-LAN-IP>:8080/`.

- [x] **LAN-04 — Verify access from another Wi-Fi device.**
  Document how to find the development computer's active Wi-Fi/LAN address
  on macOS without assuming that a particular interface name is always Wi-Fi.
  Explain same-network access, the relevant local firewall permission, guest
  network/client isolation, VPN routing and a changed DHCP address. Verify
  connectivity from a second device rather than relying on a host-only
  `localhost` check. Done: a named phone or tablet loads the startup page and
  starts a tournament using the printed LAN URL; the computer and device
  addresses, port, OS and browser versions are recorded.
  Evidence: the first manual Mac attempt over HTTP showed a Secure Context
  error. Initial mobile HTTPS attempts showed certificate warnings, and the
  iPad first opened through Advanced/unsafe continuation. After downloading the
  certificate, the user now reports that it works on the iPad (2026-10-26).
  The user subsequently checked LAN-04 and LAN-05 and explicitly confirmed
  that Wi-Fi access required HTTPS. These checks are accepted as user device
  sign-off. Exact model/OS/browser measurements were not supplied and must not
  be inferred. The CA download page explains profile installation and full
  SSL trust as separate steps.

- [x] **LAN-05 — Verify HTTP browser capabilities and provide HTTPS if needed.**
  Test the actual export over its LAN HTTP URL on the intended mobile
  browsers. Record `window.isSecureContext`, console errors, audio behavior,
  pointer/touch input, keypad entry and focus. Determine which features, if
  any, require a secure context on those browsers. If required for the tested
  flows, document a local HTTPS option with a certificate valid for the chosen
  LAN address/hostname and trusted on the test device; keep private keys local.
  Done: the supported HTTP or HTTPS route and any limitations are demonstrated
  on the named devices; insecure HTTP is not assumed equivalent to hosted
  HTTPS.
  Implemented prerequisite: `tls-init` creates a private local CA and server
  certificate; `serve` supports certificate, key and CA verification options.
  Device trust is an explicit user action. Do not mark this task complete from
  an HTTP-client TLS check or a browser certificate-error bypass.
  The user has completed this verification and confirmed the HTTPS requirement.
  Earlier automatic approval review rejected persistent Mac CA installation;
  the tooling did not install it in the login keychain. That historical
  approval request does not block the accepted user device verification.
  Detailed game-flow/rebuild acceptance remains owned by LAN-06.

- [x] **LAN-06 — Exercise the real game and the rebuild loop.**
  On the LAN-served build, test startup configuration, a normal hand, wager
  keypad Cancel/Done, pointer/keyboard focus where available, all-in runout,
  showdown, and Quit. Use supported phone portrait counts and representative
  tablet/desktop layouts. Check usable CSS size, device-pixel ratio, browser
  chrome changes and orientation changes; record deferred landscape support
  separately. Make a visible development change, rebuild, reload and verify
  the new build identity on the second device. Done: the flows and rebuild
  behavior pass, or concrete defects are linked to their owning task list.
  Implementation and host verification on 2026-10-26: development exports now
  stamp the browser tab with `Pokahdot · LAN <first-eight-build-ID-characters>`
  before payload hashing. Two additional builder regressions verify distinct
  rebuild identities, preserved older exports and failure on a missing title.
  The real rebuild passed 591 GUT tests (95,281 assertions), 89 profile-evolution
  Python tests and 32 LAN tests. Current build:
  `1c180039042e4c88bb217d5809891c86`; previous:
  `5c823781f3e54fb1ae22129065781e7c`. A CA-verified host HTTPS request confirms
  the root selects the new build and title; this is not second-device evidence.
  The unchanged production source snapshot was exercised in Chromium
  140.0.7339.16 over loopback: desktop keyboard startup configuration, a normal
  hand through showdown, Quit/Continue and confirmed Quit, touch startup keypad
  Cancel/Done, and a short-stack all-in runout through tournament completion.
  Screenshots cover CSS 1280×720, 390×844, 390×700, 768×1024 and rotation to
  844×390 and back, at DPR 1, with no browser errors. These observations are
  functional host evidence, not a physical-device visual acceptance claim.
  The existing instrumented exported-input suite separately passed all four
  pointer/touch startup/table cases, including wager Cancel/Done and focus.
  Evidence: `localtmp/lan/continuation/browser/`, `web-input/results.json`,
  `visible-rebuild.json` and `marked-build.log` under the same continuation
  directory. Physical portrait player-count coverage and deferred landscape
  remain owned by [OptimizingPhoneGuiTasks.md](OptimizingPhoneGuiTasks.md).
  User acceptance on 2026-10-26: the user completed their best-effort LAN-06
  verification and explicitly accepted and checked this task despite issues at
  some resolutions. This closes LAN-06 by user decision; it does not imply
  that every resolution passed or that unreported measurements were collected.
  Remaining layout coverage stays in the phone GUI task list linked above.

- [x] **LAN-07 — Automate the build/server regressions.**
  Add focused checks for export failure, missing payloads, an occupied port,
  server startup/shutdown, HTTP asset responses and stale-build prevention.
  Reuse the existing exported-browser input coverage where it fits the server
  workflow. Keep physical Wi-Fi reachability as explicit manual evidence;
  a loopback browser test cannot certify it. Done: automated failures return
  nonzero status and cleanup leaves no server running, with the manual device
  result recorded separately.
  Verified on 2026-10-26: 34 LAN regressions cover builds, stale status,
  payloads, routing, headers, ports, shutdown, TLS and CLI defaults. Subprocess
  checks prove failed build/serve commands return status 1; a failed build
  replaces ready status with failed status and neither command publishes server
  state. Listener tests verify authenticated shutdown and port release,
  including cleanup after startup failure and an idle TLS connection.
  `make check` includes these regressions and passed alongside all 591 GUT
  tests (95,281 assertions), 89 profile-evolution Python tests, lint and format
  checks. Evidence: `localtmp/lan/continuation/final-check.log`.
  Existing exported-browser input coverage passed four cases during LAN-06;
  physical-device results and user acceptance remain recorded separately above.

- [x] **LAN-08 — Publish the verified runbook and evidence format.**
  Document prerequisites, exact build/serve/rebuild/stop commands, example LAN
  URLs, firewall/network troubleshooting and the tested HTTP/HTTPS route in
  [`OPTIONAL_WEB_SETUP.md`](../OPTIONAL_WEB_SETUP.md) and the
  [running/testing guide](../../devdocs/how-to/running-and-testing.md); link the
  workflow from the repository README. Include a compact evidence record with
  commit, dirty fingerprint, build ID, URL, date, device/browser versions,
  viewport/DPR, results and screenshot/defect locations. Done: another developer
  can reproduce the Wi-Fi test without merging to `main`, and all new local
  documentation links resolve.
  Completed on 2026-10-26: the runbook lists prerequisites, foreground and
  second-terminal commands, certificate bootstrap/trust, network troubleshooting,
  immutable rebuild URLs and visible tab identities. README and the developer
  guide agree with the implemented CLI/Make targets. The compact evidence
  template includes provenance, device/browser measurements, viewport/DPR,
  flow/rebuild results and screenshot/defect locations. Accepted iPad/HTTPS and
  best-effort LAN-06 results are recorded with their resolution limitations;
  unreported measurements remain explicitly unreported.
  All local links and Markdown anchors in the changed workflow documents
  resolve, and `git diff --check` passes. Evidence:
  `localtmp/lan/continuation/final-documentation-check.json`.
  Follow-up: the maintained LAN instructions now live in the dedicated
  [local Wi-Fi how-to](../../devdocs/how-to/local-wifi-web-testing.md), including
  separate first-time setup and rebuild instructions and an explanation of
  already-running server errors. The Web publishing runbook links to it.

## Acceptance and ownership

This workflow establishes local development and physical-device LAN evidence.
It does not by itself establish that the GitHub Pages build or an untested
browser/device passed. Use [`GUI_VISUAL_TESTING.md`](../GUI_VISUAL_TESTING.md) for
visual evidence and [`templates/GUI_DEFECT.md`](../templates/GUI_DEFECT.md) for
defects. Phone acceptance remains tracked in
[`OptimizingPhoneGuiTasks.md`](OptimizingPhoneGuiTasks.md); use LAN testing to
supply evidence there without duplicating or prematurely completing its tasks.

## Command contract

The implementation uses a Python standard-library CLI, `python3 tools/web-lan`:

| Command | Contract |
| --- | --- |
| `build --godot <executable> --output localtmp/web-lan` | Run development checks, snapshot the production project, export a new build and publish it only after verification. Repeating this command rebuilds. |
| `tls-init --output localtmp/web-lan --address <LAN-IP>` | Prepare local CA/server files without installing trust. The CA is reused when reissuing a server certificate. |
| `serve --output localtmp/web-lan --bind 0.0.0.0 --port 8080` | Serve using the managed HTTPS certificate in the foreground; print host and candidate LAN URLs. Ctrl+C stops it. Custom certificate/key/CA options are supported. Explicit `--http` is available for loopback diagnostics. |
| `status --output localtmp/web-lan` | Report build and server identity without exposing the shutdown credential. |
| `stop --output localtmp/web-lan` | Request shutdown using a local, private credential; never kill a PID from a stale file. |
| `network` | List interface addresses and macOS network-service labels where available, so the user can identify Wi-Fi. |

Build roots stay below ignored `localtmp/`. Each successful build has an
immutable ID, source/engine metadata and payload checksums. The server's root
URL redirects to that build's game URL. After rebuilding, reopen the root URL
to select the newest build; a pinned build URL continues to identify its
original export. While building or after a failure, the root reports that
state instead of selecting the last successful game. Existing identified
builds remain available for comparison. These are development builds and do
not alter `web-release`, GitHub Pages or clean-release acceptance.
