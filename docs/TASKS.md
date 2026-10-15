# Pokahdot Tasks

This backlog follows `docs/ARCHITECTURE.md` and is ordered as vertical, runnable increments. Complete tasks in order unless a dependency explicitly allows parallel work.

The CLI is the first acceptance surface. Add CLI behavior as soon as a core capability can be exercised by a person. Do not start GUI implementation until the CLI supports a complete, playable single-table tournament and the CLI completion gate is checked.

Status markers:

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked

Task labels:

- **App increment:** the application gains new behavior that can be run by a person.
- **Human test:** manually exercise the app after automated tests pass and record/fix any issue before continuing.
- **Gate:** later work must not begin until every item in the gate is complete.

Human tests complement automated tests; they do not replace them. If a human test finds a defect, add or update an automated regression test before marking the human-test task complete.

## Milestone 0 — Development foundation and CLI shell

- [x] Vendor and pin GUT 9.7.1, retain its license, add `.gutconfig.json`, and verify a headless test run.
- [x] Pin GDScript Toolkit 4.x for development and configure `gdlint` plus `gdformat --check`.
- [x] Add shared GUT test support utilities without a custom test runner.
- [x] Implement typed configuration defaults, independent optional overrides, and authoritative validation for player count 2–9, positive integer starting stack, positive integer blinds with small blind no greater than big blind, and immutability after match start; add omission, partial-override, boundary, and rejection tests.
- [x] Implement deterministic RNG stream creation from the validated configuration.
- [x] Implement a CLI startup flow that displays all defaults and can start immediately without supplied values, plus optional independent overrides for participant count, starting stack, small blind, and big blind, invalid-input retry, and a final resolved-configuration summary.
- [x] Add CLI startup-flow tests for complete omission, partial overrides, full valid overrides, invalid-value retry, and prevention of match construction before validation succeeds.
- [x] Implement the CLI command loop and basic parsing for `help` and `quit` without adding poker rules to the adapter.
- [x] **App increment:** `cli_app.gd` starts headlessly, can start with no values supplied or with optional tournament overrides, reports configuration errors clearly, displays help, accepts `quit`, and exits cleanly.
- [x] **Human test:** launch the CLI from the documented command and start immediately without specifying values; verify the 6-player, 1000-chip, 5/10 summary. Restart with only one overridden field and verify all omitted defaults, then restart with all non-default valid values. Restart again and verify that non-integer, out-of-range, non-positive, and small-blind-greater-than-big-blind input is rejected and re-prompted. Finally verify help, unknown-command recovery, and clean `quit`.

## Milestone 1 — First interactive preflop hand

- [ ] Implement `CardData` and `Deck` with uniqueness, exhaustion, and deterministic-shuffle tests.
- [ ] Implement `ChipStack` and `Player` with non-negative chip and reset-state tests.
- [ ] Implement `Table` seat traversal, initial button, blinds, and heads-up order tests.
- [ ] Implement `PlayerAction` and typed action-validation results.
- [ ] Implement `BettingRound` with legal actions, minimum raises, calls, folds, short all-ins, and action-reopening tests.
- [ ] Implement the `PotManager` contribution ledger and single-winner fold-to-one award tests.
- [ ] Implement the initial recipient-specific `GameView` for preflop state, public action history, and hidden-card tests.
- [ ] Implement the `Agent` contract, `HumanAgent`, and scripted test agent.
- [ ] Implement `BotAgent`, `DecisionModel`, typed `DecisionModelParameters`, `BotProfile`, `DecisionModelRegistry`, and `AgentFactory` with configuration-validation tests.
- [ ] Implement `RandomDecisionModel`, its parameter Resource and default profile, plus deterministic and legal-action tests; expose `RandomAgent` as a thin preset constructor.
- [ ] Implement the first `HandController` slice: setup, blinds, hole cards, preflop betting, human wait/resume, bot fallback, fold-to-one settlement, and domain events.
- [ ] Implement the first `TournamentMatch` slice: validate configuration, start one hand, expose views/events, accept human actions, and handle `player_quit`.
- [ ] Extend CLI parsing and rendering for preflop state plus `fold`, `check`, `call`, `bet`, `raise`, `allin`, `quit`, and `exit`.
- [ ] Add an integration test that completes a hand preflop when all opponents fold.
- [ ] **App increment:** a human can use the startup-selected participant count, starting stack, and blinds to start one seeded hand against bots, inspect private/public state, make legal preflop actions, win or lose by folds, and quit.
- [ ] **Human test:** run the CLI hand with non-default startup values, verify the selected number of seats, equal starting stacks, blind postings, only the human's hole cards, and legal actions; try an invalid command and illegal amount, complete one fold-to-one hand, and quit both before and during human action.

## Milestone 2 — Complete single hand through the CLI

- [ ] Implement `HandEvaluator` with all categories, wheel handling, kickers, ties, and parameterized tests.
- [ ] Extend `PotManager` with main-pot and side-pot derivation, eligibility, split pots, and odd-chip tests.
- [ ] Extend `HandController` through flop, turn, river, automatic all-in runout, showdown, pot awards, and normal hand completion.
- [ ] Complete `GameView` street, board, pot, showdown reveal, and legal-action snapshots.
- [ ] Extend CLI rendering for community cards, pot layers, street changes, showdown hands, awards, and final stacks.
- [ ] Add deterministic integration tests for a checked-down showdown, fold after the flop, split pot, and multi-way all-in with a side pot.
- [ ] **App increment:** a complete No Limit Texas Hold'em hand can be played from blinds through showdown or an earlier fold using only the CLI.
- [ ] **Human test:** play at least one CLI hand to showdown and one hand ending by fold; verify board progression, pot and stack updates, opponent-card privacy, winner output, and clean handling of invalid input on multiple streets.

## Milestone 3 — Complete CLI tournament

- [ ] Extend `TournamentMatch` with the hand-to-hand lifecycle, button movement, elimination, winner detection, and quitting between hands.
- [ ] Implement `TightPassiveDecisionModel` and `LooseAggressiveDecisionModel`, typed parameters, default profiles, and thin `TightPassiveAgent`/`LooseAggressiveAgent` preset constructors.
- [ ] Add parameter-boundary tests and prove that the same model can run at multiple seats with different profiles and independent RNG streams.
- [ ] Configure at least two decision model classes at the standard table and report model/profile IDs in startup diagnostics without exposing private model state.
- [ ] Extend the CLI loop across hands and render hand numbers, eliminated players, remaining players, tournament winner, and `player_quit` termination.
- [ ] Add deterministic integration tests for button/blind movement, skipped busted seats, heads-up transition, tournament winner, and quit before/during/between hands.
- [ ] Add a deterministic short-stack startup selection for manual testing and verify that the values chosen by the existing CLI setup flow remain fixed across every hand without changing production defaults.
- [ ] Add a full seeded tournament smoke test and assert chip conservation after every completed hand.
- [ ] **App increment:** one human and at least two bots can play a complete single-table tournament through the CLI until one winner remains, or the human can quit without a winner.
- [ ] **Human test:** use the short-stack configuration to finish a CLI tournament; verify hand transitions, button/blind movement, elimination, heads-up behavior, final winner, and total chips.
- [ ] **Human test:** start a second CLI tournament and verify `quit`/`exit` produces `player_quit`, no winner, and a clean process exit.

## CLI completion gate — required before GUI work

- [ ] **Gate:** all GUT unit and integration tests pass headlessly.
- [ ] **Gate:** `gdlint` and `gdformat --check` pass for project GDScript.
- [ ] **Gate:** every Milestone 0–3 human-test task is complete with discovered defects covered by regression tests.
- [ ] **Gate:** the complete CLI tournament satisfies the applicable acceptance criteria in `docs/ProjectDescription.md`.
- [ ] **Gate:** CLI code contains presentation/parsing only; poker rules remain exclusively in `scripts/core/`.
- [ ] **Gate:** CLI startup can omit every value, override any subset, or override all participant/stack/blind values; it resolves omitted fields to defaults, rejects invalid explicit values before match creation, and uses the resolved values for the complete tournament.
- [ ] **Gate:** adding a test decision model and profile requires registry/configuration changes only and no edits to poker-rule modules.
- [ ] **Gate:** `README.md`, `docs/ProjectDescription.md`, and `docs/ARCHITECTURE.md` describe the working CLI accurately.

## Milestone 4 — GUI for the functionally complete game

- [ ] Build the startup configuration panel for participant count, starting stack, small blind, and big blind, prefilled with defaults and able to start without any user edits before `TournamentMatch` construction.
- [ ] Add inline startup validation, prevent starting with invalid values, and map a valid selection into a fresh immutable tournament configuration.
- [ ] Build the main `Control`-based table scene and GUI controller against the existing `TournamentMatch` API.
- [ ] Render seats, stacks, private/public cards, board, pots, blinds, dealer, acting player, eliminations, and tournament result.
- [ ] Connect Fold, Check/Call, Bet/Raise presets, free amount input, all-in, and legal-action enabled states.
- [ ] Present ordered domain events without duplicating settlement, winner, or legality rules in GUI code.
- [ ] Add the always-available `Avslutt` control with confirmation and `player_quit` handling.
- [ ] Add GUI adapter tests for startup-selection mapping and rejection, action mapping, recipient-safe rendering data, and quit confirmation behavior.
- [ ] **App increment:** the human can start with defaults or optionally change participant count, starting stack, and blind sizes, then play the same complete tournament available in the CLI through the GUI without duplicated rules.
- [ ] **Human test:** start once without editing the GUI defaults, then verify a partial override, invalid-value feedback, and a fully non-default startup selection; complete representative preflop and postflop actions, including resolved blind postings, bet sizing, all-in, showdown, and continuing to the next hand with unchanged configuration.
- [ ] **Human test:** verify opponent cards remain hidden until legitimately revealed, eliminated seats are skipped, and the tournament winner is displayed correctly.
- [ ] **Human test:** verify quit confirmation both cancels safely and ends with `player_quit`; verify desktop resizing and representative mobile aspect ratios under Compatibility rendering.

## Release verification

- [ ] Run all headless tests and resolve warnings or invariant failures.
- [ ] Verify GUI and CLI produce equivalent core outcomes for the same seed and scripted actions.
- [ ] Verify both GUI and CLI expose the optional startup overrides and produce identical validated core configuration from equivalent omissions and selections.
- [ ] Verify development addons and tests are excluded from release exports.
- [ ] Verify Compatibility rendering on target desktop platforms and basic mobile resizing.
- [ ] Review all user-facing text and documentation for consistency with the implemented game.
