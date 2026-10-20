# Priority Tasks

The tasks in this document comes from prompts to improve on observed errors and weaknesses. If they contradict ProjectDescription.md or ARCHITECTURE.md, these documents should be updated.

When executing these tasks, verification of the actual result is very important. You are allowed to iterate if the verification shows requirements are not met. Add human verification tasks if something can not be verified properly by agent driven tests. Stop execution if a human test is needed.

Status markers:
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked
- `[-] (reason)` Unable to perform

Use milestones named `Stratmilestone<number>` and subtasks to organize the work.

## 1. Define the priority acceptance baseline

- [ ] Update `docs/ProjectDescription.md` to replace fixed blinds with escalating blind levels: when a hand completes, increase after `active_player_count_at_level_start * 2` completed hands for levels begun with five or more active players, otherwise after 10 completed hands; preserve level cadence until the next increase.
- [ ] Specify and document that a blind increase sets `new_big_blind` to 125% of the current big blind rounded upward to the nearest even integer, and `new_small_blind` to exactly half of that value; include 5/10 → 7/14 and 7/14 → 9/18 examples.
- [ ] Update `docs/ARCHITECTURE.md` with the core-owned blind-level state, its hand-completion update point, the public-view contract for current blinds/level progress, and the rule that presentation layers never calculate or mutate levels.
- [ ] Add these priority tasks to the active project backlog only after this standalone list is approved.

## 2. Implement and verify blind levels in the game core

- [ ] Add a typed, core-owned blind-level progression component that receives completed-hand and active-player information, determines the current interval, and exposes the next small and big blinds without UI or standard-I/O dependencies.
- [ ] Integrate blind-level progression into `TournamentMatch` and `Table` so the newly calculated blinds take effect only on the hand after the triggering completed hand; retain correct button movement, elimination, heads-up behavior, chip conservation, and quit behavior.
- [ ] Surface the current small blind, big blind, level number, completed-hands-in-level, and hands-until-next-level in recipient-safe `GameView` snapshots and render them in the CLI and GUI.
- [ ] Add unit tests for the five-or-more-player threshold, the under-five-player 10-hand threshold, player-count changes caused by eliminations, exact trigger timing, deferred application to the next hand, both stated rounding examples, and odd 125%-calculation inputs.
- [ ] Add deterministic tournament integration tests proving changed blinds are posted and that betting minimums use the increased big blind from the appropriate next hand.

## 3. Increase table, startup, and mobile control scale of GUI

- [ ] Establish the current desktop and portrait-mobile layout measurements in GUI regression fixtures, then scale player-seat panels, avatars, seat text, position badges, card graphics, and seat action text to two times their approved current baseline while keeping all supported 2–9 player layouts in bounds and non-overlapping.
- [ ] Redesign responsive table seat placement so enlarged panels use the available felt area rather than leaving excessive unused green space, with the human seat still visually anchored at the bottom and the central board/pot zone remaining unobscured.
- [ ] Scale all startup-screen player-facing text and touch targets to two times their approved current baseline; preserve validation feedback, portrait/landscape reflow, and a direct-start path using defaults.
- [ ] Scale the on-canvas numeric keypad’s digits, keys, spacing, and hit targets to two times their approved current baseline wherever it is used, including startup numeric fields and wager entry; preserve keyboard input and focus behavior.
- [ ] Add desktop and representative Android portrait/landscape GUI regression tests for doubled measurements, minimum touch-target dimensions, readable text, non-overlap, and all 2–9 player counts; perform and record a manual Android touch/readability test.

## 4. Compact and enlarge the human action area in GUI

- [ ] Rework the lower-right human action controls into a compact two-row layout: combine All-in, the wager field, and Raise into one row; keep the entire action panel no taller than the human player seat panel; and enlarge all its player-facing text and controls to match the revised table scale.
- [ ] Preserve clear legal-action states, keyboard and numeric-keypad wager entry, disabled-state accessibility, mobile reflow, and the existing validated action-submission path.
- [ ] Add GUI layout and interaction tests for the two-row arrangement, maximum action-panel height, enlarged typography/touch targets, legal and illegal wager states, and supported desktop/mobile viewports.

## 5. Replace Preset Raise with Pot raise in GUI

- [ ] Replace the `Preset Raise` control with a `Pot raise` button that sets the raise target to the current displayed pot amount, routes it through the existing wager validation and submission path, and never bypasses No Limit minimum/maximum rules.
- [ ] Disable `Pot raise` whenever the hero cannot cover the pot-sized target from their remaining stack, when raising is unavailable, or when the target is otherwise not a legal raise; display the normal disabled styling and leave the current wager unchanged.
- [ ] Remove the old preset-raise behavior and update related labels, controller bindings, tests, and any player-facing documentation.
- [ ] Add GUI and core-adapter regression tests for pot-sized target calculation, enabled and disabled stack boundaries, minimum-raise conflicts, all-in availability, and submission of the resulting legal raise.

## 6. Final verification and release documentation

- [ ] Run the complete headless GUT suite, GDScript linting, formatting checks, and GUI regression suite; resolve any failures with focused regression coverage.
- [ ] Manually verify a nine-player desktop table and a representative Android phone in portrait and landscape: seats, avatars, text, startup fields, keypad, action controls, and `Pot raise` must be readable and reliably touchable.
- [ ] Manually verify blind increases in one five-or-more-player tournament and one under-five-player tournament, including the required 5/10 → 7/14 and 7/14 → 9/18 progression.
- [ ] Update `README.md` and relevant user-facing documentation with blind-level behavior, the visible level progress, and `Pot raise` behavior.
