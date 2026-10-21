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
- [ ] **human task:** run a seeded late-tournament GUI game in the iPad browser until a
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
- [ ] **Human task:** run a GUI hand through all four betting rounds on desktop and iPad
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
- [ ] **Human task:** verify the seven-player tournament in an iPad browser in
  landscape orientation during normal play and showdown; confirm Player 2/7
  details and latest-action text remain visible, and Player 4/5 showdown
  summaries are fully readable.

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

- [ ] **Agent task — capture the width-change reproduction:** add temporary or test-only
  geometry tracing around `_layout_table()`, `_apply_center_zone_bounds()`, and the next
  settled frame. Reproduce the screenshot at its actual table-surface size and record the
  surface, center, board, pot, and wager rectangles before and after `bind_view()`, bot-action
  refreshes, street changes, and long/short status text. Identify whether a stale deferred
  bounds call, container minimum-size negotiation, or viewport resize is the final writer of
  the unexpectedly wide rectangle, then remove diagnostic-only logging after the cause is
  established.
- [ ] **Agent task — make one layout owner authoritative:** revise the central-zone layout so
  one resolved width is applied after all child rebuilds and remains authoritative for the
  `CenterZone` and all three child panels. Do not let a later `VBoxContainer` minimum-size
  negotiation or an older deferred callback replace the current width. If deferred layout is
  required, coalesce callbacks or associate them with the latest surface/layout generation.
  Keep the central stack centered and preserve the minimum width needed for five community
  card slots.
- [ ] **Agent task — isolate status text from geometry:** ensure pot, blind, layer,
  blind-progress, and wager-status labels cannot enlarge the central stack's minimum width.
  Preserve readable player-facing text through constrained wrapping, clipping/ellipsis, or a
  presentation subregion, while keeping board/pot/wager panels equal in width and respecting
  the 20 px minimum text requirement. Verify that changing only these strings does not change
  the resolved central rectangle.
- [ ] **Agent task — add the reported desktop regression:** at the actual viewport/surface
  size represented by `localtest_strange_wide_fields.jpg` and at nearby 950x532 and 1920x1080
  surfaces, render six- and seven-player views with five board cards, short and maximally long
  status strings, repeated deferred refreshes, automatic bot actions, and street changes.
  Assert after each settled frame that center/board/pot/wager widths are equal, the width is
  stable for unchanged available space, the stack remains centered and in bounds, and no stale
  rectangle is observed after a refresh.
- [ ] **Human task:** rerun the local desktop scenario that produced
  `localtmp/localtest_strange_wide_fields.jpg`, including preflop, flop/turn/river updates,
  bot actions, and a long pot/layer status. Confirm that the community-card, pot, and wager
  fields do not suddenly widen or shrink, remain one centered equal-width stack, and retain
  readable cards and status text. Record the viewport, browser/runtime, and result here.

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
