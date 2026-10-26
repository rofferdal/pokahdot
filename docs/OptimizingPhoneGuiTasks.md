# Optimizing the Phone GUI

Status: Active — automated action-amount remediation passes; physical Android
verification is next
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
  completed phone milestone in [`GuiTasks.md`](arkiv/GuiTasks.md), current phone
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
- [x] **Verify the corrected portrait build on the same Android phone.** Deploy a clean
  commit, use a fresh session, capture startup and the same six-player preflop
  flow, and record all provenance. Acceptance: the user confirms that portrait
  operation is functional and the original always-desktop classification
  problem is gone. Commit `71463cb9152fe8c6efbd7cfe7e8a36182394517a`
  deployed successfully in workflow run `40238155060`; the user reports that
  most portrait behavior now works as described. Startup capture
  `1000049752.jpg` visibly uses the phone form and
  `Screenshot_20261025_232148_Chrome.jpg` shows the compact table. Rotation/
  landscape is excluded from this acceptance and tracked separately below.

### Phase 3 — Tune the composition for fingers and legibility

- [x] **Validate the bottom human/action region physically.** Measure
  every visible action and `More` target in logical pixels and check it by
  touch on the 6.5 cm x 14 cm screen. Keep targets at least 48 x 48 logical px,
  preserve spacing against accidental taps, show only legal actions, and keep
  the primary choices in comfortable thumb reach. Acceptance: Fold,
  Check/Call, Bet/Raise, All-in, More, wager entry, and cancellation can each
  be selected reliably without zooming or precision tapping. The corrected
  portrait capture shows one integrated bottom region with large, separated
  Fold, Call, All-in, Raise, and More targets; the user reports that portrait
  operation works as described.
- [x] **Validate all six-player seat tokens and center information.** Require
  full assigned names, numeric stacks, two card fields, state/position badges,
  community cards, pot, current wager, and turn copy to remain readable and
  non-overlapping at the real usable viewport. Preserve the 20 px logical font
  floor. Acceptance: no ellipsis or clipping removes required seat identity,
  and no seat obscures the decision information. The corrected portrait
  capture retains five full names, five numeric stacks, two card fields per
  opponent, position/state badges, board slots, pot, current wager, hero cards,
  stack, and turn copy without overlap. It also exposed a clipped `Fold` badge
  and empty framed badge cells; the working tree now uses an intentional `F`
  state badge and hides empty badge cells without narrowing names. A later turn
  capture exposed numeric amount clipping and uneven seat placement in another
  state; those follow-up defects are tracked below.
- [x] **Add a failing phone regression for per-seat action persistence.** Drive
  several players through one betting round and require every seat to retain
  its own latest public action after later players act and after any transient
  notification timer expires. A later action by the same player must replace
  only that seat's previous action. Actions must clear at the defined new-
  street or new-hand boundary, while durable fold presentation remains clear.
  Acceptance: the regression fails on the current behavior and uses only
  recipient-safe public action history.
- [x] **Keep each phone seat's latest betting-round action visible.** Make the
  compact seat-owned action/status presentation persist for the whole current
  betting round instead of expiring as a transient message. Fit Check, Call,
  Bet, Raise, All-in, and Fold states without hiding the full name, numeric
  stack, position marker, or two card fields; do not change poker-core rules or
  leak private information. Acceptance: each player's most recent action is
  continuously attributable to that player until the proper reset boundary.
- [x] **Add portrait regressions for amount visibility and symmetric opponent
  placement.** Reproduce
  `localtmp/from_real_tests/Screenshot_20261026_001503_Chrome.jpg` with a
  six-player turn-state fixture. Assert that the complete current-wager amount
  and every seat-owned Bet/Raise/Call amount fit without ellipsis or ambiguous
  abbreviation. Also assert mirrored opponent geometry in clockwise order:
  Linh lower-left, Bao upper-left, Lior top-center, Haruto upper-right, and
  Kwame lower-right. Acceptance: the tests fail on the captured composition
  before production layout changes and retain the 20 px logical font floor.
- [x] **Restore complete pot, current-wager, and latest-action amounts.** Use
  the same phone text size as the player-seat copy for `Pot` and `Current
  wager`, as suggested by the physical review, and reserve enough width for
  their numeric values. Reflow or widen the seat-owned action cell so full bet
  and raise amounts remain visible instead of collapsing to copy such as
  `B1`. Acceptance: representative small, large, and all-in amounts remain
  unambiguous without hiding names, stacks, markers, cards, or legal actions.
- [x] **Make the six-player portrait opponent arc symmetric.** Preserve the
  clockwise seat order while assigning mirrored fixed footprints around the
  center: Linh and Kwame form the lower pair, Bao and Haruto form the upper
  pair, and Lior is centered at the top. Generalize the same symmetry rule to
  supported 2-, 4-, and 7-player portrait tables without moving seats between
  action states. Acceptance: mirrored pairs have equal offsets and sizes,
  Lior's corresponding five-opponent slot is top-centered, and no seat/status
  region intersects the board or human/action region.
- [x] **Add a Web-font regression for complete opponent and human action
  amounts.** Reproduce
  `localtmp/from_real_tests/Screenshot_20261026_004126_Chrome.jpg` with the
  deployed Web font/rendering path and a current wager of 310. Require Linh's
  seat-owned action to show its complete amount instead of `R31`, and require
  the human summary to show the complete latest action instead of only `R`.
  Cover Bet, Call, and Raise values with one through four digits plus an all-in
  boundary value. Acceptance: the regression fails against the captured
  geometry before production changes and measures the rendered glyph width,
  not only the label's assigned rectangle or native desktop font metrics.
- [x] **Reserve sufficient portrait width for opponent action amounts.** Stop
  relying on an exact 48 px opponent action cell that only barely fits selected
  three-digit fixtures. Reflow the compact token's stack, action, and card
  fields so the complete recipient-safe action value fits with visible internal
  padding at the 20 px font floor. Preserve the full name, numeric stack,
  position/state marker, and both card fields without increasing token overlap
  or breaking the symmetric 2-, 4-, 6-, and 7-player footprints. Acceptance:
  no action suffix is clipped or ellipsized in native or Web rendering.
- [x] **Give the human latest-action badge content-driven space.** Rework the
  bottom summary so the complete human Check, Call, Bet, Raise, All-in, or Fold
  value remains visible alongside the hero cards, stack, and `More`. The badge
  must not collapse to a single action prefix when sibling controls consume the
  row. Acceptance: representative `B120`, `C310`, `R310`, and large all-in
  values render in full with padding while `More` remains at least 48 x 48 and
  the legal-action buttons remain unobstructed.
- [x] **Extend the phone invariant matrix with action-content padding.** Check
  both opponent tokens and the human summary at the shortest supported portrait
  viewport, the recorded Android logical viewport, browser-bar expansion and
  collapse, DPR 1/2/3, and portrait resize restoration. Assert rendered text
  plus intentional horizontal padding fits its owned cell and that stack,
  cards, badges, center information, and action controls do not intersect.
  Acceptance: the native and Web-sensitive regressions pass without lowering
  the 20 px font floor or weakening existing containment assertions.
- [ ] **Verify persistent actions on the physical phone.** Deploy one clean SHA
  and exercise 2-, 4-, 6-, and 7-player portrait tables across preflop, flop,
  turn, and river, including repeated actions by one player, folds, all-ins,
  and street transitions. Acceptance: the user confirms the latest action for
  every player remains legible and correctly resets, with no loss of touch
  usability; record screenshots and deployment provenance here.
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
- [ ] **Decide whether phone landscape is supported.** **Deferred by the user.**
  The user reports that landscape does not work well. Before implementation
  resumes, choose either a supported landscape contract with its required
  reduced-height sweep or an explicit portrait-only product contract with clear
  behavior on rotation. Do not treat unsupported landscape as an implicit,
  broken desktop fallback.
- [ ] **Capture runtime diagnostics if phone classification recurs.** In a
  temporary or explicitly enabled diagnostic surface, record CSS viewport,
  canvas CSS and backing sizes, device-pixel ratio, Godot root/table sizes,
  usable rectangle, selected profile, and mobile/touch signals. Keep this out
  of ordinary production play. This evidence enhancement is deferred unless a
  portrait classification defect recurs or landscape support resumes.
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

### 2026-10-25 — Corrected deployment physical-phone review

- Hosted URL: `https://rofferdal.github.io/pokahdot/`.
- Successful workflow run:
  `https://github.com/rofferdal/pokahdot/actions/runs/40238155060`.
- Deployed commit: `71463cb9152fe8c6efbd7cfe7e8a36182394517a`.
- Evidence: `localtmp/from_real_tests/1000049752.jpg` and
  `localtmp/from_real_tests/Screenshot_20261025_232148_Chrome.jpg`; both files
  are 1080 x 2340 JPEGs without an orientation tag.
- Startup result: pass. The first capture uses the phone form, retains default
  six players, advertises the 2–7 limit and four-player recommendation, and
  keeps its fields and actions large and visible between browser/system chrome.
- User result: portrait is not yet considered visually polished, but most
  behavior works as described. The only reported functional problem is the
  landscape path, whose follow-up the user deferred.
- Table result: pass with minor polish findings. The correct capture visibly
  uses compact avatar-free opponent tokens, hides event history and standalone
  Quit, presents `More`, and integrates the hero cards, stack, turn copy, and
  current legal actions in the bottom region. Required information is readable
  and the user reports that portrait interaction works.
- Polish finding: durable folded-state text is clipped to `Fol`, and empty
  framed badge cells resemble extra cards. The follow-up correction uses a
  compact `F` and hides empty badge cells while preserving name width.
- Added automated evidence: the real `main.tscn` startup-to-table transition at
  360 x 780 now has a regression requiring the phone profile, hidden event log
  and standalone Quit, and visible `More`. It passes locally, so the ordinary
  portrait transition does not reproduce the deferred rotation path.
- Current automated result: 505/505 GUT tests and 16,831 assertions pass; the
  complete phone invariant gate also passes.

### 2026-10-25 — Physical-phone action-persistence follow-up

- The user confirms that the portrait phone interface otherwise behaves as
  described.
- Remaining portrait defect: each player's latest action is not retained and
  visible for the duration of the current betting round.
- The phone backlog therefore remains active. The next work is the regression,
  implementation, and physical verification sequence added to Phase 3 above;
  no fix or verification is claimed by this entry.

### 2026-10-26 — Automated phone action persistence

- The phone presentation now retains each seat's latest recipient-safe public
  action for the current betting round. A later action replaces only that
  seat's value; actions clear on the next street or hand boundary, while the
  durable folded-state marker remains visible.
- Compact Check, Call, Bet, Raise, All-in, and Fold copy has a dedicated token
  cell separate from the full name, numeric stack, position/state marker, and
  two card fields. The hero action remains in the bottom human summary.
- The regression first failed against the former single expiring badge, then
  passed after the implementation. `make check` passes 510/510 GUT tests with
  17,197 assertions and 72 Python tests; lint and formatting pass. Phone, iPad,
  and historical visual invariant gates also pass.
- Physical-phone verification remains open and is not claimed by this entry.

### 2026-10-26 — Turn-state portrait follow-up

- Evidence:
  `localtmp/from_real_tests/Screenshot_20261026_001503_Chrome.jpg`, a 1080 x
  2340 Android Chrome JPEG showing a six-player turn state.
- Amount-visibility result: fail. `Current wager` ends in an ellipsis before
  its numeric value, and Linh's seat-owned latest action is compressed to
  `B1`, which does not communicate the complete bet size. `Pot: 360` remains
  visible, but the user requests that both center status rows use the smaller
  player-seat text size to preserve room for numeric values.
- Seat-distribution result: fail. The opponent footprints are not vertically
  or horizontally balanced. For the clockwise order Linh, Bao, Lior, Haruto,
  Kwame, the requested composition is Linh lower-left, Bao upper-left, Lior
  centered at the top, Haruto upper-right, and Kwame lower-right.
- No implementation or physical acceptance was claimed by this capture entry;
  the subsequent automated remediation is recorded below.

### 2026-10-26 — Automated amount and symmetry remediation

- The six-player turn regression first reproduced the missing numeric content:
  the 32 px center status copy did not fit `Current wager: 240`, and `B120`,
  `C120`, and `R240` did not fit the former 29 px action cell.
- Phone `Pot` and `Current wager` now use the same 20 px size as player-seat
  copy. Portrait opponent tokens divide their second row into non-overlapping
  numeric-stack, complete compact-action, and two-card cells while retaining
  the 20 px font floor. Landscape restores its original compact cell geometry.
- Supported portrait counts now receive deterministic mirrored footprints.
  The five-opponent order is Linh lower-left, Bao upper-left, Lior top-center,
  Haruto upper-right, and Kwame lower-right; 2-, 4-, and 7-player symmetry is
  covered by the same regression policy. The center position accounts for the
  selected player count and remains clear of the opponent arc.
- Focused phone suites pass 20/20 tests with 1,465 assertions. `make check`
  passes 517/517 GUT tests with 17,370 assertions and all 72 Python tests;
  GDScript lint and formatting pass. Phone, iPad, desktop, and historical
  visual invariant gates pass.
- Physical-phone verification remains unchecked pending the user's results.

### 2026-10-26 — Physical Web action-amount regression

- Evidence:
  `localtmp/from_real_tests/Screenshot_20261026_004126_Chrome.jpg`, a 1080 x
  2340 Android Chrome JPEG showing a six-player preflop human turn.
- Center and placement result: the pot (`645`), current wager (`310`), board,
  and symmetric opponent arc are visible, so this capture does not reproduce
  the earlier center-label or placement failures.
- Opponent result: fail. Linh's highlighted latest-action badge shows `R31`
  beside a current wager of `310`, demonstrating that the final amount digit is
  cropped in the physical Web rendering.
- Human result: fail. The latest-action badge between the hero stack and
  `More` has collapsed to `R`, so the human player's numeric action amount is
  absent even though sufficient attribution is required for every player.
- The earlier native automated checks did not catch either physical Web result.
  New work must include rendered-content padding and the actual Web font path,
  not another equality-at-the-cell-boundary assertion.
- Physical-phone action verification remains unchecked.

### 2026-10-26 — Automated Web action-amount remediation

- Portrait opponent action badges now reserve their width from rendered Web
  font metrics plus 12 px horizontal padding. Complete values such as `R310`,
  `B120`, and `A1000` remain separate from the full stack, state marker, name,
  and two card fields at the 20 px font floor.
- The hero summary gives its latest-action badge content-driven width plus 4 px
  padding. Hero cards use a compact 33 x 44 presentation with 22 px ranks, so
  `C310`, `R310`, and `A1000` fit beside the numeric stack and the 48 x 48-or-
  larger `More` target. Exact-thousand abbreviation remains limited to the
  explicitly deferred landscape composition.
- The phone invariant matrix now checks rendered action content plus padding,
  intersections with stack/cards/name/state fields, hero-summary ownership,
  and the `More` target. Web geometry coverage applies the same content checks
  to DPR 1/2/3, expanded and collapsed browser heights, and landscape fallback;
  the existing matrix also verifies portrait rotation/resize restoration.
- Focused phone regressions and the phone invariant matrix pass. `make check`
  passes 532/532 GUT tests with 17,584 assertions and all 72 Python tests;
  GDScript lint and formatting pass. Phone, iPad, desktop, and historical GUI
  invariant matrices pass.
- Physical-phone verification remains unchecked pending the user's results.
