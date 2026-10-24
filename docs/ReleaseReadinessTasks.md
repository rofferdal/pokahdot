# Release Readiness Orchestration Tasks

This backlog coordinates the remaining work in [`CoreTasks.md`](CoreTasks.md),
[`GuiTasks.md`](GuiTasks.md), and [`CliTasks.md`](CliTasks.md). It defines the
execution order and phase gates; the linked source backlogs remain authoritative
for the individual implementation, verification, and device-test tasks.

Do not copy individual source tasks into this file or mark a phase complete
while any linked required task remains open. The Web and device checklist in
`GuiTasks.md` is the single authoritative environment matrix.

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

- [ ] Complete the implementation and automated coverage tasks in
  [`GuiTasks.md` — GUI player display names](GuiTasks.md#gui-player-display-names):
  assignment service, bot and human labels, separate named RNG streams,
  presentation-boundary regressions, and representative 2-, 6-, and 9-seat
  rendering coverage.
- [ ] Exercise the longest allowed catalog names and `Human` in desktop and
  compact automated layouts without reducing player-facing text below 20 px.
- [ ] Run the focused GUI tests and the complete headless test suite. Preserve
  the source section's final visual-acceptance task for the combined visual
  gate in Milestone 3, where final small-viewport geometry is available.

## Milestone 3 — Stable GUI geometry and combined visual acceptance

Resolve known layout risk before collecting release or device evidence. The
approximately 950 x 532 reference viewport is the minimum explicit desktop
stress surface for this milestone.

- [ ] Complete the reusable foundation tasks in
  [`GuiTasks.md` — Systematic GUI issue detection and remediation](GuiTasks.md#systematic-gui-issue-detection-and-remediation):
  canonical viewport and state fixtures, automatic GUI invariants, resize
  coverage, reproducible screenshots, and the standard defect record/loop.
- [ ] Complete every automated implementation and regression task in
  [`GuiTasks.md` — Small desktop viewport table collision remediation](GuiTasks.md#small-desktop-viewport-table-collision-remediation),
  covering auxiliary labels, side panels, the central zone, controls, and all
  2–9 seat counts required by that section.
- [ ] Run the section's human verification with `godot --path .` through
  preflop, street changes, and showdown for 6- and 7-seat tables.
- [ ] Complete the visual-acceptance task in
  [`GuiTasks.md` — GUI player display names](GuiTasks.md#gui-player-display-names)
  against the final layout. Verify that names remain paired with avatars
  through rerenders, eliminations, showdown, and layout reflow.
- [ ] Run the full headless suite, lint, and formatting checks after the final
  layout correction. Do not begin release-candidate evidence collection until
  all checks pass.

## Milestone 4 — Small-phone presentation experience

Build a dedicated phone composition after the shared visual-test workflow is
available. This milestone simplifies presentation without changing poker rules
or recipient-safe core state.

- [ ] Complete every task in
  [`GuiTasks.md` — Small-phone presentation mode](GuiTasks.md#small-phone-presentation-mode),
  including layout-profile classification, the explicit player-count policy,
  compact opponent tokens, the bottom human action region, progressive
  disclosure overlays, atomic resize behavior, and documentation.
- [ ] Use the canonical visual fixtures and defect loop from Milestone 3 for
  phone portrait and landscape at 2, 4, 6, and 9 players. Close or explicitly
  accept every blocker, unreadable, and obstructive defect before proceeding.
- [ ] Decide the nine-player phone result from evidence. Prefer the tested
  density-tier design; if it cannot meet the documented readability, touch,
  bounds, and action-reachability criteria, make any phone-only player cap an
  explicit product-specification and startup-contract change with matching
  tests and user-facing explanation.
- [ ] Run the focused GUI tests, canonical screenshot review, complete headless
  suite, lint, and formatting checks. Local phone acceptance is required here;
  authoritative physical-device evidence remains in Milestone 8.

## Milestone 5 — Cross-interface behavioral verification

Verify that presentation work has not changed shared game behavior or startup
configuration.

- [ ] Complete both tasks in
  [`CliTasks.md` — Cross-interface release verification](CliTasks.md#cross-interface-release-verification),
  comparing GUI and CLI core outcomes for the same seed and scripted actions,
  and comparing resolved configuration for equivalent omissions and selections.
- [ ] Record the fixed seeds, scripted actions, and configuration cases in the
  relevant automated tests so failures can be reproduced without relying on a
  manual session.
- [ ] Run the complete headless suite after the cross-interface coverage is in
  place.

## Milestone 6 — Documentation and export audit

Audit the user-facing description and release packaging only after behavior and
layout have stabilized, so the review describes the candidate that will ship.

- [ ] Complete the remaining task in
  [`CoreTasks.md` — Shared release verification](CoreTasks.md#shared-release-verification)
  by reviewing user-facing text and documentation against the implemented game.
- [ ] Complete both tasks in
  [`GuiTasks.md` — GUI release verification](GuiTasks.md#gui-release-verification),
  including export exclusion of development addons/tests and Compatibility
  rendering with basic mobile resizing.
- [ ] Resolve every discrepancy found by the audits in its owning layer, add a
  regression where behavior changed, and rerun the relevant focused and full
  checks before closing this milestone.

## Milestone 7 — Immutable hosted release candidate

Create the candidate used for all authoritative browser and device evidence.
Follow [`WEB_SETUP.md`](WEB_SETUP.md); local editor, `file://`, LAN-only, and
simulator runs do not satisfy this milestone.

- [ ] Select a clean, immutable Git commit after Milestones 1–6 pass. Record
  its commit ID and confirm that no uncommitted files are included in the build.
- [ ] Run the repository release command and all checks required by
  `WEB_SETUP.md`. Confirm that the exported artifact contains the required game
  assets and excludes tests and development addons.
- [ ] Complete **Hosted build readiness** in the authoritative
  [`GuiTasks.md` Web and device matrix](GuiTasks.md#authoritative-web-and-device-acceptance-matrix):
  publish to stable HTTPS, perform the private-session startup check, and record
  the URL, commit, deployment run, export settings, and evidence location.

## Milestone 8 — Browser/device evidence and release decision

Use only the immutable commit and stable URL from Milestone 7. If a defect
requires a code or deployment change, that build is a new candidate: rerun the
affected gates and environments rather than mixing evidence across commits.

- [ ] Execute the available environments, defect-remediation loop, evidence
  sign-off, and final representative flow in the authoritative
  [`GuiTasks.md` Web and device matrix](GuiTasks.md#authoritative-web-and-device-acceptance-matrix).
- [ ] For Firefox and physical iPhone, replace each current unavailable status
  with completed evidence when access becomes available. If access will not be
  available for this release, record an explicit product decision stating
  whether support is deferred or the release remains blocked; do not treat an
  unavailable status as a pass.
- [ ] Confirm that all required evidence points to one immutable candidate,
  every defect is closed or explicitly accepted, and all affected environments
  were rerun after the final change.
- [ ] Mark release readiness complete only after every required source-backlog
  task is complete, the full automated checks pass, and the final human flow
  succeeds on the accepted hosted candidate.

## Dependency summary

Complete milestones in this order:

1. player-name contract and shared foundation;
2. GUI player-name implementation;
3. stable GUI geometry and combined visual acceptance;
4. small-phone presentation experience;
5. cross-interface behavioral verification;
6. documentation and export audit;
7. immutable hosted release candidate;
8. browser/device evidence and release decision.

The order deliberately places known layout remediation before hosted evidence.
This prevents screenshots and device results from becoming stale when player
names or small-viewport corrections change final geometry.
