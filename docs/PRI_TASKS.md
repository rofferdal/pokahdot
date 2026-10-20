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

Use milestones named `Stratmilestone<number>` and subtasks to organize the work.

## 1. Define the priority acceptance baseline

- [x] Update `docs/ProjectDescription.md` to replace fixed blinds with escalating blind levels: when a hand completes, increase after `active_player_count_at_level_start * 2` completed hands for levels begun with five or more active players, otherwise after 10 completed hands; preserve level cadence until the next increase.
- [x] Specify and document that a blind increase sets `new_big_blind` to 125% of the current big blind rounded upward to the nearest even integer, and `new_small_blind` to exactly half of that value; include 5/10 → 7/14 and 7/14 → 9/18 examples.
- [x] Update `docs/ARCHITECTURE.md` with the core-owned blind-level state, its hand-completion update point, the public-view contract for current blinds/level progress, and the rule that presentation layers never calculate or mutate levels.
- [x] Add these priority tasks to the active project backlog only after this standalone list is approved.

## 2. Implement and verify blind levels in the game core

- [x] Add a typed, core-owned blind-level progression component that receives completed-hand and active-player information, determines the current interval, and exposes the next small and big blinds without UI or standard-I/O dependencies.
- [x] Integrate blind-level progression into `TournamentMatch` and `Table` so the newly calculated blinds take effect only on the hand after the triggering completed hand; retain correct button movement, elimination, heads-up behavior, chip conservation, and quit behavior.
- [x] Surface the current small blind, big blind, level number, completed-hands-in-level, and hands-until-next-level in recipient-safe `GameView` snapshots and render them in the CLI and GUI.
- [x] Add unit tests for the five-or-more-player threshold, the under-five-player 10-hand threshold, player-count changes caused by eliminations, exact trigger timing, deferred application to the next hand, both stated rounding examples, and odd 125%-calculation inputs.
- [x] Add deterministic tournament integration tests proving changed blinds are posted and that betting minimums use the increased big blind from the appropriate next hand.

## 3. Increase table, startup, and mobile control scale of GUI

- [x] Establish the current desktop and portrait-mobile layout measurements in GUI regression fixtures, then scale player-seat panels, avatars, seat text, position badges, card graphics, and seat action text to two times their approved current baseline while keeping all supported 2–9 player layouts in bounds and non-overlapping.
- [x] Redesign responsive table seat placement so enlarged panels use the available felt area rather than leaving excessive unused green space, with the human seat still visually anchored at the bottom and the central board/pot zone remaining unobscured.
- [x] Scale all startup-screen player-facing text and touch targets to two times their approved current baseline; preserve validation feedback, portrait/landscape reflow, and a direct-start path using defaults.
- [x] Scale the on-canvas numeric keypad’s digits, keys, spacing, and hit targets to two times their approved current baseline wherever it is used, including startup numeric fields and wager entry; preserve keyboard input and focus behavior.
- [-] (irrelevant, since things have changed) Add desktop and representative Android portrait/landscape GUI regression tests for doubled measurements, minimum touch-target dimensions, readable text, non-overlap, and all 2–9 player counts; perform and record a manual Android touch/readability test.

## 4. Compact and enlarge the human action area in GUI

- [x] Rework the lower-right human action controls into a compact two-row layout: combine All-in, the wager field, and Raise into one row; keep the entire action panel no taller than the human player seat panel; and enlarge all its player-facing text and controls to match the revised table scale.
- [x] Preserve clear legal-action states, keyboard and numeric-keypad wager entry, disabled-state accessibility, mobile reflow, and the existing validated action-submission path.
- [x] Add GUI layout and interaction tests for the two-row arrangement, maximum action-panel height, enlarged typography/touch targets, legal and illegal wager states, and supported desktop/mobile viewports.

## 5. Replace Preset Raise with Pot raise in GUI

- [x] Replace the `Preset Raise` control with a `Pot raise` button that sets the raise target to the current displayed pot amount, routes it through the existing wager validation and submission path, and never bypasses No Limit minimum/maximum rules.
- [x] Disable `Pot raise` whenever the hero cannot cover the pot-sized target from their remaining stack, when raising is unavailable, or when the target is otherwise not a legal raise; display the normal disabled styling and leave the current wager unchanged.
- [x] Remove the old preset-raise behavior and update related labels, controller bindings, tests, and any player-facing documentation.
- [x] Add GUI and core-adapter regression tests for pot-sized target calculation, enabled and disabled stack boundaries, minimum-raise conflicts, all-in availability, and submission of the resulting legal raise.

## 6. Correct desktop table readability after the scale increase

- [x] Redimension every player-seat area so all player-facing content is visible without clipping or overlap. Reduce each current seat panel's height to approximately 75% while retaining or increasing its width as needed to fit the player name, stack, position badge, avatar, cards, and latest-action text.
- [x] Reduce the font size of all text inside player-seat areas to approximately 75% of its current post-scale value, while preserving readable names, stacks, position badges, card ranks, and action text at every supported 2–9 player desktop layout.
- [x] Increase the Quit button and every lower-right action-area control to a font size at least equal to the Community cards label. Preserve their existing legal-action states, touch/click targets, two-row arrangement, numeric-keypad behavior, and validated action-submission path.
- [x] Preserve the current Community cards area dimensions and typography; do not resize that area as part of this correction.
- [x] Add desktop GUI layout regressions for visible, non-overlapping player-seat content at 2–9 players; the reduced seat typography; action-area and Quit-button font-size parity with Community cards; and unchanged Community cards dimensions.
- [x] **human** Perform and record a manual MacBook desktop verification before marking this correction complete.
  1. On a MacBook at its normal display scaling, launch the GUI using the command in `README.md` (or open the project in Godot 4.7 and press **Play**).
  2. Start a nine-player tournament and wait for the first human turn. Inspect every seat: its name, stack, position badge, avatar, cards, and latest action must be fully visible, legible, and free from overlap with another seat, the event log, or the action panel.
  3. Confirm that **Quit** and each lower-right action control are at least as readable as the **Community cards** label, retain their click targets and two-row layout, and that opening the wager field still opens the numeric keypad.
  4. Confirm that the Community cards panel has not changed in size or typography. Take a screenshot of the full table and record the MacBook model, macOS version, display resolution/scaling, Godot version, date, and pass/fail result beneath this task. If it fails, record the observed result and exact reproduction steps instead of marking it complete.

### Follow-up from six-player MacBook verification

- [x] Specify and configure Godot's built-in plain non-serif UI font for every player-facing GUI surface, including startup labels, numeric inputs, validation feedback, the on-canvas keypad, and the live table. Verify the shared GUI theme applies this face throughout the GUI.
- [x] Replace scaled player-facing fonts and procedural line graphics with correctly sized source assets. Select and configure the actual font faces at their target point sizes, and create borders, card artwork, avatars, and other graphics at their displayed dimensions. Do not apply post-render scaling to text or line-art on the desktop path; text and lines must be visually smooth, consistent, and evenly weighted at normal MacBook display scaling.
- [x] Widen every human and bot player-seat area by approximately half the displayed avatar width, while preserving the corrected seat height, in-bounds placement, and non-overlap for all supported desktop layouts.
- [x] Move the lowest bot seats upward sufficiently that their latest-action labels, including Player 6's `Big blind 10` in the six-player layout, remain fully visible and do not overlap the lower-right action area. Preserve symmetric left/right placement where applicable.
- [x] Make the desktop event-log area match the action area's width and height, and position the two areas symmetrically on opposite sides of the human player-seat area without covering seat content or latest-action labels.
- [x] Add automated desktop regressions at 2–9 players, including the six-player configuration, that verify the widened seats; smooth, unscaled typography/line-art configuration; unobstructed latest-action labels; and event-log/action-area size parity and symmetry. Keep a focused visual-inspection fixture or screenshot reference for font and line rendering, because anti-aliasing quality itself requires human verification.
- [ ] **human** Repeat the MacBook verification with a six-player tournament after the follow-up work.
  1. At normal display scaling, inspect all text, borders, cards, avatars, and seat frames for smooth edges, even line thickness, and consistent font rendering. Compare against the screenshot attached to this task; no element may appear blurry, pixelated, unevenly weighted, or visibly scaled after rendering.
  2. Confirm that all six seat panels are wider, remain readable and non-overlapping, and that the lowest bot-player action text—especially Player 6's **Big blind 10**—is fully visible above the action panel.
  3. Confirm the event log and action panel have equal dimensions and symmetric placement around the human seat, with neither covering player-seat content.
  4. Record the MacBook model, macOS version, display resolution/scaling, Godot version, date, screenshot, and pass/fail result beneath this task. Leave it unchecked and record reproduction steps if any observation fails.

## 7. Final verification and release documentation

- [ ] Run the complete headless GUT suite, GDScript linting, formatting checks, and GUI regression suite; resolve any failures with focused regression coverage.
- [ ] **human** Manually verify a nine-player desktop table and a representative Android phone in portrait and landscape: seats, avatars, text, startup fields, keypad, action controls, and `Pot raise` must be readable and reliably touchable.
  1. On desktop, launch the GUI as described in `README.md`, start a nine-player tournament, and verify readable, non-overlapping seats, avatars, cards, labels, startup inputs, numeric keypad, action controls, and **Pot raise**. Exercise **Pot raise** once when it is enabled and confirm it is disabled when the displayed pot target is not a legal, coverable raise.
  2. Export and serve the current Web build using the procedure in `docs/WEB_SETUP.md`, then open it in current Chrome on a physical Android phone. Test both portrait and landscape, with the browser address bar both expanded and collapsed.
  3. In each orientation, start a nine-player tournament, edit a startup numeric field through the on-canvas keypad, take at least one legal action, and verify the seats, text, keypad, **Quit**, action controls, and **Pot raise** are readable, fully visible, and reliably touchable without browser zooming or horizontal scrolling.
  4. Record the desktop browser/viewport and Android model, OS, Chrome version, orientations, build identifier, date, screenshots, and pass/fail result beneath this task. For any failure, record exact reproduction steps and leave the task unchecked.
- [ ] **human** Manually verify blind increases in one five-or-more-player tournament and one under-five-player tournament, including the required 5/10 → 7/14 and 7/14 → 9/18 progression.
  1. Launch the GUI as described in `README.md`. Start a six-player tournament with 5/10 blinds, so the first level interval is 12 completed hands. After every settled hand, record the visible level progress. Confirm hand 12 completes level 1, and the next hand displays 7/14 at level 2. After 12 more completed hands, confirm the next hand displays 9/18 at level 3.
  2. Start a separate four-player tournament with 5/10 blinds, so each level interval is 10 completed hands. Confirm the next hand after completed hand 10 displays 7/14, then repeat for the next 10 completed hands and confirm 9/18.
  3. For both tournaments, capture the screen before and after each increase. Record the participant count, completed-hand count, old and new blinds, date, build identifier, and pass/fail result beneath this task. If an increase occurs on the wrong hand or has different blinds, stop and record the exact hand sequence and screenshots instead of marking the task complete.
- [x] Update `README.md` and relevant user-facing documentation with blind-level behavior, the visible level progress, and `Pot raise` behavior.
