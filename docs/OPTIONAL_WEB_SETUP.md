# Web publishing and optional hosted-verification runbook

## Local Wi-Fi development before merging

Use this workflow to test the current working tree on the development Mac,
an iPad or an Android phone without pushing or merging. Progress and physical
device evidence are tracked in [`LanTestTasks.md`](LanTestTasks.md).

Install the [normal development dependencies](../README.md#development-checks)
and Godot 4.7.2 with matching Web export templates. The CLI uses Python 3's
standard library; `git`, `make`, `strings` and `openssl` must be on `PATH`.
On macOS, install the Command Line Tools if the build tools are missing.
From the repository root:

```bash
make web-lan-network
# Replace this example with your actual Wi-Fi IPv4 address:
make web-lan-tls WEB_LAN_ADDRESS=192.168.1.42
make GODOT=/Applications/Godot.app/Contents/MacOS/Godot web-lan-build
make web-lan-serve
```

Trust the generated local CA on the test clients using the instructions below.
The certificate helper creates files only; it never changes device trust.

The build runs `make check`, then imports and exports an isolated copy of the
production game. Outputs and logs stay under `localtmp/web-lan/`; uncommitted
changes are permitted and identified by a source fingerprint. A build failure
invalidates the latest entry point instead of silently serving a previous
build. The release preset, clean release gate and Pages deployment are separate.

The server prints a host URL such as `https://localhost:8080/` and candidate LAN
URLs with interface labels. On another device, enter the URL using the Mac's
Wi-Fi address, for example `https://192.168.1.42:8080/`. Use the address actually
printed for your network. Both devices must be on the same reachable LAN.
`localhost` on a phone refers to that phone; `0.0.0.0` is a listener setting,
not a device connection address.

Find the current interfaces without assuming that Wi-Fi is always `en0`:

```bash
make web-lan-network
/usr/sbin/networksetup -listallhardwareports
# Substitute the Device value shown under Hardware Port: Wi-Fi:
/sbin/ifconfig en0
```

Allow the Python server's incoming connections if macOS requests firewall
permission. If the host URL works but the device URL does not, check the Wi-Fi
address, port, local firewall, VPN routing, and guest-network/client isolation.
Reconnect to the same non-isolated network or correct the route, then retry
the root URL. DHCP may change the Mac's address after reconnecting. A request
made by the Mac to its own LAN address does not verify a second device.

The root URL redirects to an immutable `/builds/<build-id>/index.html` URL;
all its assets come from that same export. The server runs in the foreground;
leave that terminal open and rebuild from another terminal:

```bash
make GODOT=/Applications/Godot.app/Contents/MacOS/Godot web-lan-rebuild
make web-lan-status
```

Reopen the root URL after a successful rebuild to select the new build ID.
The browser tab shows `Pokahdot · LAN <first-eight-build-ID-characters>`;
compare it with `web-lan-status` and the pinned URL on each test device.
Refreshing an old pinned URL intentionally keeps its original build. Responses
disable browser caching for development; previous exports remain identified
for comparison. During a rebuild or after failure, the root returns HTTP 503.
Already pinned successful builds remain available.

Stop the foreground server with Ctrl+C, or from another terminal:

```bash
make web-lan-stop
```

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

### HTTPS certificates and test-device trust

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

### Local device evidence record

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

### Automated checks and accepted session

Run the focused build/server regressions independently, or run the full checks
that every LAN build requires:

```bash
make web-lan-test
make GODOT=/Applications/Godot.app/Contents/MacOS/Godot check
```

The regression tests create temporary exports and loopback listeners, verify
failure exit status and stale-build prevention, and shut down their test
servers. They leave an independently running development server available.
For pointer/touch keypad and focus coverage, follow
[Exercise exported Web input](../devdocs/how-to/running-and-testing.md#exercise-exported-web-input).
That instrumented fixture is separate from the production LAN export and
does not establish physical Wi-Fi reachability.

On 2026-10-26 the user confirmed that the iPad worked after downloading the
certificate and that Wi-Fi access required HTTPS. The user accepted LAN-04–06,
including best-effort game/rebuild verification despite issues at some
resolutions. Exact device/OS/browser versions and affected resolutions were
not supplied. This acceptance closes the LAN workflow; it does not establish
that every layout passed. Remaining phone layout checks and deferred landscape
support stay in [OptimizingPhoneGuiTasks.md](OptimizingPhoneGuiTasks.md).
Build identities, host/browser evidence and the acceptance decision are
recorded in [LanTestTasks.md](LanTestTasks.md).

## Published HTTPS verification

This runbook explains how to turn the Godot project into a Web build that can
be tested from a stable HTTPS URL. It is written for a developer who is new to
Godot. Hosted browser and physical-device review is optional manual
verification, not a tracked task in
[`ReleaseReadinessTasks.md`](arkiv/ReleaseReadinessTasks.md). When reproducible hosted
evidence is useful, complete the local canonical workflow in
[`GUI_VISUAL_TESTING.md`](GUI_VISUAL_TESTING.md) first and keep all evidence tied
to the deployed commit.

The outcome is deliberately reproducible:

1. `export_presets.cfg` is committed and contains a **Web** preset.
2. a release export is generated from a known Git commit;
3. a static host serves that exact export over HTTPS at a stable URL;
4. every successful push to `main` is built and published automatically; and
5. optional browser and physical-device evidence can be recorded against that
   build.

An editor preview, a local `file://` URL, a LAN-only server, or a simulator does
not establish behavior on a published HTTPS build or named real device. Use the
published build and real device when making that specific support claim.

## 1. Concepts and prerequisites

Godot's Web exporter creates a small static website: an `index.html` page plus
JavaScript, WebAssembly, game-pack, and possibly audio-worker files. All of
those files must be deployed together, preserving the filenames generated by
Godot. The project already targets the Compatibility renderer, which is the
renderer appropriate for a Godot Web export.

Use the same Godot version as the project: **Godot 4.7.2**. Install the
matching export templates from **Editor > Manage Export Templates** before
attempting an export. The editor reports a missing template in the Export
window; do not try to work around that error by copying files from another
Godot version.

For the baseline release, use the single-threaded Web export (disable **Use
Threads** in the Web preset). This is the preferred/default Web approach in
modern Godot and avoids the special cross-origin-isolation headers that a
threaded export requires. It is especially important for the optional Safari
checks described below. If a future version deliberately enables threads, the
hosting server must send both of these response headers on every relevant
response:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Use HTTPS for a production or hosted test build. An `http://localhost` smoke
test is useful for export startup only and does not establish hosted behavior.

Official background:

- [Godot: Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [Godot: Exporting projects and `export_presets.cfg`](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)
- [Godot: command-line exports](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)

## 2. Verify or recreate the committed Web export preset

The repository contains `export_presets.cfg` with a `Web` preset. Verify it
before a release. Use the following editor procedure only when recreating or
deliberately changing the preset. The result is project configuration, not a
machine-local secret, so it belongs in version control.

1. Open the repository root in Godot 4.7.2.
2. Select **Project > Export**.
3. Select **Add…**, then choose **Web**.
4. Name the preset exactly `Web`. The name is case-sensitive when used by the
   command line and deployment workflow below.
5. Keep the committed recursive exclusions for `addons/`, `tests/`,
   `localtmp/`, and `artifacts/`, together with the root test-harness files.
   Godot's patterns need both the direct-child and recursive forms to exclude
   every depth. The game must still include the production content under
   `scenes/`, `scripts/`, `resources/`, and `assets/`.
6. In the Web preset, ensure **Use Threads** is disabled. Leave Progressive
   Web App disabled unless the team explicitly decides to support offline
   installation and documents its cache/update behaviour.
7. Select **Export Project**, choose `build/web/index.html`, and make one
   local release export. Create the `build/web` directory first if Godot asks
   for an existing output directory.
8. Close the Export dialog and inspect the repository. Godot has created or
   updated `export_presets.cfg` at the project root. Commit that file. Do
   **not** commit `build/web/`; it is reproducible build output.

The generated preset should be reviewed in a pull request. In particular,
verify that its preset name is `Web`, thread support is disabled, and it does
not contain credentials. Godot documents `export_presets.cfg` as safe to
commit; `.godot/export_credentials.cfg` is not safe to commit and must remain
local.

Add this ignore entry if it is not already present:

```gitignore
# Reproducible Web release output; deploy it as a CI artifact instead.
/build/
```

## 3. Build a release from a known commit

Start with a clean working tree. The commit ID is part of the test evidence,
so never publish a build that silently includes uncommitted changes.

Use the repository-local release command. It fails before exporting if the
working tree is not clean, then runs lint, formatting, and the full GUT suite
before creating the release output:

```bash
make GODOT=/Applications/Godot.app/Contents/MacOS/Godot web-release
```

On systems where `godot` is on `PATH`, omit the `GODOT=...` override. The
command verifies that `build/web/index.html`, its direct HTML references, and
the JavaScript, WebAssembly, and game-pack payloads exist. It also rejects a
release output containing development-only `addons`, `tests`, `localtmp`, or
`artifacts` paths. The final release path remains ignored by Git.

The command performs the equivalent export:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

The command must exit with status 0. `build/web/index.html` must exist along
with the files referenced by it. Keep the files together and deploy the
contents of `build/web`, not the repository root.

`make web-release` verifies a local Web export. After a commit is pushed to
`main`, the deployment workflow checks out that exact push SHA and runs
`make release-candidate-gate web-release`. The candidate gate checks tree
cleanliness, runs `make check`, runs `gui-current-invariant-gate`, and
checks cleanliness again. `web-release` then owns the release export and
release-output validation. Both must pass before upload.

The CI runner is headless and cannot create representative rendered
screenshots. Automatic deployment makes the current `main` build available
for browser and physical-device discovery; it does not certify the visuals or
replace human review. When collecting optional hosted evidence, run
`make gui-visual-capture` on a rendering-capable machine and keep the reviewed
manifest, PNGs, and review record tied to the same deployed commit SHA.

For a quick local smoke test, serve the directory with any static-file server,
then open it in a desktop browser. This only checks that the export is
loadable; it does not count as HTTPS or device evidence. For example:

```bash
python3 -m http.server 8080 --directory build/web
```

Open `http://localhost:8080`, start a tournament, then stop the local server.
If the page or developer console reports loading failures, fix those before
deploying.

## 4. Deploy to the configured stable HTTPS host

This repository contains `.github/workflows/deploy-web.yml`. Every push to
`main` triggers the validation, Web export, artifact upload, and GitHub Pages
deployment for the pushed commit. Treat the successful workflow's `page_url`
output as authoritative; do not infer deployment status or claim a live host
from the repository name alone. The configured Pages URL normally has this
shape:

```text
https://<owner>.github.io/<repository>/
```

If the repository is private or an organisation has a different hosting
policy, obtain approval for the hosting provider and access policy before
publishing. Do not expose the game to a wider audience than the test plan
allows.

### GitHub Pages configuration and workflow verification

1. Ensure the commit intended for hosted testing has been pushed to `main`.
2. In GitHub, open **Settings > Pages**.
3. Under **Build and deployment**, set **Source** to **GitHub Actions**.
4. In **Settings > Environments > github-pages**, ensure no required-reviewer
   or self-review protection rule pauses automatic deployments. Restrict the
   environment to `main` if branch protection is desired.
5. Review `.github/workflows/deploy-web.yml`. It must use a `push` trigger
   restricted to `main`. It must continue to:
   - check out and verify the exact pushed SHA;
   - install Godot **4.7.2** and its matching export templates;
   - run `make release-candidate-gate web-release`: the candidate gate owns
     cleanliness, the complete headless suite, and the historical, phone,
     iPad, and desktop GUI invariant gates through `gui-current-invariant-gate`,
     while
     `web-release` owns the Web export and output validation;
   - create `build/web/.nojekyll` so Pages does not apply Jekyll processing;
   - upload only `build/web` with `actions/upload-pages-artifact`; and
   - expose a build summary containing the pushed commit SHA and validated
     provenance; the workflow result records whether the candidate gate and
     Web release passed.
6. Keep the deployment in a separate `deploy` job bound to the `github-pages`
   environment.

Use job-scoped least privilege. The workflow and build job need only repository
read access; the deploy job receives Pages and identity-token permissions:

```yaml
permissions:
  contents: read

jobs:
  deploy:
    permissions:
      pages: write
      id-token: write
```

Use the official Pages deployment actions and expose the deployed address from
the deployment step:

```yaml
environment:
  name: github-pages
  url: ${{ steps.deployment.outputs.page_url }}
```

The GitHub Pages guide shows the required artifact and deployment actions:
[Deploying a website automatically](https://docs.github.com/en/get-started/start-your-journey/deploying-your-website-automatically).
The workflow must pin the Godot version to 4.7.2 and fail rather than falling
back to another installed Godot version. Treat the workflow itself as release
code and review workflow changes before they reach the protected branch.

### Automatic deployment and evidence stability

Pull requests independently run `.github/workflows/check-pr.yml`, using the
same pinned Godot 4.7.2 editor and `release-candidate-gate`. The
**Checks and current layouts** status exposes failures before merge and can
be required in branch protection. A separate **Exported Web input** job exports
an isolated test fixture and checks real Chromium input paths. Both jobs have
repository-read access and perform no deployment. This does not change the push-to-`main`
deployment policy below.

1. Push the commit to `main`.
2. Open **Actions > Deploy Web release** and wait for the build and deploy jobs
   to succeed. A failed gate leaves the previously successful site in place.
3. Record the pushed SHA and workflow-run URL before beginning browser/device
   testing.
4. Verify the live site in a private/incognito session as described below.

The Pages URL is a rolling test environment. Avoid pushing another commit to
`main` while optional browser/device evidence is being collected. If a later
push replaces the hosted build, rerun every affected environment if the
evidence must describe the current deployment. To change the repository to
manual deployment in the future, follow
[`devdocs/how-to/switching-github-pages-to-manual-deployment.md`](../devdocs/how-to/switching-github-pages-to-manual-deployment.md);
do not change the trigger without an explicit project-owner request.

### First deployment verification

After the Pages workflow succeeds:

1. Copy the exact `page_url` from the successful deployment.
2. Open it in a private/incognito desktop browser window. This prevents an
   old service worker, cache entry, saved local storage, or extension state
   from masking a bad deployment.
3. Wait until the startup form is visible.
4. Open the browser developer console and confirm there are no errors. Network
   requests for the page's generated Godot files must return successfully.
5. Verify the address begins with `https://`, has no certificate warning, and
   remains the URL used for subsequent commits.
6. Record the commit SHA and the deployment/run URL in the evidence record
   below.

Do not enable response compression for `.wasm`, `.pck`, `.js`, or other Godot
output unless the host sends the matching `Content-Encoding` header. A broken
compression configuration commonly looks like a blank canvas or a browser
console decompression error.

## 5. Optional browser and device evidence

Create one evidence record per deployed commit in the release issue, pull
request, or a committed Markdown file such as
`docs/test-evidence/web/<short-sha>.md`. Follow the screenshot naming and
storage contract in [`GUI_VISUAL_TESTING.md`](GUI_VISUAL_TESTING.md). In
particular, local files under ignored `artifacts/` are working evidence, not a
durable hosted record. Attach the immutable hosted evidence to the associated
issue or release, or place it in another agreed durable evidence store, and
link that location from the record.

Hosted screenshot names use the exact field order below. Use the first 12
characters of the tested commit, lowercase ASCII identifiers, and double
underscores between fields:

```text
<sha12>__<environment-id>__<device-os-browser>__<width>x<height>-<orientation>__p<count>__<state-id>.png
88122bd46ef0__desktop-chrome__macos14-chrome130__1920x1080-landscape__p9__showdown-long.png
88122bd46ef0__ipad-safari__ipadpro-ipados18-safari18__1024x768-landscape__p9__human-turn-flop__after-rotation.png
88122bd46ef0__iphone-safari__iphone15-ios18-safari18__390x744-portrait__p7__keypad-open.png
```

The width and height are the actual usable CSS viewport for hosted evidence,
not the device's physical panel resolution. A stable suffix such as
`__before-rotation` or `__after-rotation` may follow the canonical state ID
when one state requires multiple images.

Start every session at the stable URL in a private/incognito window or private
tab. Record this header before testing:

```markdown
## Web build evidence

- URL: `https://<owner>.github.io/<repository>/`
- Commit: `<full 40-character SHA>`
- Deployment workflow/run: `<URL>`
- Release-candidate-gate and Web-release result: `<pass and build-log URL>`
- Local rendered manifest SHA-256: `<64 lowercase hexadecimal characters>`
- Manifest source SHA, suite, and scope: `<SHA>`, `<suite>`, `<full scope>`
- Manifest acceptance eligible: `true`
- Rendered review result/reviewer (UTC): `approved`, `<reviewer>`, `<time>`
- Open or accepted defect IDs: `<none or linked IDs and decisions>`
- Tested on (UTC): `<YYYY-MM-DD HH:MM>`
- Export preset: `Web`, release, threads disabled
- Console errors at startup: none / `<exact errors>`
- Durable hosted evidence location: `<issue/release/archive URL>`
```

Record these details for each browser/device session. Repeat the block when a
rotation or browser-chrome change produces a different usable viewport:

```markdown
### Session: `<environment-id>`

- Device and OS/version: `<model and version>`
- Browser and version: `<browser and version>`
- Orientation: `portrait` / `landscape`
- Logical/CSS viewport: `<width>x<height>`
- Usable viewport: `<x>,<y> <width>x<height>`
- Device-pixel ratio: `<value>`
- Safe-area insets (top/right/bottom/left): `<values in CSS px>`
- Browser chrome: `expanded` / `collapsed` / `not applicable`
- Private/incognito session: `yes`
- Screenshot and defect links: `<durable links>`
```

Then add one row per test environment:

| Environment | Device and OS | Browser and version | Session details | 2-player result | Profile-maximum result | Screenshots / defects |
| --- | --- | --- | --- | --- | --- | --- |
| Desktop Chrome or Edge | `<model, OS>` | `<version>` | `<session anchors for 1920x1080 and 1280x720>` | `<pass/fail>` | `<pass/fail>` | `<links>` |
| Desktop Firefox | `<model, OS>` | `<version>` | `<session anchors for 1920x1080 and 1280x720>` | `<pass/fail>` | `<pass/fail>` | `<links>` |
| iPad Safari | `<model, iPadOS>` | `<version>` | `<portrait and landscape session anchors>` | `<pass/fail>` | `<pass/fail>` | `<links>` |
| iPhone Safari | `<model, iOS>` | `<version>` | `<portrait and landscape session anchors>` | `n/a` | `<7-player pass/fail>` | `<links>` |
| Android Chrome | `<model, Android>` | `<version>` | `<orientation and browser-chrome session anchors>` | `n/a` | `<7-player pass/fail>` | `<links>` |

### Suggested representative flow

For each selected desktop browser at the chosen sizes, start both a 2-player
and a 9-player default tournament. Capture evidence that seats, event history,
action controls, hole cards, board, pot, player markers, and Quit confirmation
are visible, readable, inside their bounds, and non-overlapping. Exercise and
capture at least:

1. a fold;
2. normal betting;
3. an all-in runout;
4. showdown;
5. an elimination;
6. tournament winner; and
7. `player_quit`.

On Firefox, additionally compare font rendering, suit colours, scrollable
event history, and the event-log bottom alignment with the human seat against
the approved reference screenshots.

On a **physical iPad**, test Safari in portrait and landscape for 2-player and
9-player games. Rotate during startup and during live play. Confirm that
there is no horizontal page scroll, clipped control, overlap, unreadable text,
stale layout, or lost touch input.

On a **physical iPhone**, test Safari in both orientations with a 7-player
game. Verify every bot's display name, numeric stack, and two hole-card fields,
and verify that Fold, Call, Raise, and All-in are fully tappable. Confirm that
no event-history surface is present, rotate once during play, and check that
the required states remain legible without zooming.

On a **physical Android phone**, repeat the iPhone flow in current Chrome.
Test with the browser address bar expanded and collapsed because each has a
different effective viewport height. Record all touch, clipping, contrast,
text-size, and rotation defects.

## 6. Defect handling and suggested sign-off

If a chosen manual check fails, create a defect report using
[`templates/GUI_DEFECT.md`](templates/GUI_DEFECT.md), with the evidence header,
exact reproduction steps, screenshots, and console output. Fix the issue in
the appropriate presentation-layer code, add or update a regression test, run
the checks from section 3, deploy a new commit, and repeat the affected
device/browser check.

For internally consistent optional hosted evidence, use all of the following:

- `export_presets.cfg` is committed and a `Web` release export succeeds;
- the pushed commit, checked-out commit, rendered manifest, and review record
  all identify the same full candidate SHA;
- `make release-candidate-gate web-release` passed and the independently
  reviewed rendered manifest checksum identifies a complete
  acceptance-eligible capture;
- the deployment workflow publishes the release output, not source files;
- the stable URL opens over HTTPS in a private/incognito window without console
  errors;
- the evidence record identifies the URL, exact commit, browser/device/OS
  versions, logical and usable viewports, orientation, device-pixel ratio,
  safe-area insets, browser-chrome state, durable screenshots, and any fixed
  defects; and
- the selected environments and any untested or unavailable environments are
  recorded so the evidence does not imply a broader support claim.

An unavailable environment is not a pass for that environment, but it does not
create an unfinished repository task. Record it as untested or deferred when
summarizing the scope of the optional review.
