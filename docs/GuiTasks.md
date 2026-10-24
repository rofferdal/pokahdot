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
- [ ] Perform a visual acceptance pass verifying that bot names stay paired
  with avatars through hands, eliminations, street transitions, showdown, and
  layout reflow, with `Human` always shown for the human seat.

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

## Small desktop viewport table collision remediation

The reference surface is approximately 950 × 532. The remaining tasks reserve
space for seat annotations, side panels, the central zone, and controls.

- [x] Remove the redundant textual `ACT` seat marker while retaining the white,
  three-times-thicker acting-seat frame and explicit action-status wording.
- [ ] **Reserve all auxiliary-text clearance:** include each seat's below-seat
  latest-action label and above-seat showdown-summary label in the layout
  bounds before placing seats. The left-middle and right-middle layout
  positions must retain space below their panels; the two upper layout
  positions must retain space above their panels.
- [ ] **Prevent side-panel occlusion:** ensure the event feed and human action
  panel do not intersect any seat panel, latest-action label, or showdown
  summary at small desktop sizes. If full panels do not fit, reflow or reduce
  their presentation-only footprint while preserving all events and controls.
- [ ] **Preserve central-zone visibility:** keep the community-card, pot, and
  wager zones fully visible and separated from seats, auxiliary labels, event
  feed, and action controls at the reference viewport.
- [ ] **Preserve readable controls and touch targets:** prevent action-button
  and wager-input text from wrapping or clipping while retaining distinct
  controls and the minimum supported interaction target size.
- [ ] **Add small-desktop regression coverage:** test the reference viewport
  and nearby sizes for 2–9 seats, checking bounds, non-intersection, label
  clearance, central-zone visibility, and readable controls in preflop and
  showdown states. Assert using stable core seat IDs or named layout
  positions, never transient display labels.
- [ ] **Human verification:** run `godot --path .` and inspect 6- and 7-seat
  tables through preflop, street changes, and showdown. Confirm no player
  details, actions, showdown results, event entries, or controls are obscured.

## Systematic GUI issue detection and remediation

Complete the workflow foundation in this section before implementing the
small-phone presentation milestone below. Use the same fixtures and defect loop
for the small-desktop remediation above. These local and automated checks are
pre-release gates; they do not replace the authoritative hosted browser/device
matrix.

- [ ] **Define the canonical viewport matrix:** add named logical viewport
  fixtures for at least 360 x 640, 390 x 844, and 412 x 915 phone portrait;
  640 x 360 and 844 x 390 phone landscape; the supported iPad orientations;
  950 x 532 small desktop; and 1280 x 720 and 1920 x 1080 desktop. Include
  reduced-height phone variants that represent expanded browser chrome, and
  exercise 2-, 4-, 6-, and 9-player tables where the state applies.
- [ ] **Build deterministic visual-state fixtures:** provide a presentation-test
  harness for startup, human turn, bot turn, every street, wager entry, all-in
  runout, showdown with long summaries, elimination, tournament winner, event
  history, quit confirmation, and numeric keypad states. Use fixed seeds and
  recipient-safe `GameView` data; do not read hidden core state or duplicate
  poker rules in the harness.
- [ ] **Assert GUI invariants automatically:** for every applicable fixture,
  check usable-viewport containment, unintended intersections, auxiliary-label
  clearance, text clipping/wrapping, the 20 px player-facing font floor,
  minimum touch targets, visible community cards, and reachability of every
  legal action. Define explicit exceptions for intentional modal overlays
  instead of weakening the general assertions.
- [ ] **Cover live viewport changes:** add deterministic regressions for phone
  rotation, browser-height changes, repeated resize events, opening and closing
  overlays/keypads, and rerendering after game-state changes. Verify that one
  current layout result owns each region and no stale deferred geometry is
  applied after a newer layout pass.
- [ ] **Create a reproducible screenshot workflow:** capture stable, descriptive
  images keyed by layout profile, viewport, player count, and state, with a
  manifest recording the commit and fixture inputs. Use reviewed screenshots
  to detect hierarchy, density, contrast, and proportion defects that bounds
  assertions cannot detect; do not make brittle pixel equality the only pass
  condition.
- [ ] **Standardize the defect loop:** add a GUI defect-record template with
  severity, environment, viewport/orientation, player count, state, steps,
  expected/actual result, before/after evidence, owning layer, regression, and
  verification fields. For each defect, reproduce it deterministically, add a
  failing regression where practical, change one layout owner, rerun the
  affected matrix and complete suite, and attach the corrected evidence.
- [ ] **Document and enforce the pre-release gate:** update the relevant GUI
  testing documentation and `WEB_SETUP.md` so an immutable hosted candidate is
  produced only after the canonical automated matrix passes and all blocker,
  unreadable, and obstructive defects are closed or explicitly accepted.

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
  `gui_scaling_best_practice.md` with the final layout profiles, player-count
  policy, phone information hierarchy, overlay ownership, and automated visual
  verification workflow.

## GUI release verification

- [ ] Verify development addons and tests are excluded from release exports.
- [ ] Verify Compatibility rendering on target desktop platforms and basic
  mobile resizing.
