# Minimum Raise Implementation Tasks

Status: Planned; implementation has not started.

## Authority and scope

Implement the rules in
[`ProjectDescription.md`, section 4.5](ProjectDescription.md#45-actions-no-limit)
and the design in
[`ARCHITECTURE.md`, section 5.7](ARCHITECTURE.md#57-betting_roundgd).
This backlog owns the minimum-raise change. Follow its first unchecked task
unless the user selects another task. The first task is MR-00.

The core must calculate legal wagers and action reopening. GUI, CLI and bots
consume the recipient-safe `GameView`; they must not reconstruct betting
increments from history or implement separate poker rules. Keep target-total
wagers, typed validation errors, card privacy, and the existing No Limit Pot
shortcut contract. Do not combine this work with the
[GUI replacement backlog](RestructureGuiTasks.md).

## Current implementation and affected areas

- `scripts/core/betting_round.gd` calculates minimum raises as
  `current_bet + big_blind` and treats increases of at least one big blind as
  full raises when deciding whether to reopen action. Both must change.
- `scripts/core/hand_controller.gd` constructs each street's `BettingRound`.
  `scripts/core/game_view.gd` publishes its minimum/maximum wager totals and
  legal actions. Verify initialization, street resets and view propagation.
- `scripts/gui/poker_table_controller.gd` and
  `scripts/gui/gui_table_action_controls.gd` use the bound view for Minimum,
  Pot and free-entry controls, including keypad configuration.
- `scripts/cli/cli_renderer.gd` prints legal wager ranges, while
  `scripts/cli/cli_command_loop.gd` submits actions and resolves Pot commands.
- `tests/unit/test_betting_round.gd` explicitly expects the old flat increment
  in `test_subsequent_minimum_raise_stays_one_big_blind_after_larger_raise`.
  `tests/unit/test_gui_table_actions.gd` also contains a live repeated-raise
  expectation of 50 after a raise from 20 to 40; the required minimum is 60.
  Audit other fixtures before changing numeric expectations: a synthetic
  initial wager does not necessarily represent an actual prior full raise.

## Acceptance examples

Unless stated otherwise, the big blind is 10, stacks cover the wager, and the
acting player has raise rights. Totals refer to the current street.

| Situation | Required result |
| --- | --- |
| Preflop current wager 10, no raise yet | First full raise minimum 20; reject 19. |
| Preflop raise from 10 to 30 | Increment 20; next full raise minimum 50; reject 49. |
| Next player raises from 30 to 60 | Increment 30; next full raise minimum 90. |
| Postflop opening bet 40 | Increment 40; first full raise minimum 80. |
| Full raise from 20 to 40 | Increment 20; next full raise minimum 60. |
| Raise from 10 to 30, then short all-in to 35 | Preserve increment 20; minimum full raise 55 for a player with raise rights. |
| Raise from 10 to 30, then short all-in to 40 | Increment 10 is below the required 20; preserve increment 20 and do not reopen prior callers' raise rights. Next full raise minimum 60 for a player with raise rights. |
| Stack total below the full-raise minimum but above the call total | Omit ordinary Raise; allow All-in only when raise rights are open. |
| All-in increase exactly equals the required full increment | Treat as a full raise and reopen eligible opponents' action. |
| New street or next hand | Discard the previous street's increment; use the current hand's big blind for initialization. |

## Tasks

Each task includes status, scope and a completion condition. Check it off only
after implementation and verification evidence exists. Add concise evidence
under the task; put session-only logs and captures under ignored
`localtmp/minimum_raise/`.

- [ ] **MR-00 — Record the baseline and confirm boundary rules.** Status:
  Not started. Mode: QA / Tech Lead. Run the existing checks before changes;
  record the source revision, relevant uncommitted changes, commands and
  results. Review the core, generated tests, adapter fixtures and authoritative
  rules. Resolve any specification gaps before implementing them, especially
  preflop when the big blind posts short, a postflop opening all-in below one
  big blind, and multiple short all-ins after a player has acted. Preserve the
  documented short-all-in exception; do not silently introduce cumulative
  reopening rules. Record needed clarifications in the product specification
  and architecture before coding.
  Done: baseline results and explicit expected outcomes for these boundaries
  are recorded, with existing failures distinguished from this change.

- [ ] **MR-01 — Track the full betting increment in core.** Status: Not
  started. Mode: Senior / QA. Add strongly typed street-local increment state
  in `BettingRound`, initialized to the current big blind. An opening full bet
  sets it to the bet amount; a full raise sets it to
  `new_total - previous_current_bet`. Compute the minimum from the current
  wager plus that increment, preserving checked arithmetic and saturation.
  Replace the obsolete flat-increment test with boundary tests for the first
  preflop raise, repeated equal and larger raises, and postflop opening bets.
  Verify calls, checks and folds do not change the increment. Keep the existing
  public wager-total API unless a documented core need requires a change.
  Done: focused tests prove the full-bet/full-raise acceptance examples,
  exact-minimum acceptance, below-minimum rejection without state mutation,
  and overflow handling; run the existing suite after the change.

- [ ] **MR-02 — Apply the tracked increment to all-ins and reopening.** Status:
  Not started. Mode: Senior / QA. Classify increases against the increment
  required before applying the action, including `ALL_IN`. A short increase
  changes the call total without replacing the increment or reopening closed
  raise rights. A full increase updates the increment and reopens action.
  Cover prior callers, the original bettor/raiser, unacted seats, exact all-in
  calls, and players who can afford a short all-in but no full raise. Include
  a short increase of at least one big blind but less than the tracked
  increment, so the old reopening logic cannot pass the regression.
  Done: legal-action lists, pending seats, turn order and completion agree
  with the rules; rejected actions preserve chips, increment, rights and
  history; focused and existing tests pass.

- [ ] **MR-03 — Verify street lifecycle, views and bot consumers.** Status:
  Not started. Mode: Senior / QA. Exercise real `HandController` and
  `TournamentMatch` action sequences across preflop, flop, turn, river and
  the next hand, including a changed blind level. Confirm fresh street state
  and accurate `GameView.minimum_wager_total`, `maximum_wager_total`, call
  amount and legal actions for each recipient. Extend
  `tests/unit/test_betting_round_generated.gd` with an independently tracked
  expected increment and replayable seeds; retain chip-conservation,
  rejection-immutability and privacy assertions. Audit strategy sizing and
  scripted bot fixtures, changing sequences only when the old wager becomes
  illegal under the new rules.
  Done: integration and generated tests verify state propagation and reset;
  bot sizing respects published limits without new invalid-action fallbacks;
  the existing suite passes.

- [ ] **MR-04 — Verify GUI raise presentation and submission.** Status: Not
  started. Mode: Senior / QA. Extend `tests/unit/test_gui_table_actions.gd`
  with live core-backed repeated-raise and short-all-in sequences. Check
  Minimum text/value, free-entry validation, keypad bounds and Minimum
  submission against the bound view on wide and phone layouts. Include
  tablet/small-desktop keypad entry where relevant. Verify ordinary Raise
  and its presets are unavailable when unaffordable or raise rights are
  closed, while valid Call and All-in remain available. Verify refreshed
  controls use the latest view after an opponent raises or a street changes.
  Test Pot targets below, at and above the minimum: retain `T = H + P`, disable
  unavailable targets and never clamp them into a different wager.
  Done: displayed/submitted totals match core limits, an obsolete flat-BB
  raise is rejected without advancing the turn, and a valid Minimum action
  succeeds. Capture representative wide/phone states and record visual
  review separately from automated checks. Fix presentation only as needed;
  keep poker validation in core.

- [ ] **MR-05 — Verify CLI ranges, commands and rejection recovery.** Status:
  Not started. Mode: Senior / QA. Extend `tests/unit/test_cli_renderer.gd`,
  `tests/unit/test_cli_command_loop.gd` and
  `tests/integration/test_cli_preflop_adapter.gd` with core-backed sequences.
  Verify full-state and compact output advertise the updated total range
  after raises and short all-ins; omit Raise when unavailable. Submit an
  obsolete flat-BB amount, confirm a typed rejection and retained turn, then
  submit the exact legal minimum successfully. Check target totals when the
  human already posted a blind or called. Cover `potraise` availability using
  the same exact target as the GUI, plus All-in with open and closed rights.
  Done: deterministic transcripts demonstrate displayed limits, rejection
  recovery and successful actions matching the core; CLI adapter and process
  tests pass without duplicating raise calculations in the CLI.

- [ ] **MR-06 — Run regression checks and reconcile documentation.** Status:
  Not started. Mode: QA / Code Reviewer / Documentation Updater. Run the full
  repository checks and the current GUI invariant gate. Review state updates,
  arithmetic, type safety and core/UI separation. Inspect failures in seeded
  simulation and browser fixtures for changed legal action sequences rather
  than blindly updating expected totals. Process `README.md`, current
  `docs/` excluding `docs/arkiv/`, and `devdocs/`; remove pending-implementation
  notes only after evidence exists and align examples and test guidance.
  Done: all required gates pass with zero errors, GUI/CLI evidence is recorded,
  documentation links and formatting validate, and this backlog accurately
  records completion and any remaining limitations. Historical archives stay
  unchanged.

## Verification commands

Run from the repository root. Use the installed Godot executable in place of
`godot` if it is not on `PATH`. Consult the
[testing guide](../devdocs/how-to/running-and-testing.md) and
[GUI visual workflow](GUI_VISUAL_TESTING.md) for prerequisites and capture
commands. These commands are planned checks, not recorded passing evidence.

Planning-time documentation validation found broken links in `docs/arkiv/`.
The repository-wide checker includes that directory. Record those existing
failures separately at MR-00; archive repairs require separate scope and must
not be reported as minimum-raise regressions.

```bash
make GODOT=godot check
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_betting_round.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_betting_round_generated.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_gui_table_actions.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_cli_preflop_adapter.gd
make GODOT=godot gui-current-invariant-gate
python3 -B tools/check_docs.py
git diff --check
```
