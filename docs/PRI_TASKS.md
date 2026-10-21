# Priority Tasks

The tasks in this document comes from prompts to improve on observed errors and weaknesses. If they contradict ProjectDescription.md or ARCHITECTURE.md, these documents should be updated.

When executing these tasks, verification of the actual result is very important. You are allowed to iterate if the verification shows requirements are not met. Add human verification tasks if something can not be verified properly by agent driven tests. Stop execution if a human test is needed.

Status markers:
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked
- `[-] (reason)` Unable to perform

`**human**` marks a task that requires hands-on verification and cannot be completed by automated tests. Follow its steps and record the requested evidence before changing its status.

## Short big-blind all-in progression deadlock

The reference failure is [`localtmp/ipad_game_lock_no_progress.jpg`](../localtmp/ipad_game_lock_no_progress.jpg).
Near the end of a tournament, only the human small blind and the big blind remained. The
small blind posted 660, while the big blind had only 631 chips and posted that amount. The
big blind is therefore all-in before postflop action begins. The screenshot shows the flop
dealt, `Wagers • 0 active`, no enabled human action, and `Waiting for Player 0 — Flop.`
This is a progression defect, not a layout defect: a street with no actionable players must
advance automatically to the next street or showdown.

- [x] **Agent task — add a core short-blind-post regression:** construct a deterministic
  heads-up hand with a human small blind who has more chips than the blind amount and a big
  blind whose remaining stack is below the configured big blind (for example, 660 versus
  631). Assert that the blind post commits the actual 631 chips, marks the big blind
  `all_in`, preserves the contribution ledger, and does not require a synthetic player
  action to represent the short post.
- [x] **Agent task — verify automatic no-action street progression:** extend the regression
  through flop, turn, and river. After every automatic transition, assert that the view has
  no legal actions, no actionable acting seat, and never returns `WAITING_FOR_HUMAN`; then
  assert that the hand reaches showdown/hand completion and conserves all chips. Include the
  same case through `TournamentMatch` after the other seats have been eliminated, because
  busted-seat traversal and heads-up blind order are part of the failure conditions.
- [x] **Agent task — fix bounded GUI advancement after a complete street:** update the GUI
  progression path used with `TournamentMatch.start(1)` so that a newly created betting
  round which is already complete is automatically drained. Continuation must be triggered
  by the resulting state (`acting_seat == Table.NO_SEAT`, empty legal actions, or hand
  completion), not only by the latest event being `ACTION_APPLIED`. Preserve nonblocking
  action pacing and do not create a fake check/call or expose disabled controls as an
  available action.
- [x] **Agent task — add a GUI lock regression:** bind the table to a deterministic
  short-big-blind heads-up match using the same one-transition startup path as the GUI.
  Advance deferred frames/timers and assert that the table never displays `Waiting for
  Player 0` while the bound view has zero active wagers and no legal actions. Assert that
  it continues through the remaining board streets to showdown/hand completion, with the
  action controls disabled only while automatic progression is pending and the event log
  retaining the short blind-post amount.
- [x] **human task:** run a seeded late-tournament GUI game in the iPad browser until a
  remaining big blind has fewer chips than the posted big blind. Confirm the short amount is
  shown as the big-blind post, the player is visibly all-in, the flop/turn/river runout
  continues without an action prompt, and the next hand or tournament result appears. Record
  the device, viewport, browser, seed/configuration, and result here before marking this
  task complete.

## Betting-round action-label lifecycle

The GUI currently renders each seat's latest public action below that seat, but the
requirements do not yet define the label's lifetime. Action labels must describe only the
active betting round: they are cleared at the start of pre-flop and whenever the hand moves
to flop, turn, or river. The event log remains the complete public history and must not be
cleared as part of this presentation reset.

- [x] **Agent task — scope seat action labels to the active betting round:** update the GUI
  controller and its presentation state so that the per-seat action text is reset when a
  new hand starts pre-flop and when a street/betting-round transition occurs. Keep the
  current round's latest action visible below the owning seat, and do not alter core
  `GameView` action history or the event log.
- [x] **Agent task — preserve event-history behavior:** ensure the action-label reset does
  not remove blind posts, prior-street actions, or other public events from the scrollable
  event log. The event log may continue to show the full hand while seat labels show only
  the current betting round.
- [x] **Agent task — add GUI transition regressions:** add deterministic GUI tests covering
  pre-flop, flop, turn, and river. After actions exist on one street, assert that every
  seat's old action label is absent immediately after the next street begins, then assert
  that new actions appear only under their owning seats. Also assert that the event log
  still contains the prior-street action entries.
- [x] **Agent task — cover automatic and delayed transitions:** verify the same reset when
  bot actions advance automatically, when a human action resumes the match after a GUI
  pacing delay, and when a street begins with no actionable players during an all-in
  runout. No stale label may reappear after deferred view refreshes.
- [x] **Human task:** run a GUI hand through all four betting rounds on desktop and iPad
  sizes. Confirm that seat-level action text disappears at each new round, new actions are
  shown only for that round, and the event log still retains the complete public sequence.

## Six-player desktop table collision remediation

The reference failure is a six-player desktop table at the first preflop human
turn. It shows the event feed covering a seat, action labels detached from their
seats, the central board zone obscured by action text, and the human action
controls colliding. These tasks address presentation-layer defects only; poker
state and `GameView` semantics must remain unchanged.

- [x] **Agent task — reserve non-overlapping table regions:** define resolved
  desktop bounds for the central community-card/pot/wager zone, the event feed,
  the human seat, the action panel, and every seat panel. Add GUI regression
  coverage at the default 6-player layout and at 2- and 9-player layouts that
  every region is in bounds, the central zone is unobscured, and no seat panel
  intersects the event feed or action panel.
- [x] **Agent task — attach latest actions to their seats:** render each
  player's latest public action in a dedicated, bounded line below that
  player's seat, using the action data for that seat rather than a shared or
  spatially guessed label. Add a six-player regression with distinct blind,
  call, and raise actions proving that each label is adjacent to and owned by
  the correct seat; include the required `Big blind 10` text for the big-blind
  seat.
- [x] **Agent task — protect the community zone:** prevent action-history or
  latest-action labels from entering the community-card, pot, or wager bounds.
  Preserve the five face-down preflop community placeholders and the
  `Community cards` label. Add layout assertions for the central-zone bounds
  before and after automatic bot actions.
- [x] **Agent task — make event feed and action panel symmetric:** size the
  event feed and human action panel to equal resolved dimensions, align their
  bottoms with the human seat panel, and place them symmetrically on opposite
  sides of that seat. Keep the event feed scrollable and keep the action panel
  beside (not over) the human seat. Add regression coverage for dimensions,
  bottom alignment, and symmetry at 6 and 9 players.
- [x] **Agent task — fix human action-control layout:** implement the intended
  compact two-row arrangement without control intersection or text wrapping:
  `Fold`, `Call`, and `Pot raise` in the action row, with `All-in`, wager input,
  and `Raise` in the wager row. Preserve legal/disabled states, the displayed
  call amount, wager validation, numeric-keypad behavior, and click/touch
  targets. Add interaction/layout tests proving every control has a distinct
  in-bounds rectangle in preflop and postflop states.
- [x] **Agent task — verify readable state ownership:** ensure position badges,
  latest actions, event entries, and action controls do not visually merge or
  contradict one another. Add a regression fixture for the screenshot state
  that checks the event text (`Player 1 (you): Call 10`), the blind postings,
  and the visible per-seat action labels are each rendered once and in their
  owning region.
- [x] **Agent task — run focused verification:** run the GUI regression suite,
  full GUT tests, `gdlint`, and `gdformat --check`; update this milestone with
  the commands and results. Do not mark the human task complete based only on
  automated geometry assertions.

## Seven-player iPad landscape table collision remediation

- [x] **Agent task — reserve iPad landscape seat clearance:** use a dedicated
  landscape-tablet seat arrangement for seven players so the side event feed
  and action panel cannot obscure Player 2 or Player 7.
- [x] **Agent task — preserve latest-action space:** reserve visible space below
  every seat for its latest public action, with explicit regression coverage for
  Player 2 and Player 7 beside the side panels.
- [x] **Agent task — preserve showdown-summary space:** reserve visible space
  above Player 4 and Player 5 for their showdown result text, including a top
  safety margin at the iPad landscape viewport.
- [x] **Agent task — bound the central table zone:** make the community-card,
  pot, and wager stack use an explicit width derived from the available table
  surface, rather than allowing `get_combined_minimum_size()` from changing
  status text to widen the stack. Preserve enough width for all five community
  card slots and keep the stack centered and inside the table surface.
- [x] **Agent task — stabilize central status presentation:** prevent changing
  pot, blind, layer, and blind-progress text from changing the central-zone
  footprint. Split or constrain the status presentation as needed, while
  keeping all player-facing information readable and respecting the 20 px text
  minimum.
- [x] **Agent task — add central-zone width regressions:** at the seven-player
  iPad landscape viewport, render short and long status strings and assert that
  the central-zone width remains within its configured bound, its board/pot/
  wager panels have equal widths, and none of those regions intersects a seat,
  event feed, or action panel after repeated deferred view refreshes.
- [x] **Human task:** verify the seven-player tournament in an iPad browser in
  landscape orientation during normal play and showdown; confirm Player 2/7
  details and latest-action text remain visible, and Player 4/5 showdown
  summaries are fully readable.

### Seven-player iPad verification follow-up

The first human verification found three remaining presentation defects: Player 2
and Player 7 details, especially their latest-action text, are not visible;
Player 4 and Player 5 showdown summaries are visible but overlap their player
names; and the Player 1 seat area moves vertically depending on whether a latest
action is present. These are GUI layout defects only and must not change poker
state or event-history behavior.

- [x] **Agent task — preserve Player 2/7 detail visibility:** inspect the settled
  seven-player iPad landscape layout and reserve explicit, non-overlapping bounds
  for the Player 2 and Player 7 seat panels, detail text, and latest-action lines.
  Ensure the event feed and human action panel cannot cover those bounds during
  normal play, after deferred refreshes, or when the latest-action text is absent.
- [x] **Agent task — separate Player 4/5 showdown summaries:** allocate a
  dedicated above-seat summary region for Player 4 and Player 5 with enough
  clearance from the seat panel and player-name labels. Keep the summaries
  readable at the supported iPad landscape viewport and prevent long hand/result
  text from overlapping names or neighboring seats.
- [x] **Agent task — make seat geometry independent of optional text:** give every
  seat a stable layout rectangle and reserve the latest-action line even when it
  is empty. Updating, clearing, or restoring a latest action must not move the
  Player 1 seat or any other seat vertically; only the text content should change.
- [x] **Agent task — add seven-player layout regressions for the observed states:**
  cover normal play with and without latest actions, long Player 2/7 detail text,
  and showdown summaries for Player 4/5. After deferred layout and view refreshes,
  assert visibility, in-bounds placement, required clearance, and no intersection
  between seat panels, auxiliary text, event feed, or action panel.
- [x] **Agent task — verify stable geometry across state transitions:** add a
  regression that records the Player 1 seat rectangle before and after latest
  action assignment, clearing, street changes, bot actions, and showdown. Assert
  that the rectangle remains unchanged unless the viewport/layout mode itself
  changes.
- [x] **Human task:** repeat the seven-player tournament in an iPad browser in
  landscape orientation during normal play and showdown. Confirm Player 2/7
  details and latest-action text are visible, Player 4/5 showdown summaries do
  not overlap player names, and the Player 1 seat remains fixed when latest-action
  text appears or disappears. Record device, viewport, browser, and result here.
  Done. It failed.

## Central community/pot/wager width regression follow-up

The screenshot [`localtmp/localtest_strange_wide_fields.jpg`](../localtmp/localtest_strange_wide_fields.jpg)
shows the central fields rendered as an unexpectedly wide stack during a normal six-player
desktop hand. The community-card, pot, and wager panels appear to fill a much larger column
than the five cards require, and the central footprint is not stable when the view refreshes.
The current implementation computes `center_width` in `PokerTableController._layout_table()`,
then applies it later with `call_deferred("_apply_center_zone_bounds", ...)` to a
`VBoxContainer`. The same layout pass also calls `get_combined_minimum_size()` and rebuilds
labels/cards whose minimum sizes can change as status text and card content change. Existing
coverage checks equal widths and an upper bound only at the iPad landscape viewport; it does
not prove stability at the reported desktop viewport or across repeated deferred refreshes.

- [x] **Agent task — capture the width-change reproduction:** add temporary or test-only
  geometry tracing around `_layout_table()`, `_apply_center_zone_bounds()`, and the next
  settled frame. Reproduce the screenshot at its actual table-surface size and record the
  surface, center, board, pot, and wager rectangles before and after `bind_view()`, bot-action
  refreshes, street changes, and long/short status text. Identify whether a stale deferred
  bounds call, container minimum-size negotiation, or viewport resize is the final writer of
  the unexpectedly wide rectangle, then remove diagnostic-only logging after the cause is
  established.
- [x] **Agent task — make one layout owner authoritative:** revise the central-zone layout so
  one resolved width is applied after all child rebuilds and remains authoritative for the
  `CenterZone` and all three child panels. Do not let a later `VBoxContainer` minimum-size
  negotiation or an older deferred callback replace the current width. If deferred layout is
  required, coalesce callbacks or associate them with the latest surface/layout generation.
  Keep the central stack centered and preserve the minimum width needed for five community
  card slots.
- [x] **Agent task — isolate status text from geometry:** ensure pot, blind, layer,
  blind-progress, and wager-status labels cannot enlarge the central stack's minimum width.
  Preserve readable player-facing text through constrained wrapping, clipping/ellipsis, or a
  presentation subregion, while keeping board/pot/wager panels equal in width and respecting
  the 20 px minimum text requirement. Verify that changing only these strings does not change
  the resolved central rectangle.
- [x] **Agent task — add the reported desktop regression:** at the actual viewport/surface
  size represented by `localtest_strange_wide_fields.jpg` and at nearby 950x532 and 1920x1080
  surfaces, render six- and seven-player views with five board cards, short and maximally long
  status strings, repeated deferred refreshes, automatic bot actions, and street changes.
  Assert after each settled frame that center/board/pot/wager widths are equal, the width is
  stable for unchanged available space, the stack remains centered and in bounds, and no stale
  rectangle is observed after a refresh.
- [x] **Human task:** rerun the local desktop scenario that produced
  `localtmp/localtest_strange_wide_fields.jpg`, including preflop, flop/turn/river updates,
  bot actions, and a long pot/layer status. Confirm that the community-card, pot, and wager
  fields do not suddenly widen or shrink, remain one centered equal-width stack, and retain
  readable cards and status text. Record the viewport, browser/runtime, and result here.
  Tested. It still fails.

### Second remediation after failed human verification

- [x] **Agent task — remove competing center-stack layout owners:** replace the manually sized
  `VBoxContainer` root and its container-managed direct children with a plain presentation
  `Control` whose board, pot, and wager rectangles are all assigned by one controller method.
  Child minimum-size changes must not be able to resize or reposition the central stack.
- [x] **Agent task — resolve and apply final center geometry atomically:** calculate the board
  height after card and typography scaling, add the fixed status-zone heights and separations,
  then apply the final center size, centered position, and all three equal child widths in one
  operation. Preserve the compact-layout vertical placement where explicitly required.
- [x] **Agent task — cover late minimum-size negotiation and centering:** add a regression that
  changes child text/minimum sizes and waits through multiple deferred frames at the reported
  desktop, full-HD, and iPad landscape surfaces. Assert on every frame that the center width is
  unchanged, all child widths equal it, and its horizontal midpoint equals the table surface's
  horizontal midpoint.
- [x] **Human task — repeat central-stack verification:** reproduce preflop through river on the
  desktop browser and iPad landscape browser. Confirm the board, pot, and wager stack never
  changes width or horizontal center. Record the runtime, CSS viewport, internal Godot surface
  size, and result here; do not mark complete from automated evidence.

## Desktop browser betting-action visibility follow-up

Desktop browser testing reports that players' latest public actions are not visibly rendered
during an active betting round. The event history may contain the action, but the seat-level
label must also be visible while the hand is waiting for the next legal action.

- [x] **Agent task — restore visible desktop betting actions:** add a deterministic
  browser-sized GUI regression covering blind posts, bot actions, and a human action across
  pre-flop and post-flop betting. Assert that each latest-action label is visible, readable,
  positioned directly below its owning seat, and remains visible after deferred view refreshes
  without being covered by the center, event feed, or human action panel. Preserve the full
  event log and current-round latest-action behavior. Include the actual desktop browser viewport
  in the fixture and record any required human verification details in the follow-up task.
  Follow-up correction: restore the plain-text presentation from
  `localtmp/ipad_action_log_player_overlap.jpg`, retain each seat's latest action during the
  current betting round, and clear the seat labels on each street transition and new hand.

## Fixed-size community-card rendering follow-up

The screenshot [`localtmp/cards_do_not_fit.jpg`](../localtmp/cards_do_not_fit.jpg) shows that
revealed community cards can overflow the board frame. The card root requested a 60x76 minimum,
but its horizontal rank-and-suit content imposed a larger combined minimum. Wide ranks such as
`10` therefore changed the five-card row width after the flop, while `BoardZone` clipped the
overflow.

- [x] **Agent task — make community-card bounds authoritative:** give community cards a fixed
  presentation rectangle whose child content cannot enlarge the card. Keep hero and opponent
  card layouts unchanged.
- [x] **Agent task — fit rank and suit inside each community card:** stack the rank and suit in
  separate clipped regions and use responsive font sizing for standard and small-desktop card
  dimensions.
- [x] **Agent task — add reveal-width regressions:** compare preflop placeholders with a
  five-card revealed board containing rank `10` at 950x532 and 1920x1080. Assert unchanged row
  dimensions, equal card rectangles, enclosed content, and complete containment by the board
  frame.
- [x] **Human task:** repeat the reported scenario through flop, turn, and river. Confirm that
  every rank and suit is readable, all five cards remain inside the community-card frame, and
  revealing rank `10` does not widen or shift the row.
  Tested. The cards fit, but the vertically stacked rank and suit are less readable than the
  bot-card presentation.

### Readability revision after human verification

- [x] **Agent task — restore the bot-card visual direction:** present each fixed-size community
  card with its rank and suit side by side while retaining a non-expanding card root.
- [x] **Agent task — allow slightly wider community cards:** increase the standard card width
  from 60 to 64 pixels and the small-desktop width from 45 to 48 pixels. Keep all five cards
  inside the existing central board at the reported desktop sizes.
- [x] **Agent task — protect readable rank geometry:** verify rank `10` fits its assigned region,
  rank and suit occupy separate columns, revealed cards remain equal to placeholders, and the
  complete row retains its preflop dimensions at 950x532 and 1920x1080.
- [x] **Human task:** repeat the reported scenario and compare the community cards with revealed
  bot cards. Confirm the side-by-side rank/suit treatment is readable and all five community
  cards remain inside the frame through flop, turn, and river.
  Tested. Rank and suit placement is improved, but the suit symbols are too small to distinguish
  clubs from spades reliably.

### Suit-symbol readability revision

- [x] **Agent task — enlarge the community-card suit region:** reserve approximately 42 percent
  of each card's usable width for the suit while preserving enough rank width for `10`.
- [x] **Agent task — widen desktop community cards again:** use 68x76 cards at standard desktop
  sizes and 56x57 cards in the reported compact desktop layout. Keep portrait scaling bounded
  to its prior base width.
- [x] **Agent task — protect suit readability with geometry coverage:** assert minimum suit
  widths of 26 pixels at standard desktop size and 20 pixels at compact desktop size, while
  retaining the rank-fit, fixed-row, equal-card, and board-containment checks.
- [x] **Human task:** repeat the reported showdown and confirm clubs and spades are immediately
  distinguishable on every community card without the row leaving or resizing its frame.
  Tested. It is OK, but I would like them even larger.

## Small desktop viewport table collision remediation

The developer-machine reference screenshot is a roughly 950x532 table surface.
It is currently treated as a non-mobile desktop layout even though the authored
seat panels, auxiliary labels, event feed, and action panel cannot all fit with
their required clearance. The screenshot shows the lower seats and their latest
action area compressed against the event/action panels, while the top seats have
little or no room above them for showdown summaries.

- [x] **Agent task — add a small-desktop layout mode:** detect short desktop
  surfaces independently from mobile portrait and iPad landscape modes, and
  use a compact seven-seat arrangement that remains readable at the reference
  developer viewport and nearby sizes.
- [ ] **Agent task — reserve all auxiliary-text clearance:** include each seat's
  below-seat latest-action label and above-seat showdown-summary label in the
  layout bounds before placing seats. Player 2 and Player 7 must retain space
  below their panels; Player 4 and Player 5 must retain space above their panels.
- [ ] **Agent task — prevent side-panel occlusion:** ensure the event feed and
  human action panel do not intersect any seat panel, latest-action label, or
  showdown-summary label at small desktop sizes. If the full panels cannot fit,
  reflow or reduce their presentation-only footprint while preserving access to
  all events and controls.
- [ ] **Agent task — preserve central-zone visibility:** keep the community-card,
  pot, and wager zones fully visible and separated from seats, auxiliary labels,
  the event feed, and action controls at the reference viewport.
- [ ] **Agent task — preserve readable controls and touch targets:** prevent
  action-button text and wager input text from wrapping or clipping in the
  compact layout, while retaining distinct controls and the minimum supported
  interaction target size.
- [ ] **Agent task — add small-desktop regression coverage:** test at the
  reference viewport and representative nearby sizes for 2–9 players, checking
  bounds, non-intersection, label clearance, central-zone visibility, and
  readable action controls. Include both preflop and showdown states.
- [ ] **Human task:** run `godot --path .` on the developer machine and inspect
  6- and 7-player tables through preflop, street changes, and showdown. Confirm
  that no player details, latest actions, showdown results, event entries, or
  action controls are obscured.
