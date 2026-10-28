# GUI visual testing workflow

This document defines the reusable local visual-testing contract for the GUI.
It complements the automated GUT suite and the hosted browser/device
runbook in [`OPTIONAL_WEB_SETUP.md`](OPTIONAL_WEB_SETUP.md). Local captures do
not prove browser or physical-device support, and hosted screenshots do not
replace deterministic geometry regressions.

The [GUI replacement plan](RestructureGuiTasks.md) owns new implementation and
device-acceptance work. Existing cases preserve product contracts and evidence;
they do not require the replacement to retain internal node paths, exact
legacy geometry or a past visual defect. Snapshot/observer migration precedes
legacy deletion.

## Current support and acceptance

This document owns GUI evidence terminology. The product specification owns
player limits; active acceptance checkboxes stay in their owning backlog.

| Profile | Product scope | Automated coverage | Physical/browser acceptance |
| --- | --- | --- | --- |
| Phone portrait | 2–7 players; default 6 | Dedicated phone v2 matrix, including reduced height and summary overlays | Archived [phone acceptance record](arkiv/OptimizingPhoneGuiTasks.md); open recorded checks are not completed by archive placement |
| Phone landscape | Emergency reflow and state preservation | Diagnostic phone fixtures | Deferred; diagnostic passes do not establish landscape support |
| Tablet/iPad | 2–9 players; landscape primary, portrait regression | Dedicated iPad matrix, including explicit observed-device override | Historical user iPad acceptance in [archived record](arkiv/OptimizingIpadTasks.md), limited to that evidence |
| Small desktop/desktop | 2–9 players | Dedicated desktop matrix and historical M3 fixtures | [Archived implementation record](arkiv/OptimizingDesktopGuiTasks.md) has no recorded exact hosted measurements or final visual sign-off |

`make gui-current-invariant-gate` requires the historical M3, phone, iPad, and
desktop matrices. An automated pass proves the tested deterministic invariants.
A rendered review proves only its captured scope; neither proves a physical
device passed. Accepted old captures do not certify later code or matrix versions.
The completed [LAN workflow](arkiv/LanTestTasks.md) records user acceptance with
resolution limitations; it does not complete open recorded phone acceptance checks.
The [archived GUI-05 browser capture review](arkiv/AstraSuggestionTasks.md#gui-05-browser-capture-review)
records overlapping/clipped content in two of four same-state browser captures,
provisionally clear content in the other two, and the user's positive iPad
screen review. This is limited state-level evidence: exact environments and
remaining device/input checks are pending. Preserve the working iPad result
while fixing the demonstrated browser layouts. The subsequent phone report
that showdown does not show the winner reopened GUI-01. The updated candidate
now has default visible winner feedback and direct Pots access; physical phone
verification is still pending. Summary-formatting tests alone do not establish
visible winner feedback during actual play.

General hosted checks are optional for deployment. Explicit phone acceptance
work remains required before claiming the corresponding phone/device support.

### Avatar sources and display

All sixteen PNGs in `assets/avatars/` are 64 × 64 source pixels. Full seat
panels have base logical avatar regions of 112 × 112 for opponents and
128 × 128 for the human; responsive layouts adapt these regions. Phone tokens
omit avatars. These values are not physical screen pixels: record usable
viewport and DPR separately when assessing the actual device output.

## Canonical viewport fixtures

Fixture IDs are stable evidence identifiers. Dimensions are logical viewport
dimensions in pixels, not a claim about a device's physical panel resolution.
Physical-device evidence must additionally record the browser's actual usable
viewport, device-pixel ratio, safe-area effects, and browser-chrome state.

| Fixture ID | Logical size | Orientation | Intended layout profile |
| --- | ---: | --- | --- |
| `phone_portrait_360x640` | 360 x 640 | portrait | phone portrait |
| `phone_portrait_390x844` | 390 x 844 | portrait | phone portrait |
| `phone_portrait_412x915` | 412 x 915 | portrait | phone portrait |
| `phone_portrait_390x744_chrome` | 390 x 744 | portrait | phone portrait, reduced height |
| `phone_landscape_640x360` | 640 x 360 | landscape | phone landscape |
| `phone_landscape_844x390` | 844 x 390 | landscape | phone landscape |
| `phone_landscape_844x330_chrome` | 844 x 330 | landscape | phone landscape, reduced height |
| `ipad_portrait_768x1024` | 768 x 1024 | portrait | tablet |
| `ipad_landscape_1024x768` | 1024 x 768 | landscape | tablet |
| `ipad_landscape_1194x696_chrome` | 1194 x 696 | landscape | tablet, reduced-height regression |
| `ipad_landscape_2388x1450_observed` | 2388 x 1450 | landscape | tablet regression |
| `small_desktop_950x532` | 950 x 532 | landscape | small desktop |
| `desktop_1280x720` | 1280 x 720 | landscape | desktop |
| `desktop_1920x1080` | 1920 x 1080 | landscape | desktop |

The reduced-height fixtures are deterministic browser-chrome stress surfaces.
They do not substitute for testing both expanded and collapsed browser chrome
on a physical Android device. The 1194 x 696 iPad landscape fixture models the
logical game area inferred from a browser screenshot and is automatic tablet
classification coverage; physical browser metrics must still confirm it. iPad
landscape is the primary orientation and portrait remains secondary regression
coverage. The observed 2388 x 1450 iPad fixture preserves a previously reported
regression surface; it does not redefine the canonical iPad logical sizes. It
carries an explicit tablet profile override because the
same geometry without observed-device evidence is a valid desktop window and
is classified as desktop. When a supported iPad exposes a different usable
viewport, record that actual size in hosted evidence without renaming these
canonical local fixtures.

The historical Milestone 3 non-phone table fixtures exercise 2, 4, 6, and 9
players wherever the state supports those counts. The Milestone 4 phone suite
uses 2, 4, 6, and 7. Startup uses player count `0` because no table exists yet.
A fixture may declare a narrower applicable set, but it must state why;
silently omitting a difficult viewport, player count, or state is not allowed.

The ordinary GUT suite additionally runs
`tests/unit/test_gui_phone_numeric_bounds.gd`. Its synthetic presentation stress
views exercise 2–7 phone counts at 360 × 640, large-value tablet/desktop
surfaces through nine players, exact 999999/6999999/8999999 amounts,
1,000,000 blinds, split numeric rows, profile restoration, Web fallback
font metrics, DPR normalization, and real core submissions through inline/keypad
presets. These deliberately combine boundary values to test layout rather than
representing a chip-conserving poker hand. They supplement the frozen canonical
matrices and do not establish physical-device acceptance.

The real-flow winner regressions in `test_gui_phone_winner_flow.gd` drive
`TournamentMatch` through settlement for hero/opponent wins, splits, side pots
and folds at 2/4/6/7 seats. Winner text must fit and appear before opening Pots;
card privacy and hand-pause/reset behavior are checked. GUI-05-D removed the
former known-clipping exemptions: pre/post-settlement supported portrait
layouts must pass every content invariant. Measured three-row packing covers
long names, combined roles, active heads-up actions, positive awarded stacks
and repeated resizes without rebinds. Fixed-card tests cover all 52 rank/suit
combinations at both portrait board and revealed-opponent sizes. Supplemental
seven-recipient boundary coverage
checks the largest result footer. Exported input tests include a real six-seat
showdown and touch on Pots/Close, in addition to keypad/modal cases.

## Exported browser capture reproduction

`tests/support/gui_browser_capture_fixture.gd` supplies the six-player public
preflop state from the GUI-05 capture review: pot 65, blinds 5/10, Human holding
4-spades/8-diamonds and the named blind/raise/fold records. It is a synthetic
presentation fixture, not a core replay. It preserves recipient privacy and
uses representative deterministic avatars; historical avatar assignments and
browser/build metadata remain unknown.

The isolated `tests/web/layout_fixture.tscn` mounts production main so the actual
Web normalization and fonts run. It exposes read-only geometry and existing
invariant failures. `tools/run_web_layout_tests.py` records CSS and canvas
backing sizes, DPR, visual viewport, selected profile, settled layout and all
six seats' clockwise order, plus screenshots/source/export checksums. Its
exploratory sizes are new test inputs, never inferred historical measurements.
The observer is excluded from the normal production export. The default input
export remains separate and continues to run its five input cases.

After installing the [optional browser tooling](../devdocs/how-to/running-and-testing.md#exercise-exported-web-input),
run this from the repository root with an unused output directory:

```bash
.venv/bin/python tools/run_web_layout_tests.py --godot /Applications/Godot.app/Contents/MacOS/Godot --output localtmp/gui05-layout-review
```

Add `--strict --check all` to require the complete browser regression contract;
`geometry`, `content` and `order` select explicit staged checks while all raw
failures remain in every report. The full contract checks merged seat/status
footprints, the complete six-seat clockwise order and human placement, and
visible exact Name/Stack/public-role labels in addition to existing shaped text
and containment invariants. Compact S/B markers retain their existing SB/BB
meaning. `make web-layout-test` runs the pure checker edge-case tests without
requiring a browser; it is included in `make check`. The browser gate itself
requires the optional browser environment and returns nonzero for defects.

Report mode exits successfully when measurement completes, even with recorded
layout defects. Engine/browser errors fail. Never treat report completion as
layout acceptance. See the [GUI-05-A evidence record](arkiv/AstraSuggestionTasks.md#gui-05-browser-capture-review)
for the initial 39 measured environments/transitions, reproduced defects,
explicit unknowns and clear automated controls. Physical safe areas, browser
chrome and browser zoom are not measured by this headless report.

## Canonical visual states

Use these stable state IDs in tests, manifests, filenames, and defect records:

| State ID | Required presentation |
| --- | --- |
| `startup` | startup form before tournament construction |
| `human-turn-preflop` | human legal actions before the flop |
| `human-turn-flop` | human legal actions on the flop |
| `human-turn-turn` | human legal actions on the turn |
| `human-turn-river` | human legal actions on the river |
| `bot-turn` | a bot is acting while human controls are unavailable |
| `wager-entry` | bet or raise amount entry is active |
| `all-in-runout` | all-in hand is advancing without further input |
| `status-blank` | every shared below-seat status band is reserved but visually blank |
| `status-retained-fold` | a completed-hand seat without a hand summary retains `Fold` in its shared status band |
| `showdown-long` | bare table with revealed cards and up-to-two-line hand text in non-phone status bands; no summary overlay obscures the phone cards |
| `showdown-overlay` | phone-only recipient-safe showdown summary explicitly opened above the same completed-hand table |
| `elimination` | at least one player has been eliminated |
| `tournament-winner` | final winner presentation |
| `event-history-full` | non-phone event history filled enough to require scrolling; excluded from the phone suite |
| `quit-confirmation` | quit confirmation modal is open |
| `keypad-open` | numeric keypad is open |

Modal interaction regressions in `test_gui_modal_interaction.gd` use a real
390 x 844 `SubViewport` and delivered touch/key events, including an unblocked
positive control. They cover reading past hand timers, exclusive surfaces,
focus cycling/restoration, synthetic engine back dismissal, profile cleanup,
and keypad-to-native-quit transitions. Exported Web input tests also exercise
touch on an underlying Fold while a menu is open, Tab focus containment,
menu-to-quit switching, outside-keypad touch, and Escape cancellation. Synthetic back coverage does
not establish physical Android or browser-history navigation acceptance.

Fixtures use fixed seeds and recipient-safe `GameView` data. They must not read
hidden core state or reproduce poker rules inside the presentation harness.
When a fixture needs a modal, its manifest entry identifies that modal as an
intentional overlap exception; exceptions belong to named controls and states,
not to an entire viewport or assertion class.

## Milestone gates

Milestone 3 establishes the matrix, deterministic state harness, invariant
checks, resize coverage, capture process, and defect loop. Its layout acceptance
scope is tablet, small-desktop, and desktop geometry, including blank,
one-line-action, retained-action-at-showdown, and two-line-showdown status-band
states plus the final player-name review.

Establishing the reusable scene harness and assertion helpers is a foundation
step, not a claim that known layout defects already pass. After the unified
seat-status-row and small-desktop footprint remediations, the complete
applicable Milestone 3 invariant matrix must pass before rendered visual
acceptance begins.

Milestone 4 activates the phone portrait, phone landscape, and reduced-height
fixtures for the completed phone composition at 2, 4, 6, and 7 players. The
406-case `milestone-4-phone-v2` suite excludes `event-history-full` because phones expose no
event-history surface. Defining those fixtures during Milestone 3 does not
imply that the pre-Milestone-4 desktop composition passes phone acceptance.

QA-03 versions the suites because required text is now checked in full,
including ellipsized labels, vertical fit, line limits, and overlay text.
`milestone-3-v2` retains all 348 historical M3 case identities; the phone-only
overlay fixture is excluded from M3, iPad, and desktop matrices. The phone v2
suite adds 28 explicit summary-overlay cases to the prior 378 cases, while
`showdown-long` now captures the unobscured phone table. Existing v1 manifests
and reviews remain immutable historical evidence; they do not certify the
revised v2 checks or capture composition. Landscape fixtures remain diagnostic
regressions and do not establish phone-landscape device acceptance.

Compact portrait tablets reserve a full two-line status band and use the
existing compact showdown descriptions. Compact landscape tablets retain
single-line bands with complete categories and conventional rank symbols
(for example, `Full house: A / K`). Phone role/state badges reserve their
measured text width. Role and state tokens remain separated (for example,
`BB F` or `BB T`); the tight all-in case concatenates its unchanged tokens
(`BBAI`). Eliminated seats no longer show blind positions.
The emergency phone landscape row hides its redundant status sentence rather
than displaying a one-pixel ellipsis; the acting-seat badge and action buttons
remain visible. The revised heads-up fixture places the button on the small
blind, consistently with the product rules.

Before clean release evidence is produced, every implemented scope must pass
its canonical automated matrix and rendered review. Every known blocker,
unreadable, or obstructive defect in that scope must be fixed or explicitly
accepted by the product decision owner. Hosted browser and physical-device
testing is optional for general deployment; explicit physical-phone acceptance
remains required for its device claims. A defect found there should be fixed
and reverified; it does not retroactively turn local evidence into device
evidence.

## Automated and rendered passes

The headless automated pass owns deterministic facts: usable-viewport
containment, unintended intersections, fixed shared-status-band clearance and
height, one-line action and two-line showdown limits, text wrapping or
clipping, the 20 px player-facing font floor, minimum touch targets,
community-card visibility, legal-action reachability, and stable geometry
after repeated state and viewport changes. It must report failures by viewport
ID, player count, state ID, and stable core seat ID or named region.

The rendered pass captures the same fixture inputs with Godot's Compatibility
renderer. Review the images at 100% for hierarchy, density, contrast,
proportion, font and card clarity, state communication, and aesthetic
consistency. Screenshot checksums make evidence identifiable; exact pixel
equality is not the sole pass criterion and must not hide a human-visible
problem behind a tolerance value.

Run the implemented commands from the repository root. Override `GODOT` when
the editor binary is not on `PATH`, for example
`make GODOT=/Applications/Godot.app/Contents/MacOS/Godot <target>`.

| Command | Purpose and evidence status |
| --- | --- |
| `make gui-visual-capture-smoke` | Render only the 1280 x 720, six-player `human-turn-preflop` case. It accepts a dirty tree, writes development-only output, and checks the renderer/capture pipeline without running the complete matrix or ordinary test suite. It is never acceptance evidence. |
| `make gui-visual-invariant-gate` | Run the historical Milestone 3 tablet, small-desktop, and desktop matrix through the reusable scene harness and invariant assertions under GUT. It writes no screenshot evidence. |
| `make gui-phone-invariant-gate` | Run the distinct 406-case phone v2 matrix across canonical portrait, landscape, and reduced-height fixtures at 2, 4, 6, and 7 players. It verifies full bot names, numeric stacks, two hole-card fields, separate bare-table and summary-overlay states, absent event history, and resize cycles. |
| `make gui-ipad-invariant-gate` | Run the iPad-specific full-state matrix at canonical portrait and landscape sizes, the 1194 x 696 reduced-height Chrome regression, and the 2388 x 1450 observed surface for 2, 4, 6, 7, and 9 players. It adds centering and symmetric-arc coverage without changing the frozen 348-case Milestone 3 capture matrix. |
| `make gui-desktop-invariant-gate` | Run the desktop-specific full-state matrix at 950 x 532, 1280 x 720, the provisional 1853 x 916 screenshot raster, and 1920 x 1080 for 2, 4, 6, and 9 players. The raster fixture is diagnostic coverage and does not replace measured CSS viewport evidence. |
| `make gui-current-invariant-gate` | Run the historical Milestone 3 gate followed by the dedicated phone, iPad, and desktop gates. Pull-request validation and release candidates both require every matrix to pass. Historical fixture identities and manual device-acceptance status remain separate. |
| `make gui-visual-capture-development` | Render the complete Milestone 3 capture matrix with `--development`. It accepts a dirty tree, records dirty paths and their fingerprint, and always produces non-acceptance evidence. It does not implicitly run `make check` or the standalone invariant gate. |
| `make gui-phone-capture-development` | Render the complete Milestone 4 phone matrix as development-only evidence. Human review of this output is required by the separate local phone visual-acceptance task. |
| `make gui-visual-capture` | Produce clean candidate evidence. It refuses a dirty tree, runs `make check` and `gui-current-invariant-gate`, checks cleanliness again, then renders the complete Milestone 3 matrix. Its manifest is acceptance-eligible only when all 348 expected captures settle and pass their recorded invariants. |

`GuiInvariantMatrixSuites` declares the viewport/count/state coverage used by
both captures and gates. `GuiInvariantMatrixRunner` owns rendering, settling,
invariant checks and phone resize cycles; `GuiPhoneMatrixContract` retains the
additional phone privacy/content/touch-target checks. The four historical
manual entry points and fixture identities remain stable. Capture provenance
hashes the shared definitions, runner and phone contract alongside fixtures.

All rendered commands require a real display and the Compatibility renderer;
the capture runner rejects a headless or dummy renderer. Capture targets refuse
to overwrite an existing manifest or PNG set. Preserve an existing evidence
directory before attempting to capture the same source identity again.

The Milestone 6 local Compatibility gate targets macOS only and uses these
rendered workflows plus representative phone portrait/landscape review for
basic resizing. It does not replace or duplicate the hosted desktop-browser
and physical-device evidence that may be collected manually.

For each affected matrix slice:

1. Reproduce the case with the scene harness and record its invariant failures.
2. During remediation, run `make gui-current-invariant-gate` and use
   `make gui-visual-capture-development` or the smoke target for rendered
   evidence.
3. Validate that the manifest and PNG set are complete and mutually referential.
4. Review the captures and record pass, defect IDs, or an explicit acceptance.
5. For a defect, follow [`templates/GUI_DEFECT.md`](templates/GUI_DEFECT.md),
   add a failing regression where practical, change the owning presentation
   layer, and rerun the affected slice plus the complete suite.
6. Capture corrected development evidence without overwriting the before
   evidence. For candidate sign-off, rerun `make gui-visual-capture` from the
   clean fix commit and review that acceptance-eligible manifest.

A dirty-tree capture is useful while developing but cannot sign off a gate. A
gate manifest must identify a clean full commit SHA. Generated screenshots do
not themselves make the source tree dirty when kept in the ignored artifact
location described below.

## Screenshot names and storage

Use lowercase ASCII fixture identifiers. Separate filename fields with double
underscores. Local canonical screenshots use:

```text
<sha12>__<viewport-id>__<width>x<height>-<orientation>__p<count>__<state-id>.png
```

For example:

```text
88122bd46ef0__small_desktop_950x532__950x532-landscape__p6__showdown-long.png
```

Hosted screenshots add the test environment before the actual viewport:

```text
<sha12>__<environment-id>__<device-os-browser>__<width>x<height>-<orientation>__p<count>__<state-id>.png
```

If a state requires more than one image, append a stable suffix such as
`__before-rotation` or `__after-rotation`. Never distinguish evidence only with
timestamps or operating-system-generated counters.

Keep generated local captures and their manifest under the ignored path:

```text
Clean candidate: artifacts/gui_visual/<full-sha>/
Development:     artifacts/gui_visual/development/<full-sha>-<dirty-fingerprint>/
```

Attach an immutable archive to the release issue, pull request, or other agreed
evidence store for durable review. Repository records may link to that archive.
If a Markdown evidence record is committed after testing, it documents the
target SHA; its later documentation commit does not become or rebuild the
tested candidate.

## Capture manifest

Write `manifest.json` beside the screenshots. The manifest is generated data,
not a hand-maintained substitute for fixture definitions. It contains:

- `schema_version`, `visual_suite_version`, `capture_scope`, and whether the
  run is a development capture;
- `source_sha`, `source_tree_state`, `dirty_paths`, and the dirty fingerprint;
- `acceptance_eligible`, Godot version, display server, renderer, rendering
  driver, video adapter, UTC capture time, fixture-matrix SHA-256, and checksums
  for the matrix source files;
- one record per capture with its stable capture ID, relative filename, PNG
  SHA-256, viewport ID, logical size, usable rectangle or insets, orientation,
  layout profile, player count, state ID, fixture ID, fixed seed, and human
  seat; and
- named intentional-overlay exception IDs plus `invariants.passed`,
  `invariants.layout_settled`, and the exact invariant-failure list.

Development and filtered captures always have `acceptance_eligible: false`.
For the current `milestone-3-v2` suite, only a clean, non-development,
`full_m3` manifest containing all 348 passing captures can be
acceptance-eligible. Independently compute and record the completed manifest's
SHA-256 in its review or defect record; the runner also prints that checksum.

Review status is recorded outside the generated manifest so review cannot
silently mutate the captured input record. The review record identifies the
manifest checksum, reviewer, review time, result, defect IDs or acceptance
decision, and durable evidence URL. When optional hosted evidence is retained,
the manifest source SHA, reviewed SHA, and hosted commit SHA should match.

## Optional hosted-verification handoff

Each push to `main` automatically runs the headless release gates and deploys
the pushed commit to GitHub Pages. Rendered capture and review remain a
separate human activity. When collecting reproducible hosted evidence, use
this process:

1. Run clean `make gui-visual-capture` and independently compute the completed
   `manifest.json` SHA-256.
2. Review the full image set and record the manifest checksum, exact source
   SHA, suite and full scope, reviewer, UTC review time, result, and every
   defect or explicit acceptance decision.
3. Upload the immutable manifest, PNGs, review, and linked decisions to one
   durable HTTPS evidence location. The ignored local `artifacts/` directory
   is not the promotion record.
4. Push the reviewed commit to `main`, then record the automatically triggered
   **Deploy Web release** run URL and deployed commit SHA.
5. CI checks out the pushed SHA and runs `make release-candidate-gate`. Its
   headless environment reruns the complete suite and the historical, phone,
   iPad, and desktop invariant matrices;
   `web-release` then performs the Web export/output checks. CI does not
   regenerate representative screenshots or replace the completed rendered
   review.
6. Confirm the checked-out SHA, manifest source SHA, reviewed SHA, and live
   Pages build are identical before accepting hosted evidence.

Avoid pushing to `main` while hosted evidence is collected. A successful new
deployment replaces the tested build, so repeat the affected checks if the
evidence is intended to describe the current deployment. See
[`OPTIONAL_WEB_SETUP.md`](OPTIONAL_WEB_SETUP.md) for the GitHub configuration
and evidence fields.

## Local-review and optional hosted-evidence boundary

Canonical review establishes that the repository candidate is suitable to
publish. If optional hosted checks are performed,
[`OPTIONAL_WEB_SETUP.md`](OPTIONAL_WEB_SETUP.md)
provides fields for the deployment run, stable HTTPS URL, browser/device
versions, actual usable viewport, orientation, console result, and physical
interaction evidence. Do not reuse a local fixture label as proof that a named
browser or physical device passed.

Choose the environments that are useful for each manual review. If the result
is used to make a browser or device support claim, record untested or
unavailable environments as limitations rather than treating them as passes.
