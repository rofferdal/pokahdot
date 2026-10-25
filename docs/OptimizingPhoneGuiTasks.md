# Optimizing the Phone GUI

Status: Active, iterative physical-device remediation backlog  
Started: 2026-10-25  
Evidence baseline: `localtmp/from_real_tests/Screenshot_20261025_214505_Chrome.jpg`

## Purpose and working method

This document tracks improvements discovered while using Pokahdot on real
phones. It remains active until the phone experience is accepted by the user.
Each new physical-device review should add evidence and either close, refine,
or add tasks here. A passing synthetic viewport suite is necessary but is not
evidence that a named browser and physical device are satisfactory.

Do not redesign poker rules or mutate tournament state to solve presentation
problems. Phone work belongs to the GUI presentation layer and must preserve
the recipient-safe `GameView`, the desktop/tablet presentation, and an active
tournament across browser-height and orientation changes.

## Baseline review: Android Chrome portrait capture

The source image is 1080 x 2340 pixels and includes Android status/navigation
areas and Chrome browser chrome. The user reports an approximately 6.5 cm x
14 cm touch display. The game is a six-player preflop human-turn state.

Verdict: **fail**. The capture does not show the documented small-phone
composition. It appears to show the older/full table composition scaled into
a narrow portrait screen.

| Requirement | Expected phone presentation | What the capture shows | Result |
| --- | --- | --- | --- |
| Phone composition | Dedicated phone layout selected from usable logical geometry | Full seat panels and desktop-style auxiliary regions | Fail |
| Opponent seats | Avatar-free compact tokens with full name, numeric stack, marker/state, and two card fields | Large avatars; names and stacks are clipped (`Ma...`, `Luz...`, `Zul...`, `Joã...`, `Die...`) | Fail |
| Event history | No phone event-log field, drawer, menu entry, or fixture | A persistent log shows `Hand 1 started` and `Player 4 posted a blind of 5` | Fail |
| Human region | One bottom region containing cards, stack, turn status, and current legal actions | A separate large avatar/seat sits below a detached, very small action panel | Fail |
| Legal actions | Only current legal actions, each at least 48 x 48 logical px, with adequate separation | Seven densely packed text controls are difficult to read and target with a finger | Fail |
| Secondary commands | `More` opens required phone commands; Quit uses a confirmation surface | Tiny standalone `Quit` button near the table center | Fail |
| Center information | Community cards, pot, current wager, and turn/legality copy continuously legible | Community, pot, wager, blind text, seats, and Quit compete and overlap visually | Fail |
| Table geometry | No unintended overlap or clipped player-facing text | Multiple clipped labels and center/seat interference; much of the middle is unused while critical controls are compressed | Fail |
| Typography | At least 20 logical px; reflow instead of shrinking | Several controls and status lines are visibly too small for comfortable phone use | Fail pending runtime measurement |
| Finger use | Primary controls are comfortably reachable and separated | The action cluster is small, crowded, and positioned above a separate hero panel | Fail |

The current repository describes and implements a materially different phone
layout: compact opponent tokens around a reserved center, an integrated bottom
human/action region, a `More` button, no event log, and minimum 48 x 48 logical
pixel action targets. The canonical 390 x 744 and 412 x 915 development
captures illustrate that intended composition. They are comparison evidence,
not a substitute for a real-device pass.

### Initial diagnosis

Two explanations must be separated before changing layout code:

1. **Stale hosted build or browser cache.** This was eliminated after the user
   reproduced the same presentation against the current site. GitHub Actions
   run `40236546882` successfully deployed commit `97eae50727bc`, which
   contains the dedicated phone work from `b513447`.
2. **High-density Web viewport misclassification.** The 1080-pixel-wide
   screenshot is consistent with a roughly 360-CSS-pixel phone at a 3x device
   pixel ratio. If Godot receives or classifies the backing-canvas dimensions,
   the current `PHONE_MAX_SHORT_EDGE` of 600 rejects 1080 as a phone. The
   resulting non-phone branch would explain the avatars, event log, standalone
   Quit control, full seat panels, and desktop action composition together.

The deployed loader confirms the second explanation. Its full-window resize
path sets the canvas backing size to `window.innerWidth * devicePixelRatio`,
while the project retained a fixed 1920 x 1080 virtual content base. The GUI
therefore received large virtual geometry and selected a non-phone profile.

## Tasks

Tasks are ordered. Complete the first unchecked task before moving to the
next, unless the user explicitly changes the order. A checkbox may be marked
complete only when its acceptance evidence has been recorded.

### Phase 1 — Establish what ran on the phone

- [x] **Record and assess the first physical-device capture.** Compare the
  Android Chrome screenshot with
  [`ProjectDescription.md`](ProjectDescription.md),
  [`ProvisionalGUILayoutGuidance.md`](ProvisionalGUILayoutGuidance.md), the
  completed phone milestone in [`GuiTasks.md`](GuiTasks.md), current phone
  code, and canonical phone captures. Record the verdict, visible defects,
  initial hypotheses, and screenshot limitations in this document.
- [x] **Tie the capture to an exact hosted build.** Record the full tested URL,
  successful **Deploy Web release** run URL, deployed commit SHA, and user
  confirmation that the capture remains representative. Verify that the
  deployed SHA contains commit `b513447` or later. If it does not, wait for or
  fix the deployment, reload in a fresh session, and capture the same state again.
  Acceptance: the evidence unambiguously identifies the code that produced the
  screen; a stale-build finding is not misreported as a layout-code defect.
  The user reproduced the issue on the current Pages site. Workflow run
  `40236546882` deployed `97eae50727bc` successfully and therefore rules out a
  pre-Milestone-4 release. Device/OS/browser version details remain useful for
  the final evidence record but are not needed to identify this defect's code.
- [ ] **Capture runtime viewport and profile diagnostics on the real phone.** In
  a temporary or explicitly enabled diagnostic surface, record CSS viewport
  width/height, canvas CSS size, canvas backing size, device-pixel ratio,
  Godot viewport size, table root size, usable rectangle, safe-area/browser
  reductions, selected `GuiLayoutProfile.Kind`, and mobile/touch feature
  signals. Keep diagnostics out of ordinary production play. Acceptance: one
  evidence record explains exactly why the runtime selected its profile.
- [x] **Reproduce the diagnosed path locally.** Add a deterministic fixture for
  the real metrics, including distinct CSS/logical and backing-canvas sizes
  when they differ. First demonstrate that the fixture catches the observed
  wrong composition. Acceptance: the regression fails before the correction
  and does not depend on the physical phone to run. Regression coverage now
  proves that an unnormalized 1080-wide backing canvas selects desktop, while
  DPR-normalized portrait and landscape sizes instantiate the real phone
  composition.

### Phase 2 — Make actual phone classification reliable

- [x] **Correct the usable-geometry boundary.** Ensure layout classification
  receives one normalized logical usable rectangle after browser chrome and
  safe-area reductions, rather than accidentally classifying physical screen
  or backing-canvas pixels. Mobile/OS/touch evidence may supplement ambiguous
  geometry but must not be the sole signal; a phone-sized desktop window must
  still receive the phone layout. Keep profile selection in the GUI adapter,
  not the poker core. Acceptance: the recorded Android metrics select
  `PHONE_PORTRAIT`, canonical desktop/tablet fixtures retain their profiles,
  and resize/rotation does not mutate match state. The Web composition root now
  assigns backing-size/DPR geometry to `Window.content_scale_size`; native
  composition is unchanged, and Web resize events refresh the same boundary.
- [x] **Add high-density Web regression coverage.** Cover at least a 360 x 780
  logical viewport represented by a 1080 x 2340-class device capture, browser
  chrome expansion/collapse, device-pixel ratios 1/2/3, and portrait-to-
  landscape rotation. Assert the selected profile and the resulting phone
  composition, not only the classifier return value. Acceptance: avatars,
  event history, the standalone Quit button, and full opponent panels cannot
  reappear in these phone fixtures. Coverage includes DPR 3 portrait and
  landscape composition, phone composition at DPR 1/2/3, fractional DPR 2.625
  recovery, DPR 2 desktop preservation, invalid input, and explicit assertions
  that phone avatars, event history, and standalone Quit are absent while
  `More` remains visible.
- [ ] **Verify the corrected build on the same Android phone.** Deploy a clean
  commit, use a fresh session, capture startup and the same six-player preflop
  turn, and record all provenance. Acceptance: the physical phone shows the
  compact phone composition and the user confirms that the classification
  problem is gone.

### Phase 3 — Tune the composition for fingers and legibility

- [ ] **Validate and tune the bottom human/action region physically.** Measure
  every visible action and `More` target in logical pixels and check it by
  touch on the 6.5 cm x 14 cm screen. Keep targets at least 48 x 48 logical px,
  preserve spacing against accidental taps, show only legal actions, and keep
  the primary choices in comfortable thumb reach. Acceptance: Fold,
  Check/Call, Bet/Raise, All-in, More, wager entry, and cancellation can each
  be selected reliably without zooming or precision tapping.
- [ ] **Validate all six-player seat tokens and center information.** Require
  full assigned names, numeric stacks, two card fields, state/position badges,
  community cards, pot, current wager, and turn copy to remain readable and
  non-overlapping at the real usable viewport. Preserve the 20 px logical font
  floor. Acceptance: no ellipsis or clipping removes required seat identity,
  and no seat obscures the decision information.
- [ ] **Validate browser bars, safe areas, and Android navigation behavior.**
  Exercise the address bar expanded and collapsed, page scroll prevention,
  fullscreen if supported, keyboard/keypad opening, back navigation, and
  rotation. Acceptance: controls remain inside the current usable area and no
  stale layout pass moves content under browser or system UI.
- [ ] **Validate phone overlays by touch.** Exercise wager entry, overflow,
  seat detail, showdown summary, and quit confirmation. Each surface must have
  an obvious 48 x 48-or-larger close/cancel path, preserve its transaction
  semantics and recipient privacy, and restore the unchanged table. Acceptance:
  no overlay is clipped, trapped, or accidentally dismissed by an adjacent
  control.

### Phase 4 — Broaden physical-device confidence

- [ ] **Run the supported portrait player-count sweep.** On the Android phone,
  review 2-, 4-, 6-, and 7-player tables in startup, bot turn, human turn on
  multiple streets, wager entry, all-in runout, showdown, elimination, and
  tournament winner states. Acceptance: every required identity and legal
  action remains reachable, legible, and unobstructed.
- [ ] **Run the landscape and reduced-height sweep.** Repeat the critical
  human-turn and overlay states in landscape with browser chrome expanded and
  collapsed. Acceptance: phone landscape stays a phone layout, retains at
  least 48 x 48 action targets, and does not lose center decision information.
- [ ] **Perform an independent browser/device check.** After Android Chrome is
  accepted, verify at least one materially different phone/browser combination
  from the optional hosted matrix. Record differences as new tasks instead of
  weakening the shared requirements.
- [ ] **Close the phone optimization backlog only with user acceptance.** Run
  the focused phone tests, complete visual invariant gate, full `make check`,
  and physical-device review against one clean deployed SHA. Reconcile current
  guidance in `README.md`, `docs/`, and `devdocs/`, then mark this document
  complete only after the user states that the phone experience is
  satisfactory.

## Evidence log

### 2026-10-25 — Initial Android Chrome capture

- Evidence: `localtmp/from_real_tests/Screenshot_20261025_214505_Chrome.jpg`
- Raster size: 1080 x 2340.
- Physical screen reported by user: approximately 6.5 cm x 14 cm, touch input.
- Visible state: six-player preflop human turn, 5/10 blinds.
- Result: fail; full/legacy composition appears instead of the dedicated phone
  composition.
- Deployment SHA and workflow run were subsequently established below. Device
  model, Android/Chrome versions, CSS viewport, device-pixel ratio, canvas
  dimensions, and selected runtime profile have not yet been recorded.
- Next action at capture time: establish deployed-build provenance.

### 2026-10-25 — Current deployment and high-DPI diagnosis

- Hosted URL: `https://rofferdal.github.io/pokahdot/`.
- Successful workflow run: `https://github.com/rofferdal/pokahdot/actions/runs/40236546882`.
- Deployed commit: `97eae50727bcca3515b322358ba7cb78d6b38b07`.
- User re-check: the original capture remains representative on the current
  hosted build.
- Loader evidence: full-window policy 2 sets backing width and height from
  `window.innerWidth`/`window.innerHeight` multiplied by `devicePixelRatio`.
- Project evidence: the 1920 x 1080 `canvas_items`/`expand` virtual base kept
  phone controls in large virtual coordinates, so the layout classifier did
  not receive CSS-pixel phone geometry.
- Correction: normalize Web backing geometry through
  `DisplayServer.screen_get_scale()` into root `Window.content_scale_size` and
  refresh it on Web window-size changes.
- Automated evidence: 503/503 GUT tests and 16,821 assertions pass, including
  portrait/landscape high-density composition regressions.
- Next action: deploy the correction and verify it on the same Android phone.
