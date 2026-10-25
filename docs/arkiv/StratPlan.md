# Bot Strategy Improvement Plan

> **Archived / superseded.** This document preserves the plan used for the
> completed parameterized-strategy milestones. Current simulation and
> profile-evolution design is in
> [`Simulation_And_Evolutionary_Bot_Strategy.md`](../Simulation_And_Evolutionary_Bot_Strategy.md),
> with completed implementation evidence preserved beside this file in
> [`SimCoreTasks.md`](SimCoreTasks.md) and [`SimCliTasks.md`](SimCliTasks.md).

## Purpose and scope

This plan replaces the current deliberately simple tight-passive and
loose-aggressive heuristics with configurable, reproducible poker policies.
It does not change Texas Hold'em rules, `BettingRound`, pot settlement, GUI
behavior, or the information boundary: every decision must use only the
recipient-safe `GameView` already supplied to that bot.

The first deliverable is a single reusable, parameterized decision model with
several distinct profiles. This is preferable to multiplying nearly identical
classes: profiles make a bot's style explicit, comparable, and easy to tune,
while the model remains a single tested implementation. Additional models are
reserved for genuinely different decision methods, such as an equity-sampling
model in a later phase.

## Experimental in-game access

The new parameterized profiles must be playable as soon as their first
implementation is complete, without waiting for the simulation-based default
rollout. They are therefore an explicit opt-in startup choice:

- CLI accepts the user argument `--allow-experimental-models`. When launching
  through Godot, pass it after Godot's argument separator, for example:
  `godot --headless --path . --script res://scripts/cli/cli_app.gd -- --allow-experimental-models`.
- The GUI startup form provides an unchecked **Allow experimental models**
  checkbox, with brief text that these bots are still being evaluated.
- The option defaults to `false` in every startup path, including omitted CLI
  setup, short-stack setup, and a fresh return to the GUI startup screen.

The selected value becomes an immutable field of the resolved startup
configuration so a started match, diagnostics, deterministic replay, and
simulation report all identify whether the experimental roster was used. It is
not a poker rule and must not alter `TournamentMatch`, `BettingRound`, card
visibility, or the recipient-safe `GameView` contract.

When disabled, both interfaces retain the existing production roster. When
enabled, their composition roots substitute a documented mixed roster of
parameterized profiles for the standard bot seats. The human remains in seat
0, profile selection remains outside poker-rule modules, and an experimental
selection does not silently change a saved/default configuration. The startup
diagnostics must name the experimental model/profile selected for every bot.

## Four style parameters

Create `StrategyDecisionModelParameters`, a typed
`DecisionModelParameters` Resource. All four exported values are integers in
the inclusive range 0--100; validation rejects every value outside that range.
They have the following independent meanings:

| Parameter | 0 | 100 | Primary decision it controls |
| --- | --- | --- | --- |
| `tight_vs_loose` | Very tight | Very loose | Minimum strength required to voluntarily put chips in the pot |
| `passive_vs_aggressive` | Very passive | Very aggressive | Frequency of initiating or escalating a wager when doing so is allowed |
| `call_vs_bet` | Prefer check/call | Prefer bet/raise | Choice between passive continuation and a legal aggressive action |
| `bluff_rate` | Never bluff | Bluff on every eligible bluff opportunity | Probability of an intentional weak-hand bet or raise |

`bluff_rate` is a percentage probability, not a fraction and not a general
aggression multiplier. A bluff is considered only when the evaluator has
classified the hero as weak and an opponent-facing wager is legal. It must not
cause a fold to become an illegal call, a check to become mandatory, or a bot
to inspect hidden cards.

All parameters are immutable for the duration of a tournament, consistent with
the existing `BotProfile` contract. A new match is required to change a
profile.

## Decision pipeline

The strategy model should turn one `GameView` into exactly one legal
`PlayerAction` through the following ordered pipeline. Each probabilistic
choice uses the model's injected per-seat RNG only, so a seed reproduces both
deals and decisions.

1. **Build a public decision context.** Derive pot size, call amount, legal
   wager bounds, street, acting position, active-opponent count, effective
   stack, and public action pressure from `GameView`. The context owns no
   mutable game objects.
2. **Estimate hand potential.** Produce a normalized 0--100 score from the
   hero's two cards, board, and public state only. Preflop uses a documented
   starting-hand evaluator (pairs, ranks, suitedness, connectivity and
   position). Postflop adds made-hand class, draw quality, board texture, and
   whether the hero can improve. It must never evaluate an opponent's hole
   cards or read the deck.
3. **Choose fold, continue, or an eligible bluff.** Map `tight_vs_loose` to a
   continuation threshold. A useful initial linear calibration is `75 -
   0.45 * tight_vs_loose`: a value of 0 requires roughly 75 strength, 50
   requires 52--53, and 100 requires 30. Compare hand potential, price to
   call, position, and stack pressure with that threshold. When checking is
   free, the passive baseline is check rather than fold. A weak hand with a
   legal bet/raise may take the bluff branch with probability
   `bluff_rate / 100`; otherwise it follows the normal fold/check path.
4. **Choose passive or aggressive continuation.** For a hand already chosen
   to continue, compute an aggression propensity from both
   `passive_vs_aggressive` and `call_vs_bet`, then make one seeded roll. The
   former decides *how often* the bot wants to create pressure; the latter
   resolves the *style of continuation* when checking/calling and betting/
   raising are both possible. Thus an aggressive caller can still call often,
   while a passive bet-preferrer may make occasional, small value bets.
5. **Choose a legal sizing.** Map strength and aggression to discrete,
   legal target totals, clamped to `minimum_wager_total` and
   `maximum_wager_total`: minimum, about half-pot, about pot, and all-in only
   when the policy specifically selects it. Convert the selected target to
   `PlayerAction.bet_to()` or `PlayerAction.raise_to()`. Do not reproduce
   betting validation in the model; `BettingRound` remains authoritative and
   the existing HandController fallback remains the safety net.
6. **Record explainable diagnostics.** In test/simulation mode, expose a
   typed decision trace containing input score band, selected branch, legal
   alternatives, requested action, and profile ID. Do not expose this trace to
   opponents or the regular player UI in v1.

The numerical calibration above is intentionally a starting point, not a
claim of poker optimality. Simulation results, not intuition alone, decide
later coefficient changes.

## Initial profiles

Add one Resource for each profile below, all using the same
`strategy_parameterized` model ID. The values are first-pass hypotheses to be
validated by simulation.

| Profile ID | Display name | Tight/loose | Passive/aggressive | Call/bet | Bluff rate | Intended behavior |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `nit_caller` | Nit Caller | 60 | 20 | 20 | 2 | Folds marginal hands and mostly check/calls strong ones. |
| `tight_aggressive` | Tight Aggressive | 65 | 75 | 70 | 8 | Selective entry with frequent value betting and raises. |
| `loose_passive` | Loose Passive | 100 | 25 | 15 | 5 | Enters widely but prefers checking and calling. |
| `loose_aggressive` | Loose Aggressive | 100 | 85 | 85 | 22 | Applies frequent pressure with a materially wider range. |
| `balanced` | Balanced | 70 | 55 | 50 | 12 | Neutral baseline for comparisons. |

Keep `RandomDecisionModel` as a smoke-test opponent. Keep the legacy
`TightPassiveDecisionModel` and `LooseAggressiveDecisionModel` as the default
production roster until the new profiles have passed their acceptance gate.
The startup opt-in above exposes the experimental roster early; it does not
migrate the unchecked/default configuration. After acceptance, migrate the
standard seat configuration deliberately while preserving a mixed table of
distinct bot styles.

## Implementation phases

### Phase 1 — Contract and deterministic foundations

1. Add `StrategyDecisionModelParameters` with defaults, inclusive-range
   validation, and clear field documentation.
2. Add `StrategyDecisionModel`, register it in the composition roots, and add
   the five profile Resources above.
3. Add factory/registry tests for parameter type matching, Resource deep-copy,
   invalid ranges, independent seat instances, and deterministic identical-seed
   decisions.
4. Add the disabled-by-default CLI flag and GUI startup checkbox. Resolve and
   freeze the selected value with the startup configuration, select the
   appropriate roster in both composition roots, and display the selection in
   diagnostics.
5. Update [`ARCHITECTURE.md`](../ARCHITECTURE.md) only when the new model, experimental-startup
   option, and simulation interfaces are implemented; then add the concrete
   implementation tasks to the appropriate current backlog in dependency order.

### Phase 2 — Explainable strength and policy

1. Implement a pure `HandPotentialEstimator` service with no dependency on
   `Table`, `Player`, GUI, CLI, or mutable match state.
2. Start with preflop scoring and tests for pairs, high cards, suited
   connectors, weak offsuit hands, all parameter boundaries, and positional
   adjustments.
3. Add postflop made-hand and draw scoring, including paired boards, flush and
   straight draws, board-only hands, and dangerous coordinated boards.
4. Implement the pipeline above with legal-action, free-check, short-stack,
   all-in, and unavailable-bet/raise tests. Assert that all requested wagers
   stay within the view's legal bounds.

### Phase 3 — Controlled rollout

1. Run the old and new profiles side by side in fixed-seed simulations.
2. Replace the standard `tight_passive` and `loose_aggressive` seat presets
   only after the proposed profile demonstrates the intended measurable style
   and passes all core tests.
3. Keep profile IDs stable once published. Changes to coefficients create a
   new profile ID or a documented versioned Resource so historical simulation
   results remain interpretable.

### Phase 4 — Optional advanced model

After the heuristic policy is stable, consider a separate
`EquitySamplingDecisionModel`. It may estimate equity by deterministic
Monte-Carlo completions of unknown board/opponent cards, but must use a
separate injected RNG stream or reproducible derived substream and must never
access real unrevealed cards. This is a new model ID, not a hidden change to
the parameterized model. It should be pursued only if profiling shows the
headless and Web performance budget remains acceptable.

## Bot-only simulation plan

Create a headless simulation harness under tests/support or a dedicated
non-product simulation module. It composes `TournamentMatch` with all seats
assigned `BotAgent`s; it must not route through GUI, CLI, stdin, or scene
objects. If the normal composition roots require exactly one human, introduce
a simulation-only composition root outside `scripts/core`, rather than
weakening the product configuration contract.

Each simulation batch should:

1. Run a named set of profiles over a declared range of tournament seeds.
2. Rotate seat assignments across seeds so position and button order do not
   favor one profile.
3. Use several stack/blind regimes: the normal 100 BB setup, shallow stacks,
   and short-stack/tournament-endgame setups.
4. Collect aggregate metrics by profile: tournament wins, chip EV, BB/100,
   VPIP (voluntary put money in pot), preflop raise rate, aggression factor,
   fold-to-bet rate, call-vs-raise split, bluff attempts and success rate,
   mean bet size, bust order, hands played, and invalid-action fallbacks.
5. Save the seed range, exact profile Resource IDs/values, engine revision,
   and summary report beside the result. Do not treat one lucky seed as an
   evaluation.

The first acceptance batch should include at least 1,000 complete tournaments
per matchup and should be repeatable with a fixed seed range. It compares
mirrored tables, for example five copies of one candidate against five copies
of a baseline across rotated positions, as well as mixed tables of all
profiles. Increase the batch size before accepting close results; report
confidence intervals or bootstrap intervals for win rate and BB/100 rather
than only the mean.

Simulation output is for balancing, regression detection, and style
validation—not for training a model in production. Do not add online learning
or persist opponent-specific memories in the first implementation.

## Quality gates

- All strategy decisions are reproducible for a configuration and seed.
- A model receives only its `GameView`; tests prove it cannot obtain opponent
  hole cards, deck order, or mutable table/player references.
- Every returned action is legal in its supplied view, with no fallback in a
  representative simulation batch.
- Profile statistics demonstrate ordered behavior: tight profiles have lower
  VPIP than loose profiles; aggressive profiles have higher bet/raise rates
  than passive profiles; larger `call_vs_bet` values produce more aggressive
  continuations; larger `bluff_rate` values produce more eligible bluffs.
- Full GUT, lint, formatting, and existing deterministic tournament tests pass
  before changing the default table composition.
- The simulation harness itself has unit tests for seed reproducibility, seat
  rotation, metric accounting, and no-human headless completion.

## Decisions deliberately deferred

- Exact preflop lookup tables and postflop score coefficients.
- Opponent modelling from `observe()` records.
- Exploitative adaptation, profile switching mid-tournament, and online
  parameter learning.
- Solver-grade equity calculation and real-time performance tuning.
- Individual GUI control for selecting bot strategy profiles; the single
  startup checkbox only enables the documented experimental roster.

These should be selected from evidence produced by the simulation plan, then
documented in [`ARCHITECTURE.md`](../ARCHITECTURE.md) and scheduled in
[`SimCoreTasks.md`](SimCoreTasks.md) or
[`SimCliTasks.md`](SimCliTasks.md) when implementation begins.
