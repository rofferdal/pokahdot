# GUI Tasks

This backlog contains unfinished GUI, Web presentation, and device-validation
work. Task status is preserved from the source backlogs. The environment table
below is the single authoritative Web/device checklist; do not duplicate those
environment tasks elsewhere.

## Milestone dependency — Strategic default roster and optional legacy heuristics

Complete the core configuration and roster-selection gates in
[`CoreTasks.md`](CoreTasks.md) before beginning these tasks.

- [ ] Remove the “Allow experimental models” checkbox, adapter field,
  controller wiring, scene-node name, and regression coverage. Add an
  unchecked **Use legacy heuristic models** checkbox bound only to the shared
  `use_legacy_models` startup override; reset it to false whenever the startup
  form is reset.
- [ ] Update startup feedback and any match diagnostics to describe whether
  legacy heuristic models are included. Do not present a separate experimental
  mode or expose profile parameter/RNG details in the GUI.
- [ ] Add GUI adapter/controller and integration tests proving that the
  default GUI game selects only strategic profiles; enabling the checkbox
  produces the exact shared legacy/strategic split for representative 2-, 6-,
  and 9-seat tables; fixed seeds reproduce selection; and the setting remains
  immutable for an already-started tournament.

## GUI player display names

- [ ] Add a GUI-owned player-name assignment service alongside avatar
  assignment. Load the validated stored catalog of exactly 50 internationally
  representative first names, assign bot names without replacement at GUI
  tournament creation, and retain the `seat -> visual name` mapping until the
  tournament ends.
- [ ] Use only names made of Unicode letters and no longer than eight Unicode
  code points. Length is measured by code points, not bytes or grapheme
  clusters.
- [ ] Render each assigned bot name in its seat panel instead of the legacy
  numbered label. Render the human seat exactly as `Human`, regardless of core
  seat number or internal display name.
- [ ] Keep visual naming strictly presentation-only: do not write it into
  `Player`, `GameView`, match configuration, events, agents, simulation data,
  or the interactive CLI. Existing CLI `(you)` labeling remains unchanged.
- [ ] Derive name choice from the presentation-only `gui_names` RNG stream and
  avatar choice from the distinct `gui_avatars` stream. Prove that consuming
  either stream does not change the other mapping or any core RNG result.
- [ ] Preserve readable, non-overlapping name rendering at 2–9 seats across
  desktop and compact layouts. The longest catalog names and `Human` must fit
  the existing name region without reducing player-facing text below 20 px.
- [ ] Add GUI unit/regression coverage for catalog validation, deterministic
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

## GUI release verification

- [ ] Verify development addons and tests are excluded from release exports.
- [ ] Verify Compatibility rendering on target desktop platforms and basic
  mobile resizing.
