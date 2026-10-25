# Release Readiness Orchestration Tasks

This backlog records the completed ordered work in [`CoreTasks.md`](CoreTasks.md),
[`GuiTasks.md`](GuiTasks.md), and [`CliTasks.md`](CliTasks.md). It defines the
execution order and phase gates; the linked source backlogs remain authoritative
for the individual implementation and verification evidence.

Individual source tasks are not duplicated here. Optional hosted browser and
physical-device verification is documented separately in [`WEB_SETUP.md`](WEB_SETUP.md)
and is not tracked by this completed backlog.

## Milestone 1 — Player-name contract and shared foundation

Complete this milestone before changing GUI player-name rendering. It fixes the
data constraints and presentation-only boundary that the GUI must consume.

- [x] Complete every task in
  [`CoreTasks.md` — GUI player-name presentation foundation](CoreTasks.md#gui-player-name-presentation-foundation),
  including the stored 50-name catalog, Unicode validation, deterministic
  assignment contract, and tests for uniqueness, stability, and RNG isolation.
- [x] Confirm the completed design remains presentation-only: no assigned name,
  catalog dependency, or `gui_names` RNG state may enter `Player`, `GameView`,
  match configuration, domain events, agent decisions, simulation artifacts,
  or interactive CLI output.
- [x] Run the focused foundation tests and the complete headless test suite.
  Mark this milestone complete only when both pass with zero errors.

## Milestone 2 — GUI player-name implementation

Build the visible feature on the stable contract from Milestone 1. Keep the
seat-to-name mapping stable for the whole tournament and independent from avatar
selection and core randomness.

- [x] Complete the implementation and automated coverage tasks in
  [`GuiTasks.md` — GUI player display names](GuiTasks.md#gui-player-display-names):
  assignment service, bot and human labels, separate named RNG streams,
  presentation-boundary regressions, and representative 2-, 6-, and 9-seat
  rendering coverage.
- [x] Exercise the longest allowed catalog names and `Human` in desktop and
  compact automated layouts without reducing player-facing text below 20 px.
- [x] Run the focused GUI tests and the complete headless test suite. Preserve
  the source section's final visual-acceptance task for the combined visual
  gate in Milestone 3, where final small-viewport geometry is available.

## Milestone 3 — Stable GUI geometry and combined visual acceptance

Resolve known layout risk before collecting release or device evidence. The
approximately 950 x 532 reference viewport is the minimum explicit desktop
stress surface for this milestone.

- [x] Complete the reusable foundation tasks in
  [`GuiTasks.md` — Systematic GUI issue detection and remediation](GuiTasks.md#systematic-gui-issue-detection-and-remediation):
  canonical viewport and state fixtures, the reusable GUI scene harness and
  invariant assertions, resize coverage, reproducible screenshots, the
  standard defect record/loop, and gate documentation. Complete the harness
  task only after its focused support tests pass. This step establishes the
  reusable mechanism; known geometry failures are resolved by the coupled
  validation group below before the combined matrix must pass. Define the phone
  fixtures here for reuse, but defer the complete phone pass until Milestone 4.
- [x] Complete the unified status-row and small-desktop footprint work as one
  coupled validation group, in this order:
  1. complete all production presentation and geometry tasks in
     [`GuiTasks.md` — Unified seat status row and stable geometry](GuiTasks.md#unified-seat-status-row-and-stable-geometry),
     replacing the separate action and showdown-description regions with one
     permanently reserved fixed-height band below every seat, showing exactly
     `Winner` there for a hand won before showdown, and retaining either type
     of completed-hand presentation for the same configured pause;
  2. complete every incomplete implementation and regression task in
     [`GuiTasks.md` — Small desktop viewport table collision remediation](GuiTasks.md#small-desktop-viewport-table-collision-remediation),
     treating each seat and band as one footprint and removing the obsolete
     above-seat showdown clearance; and
  3. complete **Add automated unified-status-state regressions** in
     [`GuiTasks.md` — Unified status-row and footprint regression](GuiTasks.md#unified-status-row-and-footprint-regression),
     comparing blank, one-line action, retained-fold-at-showdown, and
     up-to-two-line showdown states across 2–9 players.
  Require stable seat and band rectangles, fixed band height, the documented
  line limits, readable text, viewport containment, non-intersection, and
  unchanged lower-table regions. The geometry, footprint, and regression
  constituents, including the exact `Winner` status and shared completed-hand
  pause, pass the strict matrix and complete suite together.
- [x] Complete **Make the applicable Milestone 3 invariant matrix pass** in
  [`GuiTasks.md` — Systematic GUI issue detection and remediation](GuiTasks.md#systematic-gui-issue-detection-and-remediation).
  Require the tablet, small-desktop, and desktop subsets to pass every listed
  invariant across the applicable canonical states and required player counts.
  Do not require the complete phone matrix before the dedicated phone
  composition in Milestone 4. `make gui-visual-invariant-gate` passes the full
  required 2-, 4-, 6-, and 9-player subset.
- [x] Complete both tasks in
  [`GuiTasks.md` — Milestone 3 combined visual verification](GuiTasks.md#milestone-3-combined-visual-verification):
  confirm the blank, one-line action, retained-fold-at-showdown, and two-line
  showdown states keep every seat, shared status band, and all three
  lower-table regions fixed and readable, then inspect 6- and 7-seat tables
  with `godot --path .` through preflop, street changes, and showdown. The
  rendered matrix passed independent review, and the user confirmed on
  2026-10-25 that 6- and 7-seat gameplay is satisfactory after correction.
- [x] Complete the visual-acceptance task in
  [`GuiTasks.md` — GUI player display names](GuiTasks.md#gui-player-display-names)
  against the final layout. Verify that names remain paired with avatars
  through rerenders, eliminations, showdown, and layout reflow. Independent
  review of the 348-capture development corpus passed this scope. A clean
  capture may still be produced when preparing optional hosted evidence.
- [x] Run the full headless suite, lint, and formatting checks after the final
  layout correction. Do not collect clean rendered evidence until all checks
  pass. `make check` passes 445/445 tests and 13,805 GDScript
  assertions plus 72 Python tests, lint, and formatting. The strict applicable
  Milestone 3 invariant gate also passes, and the user confirmed the corrected
  6-/7-seat gameplay interactively.

## Milestone 4 — Small-phone presentation experience

Build a dedicated phone composition after the shared visual-test workflow is
available. This milestone simplifies presentation without changing poker rules
or recipient-safe core state. The six-player tournament default remains
unchanged. Small-phone profiles support 2–7 players, while larger profiles
retain 2–9 support. Do not render an event log field, drawer, or other event-
history surface on small phones; use the recovered space to make every bot seat
large enough to communicate its required public information without overlap.

- [x] Complete every task in
  [`GuiTasks.md` — Small-phone presentation mode](GuiTasks.md#small-phone-presentation-mode),
  including layout-profile classification, the explicit player-count policy,
  compact opponent tokens, the bottom human action region, progressive
  disclosure overlays, atomic resize behavior, and documentation. All source
  tasks are complete with the local development-evidence limitations recorded
  in `GuiTasks.md`.
- [x] Use the canonical visual fixtures and defect loop from Milestone 3 for
  phone portrait and landscape at 2, 4, 6, and 7 players. Make the full phone
  fixture subset pass here, and close or explicitly accept every blocker,
  unreadable, and obstructive defect before proceeding. The 378-case phone
  invariant gate passes, and the reviewed development manifest has SHA-256
  `2587a10479f4a945915d89628e415fb6a926717c9bbe9ae5169f6ceb5287ec9a`.
- [x] Implement the approved seven-player maximum for small-phone profiles.
  Keep six as the actual startup default, retain 2–9 validation on tablet,
  small-desktop, and desktop profiles, and provide clear phone-specific
  validation and user-facing guidance instead of silently altering an entered
  value or an in-progress tournament. Focused startup and resize tests pass.
- [x] Remove the event log from the small-phone composition, including its
  drawer/menu entry and phone visual fixtures. Preserve event history in the
  game state and keep existing non-phone event-log behavior unchanged. Reclaim
  the phone space for larger opponent seats rather than replacing the log with
  another persistent surface. Phone overlay and capture-manifest tests pass;
  the historical non-phone invariant matrix remains green.
- [x] Define and implement one responsive numeric-input policy for startup
  configuration fields and the live-table wager field. On keyboard-capable
  small-desktop and desktop profiles, mouse focus and ordinary field
  interaction must accept physical-keyboard digits and editing keys without
  automatically opening or requiring the in-canvas numeric keypad. Preserve
  the in-canvas keypad for touch-driven phone and tablet interaction, and do
  not infer physical-keyboard availability from viewport size alone. Dispatch
  now follows touch versus pointer events on every layout profile.
- [x] Add automated regressions for numeric input across layout profiles and
  input methods. Cover physical-keyboard entry, correction, cancellation, and
  submission on desktop; touch opening and closing of the in-canvas keypad;
  unchanged minimum/maximum validation; and transitions between touch and
  keyboard input without losing or submitting a value unexpectedly. The 60
  focused startup, wager, and keypad tests pass.
- [x] Run the focused GUI tests, canonical screenshot review, complete headless
  suite, lint, and formatting checks. Local phone acceptance is required here;
  verify the responsive numeric-input matrix here as well. Optional
  physical-device verification remains outside this backlog. `make check`
  passes 489 GUT tests and 72 Python tests; lint and formatting pass; both the
  historical Milestone 3 and 378-case phone invariant gates pass. The local phone capture
  review is development evidence and does not claim physical-device behavior.

## Milestone 5 — Cross-interface behavioral verification

Verify that presentation work has not changed shared game behavior or startup
configuration.

- [x] Complete
  [`GuiTasks.md` — Pot wager shortcut correctness](GuiTasks.md#pot-wager-shortcut-correctness),
  including deterministic bet and raise reproductions, ordinary core legality
  and bounds validation, and regression coverage for enabled and disabled
  shortcut states. Seeded live-match regressions now exercise both wager
  kinds through the ordinary core submission path; the focused 32-test GUI
  action suite passes.

- [x] Complete
  [`CliTasks.md` — CLI bot-profile startup presentation](CliTasks.md#cli-bot-profile-startup-presentation),
  including one startup row per bot seat with its assigned
  `BotProfile.display_name`, stable seat-to-profile mapping, preserved human
  labeling and existing diagnostics, and deterministic default/mixed-roster
  regression coverage. The CLI now constructs the match and startup report
  from one selection result; the focused 11-test integration suite passes.

- [x] Complete both tasks in
  [`CliTasks.md` — Cross-interface release verification](CliTasks.md#cross-interface-release-verification),
  comparing GUI and CLI core outcomes for the same seed and scripted actions,
  and comparing resolved configuration for equivalent omissions and selections.
  The focused cross-interface suite passes all five tests.
- [x] Record the fixed seeds, scripted actions, and configuration cases in the
  relevant automated tests so failures can be reproduced without relying on a
  manual session. The tests record outcome seed `9123`, four check-or-call
  actions, startup-default seed `20261026`, full explicit selections, and four
  single-field selection/three-field omission cases.
- [x] Run the complete headless suite after the cross-interface coverage is in
  place. `make check` passes 497 GUT tests and 72 Python tests; repository-wide
  GDScript lint and formatting checks pass.

## Milestone 6 — Documentation and export audit

Audit the user-facing description and release packaging only after behavior and
layout have stabilized, so the review describes the candidate that will ship.

- [x] Complete the remaining task in
  [`CoreTasks.md` — Shared release verification](CoreTasks.md#shared-release-verification)
  by reviewing user-facing text and documentation against the implemented game.
  The review corrected launch/version guidance, current roster documentation,
  selection and validation wording, and nonportable links; all current local
  Markdown links resolve.
- [x] Complete both tasks in
  [`GuiTasks.md` — GUI release verification](GuiTasks.md#gui-release-verification),
  including export exclusion of development addons/tests and Compatibility
  rendering with basic mobile resizing. The local rendering gate is macOS-only;
  browser coverage may be performed separately using the optional manual
  runbook.
- [x] Resolve every discrepancy found by the audits in its owning layer, add a
  regression where behavior changed, and rerun the relevant focused and full
  checks before closing this milestone. The export-filter regression, fresh
  Web release output validation, 497-test GUT suite, 72 Python tests, lint,
  formatting, Markdown-link audit, and macOS Compatibility smoke all pass.

## Dependency summary

Complete milestones in this order:

1. player-name contract and shared foundation;
2. GUI player-name implementation;
3. stable GUI geometry and combined visual acceptance;
4. small-phone presentation experience;
5. cross-interface behavioral verification;
6. documentation and export audit.

The order deliberately places layout remediation before the documentation and
export audit so the completed review describes the implementation that ships.
