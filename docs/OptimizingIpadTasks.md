# Optimizing the iPad GUI

Status: Deferred — record only; do not start while phone GUI work is active  
Evidence baseline: iPad Chrome screenshot supplied by the user on 2026-10-25

## Scope

This backlog records the iPad layout regression separately from the active
phone work. Do not implement, test, or mark any remediation task complete until
the user explicitly resumes iPad GUI work. Future iPad changes must preserve
the phone and desktop compositions, recipient privacy, poker behavior, and the
active tournament across browser resize or orientation changes.

The supplied image is a 2388 x 1668 raster that includes iPad and Chrome UI.
It shows a six-player preflop human turn in landscape orientation. Its full
raster size is not the game's CSS viewport: the exact CSS viewport, canvas CSS
and backing sizes, device-pixel ratio, browser zoom, Godot root size, and table
surface must be measured before implementation. The repository's existing
2388 x 1450 fixture is relevant observed-device coverage, but it must not be
silently assumed to describe this capture.

## Required composition

The community-card region must occupy the visual center of the usable table
surface. Pot and wager information should remain grouped with that center
without displacing it into the top seat row.

The human remains anchored at the bottom center. Bot seats must follow a
symmetric semicircular arc around the center, like players around a table. For
the captured six-player game, the five bot seats should have one seat at the
upper apex and two mirrored pairs around it. Equivalent odd/even arrangements
must preserve left/right balance at other supported player counts. Event
history and action controls remain in owned lower regions and must not distort
the table arc.

## Screenshot assessment

Verdict: **iPad layout remediation required**. The screen remains operable and
most poker information is visible, but its spatial hierarchy no longer reads
as a poker table.

| Area | Observation | Assessment |
| --- | --- | --- |
| Community cards | The board is inserted into the upper row between opponent seats instead of occupying the table's visual center. | Fail: violates the required centered-table composition. |
| Bot-seat arrangement | Four bots form a crowded top strip while Haruto sits alone below and left of center. The five opponents do not form a balanced arc around the board. | Fail: asymmetric and unlike seating around a table. |
| Felt use | Most of the middle felt is empty while seats and decision information compete near the top and bottom edges. | Fail: poor use of the available iPad surface. |
| Center information | Board, pot, wager, and Quit are stacked near the upper center rather than forming a stable central hierarchy. | Needs re-centering and explicit ownership. |
| Human seat | The human seat is correctly near the bottom center, with cards and stack visible. | Preserve this anchor while rebuilding the surrounding geometry. |
| Event and action regions | Event history is bottom-left and legal actions are bottom-right. They are visible, but the action labels are crowded and both regions must be treated as reserved geometry. | Preserve the larger-layout features; verify size, clipping, and separation after reflow. |
| Position markers | The dealer and blind letters are drawn over avatar imagery instead of in a dedicated marker area. | Fail: identity art and position state interfere. |
| Seat status | Fold/raise/blind text is visible beneath seats, but the detached labels strengthen the impression of a loose grid rather than one table arrangement. | Needs seat-owned alignment and clearance checks. |

The current automated checks emphasize containment, non-intersection, stable
center width, and readable controls. Those properties are useful, but they do
not by themselves require the center region to be vertically centered or the
opponent seats to be mirror-symmetric. That gap can allow the captured layout
to pass even though the overall composition has regressed.

## Deferred tasks

- [ ] **Record reproducible iPad-browser evidence.** Recreate the supplied
  six-player state and record the iPad model and OS, Chrome version, exact URL,
  deployed SHA and workflow run, browser zoom, CSS viewport, canvas CSS and
  backing sizes, device-pixel ratio, safe-area insets, Godot root/table sizes,
  and selected layout profile. Save a fresh screenshot with those measurements.
  Acceptance: the observed geometry is reproducible without treating screenshot
  pixels as logical pixels.
- [ ] **Specify the iPad table-geometry contract in tests.** Define the usable
  table center, center-zone tolerance, seat-panel sizes, radial/arc clearances,
  and deterministic seat slots for 2–9 players in landscape and portrait. Keep
  the human at bottom center. For five bots, require one upper-apex seat and two
  mirrored pairs; for every other count, require an equivalent balanced arc.
  Acceptance: the contract is precise enough to fail a top-row grid or a single
  unpaired lower-left seat without depending on player names.
- [ ] **Add a regression for the captured composition before changing layout.**
  Exercise the measured usable viewport and the existing observed 2388 x 1450
  fixture. Assert both coordinates of the center-zone midpoint against the
  usable table center, mirrored bot-seat centers and sizes, stable arc ordering,
  the bottom-center human anchor, and reserved lower utility regions.
  Acceptance: the test fails on the captured arrangement for the intended
  reason while existing containment and non-intersection checks remain intact.
- [ ] **Restore a genuinely centered community-card region.** Position the
  board at the visual center of the playable table surface and keep pot and
  wager information in a bounded center stack. Account explicitly for the
  lower human/event/action band instead of centering in the screenshot raster
  or browser chrome. Acceptance: the center remains centered and unobstructed
  across supported iPad sizes, states, and browser-bar changes.
- [ ] **Restore symmetric semicircular bot seating.** Replace the captured top
  strip and displaced fifth bot with deterministic positions around the center.
  Use mirrored geometry from one layout owner, preserve stable seat identities
  through state changes, and keep sufficient clearance from the center and
  lower utility regions. Acceptance: screenshot and coordinate tests visibly
  read as players seated around one table at 2, 4, 6, 7, and 9 players.
- [ ] **Give position markers and status bands owned seat regions.** Reserve a
  marker cell that cannot cover an avatar, name, stack, or cards, and keep each
  latest action, blind post, durable fold, showdown summary, and winner result
  attached to its seat. Acceptance: no marker overlays identity art, no status
  appears detached or ambiguous, and state changes do not move seat rectangles.
- [ ] **Rebalance the lower iPad utility band.** Keep the human seat at bottom
  center with event history and action controls in explicit lower-left and
  lower-right regions. Give Quit an owned non-overlapping location and preserve
  readable action labels and touch targets. Acceptance: lower utilities neither
  displace the table center nor intrude into the opponent arc.
- [ ] **Run the automated iPad matrix.** Cover canonical 768 x 1024 portrait and
  1024 x 768 landscape, the measured real-browser viewport, and observed
  2388 x 1450 coverage with 2, 4, 6, 7, and 9 players. Exercise startup, bot
  turn, human turns on multiple streets, wager entry, fold retention, all-in
  runout, showdown, winner, elimination, quit confirmation, browser-bar
  changes, and rotation. Acceptance: centering, symmetry, containment,
  non-intersection, text, touch-target, privacy, and state-preservation checks
  all pass without weakening phone or desktop assertions.
- [ ] **Perform physical-iPad visual acceptance.** Deploy one clean SHA and
  inspect the corrected states on the same iPad/browser setup in landscape and
  portrait. Record screenshots and deployment provenance. Acceptance: the user
  confirms that the board is centered, bot seats form a symmetric table arc,
  controls work comfortably by touch, and the iPad presentation is satisfactory.
