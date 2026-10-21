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

## Six-player desktop table collision remediation

The reference failure is a six-player desktop table at the first preflop human
turn. It shows the event feed covering a seat, action labels detached from their
seats, the central board zone obscured by action text, and the human action
controls colliding. These tasks address presentation-layer defects only; poker
state and `GameView` semantics must remain unchanged.

- [ ] **Agent task — reserve non-overlapping table regions:** define resolved
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

