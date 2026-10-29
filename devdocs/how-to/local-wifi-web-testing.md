# How-To Guide: Build and Serve the Latest Game over Local Wi-Fi

Use this workflow to test the current working tree on the development Mac,
an iPad or an Android phone without pushing or merging. The completed server workflow is recorded in
[`LanTestTasks.md`](../../docs/arkiv/LanTestTasks.md). GUI device-review evidence and
remaining acceptance limitations are recorded in the archived
[`OptimizingPhoneGuiTasks.md`](../../docs/arkiv/OptimizingPhoneGuiTasks.md)
and section 5 of the archived [`AstraSuggestionTasks.md`](../../docs/arkiv/AstraSuggestionTasks.md).

Install the [normal development dependencies](../../README.md#development-checks)
and Godot 4.7.2 with matching Web export templates. The CLI uses Python 3's
standard library; `git`, `make`, `strings` and `openssl` must be on `PATH`.
On macOS, install the Command Line Tools if the build tools are missing.
Run commands from the repository root. The examples below use Wi-Fi address
`192.168.39.105`; substitute your current address if it changes. Copy only the
commands inside a code block. Interactive zsh can treat pasted `#` comment
lines as commands, so the copyable blocks here contain no shell comments.

## Update an already running server with the latest local code

Save your edited files first, then check the recorded build/server state:

```bash
make web-lan-status
```

If a server is already running, keep it running. In another terminal, build
the current saved working tree:

```bash
make GODOT=/Applications/Godot.app/Contents/MacOS/Godot web-lan-rebuild && make web-lan-status
```

Wait for a successful build and `build.state` equal to `ready`. Then enter
`https://192.168.39.105:8080/` in the browser address bar on each device.
The existing server automatically selects the newly published build at that
root URL. **Do not run `web-lan-serve` again for an already running server.**

Each browser is redirected to `/builds/<build-id>/index.html`. Refreshing that
pinned URL keeps the old build; re-enter the root URL to get the new one.
Compare the build ID in that URL with `build.build_id` in `web-lan-status`.
The export stamps `Pokahdot · LAN <first-eight-build-ID-characters>` into the
initial tab title, but Godot can reset it to `Pokahdot` after startup. The
pinned URL and its adjacent `build-info.json` identify the running build.
An already open game does not update
itself; reopening loads a new game session.

“Latest code” means the saved files in your currently checked-out branch,
including uncommitted changes. The build does not fetch, pull, switch branches
or merge. Select the intended branch/version yourself before building, and
avoid editing source files while the build runs.

The build runs `make check`, then imports and exports an isolated copy of the
production game. Outputs and logs stay under `localtmp/web-lan/`; uncommitted
changes are permitted and identified by a source fingerprint. A build failure
invalidates the latest entry point instead of silently serving a previous
build. While building or after failure, the root returns HTTP 503; already
pinned successful builds remain available. After a failure, fix the reported
error and rebuild successfully before reopening the root. The release preset,
clean release gate and Pages deployment are separate.
The builder rejects engine/script error lines even if checks exit successfully.
Expected negative-test diagnostics are captured inside their tests; an error
in the outer check log still blocks publication.

## First-time setup or starting a stopped server

1. Find the active Wi-Fi address:

   ```bash
   make web-lan-network
   ```

   Use the address labelled Wi-Fi. Both the Mac and test devices must be on
   the same reachable network.

2. On first setup, prepare HTTPS for that address:

   ```bash
   make web-lan-tls WEB_LAN_ADDRESS=192.168.39.105
   ```

   Trust the generated CA on each test device using the
   [certificate instructions below](#https-certificates-and-test-device-trust).
   The helper creates files only; it never changes device trust. Skip this
   step on routine builds when the address/certificate is still valid and the
   same CA is already trusted. If the address changed or the certificate
   expired, follow the restart steps below.

3. Build, then start the server only if the build succeeds:

   ```bash
   make GODOT=/Applications/Godot.app/Contents/MacOS/Godot web-lan-build && make web-lan-serve
   ```

   Wait for `LAN server ready (HTTPS)` and the printed URLs. The server stays
   in the foreground: leave this terminal open while testing. It serves the
   exported files; it does not watch source files or build on request.

4. Open `https://192.168.39.105:8080/` on the Mac, iPad or phone. Use HTTPS for
   the game; the HTTP certificate-download page on port 8081 is separate.

The server prints a host URL such as `https://localhost:8080/` and candidate LAN
URLs with interface labels. On another device, enter the URL using the Mac's
Wi-Fi address, for example `https://192.168.39.105:8080/`. Use the address actually
printed for your network. Both devices must be on the same reachable LAN.
`localhost` on a phone refers to that phone; `0.0.0.0` is a listener setting,
not a device connection address.

## Network and connection troubleshooting

Find the current interfaces without assuming that Wi-Fi is always `en0`:

```bash
make web-lan-network
/usr/sbin/networksetup -listallhardwareports
```

For additional details, run `/sbin/ifconfig en0`, substituting the Device
value shown under Hardware Port: Wi-Fi.

Allow the Python server's incoming connections if macOS requests firewall
permission. If the host URL works but the device URL does not, check the Wi-Fi
address, port, local firewall, VPN routing, and guest-network/client isolation.
Reconnect to the same non-isolated network or correct the route, then retry
the root URL. DHCP may change the Mac's address after reconnecting. A request
made by the Mac to its own LAN address does not verify a second device.

## Stop or restart the server

Stop with Ctrl+C in its terminal, or request authenticated shutdown from
another terminal:

```bash
make web-lan-stop
```

If you changed server code/options or regenerated its certificate, stop and
restart it to load those changes. Game-only rebuilds need no server restart.
After a successful stop, start it again in the terminal you want to keep open:

```bash
make web-lan-serve
```

If the Wi-Fi address changed or the server certificate expired, stop first,
then regenerate and restart:

```bash
make web-lan-tls WEB_LAN_ADDRESS=192.168.39.105 && make web-lan-serve
```

Use the current address. The existing CA is reused, so devices that already
trust it do not need another CA installation. Rebuild first if you also want
to include saved game changes.

## Understanding the reported errors

- **`zsh: command not found: #`:** a pasted documentation comment was treated
  as a command. It did not undo subsequent successful commands. Use the
  comment-free command blocks above.
- **`A LAN server is already running for this output directory`:** the existing
  server holds the output directory's server lock. A successful build is still
  published; reopen the root URL to use it. To replace the server process, use
  the stop/restart steps above.
- **`Cannot bind LAN server ... Address already in use`:** another listener
  owns that address/port. Stop the known server or choose another port, then
  use that port in the device URL.

The stop command authenticates using a private local server record and never
kills a PID from a stale file. To choose another build root, bind address or
port, use `WEB_LAN_OUTPUT=localtmp/my-lan-builds`,
`WEB_LAN_BIND=192.168.1.42` and `WEB_LAN_PORT=8443` with the relevant Make
commands. Build roots must be subdirectories of the project's `localtmp/`.
The public certificate helper uses `WEB_LAN_CA_PORT=8081` by default.

For each physical device, record model, OS/browser versions, root and pinned
URLs, build ID, whether startup loads, and whether Start opens a tournament.
Keep the record under `localtmp/lan/` during development. Complete the
subsequent HTTP/input and game-flow checks in the LAN task list before
claiming acceptance for a device.

## HTTPS certificates and test-device trust

The installed Godot 4.7.2 export reports a missing **Secure Context** when
opened through a plain HTTP LAN address. Use HTTPS for the LAN game.
An explicit loopback diagnostic remains available with
`python3 tools/web-lan serve --http --bind 127.0.0.1`; a successful localhost
session does not establish LAN browser capability.

`web-lan-tls` creates a local development CA and a 30-day server certificate
covering the supplied IPv4 address, `localhost` and `127.0.0.1`. CA and server
private keys stay under `localtmp/web-lan/tls/` with restricted permissions.
Changing the LAN address requires regenerating the server certificate and
restarting the server; the existing CA is reused. Do not commit private keys.

To deliver only the public CA certificate to the devices, run in a separate
terminal:

```bash
make web-lan-ca-serve
```

Open `http://<Mac-Wi-Fi-IP>:8081/` on the devices. The directory contains the
public certificate in `.cer` and `.crt` formats and its SHA-256 fingerprint;
compare that fingerprint with the `web-lan-tls` output. This bootstrap page
contains no game or private keys. Stop this foreground helper with Ctrl+C when
certificate downloads are finished.

- **macOS:** open the CA certificate in Keychain Access, import it into the
  login keychain and explicitly trust this development CA for SSL. A persistent
  user-account trust change is a separate choice; the tooling does not install
  it automatically.
- **iPad:** download the `.cer`, install its profile in Settings, then enable
  its SSL trust under **General > About > Certificate Trust Settings**.
  Profile installation under **General > VPN & Device Management** and enabling
  full SSL trust are separate steps; both are required. Choosing an unsafe
  browser exception does not perform either installation step. See
  [Apple's certificate-trust instructions](https://support.apple.com/en-au/102390).
- **Android:** download the `.crt`, open the device's certificate installation
  settings and choose **CA certificate**, not a Wi-Fi client certificate.
  Manufacturer menu names vary. See the Android section of
  [these CA installation instructions](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/user-side-certificates/manual-deployment/).

Trusting a CA allows certificates signed by it to validate for that account or
device beyond this test session. Remove **Pokahdot Local LAN Development CA**
from the device's user certificate/profile store when it is no longer needed;
remove this specific certificate rather than clearing unrelated credentials.

For an existing certificate, supply `--cert`, `--key` and, when signed by a
local CA, `--ca-cert` to `python3 tools/web-lan serve`. Certificates must cover
the selected LAN address. Wildcard HTTPS serving also uses `localhost` for
authenticated local shutdown, so include that SAN. Explicit-address listeners
use that address for shutdown and verify it against the certificate.

Record `window.isSecureContext`, console errors, browser versions, touch/keypad
and focus results on each named device. The current game has no audio player
or sound assets: audible game playback is not an acceptance claim. Browser
audio capability can be recorded separately. HTTP and HTTPS results must not
be combined into a single device pass.

## Local device evidence record

Keep one record per device and tested build under ignored `localtmp/lan/`.
Copy build identity from the pinned game's adjacent `build-info.json`. Record
observations explicitly; an untested flow remains pending.
Open `https://<Mac-Wi-Fi-IP>:8080/__lan/` to copy a read-only JSON record of
the public build identity, secure-context flag, viewport, DPR, user agent and
audio API exposure. This page sends no collection request; copy its JSON with
your observations. Supply actual device/OS versions separately when a browser
reports a desktop-style user agent.

```text
Tested at (UTC):
Root URL / pinned game URL:
Build ID / source SHA / dirty-source fingerprint:
Device model / OS version:
Browser name / version:
CA fingerprint / certificate trusted without a browser warning:
CSS viewport / DPR / orientation / browser chrome:
Canvas CSS and backing sizes / visual viewport / safe-area inset observations:
Secure context / console errors:
Startup / six-player tournament:
Keypad Cancel / Done / pointer-keyboard focus where available:
Normal hand / all-in runout / showdown / Quit:
Rebuild before ID / after ID / root reopened on this device:
Results / defects / screenshot locations / untested flows:
```

Physical-device success is separate from the automated `make web-lan-test`
regressions and the host's own requests to its Wi-Fi address. This LAN record
does not certify the rolling Pages build.

## Current GUI-05 device review

Use one pinned LAN build on desktop browsers at multiple sizes, iPad, and
phone, as selected for the
[GUI redesign acceptance plan](../../docs/RestructureGuiTasks.md).

Reopen the root URL after rebuilding and compare the build ID on every device.
Consult the archived
[phone acceptance record](../../docs/arkiv/OptimizingPhoneGuiTasks.md) for earlier
evidence and remaining recorded limitations, keeping the completed
server-workflow archive unchanged.

- Record device/OS/browser versions, CSS viewport, DPR and browser-bar state.
  The `/__lan/` page records its own viewport; it does not measure the game's
  canvas or Godot usable rectangle. Where browser inspection is available,
  record the game canvas's CSS bounding rectangle, backing width/height,
  `visualViewport` dimensions/offsets and computed safe-area insets separately.
  Mark unavailable measurements pending rather than inferring a device pass.
- On phones, review 2-, 4-, 6-, and 7-player portrait tables. On larger layouts,
  include 9 players. Cover human/bot turns, large supported amounts, folds,
  all-ins, showdown, elimination and a named tournament winner.
- Open the hand summary and check named main/split/side-pot awards where
  reached. Open each overlay, wait beyond the usual hand pause, and check its
  close/cancel path, focus, background-input blocking and Quit access.
- Check keypad Cancel with valid, invalid, blank and whitespace text; use Done
  separately to commit. Exercise address bars, keyboard/keypad opening,
  desktop resize, Escape and device/browser Back; record browser navigation
  separately from in-game dismissal. Phone landscape remains deferred.
- Attach screenshots and the pinned build identity to each defect, including
  the last action and browser state needed to reproduce it. Untested states
  and a second independent browser/device remain pending until observed.

For a reproducible same-state browser layout report, use the
[exported capture reproduction workflow](../../docs/GUI_VISUAL_TESTING.md#exported-browser-capture-reproduction).
It records real automated CSS/DPR/canvas geometry and defects, without filling
in missing historical device measurements or claiming physical acceptance.

## Automated checks and accepted session

Run the focused build/server regressions independently, or run the full checks
that every LAN build requires:

```bash
make web-lan-test
make GODOT=/Applications/Godot.app/Contents/MacOS/Godot check
```

The `web-lan-test` target creates the ignored `localtmp/` parent when needed,
including on a fresh CI checkout; it does not require a prior LAN build.

The regression tests create temporary exports and loopback listeners, verify
failure exit status and stale-build prevention, and shut down their test
servers. They leave an independently running development server available.
For pointer/touch keypad and focus coverage, follow
[Exercise exported Web input](running-and-testing.md#exercise-exported-web-input).
That instrumented fixture is separate from the production LAN export and
does not establish physical Wi-Fi reachability.

On 2026-10-26 the user confirmed that the iPad worked after downloading the
certificate and that Wi-Fi access required HTTPS. The user accepted LAN-04–06,
including best-effort game/rebuild verification despite issues at some
resolutions. Exact device/OS/browser versions and affected resolutions were
not supplied. This acceptance closes the LAN workflow; it does not establish
that every layout passed. Remaining phone layout checks and deferred landscape
support remain recorded in the archived
[phone review](../../docs/arkiv/OptimizingPhoneGuiTasks.md).
Build identities, host/browser evidence and the acceptance decision are
recorded in [LanTestTasks.md](../../docs/arkiv/LanTestTasks.md).
