# GUI Tasks

This backlog contains unfinished GUI, Web presentation, and device-validation
work. Task status is preserved from the source backlogs. The environment table
below is the single authoritative Web/device checklist; do not duplicate those
environment tasks elsewhere. Follow the phase order in
[`ReleaseReadinessTasks.md`](ReleaseReadinessTasks.md); section position in this
ownership backlog does not override those dependency gates.

## Milestone dependency — Strategic default roster and optional legacy heuristics

Complete the core configuration and roster-selection gates in
[`CoreTasks.md`](CoreTasks.md) before beginning these tasks.

- [x] Replace the obsolete roster checkbox, adapter field,
  controller wiring, scene-node name, and regression coverage. Add an
  unchecked **Use legacy heuristic models** checkbox bound only to the shared
  `use_legacy_models` startup override; reset it to false whenever the startup
  form is reset.
- [x] Update startup feedback and any match diagnostics to describe whether
  legacy heuristic models are included. Do not present a separate experimental
  mode or expose profile parameter/RNG details in the GUI.
- [x] Add GUI adapter/controller and integration tests proving that the
  default GUI game selects only strategic profiles; enabling the checkbox
  produces the exact shared legacy/strategic split for representative 2-, 6-,
  and 9-seat tables; fixed seeds reproduce selection; and the setting remains
  immutable for an already-started tournament.

## GUI player display names

- [x] Add a GUI-owned player-name assignment service alongside avatar
  assignment. Load the validated stored catalog of exactly 50 internationally
  representative first names, assign bot names without replacement at GUI
  tournament creation, and retain the `seat -> visual name` mapping until the
  tournament ends.
- [x] Use only names made of Unicode letters and no longer than eight Unicode
  code points. Length is measured by code points, not bytes or grapheme
  clusters.
- [x] Render each assigned bot name in its seat panel instead of the legacy
  numbered label. Render the human seat exactly as `Human`, regardless of core
  seat number or internal display name.
- [x] Keep visual naming strictly presentation-only: do not write it into
  `Player`, `GameView`, match configuration, events, agents, simulation data,
  or the interactive CLI. Existing CLI `(you)` labeling remains unchanged.
- [x] Derive name choice from the presentation-only `gui_names` RNG stream and
  avatar choice from the distinct `gui_avatars` stream. Prove that consuming
  either stream does not change the other mapping or any core RNG result.
- [x] Preserve readable, non-overlapping name rendering at 2–9 seats across
  desktop and compact layouts. The longest catalog names and `Human` must fit
  the existing name region without reducing player-facing text below 20 px.
- [x] Add GUI unit/regression coverage for catalog validation, deterministic
  injected-RNG assignment, uniqueness, stable rerenders, human labeling, RNG
  isolation, and seat-panel rendering at representative 2-, 6-, and 9-seat
  layouts.
- [x] Perform a visual acceptance pass verifying that bot names stay paired
  with avatars through hands, eliminations, street transitions, showdown, and
  layout reflow, with `Human` always shown for the human seat. The complete
  348-capture Milestone 3 development corpus was independently reviewed across
  2-, 4-, 6-, and 9-seat states; names remained readable and paired with the
  same avatars through ordinary, showdown, elimination, winner, and compact
  layout states.

## Pot wager shortcut correctness

- [ ] **Repair legal Pot bet and Pot raise availability:** add deterministic
  reproductions for both an unopened postflop `Pot bet` and a `Pot raise`
  facing an existing wager. Cover targets at and around the minimum and
  maximum wager totals, insufficient-stack cases, and cases where the
  displayed pot target is genuinely illegal. Enable and submit the shortcut
  whenever the displayed-pot target is available and legal, using the ordinary
  core wager-validation path rather than duplicating betting rules in the GUI.
  Add regression tests for the enabled target, submitted total, disabled
  illegal states, and correct button wording. Keep this task separate from the
  Milestone 3 geometry coupled group.

## Authoritative Web and device acceptance matrix

Follow [`WEB_SETUP.md`](WEB_SETUP.md). Every environment has exactly one
status here and must be tested against one immutable commit and stable HTTPS
URL. Record device/OS/browser versions, viewport or orientation, screenshots,
and defects in the evidence record described by the runbook.

- [ ] **Hosted build readiness:** publish the Web export at a stable HTTPS URL.
  Open it in a private/incognito session, wait for the startup screen without
  console errors, and record URL, commit, deployment run, export settings, and
  evidence location.
- [ ] **Desktop Chrome or Edge:** on current Windows or macOS, test 2-seat and
  9-seat default tournaments at 1920 × 1080 and 1280 × 720. Complete the
  representative flow below and capture every required state plus
  readability/bounds results.
- [-] (Firefox not available) **Desktop Firefox:** repeat the desktop matrix at
  both sizes. Explicitly record font rendering, suit colors, event-history
  scrolling, and event-log/human-seat bottom alignment against approved
  references.
- [ ] **Physical iPad Safari:** in portrait and landscape, test 2-seat and
  9-seat games. Rotate during startup and live play; record scrolling,
  clipping, overlap, readability, stale-layout, and touch results.
- [-] (no available iPhone for testing) **Physical iPhone Safari:** in both
  orientations, test a 9-seat game. Verify wrapped controls, event-history
  scrolling, Fold/Call/Raise/All-in taps, and one mid-play rotation with
  before/after screenshots.
- [ ] **Physical Android Chrome:** repeat the iPhone flow with the browser
  address bar expanded and collapsed. Record touch, clipping, contrast,
  text-size, and orientation results.
- [ ] **Defect remediation:** for each reported defect, reproduce it from the
  evidence where possible, change only the appropriate presentation or
  deployment layer, add/update a regression, run the full suite, and prepare
  a new deployment candidate.
- [ ] **Evidence sign-off:** ensure every required record is attached to the
  same immutable commit and stable URL, and affected environments are rerun
  after every fix.
- [ ] **Final representative human flow:** play through normal betting, an
  all-in runout, showdown, elimination, tournament completion, and
  `player_quit`. Resolve missing, ambiguous, clipped, overlapping,
  low-contrast, or aesthetically inconsistent presentation before release.

The representative flow for each applicable environment includes a fold,
normal betting, all-in runout, showdown, elimination, tournament winner, Quit
confirmation, and `player_quit`. No environment passes on editor preview,
`file://`, LAN-only hosting, simulator-only evidence, or a different commit.

## Unified seat status row and stable geometry

Replace the separate below-seat latest-action and above-seat showdown regions
with one permanently reserved, fixed-height status band below every human and
bot seat. During play it shows the latest action on one line. At showdown it
shows recipient-safe showdown hand text when available, otherwise retaining a
relevant latest action such as `Fold`. The visually blank state remains
geometrically reserved. Size the shared band for readable showdown summaries
of up to two lines without changing its rectangle. For a hand won before
showdown, show exactly `Winner` in the winning seat's same shared band and hold
that completed-hand state for the configured showdown pause. Establish this
production geometry ownership before the small-desktop footprint remediation,
then run the combined regression and visual gates against the corrected layout.

The three tasks in this section, the small-desktop remediation tasks, and the
unified-status regression below form one validation group. Their focused
tests, the strict Milestone 3 matrix, and the complete suite pass together,
including the exact `Winner` text and shared completed-hand pause.

- [x] **Implement every player's unified status row:** give each human and bot
  seat one fixed-height below-seat band shared by latest-action and showdown
  text, and remove the separate above-seat showdown-description region. Keep
  action text to one line and permit showdown summaries up to two lines without
  reducing player-facing text below 20 px. At showdown, prefer available
  showdown hand text; otherwise retain the relevant latest action. Do not
  synthesize placeholder text when the band should be visually blank.
- [x] **Keep one geometry owner for the lower-table regions:** derive the event
  feed, human seat panel, human action panel, seat panels, and their fixed
  status bands in the same layout pass. Changing among blank, one-line action,
  retained-fold-at-showdown, and up-to-two-line showdown content must not move
  any of those rectangles or leave stale deferred geometry. A dedicated
  six- and seven-player regression also compares layout-owned seat rectangles
  on desktop and the observed landscape-tablet surface while active, folded,
  and showdown-winner content changes.
- [x] **Retain Fold through street transitions:** keep each seat's most recent
  `Fold` visible in its shared status band after the preflop, flop, turn, and
  river action-round resets, while clearing other prior-round actions. Cover
  both six- and seven-player tables and verify that a new hand clears the
  retained fold.
- [x] **Present a pre-showdown winner for the completed-hand pause:** when all
  opponents have folded, show exactly `Winner` in the winning seat's shared
  status band and retain the completed-hand presentation for the same
  `showdown_pause_seconds` duration used after showdown (five seconds by
  default) before starting any next hand. Add deterministic controller tests
  for the displayed seat and text, configurable pause, and next-hand boundary;
  do not infer hidden state or add timing to the core. The controller now uses
  the recipient-safe completed-hand winner seat only when no showdown results
  exist, and the focused action suite verifies the exact label, retained
  losing-seat `Fold`, configurable pause, and next-hand cleanup.

## Small desktop viewport table collision remediation

The reference surface is approximately 950 × 532. Treat each seat plus its
fixed-height below-seat status band as one footprint while reserving space for
side panels, the central zone, and controls.

- [x] Remove the redundant textual `ACT` seat marker while retaining the white,
  three-times-thicker acting-seat frame and explicit action-status wording.
- [x] **Reserve every unified status-band footprint:** include each seat's
  fixed-height below-seat band in layout bounds before placing seats. Reserve
  the same band height for blank, one-line action, and up-to-two-line showdown
  states at every layout position; do not retain a separate above-seat
  showdown footprint.
- [x] **Prevent side-panel occlusion:** ensure the event feed and human action
  panel do not intersect any seat panel or unified status band at small
  desktop sizes. If full panels do not fit, reflow or reduce their
  presentation-only footprint while preserving all events and controls.
- [x] **Preserve central-zone visibility:** keep the community-card, pot, and
  wager zones fully visible and separated from seats, unified status bands,
  event feed, and action controls at the reference viewport.
- [x] **Preserve readable controls and touch targets:** prevent action-button
  and wager-input text from wrapping or clipping while retaining distinct
  controls and the minimum supported interaction target size.
- [x] **Add small-desktop regression coverage:** test the reference viewport
  and nearby sizes for 2–9 seats, checking bounds, non-intersection,
  status-band clearance, central-zone visibility, and readable controls in
  blank, one-line action, retained-fold-at-showdown, and two-line showdown
  states. Assert using stable core seat IDs or named layout positions, never
  transient display labels.

## Unified status-row and footprint regression

Run this gate after the small-desktop remediation above so the 950 x 532
containment and non-intersection requirements validate the complete corrected
seat-plus-band footprint.

- [x] **Add automated unified-status-state regressions:** at the approximately
  950 x 532 reference viewport, render otherwise identical blank, one-line
  latest-action, retained-fold-at-showdown, and up-to-two-line showdown states
  across 2–9 player layouts. Assert equal seat and band positions, equal
  fixed-band height, one-line action and two-line showdown limits, readable
  text, viewport containment, and non-intersection. For the human-seat cases,
  also assert equal positions and sizes for the event feed, human seat panel,
  and human action panel.

## Startup form hierarchy and responsive sizing

The startup form is a separate GUI composition and must remain readable at the
canonical desktop, small-desktop, and tablet fixtures. Its title and
description occupy the full form width, fields remain a deliberate label/input
grid, and the action buttons form one clearly grouped row.

- [x] **Correct startup hierarchy and sizing:** use the deliberate startup
  hierarchy at 1920 x 1080 instead of pairing unrelated controls in one flat
  grid, keep normal desktop typography at the canonical desktop sizes, and
  retain compact scaling only for genuinely constrained surfaces. Verify
  portrait rotation, 950 x 532 small desktop, and iPad startup layout with
  focused controller/readability tests.
- [x] **Review corrected startup captures:** inspect the targeted development
  captures for 1920 x 1080, 1280 x 720, 950 x 532, and iPad portrait startup.
  The captures are dirty-tree development evidence and remain separate from
  clean release-candidate evidence.
- [x] **Give the startup actions explicit button affordances:** render Start
  Tournament and Quit with visible borders and distinct normal, hover,
  pressed, focus, and disabled states while retaining their grouped row. A
  focused style regression and a rendered 1920 x 1080 development capture
  verify that both controls read as buttons.

## Systematic GUI issue detection and remediation

Complete the workflow foundation in this section before implementing the
small-phone presentation milestone below. Use the same fixtures and defect loop
for the small-desktop remediation above. These local and automated checks are
pre-release gates; they do not replace the authoritative hosted browser/device
matrix. Milestone 3 defines phone fixtures so the workflow has stable inputs,
but its passing gate covers desktop, tablet, and small-desktop cases. The full
phone subset becomes a required passing gate only after the dedicated phone
composition is implemented in Milestone 4.

Follow [`GUI_VISUAL_TESTING.md`](GUI_VISUAL_TESTING.md) for the canonical
fixture IDs, capture manifest, evidence naming/storage, review boundary, and
Milestone 3/Milestone 4 gate split. Record each discovered issue with
[`templates/GUI_DEFECT.md`](templates/GUI_DEFECT.md).

- [x] **Define the canonical viewport matrix:** add named logical viewport
  fixtures for at least 360 x 640, 390 x 844, and 412 x 915 phone portrait;
  640 x 360 and 844 x 390 phone landscape; 768 x 1024 iPad portrait and
  1024 x 768 iPad landscape; 950 x 532 small desktop; and 1280 x 720 and
  1920 x 1080 desktop. Include 390 x 744 portrait and 844 x 330 landscape as
  the reduced-height phone variants representing expanded browser chrome.
  Retain 2388 x 1450 landscape as an additional observed-iPad regression, not
  as a canonical logical viewport. Exercise 2-, 4-, 6-, and 9-player tables
  where the state applies.
- [x] **Build deterministic visual-state fixtures:** provide a presentation-test
  harness for startup, human turn, bot turn, every street, wager entry, all-in
  runout, showdown with long summaries, elimination, tournament winner, event
  history, quit confirmation, and numeric keypad states. Use fixed seeds and
  recipient-safe `GameView` data; do not read hidden core state or duplicate
  poker rules in the harness.
- [x] **Implement the reusable scene harness and invariant assertions:** bind
  each applicable deterministic state fixture to the real GUI scene and add
  reusable checks for usable-viewport containment, unintended intersections,
  auxiliary-label clearance, text clipping/wrapping, the 20 px player-facing
  font floor, minimum touch targets, visible community cards, and reachability
  of every legal action. Define explicit exceptions for intentional modal
  overlays instead of weakening the general assertions. Add focused support
  tests that prove the harness and assertions detect representative violations
  and honor only the named exceptions. This foundation task is complete only
  when those support tests pass; it does not require known Milestone 3 geometry
  defects to pass the complete matrix before their remediation tasks run.
- [x] **Cover live viewport changes:** add deterministic regressions for phone
  rotation, browser-height changes, repeated resize events, opening and closing
  overlays/keypads, and rerendering after game-state changes. Verify that one
  current layout result owns each region and no stale deferred geometry is
  applied after a newer layout pass.
- [x] **Create a reproducible screenshot workflow:** capture stable, descriptive
  images keyed by layout profile, viewport, player count, and state, with a
  manifest recording the commit and fixture inputs. Use reviewed screenshots
  to detect hierarchy, density, contrast, and proportion defects that bounds
  assertions cannot detect; do not make brittle pixel equality the only pass
  condition. Keep headless geometry assertions in GUT, and run screenshot
  capture separately with rendering enabled because the headless display
  driver cannot produce representative pixels.
- [x] **Standardize the defect loop:** add a GUI defect-record template with
  severity, environment, viewport/orientation, player count, state, steps,
  expected/actual result, before/after evidence, owning layer, regression, and
  verification fields. For each defect, reproduce it deterministically, add a
  failing regression where practical, change one layout owner, rerun the
  affected matrix and complete suite, and attach the corrected evidence.
- [x] **Document and enforce the pre-release gate:** update the relevant GUI
  testing documentation and `WEB_SETUP.md` so an immutable hosted candidate is
  produced only after the applicable automated matrix passes and all blocker,
  unreadable, and obstructive defects are closed or explicitly accepted.
  Milestone 3 requires the desktop, tablet, and small-desktop subsets; after
  Milestone 4 implements the phone composition, the complete phone subset is
  required as well.
- [x] **Make the applicable Milestone 3 invariant matrix pass:** after the
  unified-status-row and small-desktop footprint remediations, run every
  applicable tablet, small-desktop, and desktop fixture and require passing
  usable-viewport containment, unintended-intersection, status-band clearance,
  text clipping/wrapping, 20 px player-facing font-floor, minimum touch-target,
  visible-community-card, and legal-action-reachability results.
  Permit only the named intentional-modal exceptions. Exercise the required
  2-, 4-, 6-, and 9-player cases and all applicable canonical states. This is
  the final combined automated geometry gate before Milestone 3 visual
  acceptance; the complete phone matrix remains a Milestone 4 gate.
  Verification: `make gui-visual-invariant-gate` passes every applicable
  2-, 4-, 6-, and 9-player tablet, small-desktop, and desktop fixture, and
  `make check` passes 445/445 tests and 13,805 GDScript assertions plus 72
  Python tests, lint, and formatting checks.

## Milestone 3 combined visual verification

Run these human checks only after the applicable Milestone 3 invariant matrix
passes against the corrected geometry.

- [x] **Verify the unified status row visually:** capture the blank, one-line
  action, retained-fold-at-showdown, and two-line showdown reference states.
  Confirm every seat and shared band remains aligned, the three lower-table
  regions remain fixed, action and showdown text remains readable, and each
  empty reserved band remains visually blank. Independent review of all 348
  rendered development captures found no remaining blocker across the required
  tablet, small-desktop, and desktop viewports. This is dirty-tree development
  evidence, not the later clean release-candidate capture.
- [x] **Verify the small-desktop correction interactively:** run
  `godot --path .` and inspect 6- and 7-seat tables through preflop, street
  changes, and showdown. Confirm no player details, actions, showdown results,
  event entries, or controls are obscured. User verification on 2026-10-25
  confirmed that gameplay is satisfactory after the seat-stability and
  retained-`Fold` corrections.

## Small-phone presentation mode

Implement a distinct phone experience instead of uniformly shrinking the
desktop table. Preserve core rules, recipient-safe views, and the 20 px text
floor. Phone-only visibility and composition decisions belong to the GUI
presentation layer.

- [ ] **Define and test one layout-profile classifier:** distinguish phone
  portrait, phone landscape, tablet, small desktop, and desktop from the usable
  viewport's shortest dimension, aspect ratio, and orientation. Account for
  browser chrome and safe-area reductions; do not classify solely from OS
  feature flags, raw pixel resolution, or portrait aspect. Both orientations
  of the same phone must remain phone layouts.
- [ ] **Record the phone player-count policy before implementation:** start from
  continued 2–9 support with a recommended four-player phone default and
  density tiers for 2–4, 5–6, and 7–9 players. Prototype and test the nine-seat
  minimal layout. Introduce a phone-only maximum only if the canonical
  acceptance criteria cannot be met, and then update `ProjectDescription.md`,
  `ARCHITECTURE.md`, startup messaging/validation, and regression expectations
  explicitly rather than silently rejecting or altering a tournament.
- [ ] **Replace full opponent panels with phone seat tokens:** retain the
  assigned display name, stack, position/acting/folded/all-in state, and compact
  card backs or legitimately revealed cards. Hide avatars and nonessential
  decoration on phones, use compact badges such as `D`, `SB`, `BB`, and `AI`,
  and provide additional seat details on deliberate tap without changing core
  identity or state.
- [ ] **Create one bottom human interaction region:** combine the human cards,
  stack, turn status, and actions; render only currently legal actions rather
  than reserving space for every disabled desktop control. Keep each action
  reachable with the supported touch-target size and preserve unambiguous
  Fold, Check/Call, Bet/Raise, and All-in behavior.
- [ ] **Move secondary content into phone overlays:** replace the permanently
  visible event log with a Log drawer, move wager presets and numeric entry to
  a bottom sheet, present showdown details in a scrollable summary overlay, and
  place Quit and other secondary commands in an overflow menu. Every overlay
  must have an obvious close/cancel path, preserve recipient privacy, and
  restore the unchanged table state.
- [ ] **Simplify the phone center and action feedback:** keep community cards,
  pot, current wager, and turn status continuously legible; replace persistent
  per-seat action sentences with compact, short-lived seat-owned badges. Move
  blind-level detail and full history behind progressive disclosure without
  hiding information required to choose a legal action.
- [ ] **Make phone layout transitions atomic:** debounce resize/orientation
  changes, calculate all regions from one current usable rectangle, and prevent
  stale callbacks or competing `Container` and manual geometry owners from
  restoring obsolete bounds. Preserve an in-progress tournament and open UI
  state wherever safe across rotation and browser-bar changes.
- [ ] **Add full phone regression coverage:** run the canonical portrait and
  landscape fixtures at 2, 4, 6, and 9 players through the representative
  visual states. Verify bounds, density tiers, long names, text and touch
  minimums, legal-action reachability, overlay behavior, card privacy, resize
  stability, and unchanged core outcomes.
- [ ] **Perform local phone visual acceptance:** inspect the canonical
  screenshots and interactive local runs for information hierarchy, density,
  contrast, readability, and one-handed action use. Resolve all blocker,
  unreadable, and obstructive defects before publishing the authoritative
  hosted candidate; preserve physical-device sign-off for the existing Web and
  device matrix.
- [ ] **Document the implemented contract:** update `ARCHITECTURE.md` and
  `ProvisionalGUILayoutGuidance.md` with the final layout profiles, player-count
  policy, phone information hierarchy, overlay ownership, and automated visual
  verification workflow.

## GUI release verification

- [ ] Verify development addons and tests are excluded from release exports.
- [ ] Verify Compatibility rendering on target desktop platforms and basic
  mobile resizing.
