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

- [x] **Repair legal Pot bet and Pot raise availability:** add deterministic
  reproductions for both an unopened postflop `Pot bet` and a `Pot raise`
  facing an existing wager. Cover targets at and around the minimum and
  maximum wager totals, insufficient-stack cases, and cases where the
  displayed pot target is genuinely illegal. Enable and submit the shortcut
  whenever the displayed-pot target is available and legal, using the ordinary
  core wager-validation path rather than duplicating betting rules in the GUI.
  Add regression tests for the enabled target, submitted total, disabled
  illegal states, and correct button wording. Keep this task separate from the
  Milestone 3 geometry coupled group. Seeded live-match regressions cover an
  unopened flop Pot bet to 20 and a Pot raise to 30, plus inclusive wager
  bounds, insufficient-stack and unavailable-action states, and responsive
  button wording. The focused 32-test action suite passes.

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
  orientations, test a 7-seat game. Verify the phone event log is absent,
  required seat information remains legible, Fold/Call/Raise/All-in taps work,
  and one mid-play rotation preserves state without overlap; capture before/
  after screenshots.
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

- [x] **Define and test one layout-profile classifier:** distinguish phone
  portrait, phone landscape, tablet, small desktop, and desktop from the usable
  viewport's shortest dimension, aspect ratio, and orientation. Account for
  browser chrome and safe-area reductions; do not classify solely from OS
  feature flags, raw pixel resolution, or portrait aspect. Both orientations
  of the same phone must remain phone layouts. `GuiLayoutProfile` now owns the
  geometry contract and canonical fixtures exercise every profile, browser-
  chrome reductions, rotation, and safe invalid-size fallback. The observed
  2388 x 1450 iPad regression declares an explicit tablet override; without
  that device evidence, the same usable geometry correctly remains desktop.
- [x] **Apply the approved phone player-count policy:** keep six as the actual
  default, support 2–7 players on small-phone profiles, and retain 2–9 support
  on tablet, small-desktop, and desktop profiles. Update startup validation and
  guidance, `ProjectDescription.md`, `ARCHITECTURE.md`, and regression
  expectations explicitly; never silently clamp or alter an entered value or
  an in-progress tournament when the layout profile changes. The startup GUI
  now advertises and enforces 2–7 only for phone profiles, retains entered
  values across profile changes, and directs 8–9 player configurations to a
  larger layout. Shared core validation and larger GUI profiles remain 2–9;
  the default remains 6. Focused GUI coverage passes.
- [x] **Replace full opponent panels with legible phone seat tokens:** retain the
  assigned display name, stack, position/acting/folded/all-in state, and compact
  card backs or legitimately revealed cards. Hide avatars and nonessential
  decoration on phones, use compact badges such as `D`, `SB`, `BB`, and `AI`,
  and provide additional seat details on deliberate tap without changing core
  identity or state. Size and space the tokens for the approved seven-player
  maximum so the required information is readable without overlap; do not use
  the rejected nine-player minimal-density presentation as the acceptance
  baseline. Phone opponents now render recipient-safe avatar-free tokens with
  each full catalog display name, a numeric stack, two compact hole-card
  fields, 20 px text, seat/state badges, and a full-token detail target.
  Short-lived action feedback uses the state-badge cell instead of covering a
  required field. Seven-player tokens are larger than the state-preserving 8–9
  player emergency geometry, and the focused layout, token, and manifest
  regressions pass.
- [x] **Create one bottom human interaction region:** combine the human cards,
  stack, turn status, and actions; render only currently legal actions rather
  than reserving space for every disabled desktop control. Keep each action
  reachable with the supported touch-target size and preserve unambiguous
  Fold, Check/Call, Bet/Raise, and All-in behavior. Phones now replace the
  separate human seat with one bottom region containing recipient-safe cards,
  stack, turn status, and only the current legal actions. Bet/Raise launches
  the existing validated wager-entry seam, every visible action is at least
  48 x 48 px, and leaving the phone profile restores the unchanged desktop and
  tablet control reservation. Focused legal-action, waiting-state, wager-entry,
  touch-target, and profile-restoration coverage passes.
- [x] **Remove phone event history and keep only required overlays:** do not
  render an event log field, drawer, menu entry, or phone event-history fixture.
  Preserve the event history in game state and leave non-phone event-log
  behavior unchanged. Keep wager presets and numeric entry in a bottom sheet,
  showdown details in a scrollable summary overlay, and Quit and other required
  secondary commands in an overflow menu. Every retained overlay must have an
  obvious close/cancel path, preserve recipient privacy, and restore unchanged
  table state. The phone log drawer, menu entry, controller path, and capture
  state are removed. Wager, showdown, quit, seat-detail, and overflow surfaces
  retain explicit close/cancel behavior; desktop event history and recipient-
  safe game-state history remain unchanged. Focused overlay, resize, and
  capture-manifest regressions pass.
- [x] **Simplify the phone center and action feedback:** keep community cards,
  pot, current wager, and turn status continuously legible; replace persistent
  per-seat action sentences with compact, short-lived seat-owned badges. Keep
  blind-level detail behind progressive disclosure, but remove full event
  history from the phone presentation. Do not hide information required to
  choose a legal action. Public actions appear in the acting seat token, or the
  bottom human region, for a presentation-configured duration with stale-
  expiry protection; Fold remains durable seat state. Focused coverage must
  verify center and decision copy, badge ownership, expiry, refresh, privacy,
  absence of phone event history, and restoration of the unchanged desktop
  presentation. The center continuously presents board, pot, current wager,
  and turn/legality copy; blind progression lives in More. Seat-owned action
  badges use generation-guarded expiry, while Fold remains durable. Focused
  center, privacy, expiry, overlay-absence, and desktop-restoration regressions
  pass.
- [x] **Make phone layout transitions atomic:** debounce resize/orientation
  changes, calculate all regions from one current usable rectangle, and prevent
  stale callbacks or competing `Container` and manual geometry owners from
  restoring obsolete bounds. Preserve an in-progress tournament and open UI
  state wherever safe across rotation and browser-bar changes. Phone table
  regions now consume one immutable per-generation geometry plan, resize bursts
  invalidate every older deferred callback, and layout-profile exits rebuild
  full panels so compact minima cannot leak into restored desktop/tablet bounds.
  Deterministic regressions rotate and vary browser height with overflow,
  showdown, seat details, and a transactional wager sheet open; they verify
  safe state preservation, stale-plan rejection, draft cancellation on desktop
  exit, and unchanged tournament/view state. A larger match begun on a 2–9
  profile retains its view and emergency geometry if resized to phone, displays
  explicit larger-layout guidance, and restores the supported full composition
  on exit. All focused resize regressions pass.
- [x] **Add full phone regression coverage:** run the canonical portrait and
  landscape fixtures at 2, 4, 6, and 7 players through the representative
  visual states. Verify bounds, density tiers, long names, text and touch
  minimums, legal-action reachability, overlay behavior, card privacy, resize
  stability, the absence of every phone event-log surface, and unchanged core
  outcomes. Keep the historical 348-case Milestone 3 suite unchanged. The
  Milestone 4 phone matrix must verify larger readable seat-token rectangles,
  full eight-character display names directly in each token, numeric stacks,
  two hole-card fields, the 20 px font and 48 px target floors, reachable legal
  actions, retained phone overlays,
  recipient-safe hidden/revealed cards, portrait/landscape resize cycles, and
  presentation-only core snapshots. The separate 378-case phone manifest uses
  2, 4, 6, and 7 players across seven canonical phone viewports and excludes
  the removed event-history state; the historical 348-case Milestone 3 matrix
  remains unchanged. The gate measures every rendered bot name and stack,
  requires exactly two card fields even for folded or busted bots, and rejects
  action badges that cover required fields. `make gui-phone-invariant-gate`
  passes after correcting seven-player reduced-height landscape clearance.
- [x] **Perform local phone visual acceptance:** inspect the canonical
  screenshots and interactive local runs for information hierarchy, density,
  contrast, readability, and one-handed action use. Resolve all blocker,
  unreadable, and obstructive defects before publishing the authoritative
  hosted candidate; preserve physical-device sign-off for the existing Web and
  device matrix. The complete 378-image development capture at
  `artifacts/gui_visual/development/8f398a1620188f60491c06629d10f618dc2b2ba3-dbd2ad282b13`
  was reviewed at 100%. The densest seven-player 360 x 640, 640 x 360, and
  844 x 330 cases keep every bot's full display name, numeric stack, and two
  card fields visible, with readable center status and unobstructed actions.
  Manifest SHA-256:
  `2587a10479f4a945915d89628e415fb6a926717c9bbe9ae5169f6ceb5287ec9a`.
  This dirty-tree local evidence is not physical-device or candidate sign-off.
- [x] **Document the implemented contract:** update `ARCHITECTURE.md` and
  `ProvisionalGUILayoutGuidance.md` with the final layout profiles, player-count
  policy, phone information hierarchy, overlay ownership, and automated visual
  verification workflow. `README.md`, `ProjectDescription.md`,
  `GUI_VISUAL_TESTING.md`, `WEB_SETUP.md`, and affected developer guidance now
  consistently describe the same 2–7 phone policy, required seat information,
  absent phone event history, input-source policy, and 378-case workflow.

## GUI release verification

- [x] Verify development addons and tests are excluded from release exports.
  The Web preset now excludes direct and nested `addons`, `tests`, `localtmp`,
  and `artifacts` content plus the root test harness. The focused preset test
  passes, a fresh Godot 4.7.2 release export passes the pack validator, and no
  development-only path remains in `index.pck`.
- [x] Verify Compatibility rendering on local macOS and basic mobile resizing.
  This local gate is intentionally macOS-only; hosted desktop-browser coverage
  remains in the authoritative Web/device matrix. Godot 4.7.2 rendered the
  current 1280 x 720 desktop smoke fixture through OpenGL Compatibility on an
  Apple M4 with all invariants passing. The passing resize regressions and the
  reviewed 390 x 844 portrait and 640 x 360 landscape captures verify the
  representative mobile transitions without adding another automated task.
