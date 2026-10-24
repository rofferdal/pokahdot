# Pokahdot Architecture

Status: Core, interactive CLI tournament play, the simulation CLI introduction, GUI work through archived Milestone 4.6b plus player-name implementation, and strategy work through archived Stratmilestone3 are implemented. GUI naming visual acceptance, remaining device/small-viewport verification, and profile-evolution backlogs remain unfinished.
Last updated: 2026-10-24
Requirements source: [`docs/ProjectDescription.md`](ProjectDescription.md)

## 1. Purpose

Pokahdot is a single-table No Limit Texas Hold'em tournament for one human player and automated opponents. The same deterministic game core supports a Godot `Control`-based GUI, a headless interactive terminal interface, and a dedicated non-interactive all-bot simulation adapter.

This document defines module boundaries, state ownership, runtime flow, and the contracts that presentation layers and agents use. `docs/ProjectDescription.md` is normative; this document may refine implementation structure but must not add or change game rules.

The v1 boundary is one single-table tournament with 2–9 participants, equal starting stacks, exactly one human, and bots in every other seat. Before each tournament starts, the human may optionally override the participant count, common starting stack, starting small blind, and starting big blind; omitted values use defaults. Blinds then follow the defined hand-based blind-level schedule. V1 has no cash-game accounting, buy-ins, cash-out, rebuys, antes, rake, action timer, network play, or prize payout. Normal play ends only when one participant has chips; a human-requested quit ends it without a winner. The project uses Godot 4, GDScript, and the Compatibility renderer, with no C# or platform-specific plugins.

## 2. Architectural drivers

- One rules implementation for GUI, interactive CLI, and simulation.
- Correct betting, all-in, side-pot, showdown, and tournament elimination behavior.
- No hidden-card leakage to agents or presentation layers.
- Replaceable bot strategies without changes to poker rules.
- Multiple decision-model implementations with independently tunable, per-seat behavior profiles.
- Strategic profiles as the standard product roster, with an explicit optional
  legacy-heuristic share for product games.
- Optional startup overrides, with defaults, for participant count, common starting stack, and both blind sizes in GUI and CLI.
- Deterministic runs when an RNG seed is supplied.
- A human action may arrive later without blocking Godot's main thread.
- The human may quit at any time without manufacturing a tournament winner.
- Core logic must be testable without loading scenes or reading stdin.

## 3. Architectural style

Use a small layered architecture with explicit ports between the game core and its adapters.

```text
GUI composition root   Interactive CLI root   Simulation CLI root
        |                       |                     |
        +----------- adapters and construction ------+
                                |
                        TournamentMatch API
                                |
              HandController -> BettingRound -> PotManager
                     |                 |              |
                   Table             Player      HandEvaluator
                     \                 |              /
                      Deck -------- domain data -----
                                |
                          Agent interface
                         /               \
                   HumanAgent          BotAgent
                                           |
                                  DecisionModel + BotProfile
```

Dependencies point inward. `scripts/core/` may use Godot base types such as `RefCounted`, `Resource`, `RandomNumberGenerator`, and typed signals or value containers, but it must not depend on `Control`, scenes, GUI nodes, stdin, or stdout.

There are three composition roots. GUI and interactive CLI each construct exactly one human plus bots. The non-interactive simulation root may construct all-bot tournaments. No other composition path may bypass the exactly-one-human product invariant. Each root creates validated configuration, players, agents, named RNG streams, and `TournamentMatch`, then drives the same public API.

`TournamentConstructionContract` makes the composition distinction explicit at
the match boundary. `TournamentMatch` defaults to the product contract and
therefore requires exactly one `HumanAgent`; the dedicated simulation root must
pass `TournamentConstructionContract.simulation()`, which instead requires
zero human agents. This contract is separate from the editor-facing product
configuration, so `ConfigResolver`, GUI startup, and interactive CLI startup
retain their existing exactly-one-human validation.

`SimulationMatchFactory` is the simulation-owned, headless composition root.
It deep-copies the supplied `BotProfile` Resources before constructing one
fresh `BotAgent` per seat, uses the all-bot construction contract, and advances
the match without rendering or stdin. It treats a human wait state as a
simulation error. Typed batch input and outcome contracts build on this root
without entering the game core.

`SimulationBatchRunner` executes a caller-supplied ordered collection of
`SimulationTournamentInput` values. It does not schedule indexes, select
matchups, or mutate profile snapshots; it reconstructs the resolved
configuration with each input's effective seed and returns a typed outcome for
every input, including structured validation, construction, and execution
failures. This makes a future shard a filter of the same global plan rather
than a separately seeded local batch.

`SimulationBatchPlanner` converts explicit global indexes into inputs using
`seed_start + index`, ordered round-robin matchup selection, and cyclic seat
rotation. Each matchup maintains its own zero-based occurrence count, so a
rotation is `occurrence % player_count` even when matchups are interleaved.
Its shard helper filters those already-planned inputs by global index and never
renumbers or replans them. `SimulationRegime` owns the only permitted v1
structural variations (player count, common stack, and starting blinds) and
validates them through the normal `ConfigResolver`; all regimes therefore use
the existing single-table and hand-based blind-progression rules.

`SimulationTournamentMetrics` observes only recipient-safe completed-hand
snapshots, public action records, domain events, and copied bot-decision
metadata. `HandController` records the starting active seats and stacks for
that hand in its safe `GameView`; `BotAgent` separately retains legal-action
alternatives and strategy traces only for simulation measurement. The adapter
can therefore calculate survival, blind-normalized chip change, per-hand
VPIP/PFR, all-street bet/raise and call counts, action-opportunity rates,
call-versus-raise splits, eligible bluff frequency, and invalid-action
fallbacks without retaining cards or mutable core state. Measurement consumes
every applied decision independently of optional bounded trace sampling.

`SimulationTraceConfig` restricts tracing to none, errors, or a bounded
deterministically sampled mode. `SimulationTraceEntry` contains strategy
branch/action metadata and hand outcomes only; it deliberately contains no
hole cards or deck data. `SimulationAggregateCalculator` groups completed
seat observations by profile, matchup, seat, regime, and evaluation plan.
Behavioral rates divide summed raw numerators by summed opportunity
denominators; tournaments with no opportunity do not become artificial zero
observations. Aggregates also report those summed counts, 95% normal
half-width estimates, sample-threshold eligibility, and the documented
normalized fitness formula. Public all-ins are classified as calls, opening
bets, or raises from their target total relative to the street's prior wager.

`RngStreamFactory` derives every random stream from the effective tournament
seed and a stable name. In addition to deck, initial-button, and per-seat bot
streams, simulations receive `tournament_construction`,
`seat_profile_assignment`, and `trace_sampling` streams. `RngStreams` records
the derived seed for every name; `SimulationMatchCreationResult` preserves the
effective seed and copied stream-seed map for subsequent outcome reporting.
The simulation factory passes the same stream collection to the agents and
`TournamentMatch`, so bot decisions and poker progression cannot accidentally
draw from separate copies of a stream.

Simulation adapter values are explicit `RefCounted` snapshots: a
`SimulationTournamentInput` identifies the tournament index, resolved seed,
matchup, and assigned immutable profile snapshots; a
`SimulationTournamentOutcome` carries copied identity, final seat-to-profile
mapping, completion summary, and structured diagnostics. Neither retains live
core state, rendering data, command-line arguments, or serialization details.

`SimulationManifest` schema 2 is the versioned simulation CLI input contract. It owns
immutable profile snapshots, explicit structural regimes, matchups, and named
evaluation plans. Every model parameter is required in a snapshot; schema 1
and mixed legacy/current parameter fields are rejected instead of receiving
silent defaults. `SimulationManifest.build_plan()` concatenates plans in
manifest order, assigns global zero-based indexes and `seed_start + index`,
derives matchup occurrence and cyclic seat rotation from each plan-local
occurrence, and applies `SimulationShard` only after global planning.
`SimulationCommandOptions` is the typed boundary for strict CLI arguments.

`SimulationManifestGenerator` is a simulation-layer export service that bridges
the curated product catalog to an evaluation baseline without reversing those
dependencies. It obtains fresh deep copies through
`PlayableBotRoster.get_catalog_profiles()`, duplicates them again into a
schema-2 manifest, and validates both the manifest and its executable batch
plan before returning it. Its typed `SimulationRosterManifestSettings` defaults
to a non-zero seed, 100bb (1000-chip) 5/10 play, and balanced cyclic rotation.
Catalogs of at most nine profiles use one all-active matchup. Larger catalogs
use deterministic cyclic translations of a seed-derived difference-covering
nine-profile block, giving equal appearances, complete pair coverage, and
aggregate seat balance without increasing the nine-player table limit. The
tournament count must be divisible by the catalog size. The service performs
no argument parsing, filesystem work, or terminal output. The simulation CLI's
`export-roster-manifest` command is the outer adapter: it translates command
options into these settings and atomically serializes only the validated
snapshot. Neither a manifest nor an evaluation retains live product Resources.

`SimulationReport` schema 3 stores the canonical manifest snapshot and checksum beside
typed outcome mappings, aggregate groups, diagnostics, and recipient-safe
traces. Report writes use a temporary sibling followed by an atomic rename.
It also records a deterministic roster provenance object derived from the
manifest's immutable profile snapshots, and every tournament records its
ordered selected profile IDs beside its seat map. This lets candidate
evaluations reproduce their profile collection without claiming they used the
product-curated roster. Normal GUI/interactive-CLI composition uses the
source-controlled `PlayableBotRoster.ROSTER_VERSION`; interactive diagnostics
record that version and the selected bot profile IDs.

For product composition, `PlayableBotRoster` classifies a profile by its
concrete decision-model family: `StrategyDecisionModel` profiles are
strategic; every other decision-model implementation is a legacy heuristic.
The classification is derived from the registered model rather than a second
hand-maintained profile list, so a future non-strategic model automatically
joins the legacy family. Standard GUI and CLI games select only strategic
profiles, and the product strategic catalog is capped at 25 profiles. That cap
belongs exclusively to `PlayableBotRoster` product validation: simulation
manifests, candidate batches, and matchups may contain more strategic profiles
and must never be rejected or truncated because of the product limit. With
`use_legacy_models` enabled, the roster selector assigns
`ceil(bot_count / 2)` legacy profiles and the remainder strategic profiles.
Selection is deterministic from the seat-profile-assignment RNG stream,
random within each family, and reuses a profile only after exhausting the
assigned family's available profiles. This supports all 1–8 product bot-seat
counts even when a family has fewer profiles than seats.
`simulation_cli_app.gd` is a separate `SceneTree` process entry point for
`help`, `validate`, `run`, `inspect`, and `replay`; it never calls the
interactive CLI or reads stdin. Replay rebuilds the manifest plan, executes
the same simulation composition path, and compares a normalized outcome
digest so JSON integer/float representation cannot change reproducibility.

## 4. Key decisions

| Decision | Rationale |
| --- | --- |
| Use an explicit tournament and hand state machine | Poker flow is sequential but must pause safely for human input and terminate safely on quit. |
| Never block the Godot main thread | The GUI must remain responsive while waiting for the human. “Wait” means returning `WAITING_FOR_HUMAN`, not a blocking loop in core code. |
| Keep commands separate from views | Commands request mutations; `GameView` is a recipient-specific read-only snapshot. |
| Treat quit as tournament control, not a poker action | Quitting must work outside a betting turn and must not affect betting legality. |
| Track per-hand contributions by seat | Main and side pots can then be derived consistently at settlement. |
| Build a different `GameView` for each recipient | Hidden information is filtered at one boundary instead of relying on UI or bot discipline. |
| Inject seeded RNG streams | Tests and recorded scenarios remain reproducible. |
| Build a validated configuration before constructing a match | GUI and CLI can merge optional startup overrides onto defaults without permitting partially configured game state. |
| Compose bots from agent, decision model, and profile | New decision algorithms and per-seat behavior can be added without changing poker rules or duplicating input/error handling. |
| Keep runtime state in core objects, not scenes or Resources | Scenes display state. Configuration and static card data may be Resources; mutable match state stays in dedicated runtime objects. |
| Keep avatar selection in the GUI presentation layer | Avatar identity is visual-only and must not affect `Player`, `GameView`, tournament configuration, or core RNG streams. |
| Keep GUI display names in the GUI presentation layer | A validated 50-name catalog and tournament-local assignment map affect rendering only; the GUI human label is `Human`, while interactive CLI labeling remains unchanged. |
| Separate presentation RNG streams | GUI name selection uses `gui_names` and avatar selection uses `gui_avatars`; neither may perturb the other or any game RNG stream. |
| Keep GUI action pacing in a Resource | Per-seat visual pauses are configurable without putting timers or presentation policy in poker rules. |
| Keep blind-level progression in the core | Hand-completion timing, active-player snapshots, and 125%-to-even rounding must be identical for GUI and CLI. |
| Enforce a 20 px minimum for player-facing GUI text | Controls may reflow for compact screens, but readable text must not be reduced below the desktop opponent-name baseline. |
| Use responsive Control layout guidance | `canvas_items` with `expand`, containers, anchors, and responsive margins govern layout adaptation; font and texture crispness is not assumed from stretch mode alone. |
| Give manually positioned GUI regions one layout owner | The central board/pot/wager stack uses a plain `Control`; `PokerTableController` atomically assigns its centered bounds and its three child panel rectangles. A Godot `Container` must not compete with those explicit rectangles or resize the stack from late child minimum-size notifications. |
| Preserve mobile usability targets | Interactive controls provide at least 48 × 48 px touch targets, with approximately 160 × 50 px targets for horizontal text buttons where space allows. |
| Share one in-canvas numeric keypad between startup and live-table inputs | Web and iPad number entry remains consistent, preserves the canvas viewport, and avoids browser keyboard behavior. |
| Use GUT as the test framework | Its Godot 4.7 release provides GDScript assertions, parameterized tests, doubles, headless execution, and JUnit output without adding runtime coupling. |

## 5. Core module responsibilities

### 5.1 `card_data.gd`

`CardData` is an immutable `Resource` value containing a stable card ID, rank, and suit. Equality and ordering use the stable ID and rank values, never display text or textures.

Card visuals are presentation metadata and must not be required by the evaluator or deck.

`CardData` may expose stable domain values or diagnostic codes, but it does not own CLI display formatting. The CLI adapter maps ranks to `2`–`10`, `J`, `Q`, `K`, or `A` and suits to `♠`, `♥`, `♦`, or `♣` according to [`POKERCARDS_IN_CLI.md`](POKERCARDS_IN_CLI.md). This prevents terminal-specific Unicode and collection delimiters from leaking into poker rules or card identity.

### 5.2 `deck.gd`

`Deck` owns the 52-card collection for one hand.

- Reset to exactly 52 unique cards.
- Shuffle through an injected `RandomNumberGenerator`.
- Draw cards without replacement.
- Use the standard 13 ranks and four suits, with no jokers.
- Fail explicitly if a caller attempts to draw from an empty deck.

`Deck` knows nothing about players, streets, or UI.

### 5.3 `chip_stack.gd`

`ChipStack` is the only component allowed to add or remove chips from a player's stack.

- Values are integers and never negative.
- A debit returns the actual amount removed, allowing short all-ins.
- A credit rejects negative values.

### 5.4 `player.gd`

`Player` owns runtime state for one seat:

- identity, seat, and agent reference;
- stack and hole cards;
- per-hand flags: folded and all-in;
- tournament flag: busted;
- `bet_this_round` and total contribution for the current hand.

Hand-specific state is reset by `HandController`; `busted` survives between hands.

### 5.5 `table.gd`

`Table` owns seat ordering, button position, current blind sizes for posting, and active-seat traversal. It receives the current blind values from the tournament's blind-level state; it does not decide when a level changes.

- All traversal helpers skip busted seats.
- The initial button is selected from active seats by injected RNG.
- Later hands move the button clockwise to the next active seat.
- Heads-up blind and action order are exposed as explicit helpers rather than scattered conditionals.

### 5.5.1 Blind-level state

`TournamentMatch` owns the mutable blind-level state (implemented as a core value/component), including the level number, current small and big blinds, completed hands in the level, the active-player count captured when the level began, and the computed hands until the next increase. The state uses an interval of `active_player_count_at_level_start * 2` for levels that began with at least five active players, otherwise 10; that interval remains unchanged until the next level begins.

After a hand settles and zero-stack players are eliminated, `TournamentMatch` records the completed hand in the blind-level state. If the interval is reached, it calculates the next big blind as the smallest even integer greater than or equal to 125% of the current big blind and sets the small blind to exactly half of it. The current hand keeps its posted blinds, so an increase is applied only when the next hand is initialized. The new level then captures the current active-player count and starts its completion counter at zero.

### 5.6 `player_action.gd`

`PlayerAction` contains an `ActionKind` and amount.

```text
FOLD, CHECK, CALL: amount = 0
BET, RAISE: amount = target total bet_this_round after the action
```

For `BET` and `RAISE`, “total wager amount” means the player's target total contribution on the current street, not the number of additional chips to move. Using a target total avoids ambiguity after blinds or earlier contributions. `BettingRound` remains the authority for whether an action and amount are legal.

### 5.7 `betting_round.gd`

`BettingRound` owns one street's action state:

- acting seat;
- current bet;
- the table's big blind as the fixed minimum full-raise increment;
- seats that still owe action;
- seats whose raise rights are open;
- legal action calculation;
- action application and next-seat selection;
- round completion.

A full raise must reach at least `current_bet + big_blind`, regardless of the size of any previous bet or raise on the street. An opening postflop bet must be at least one big blind. A short all-in raise with an increment below one big blind updates the amount to call but does not reopen raise rights for players who already acted and matched the previous full raise. These rules must be represented directly in state, not inferred from action history in the UI.

Invalid actions return a typed rejection and leave all state unchanged. Bot fallback selection happens in `HandController`, not inside `BettingRound`.

### 5.8 `pot_manager.gd`

`PotManager` records total per-hand contributions by seat. It derives pot layers from unique contribution thresholds when a hand is settled.

For each layer:

1. Determine the next contribution threshold.
2. Include chips from every seat that contributed to that layer, including folded seats.
3. Mark only non-folded contributors as eligible winners.
4. Evaluate and award each pot independently.
5. Give an odd chip to the first eligible winner clockwise from the button.

Unmatched excess contribution is returned to its contributor rather than becoming a one-player pot. Adjacent layers with identical eligible winners are merged, so live blinds or unequal called wagers do not appear as misleading side pots. This ledger-based design keeps side-pot construction independent of the order in which all-ins occurred.

### 5.9 `hand_evaluator.gd`

`HandEvaluator` is a pure service. It accepts five to seven cards and returns a comparable `HandRank` value containing:

- category;
- ordered tie-break values;
- the selected five cards for display and diagnostics.

It must not inspect players, stacks, pots, or UI state.

### 5.10 `game_view.gd`

`GameView` is a snapshot, never a live reference to mutable core collections. A factory builds it for a specific viewing seat. Its required fields are:

- `street`: `preflop`, `flop`, `turn`, `river`, `showdown`, or `hand_end`;
- button, acting, small-blind, and big-blind seats;
- community cards and pots, including each pot's amount and eligible seats;
- each seat's name, human flag, stack, street contribution, folded/all-in/busted flags, and active/eliminated status;
- `hero_seat` and only that recipient's `hero_hole_cards`;
- current `small_blind` and `big_blind`;
- current `blind_level`, `completed_hands_in_level`, `hands_until_next_level`, and the active-player count captured at level start;
- legal actions, including call size and minimum/maximum bet or raise totals;
- public action history and recipient-safe showdown results, including category, ordered tie-break values, and the selected five cards for each legitimately revealed hand;
- hand number, tournament status, end reason, and optional winner.

Public action history contains only actions and public outcomes. Opponent hole cards appear only at showdown, or at `hand_end` when those cards were actually shown; folded or otherwise unrevealed cards never appear.

Collections exposed in a view are duplicated so a bot or UI cannot mutate core state indirectly.

GUI and CLI presentation layers render the blind values and progress fields from `GameView`. They never calculate level intervals, round blind values, advance levels, or mutate blind-level state; all such decisions belong to `TournamentMatch` and its core blind-level component.

### 5.11 `agents/agent.gd`

`Agent` defines one decision contract:

```gdscript
func choose_action(view: GameView) -> PlayerAction
```

Bot agents return synchronously in v1. They may depend on `GameView` and `PlayerAction`, but not on mutable `Table`, `Player`, `Deck`, or `PotManager` objects.

`HumanAgent` does not read devices or stdin. It acts as an input mailbox with `submit_action()` and `has_pending_action()`. `HandController` returns `WAITING_FOR_HUMAN` while the mailbox is empty, thereby blocking hand progression without blocking Godot's main thread, and calls the common `choose_action()` contract only when an action is queued. The queued action is still validated by `BettingRound`; parsing it successfully does not make it legal.

### 5.12 Bot decision models and profiles

`BotAgent` implements the stable `Agent` contract and delegates the actual choice to one injected `DecisionModel`. This separates orchestration and safety behavior from poker strategy.

```gdscript
class_name DecisionModel

func configure(
    parameters: DecisionModelParameters,
    rng: RandomNumberGenerator,
) -> PackedStringArray

func choose_action(view: GameView) -> PlayerAction

func observe(event: PublicGameEvent) -> void
```

`configure()` is called exactly once and returns an empty array on success or descriptive validation errors on failure. Profiles cannot be changed during a tournament; start a new tournament to use different parameters.

`observe()` has a default no-op implementation. It allows future adaptive models to maintain private, per-seat memory from public actions without exposing core objects or hidden cards. `BotAgent` forwards observations exactly once and in domain-event order. Each seat receives its own model instance; mutable model state is never shared between seats.

`PublicGameEvent` is an immutable, recipient-safe projection of a domain event. It may describe actions, public cards, pot awards, eliminations, and street changes, but never unrevealed cards or mutable core references. `BotAgent` forwards the same public observations available through `GameView` to its model.

`BotProfile` is an immutable-at-runtime `Resource` that binds:

- a stable `profile_id` for diagnostics and configuration;
- a `model_id` resolved by `DecisionModelRegistry`;
- one model-specific `DecisionModelParameters` Resource;
- an optional display name that does not affect behavior.

Each model defines a typed parameters subclass and validates it during match construction. Example parameters include preflop strength threshold, aggression, bluff frequency, pot-size fractions, or weighted random actions. Parameters have documented ranges and defaults. Avoid untyped dictionaries and magic string keys for model behavior.

`AgentFactory` deep-duplicates parameter Resources before configuration and models treat the resulting parameters as read-only. Models must not load profiles, read project settings, or mutate shared Resources themselves.

`DecisionModelRegistry` maps stable model IDs to constructors and expected parameter types. It belongs to the composition layer and is passed to `AgentFactory`; poker rule modules never query global registries. Adding a model requires only:

1. A `DecisionModel` implementation.
2. Its typed parameter Resource and validation tests.
3. Registration under a new stable model ID.
4. At least one `BotProfile` Resource.
5. Determinism, legal-action, and information-boundary tests.

No changes should be required in `TournamentMatch`, `HandController`, `BettingRound`, `PotManager`, or `GameView`. Multiple seats may use the same model with different profiles, and one profile may be reused by multiple seats because parameters are treated as read-only.

Every `BotAgent` receives a separate RNG stream derived from the tournament seed. A model must use only that stream for randomness. This makes a model/profile pair reproducible and prevents one bot's random calls from changing deck order or another bot's decisions.

`RandomDecisionModel`, `TightPassiveDecisionModel`, and
`LooseAggressiveDecisionModel` remain supported legacy heuristic models for
testing and optional variety. Their profiles are excluded from standard
product selection, but participate in the deterministic legacy share when
`use_legacy_models` is enabled. New decision models that are not
`StrategyDecisionModel` receive the same treatment.

`StrategyDecisionModel` is the first parameterized strategy model, registered as
`strategy_parameterized`. Its typed `StrategyDecisionModelParameters` Resource
contains inclusive integer percentages for `tight_vs_loose`,
`passive_vs_aggressive`, `call_vs_raise`, and `bluff_rate`. The model receives
only its per-seat injected RNG and recipient-safe `GameView`; it has no access
to opponents' hole cards, the deck, or mutable poker state. Its initial
foundation, public hand-potential estimator, and legal wagering policy are
implemented and covered by the archived strategy milestones.
The five immutable-at-runtime profile Resources are `nit_caller`,
`tight_aggressive`, `loose_passive`, `loose_aggressive`, and `balanced`.

`StrategyDecisionTrace` is a typed, test/simulation-only value object for
explaining a parameterized model decision. `AgentFactory` supplies the
profile ID to the model through an explicitly test-only hook, and
`StrategyDecisionModel` records the selected baseline branch, legal
alternatives, and requested action. `BotAgent` exposes a copied trace only
through the matching test/simulation hook. Traces are never added to
`GameView`, public events, CLI output, GUI state, or opponent-visible data.

The initial action-policy phase keeps the free-check baseline, then applies a
fold/continue threshold of `75 - 0.45 * tight_vs_loose` to the estimator's
recipient-safe score. Call price and stack pressure increase the required
strength, while later position supplies a bounded continuation credit. A
missing estimate retains the safe check/call baseline. The eligible-bluff phase
is separate: only a weak estimate with a legal bet or
raise can consume one injected-RNG roll, with probability exactly
`bluff_rate / 100`; `bluff_rate` is never used as a general aggression
multiplier. Bluff wagers use the legal minimum target; ordinary aggressive
continuation sizing is described below.
When checking or betting are both legal, one injected-RNG roll applies
`passive_vs_aggressive` to that opening decision. When calling or raising are
both legal, one roll instead applies `call_vs_raise`. This context split
replaced the schema-1 two-roll AND gate after controlled batches confirmed
that the old controls were commutative aliases. If only one action class is
legal, that class is selected without a roll. Aggressive continuation uses the estimator's
stable bands for discrete target totals: minimum for weak hands, approximately
half-pot for marginal hands, approximately one pot for strong hands, and the
maximum legal total for premium hands. The loose profile Resources use a
`tight_vs_loose` value of 100 so their continuation threshold reaches the
widest calibrated range. The calibrated continuation order is Nit Caller 60,
Tight Aggressive 65, Balanced 70, then both loose profiles at 100; the first
two still fold marginal hands but now contest premium and strong suited
broadway hands. Each target is clamped to the
recipient-safe `GameView` minimum and maximum wager totals, and bet/raise
requests always carry a target total rather than a chip delta.

Published schema-1 profile values migrate explicitly by calculating
`round(passive_vs_aggressive * call_vs_bet / 100)` and assigning that result
to both schema-2 aggression fields. This preserves the old aggregate
aggressive propensity as a starting point while allowing later independent
tuning. The five bundled Resources were migrated with that formula; no loader
silently upgrades an artifact. The evidence and exact mapped values are in
`StrategyParameterValidation.md`.

`HandPotentialEstimator` is a pure helper for the later policy stage. Its only
inputs are the recipient's two hole cards, public board cards, and an explicit
`HandPotentialContext` containing public scalar values: street, position
ordinal, active opponents, pot, call amount, effective stack, and big blind.
It copies those inputs into `HandPotentialEstimate` and neither accepts nor
retains `Table`, `Player`, `Deck`, `GameView`, GUI, CLI, or mutable match
references. Its preflop 0--100 heuristic weights pair strength (45%), rank
strength (30%), suitedness (10%), connectivity (10%), and position (5%).
Postflop it reports a bounded score plus made-hand class, direct/backdoor draw
quality, draw outs, public board texture, board-only status, and improvement
potential. The estimate is a deterministic heuristic, not equity; it must not
be rendered in normal player UI or used to reveal unshown cards.

There is no experimental game mode. `TournamentConfig` defaults
`use_legacy_models` to false, `StartupOverrides` may explicitly select it,
and `ResolvedTournamentConfig` freezes the resolved value. The CLI reads
`--use-legacy-models` only from Godot user arguments after `--`; the GUI
presents an unchecked “Use legacy heuristic models” checkbox and clears it
when returning to startup. The option changes only product-roster selection;
poker-rule modules see only the completed agents and never a strategy-family
branch.

Model output is still validated by `BettingRound`. Invalid output produces the standard warning and fallback in `HandController`, regardless of model implementation. Network-backed or asynchronous models are outside v1; they may later add a pending decision result without changing poker rules or profile formats.

### 5.13 `hand_controller.gd`

`HandController` orchestrates one hand and owns the hand state machine. It coordinates existing rule components but does not reimplement their rules.

```text
SETUP
  -> PREFLOP
  -> FLOP
  -> TURN
  -> RIVER
  -> SHOWDOWN
  -> COMPLETE

Any active state -> ABORTED when the tournament receives player_quit
```

Automatic transitions skip betting when all remaining players are all-in or only one player can act. A fold-to-one result moves directly to settlement without revealing hidden cards.

Setup follows the normative dealing sequence: reset hand state, shuffle, post possibly short all-in blinds, and deal two cards to each active participant clockwise from the small blind. Flop, turn, and river are dealt directly as 3/1/1 community cards; v1 never burns cards.

### 5.14 `match.gd`

`TournamentMatch` owns the tournament lifecycle:

```text
NOT_STARTED -> RUNNING -> FINISHED
                            |-- end_reason = winner
                            `-- end_reason = player_quit
```

Responsibilities:

- validate and defensively copy the completed startup configuration, then freeze it for the tournament;
- create and advance hands;
- mark zero-stack players as busted after a completed hand;
- stop when one player has chips and record that seat as winner;
- accept `request_quit()` in every non-finished state;
- expose snapshots and domain events to adapters.

When `request_quit()` is received before, during, or between hands, it immediately marks the tournament finished and prevents any further gameplay transition. A current hand becomes `ABORTED`; no pot is awarded and no winner is assigned. The final snapshot is diagnostic state only, with `end_reason = player_quit`; chip conservation after an aborted hand is not used to determine tournament results.

## 6. Runtime control flow

The central API is step-based:

```gdscript
func start() -> StepResult
func advance_until_blocked(max_transitions: int = 32) -> StepResult
func submit_human_action(action: PlayerAction) -> StepResult
func request_quit() -> StepResult
func get_view_for(seat: int) -> GameView
```

`advance_until_blocked()` performs automatic dealing, bot actions, street transitions, settlement, and tournament transitions until it reaches one of these boundaries:

- `WAITING_FOR_HUMAN`
- `HAND_COMPLETED`
- `TOURNAMENT_FINISHED`
- `YIELDED`
- `ERROR`

The method may execute several bot turns synchronously, but it returns `YIELDED` when its positive transition budget is exhausted. This guard prevents a defect from freezing the application in an infinite transition loop.

The core checks a latched quit request before every state transition. GUI driving must use a bounded transition budget and yield back to Godot's event loop between budgets so the always-available quit control remains responsive. The CLI loops through bot progress without requesting stdin and accepts `quit`/`exit` whenever it is reading a human command.

The completed implementation history proceeded through the interactive CLI first, then the GUI. Current unfinished work is split across [`CoreTasks.md`](CoreTasks.md), [`CliTasks.md`](CliTasks.md), [`GuiTasks.md`](GuiTasks.md), [`SimCoreTasks.md`](SimCoreTasks.md), and [`SimCliTasks.md`](SimCliTasks.md); completed historical sequencing is preserved under [`arkiv/`](arkiv/).

### GUI adapter

1. Show a startup panel prefilled with 6 participants, 1000 chips, small blind 5, and big blind 10; starting immediately without editing is valid.
2. Validate edits locally for immediate feedback, then create a fresh validated match configuration and construct `TournamentMatch`; do not create players, chips, or cards while the input is invalid.
3. Call `start()` and render the returned human `GameView`: board, pots, stacks, current blinds, level progress, acting seat, hero cards, active/eliminated participants, and final winner when applicable. Opponent cards remain hidden unless the view explicitly reveals them.
4. Enable only actions listed in `legal_actions`; expose Fold, Check/Call, minimum Bet/Raise, a Pot raise target, All-in, and free-entry amounts as applicable. The Pot raise control sends the displayed pot amount through the ordinary wager-validation path and is disabled unless that target is a legal raise the hero can cover.
5. On a button press, create `PlayerAction`, submit it, and render the next result.
6. Keep `Quit` available at all times; confirm in the GUI and then call `request_quit()`.

The startup panel and table are views in one scalable `Control`-based main scene with `canvas_items` stretch mode and `expand` aspect. Layouts use containers, anchors, and responsive margins rather than fixed pixel positioning. Stretch mode scales the 2D layout but does not by itself guarantee crisp text or textures; those depend on viewport configuration and source assets. Starting a new tournament returns to the startup panel so new values can be chosen.

The table view uses a green felt surface. Its layout has explicit, visually distinct zones for community cards, the current pot, and player wagers; player-seat panels are arranged around that surface. The layout is presentation-only: it reads board, pot, contribution, position, and action data from `GameView` and must not calculate poker state itself. The GUI maps the recipient's seat to the bottom visual position for readability while retaining each core seat ID and rendering its actual dealer and blind markers. The acting player is identified by a white seat frame three times thicker than an ordinary frame, without a redundant textual `ACT` marker. The recipient's stack/status and private hole cards appear in that bottom seat panel; individual cards are rendered as card faces. This visual remapping is local to `PokerTableController` and must not mutate `GameView`, `Table`, player ordering, or poker position semantics.

`GuiActionTimingConfig` at `resources/gui_action_timing_config.tres` controls nonblocking GUI pacing. Its default action pause is two seconds; `pause_seconds_by_seat` can override the duration for each bot seat (or the human seat) independently. The same pause is used after each community-card reveal, while `showdown_pause_seconds` defaults to five seconds before a new hand begins. `GuiActionPacer` uses a scene-tree timer, then asks `TournamentMatch` for exactly one further automatic action. The core exposes that boundary but owns every deal, betting, settlement, and tournament transition; it contains no GUI timer dependency.

The default game viewport is 1920 by 1080, while the `Control` layout must reflow without overlap at supported desktop and mobile aspect ratios. The human recipient is visually anchored at the bottom; this is a presentation mapping only and must not alter core seat identities or poker positions. Desktop seat panels use equal wide dimensions across 2–9 seats, with mirrored left/right placement where applicable; compact layouts may change dimensions but retain readable names, stacks, markers, and cards. Tall mobile portrait surfaces are detected from their aspect ratio, not just logical canvas width, then scale seats, cards, table zones, event history, and action controls from the available surface so a high-DPI Web canvas does not retain desktop-sized controls inside unused felt.

`resources/gui_theme.tres` uses Godot's built-in plain non-serif UI font for both the startup screen and the table. Startup labels, numeric inputs, validation feedback, and the on-canvas keypad inherit that face, as do table labels and controls; presentation code must not introduce a serif face. Desktop table typography and line-art are configured at their source sizes rather than post-render scaled.

The shared theme may adapt font sizes to the viewport, but all player-facing text remains at least 20 px. Compact layouts reflow or simplify content instead of shrinking text below that threshold. Mobile controls provide at least 48 × 48 px touch targets, with approximately 160 × 50 px targets for horizontal text buttons where space allows.

Each seat panel displays one distinct avatar sourced at 32 by 32 pixels and enlarged for readable presentation (currently 56 pixels for opponents and 64 pixels for the human). At GUI tournament creation, a GUI-owned avatar assignment service selects distinct avatar asset IDs without replacement and retains its `seat -> avatar ID` mapping until that tournament ends. It uses a presentation-local RNG stream (injectable and seedable in adapter tests), never the core tournament RNG streams. The mapping is not stored in `Player`, `GameView`, match configuration, domain events, or any core rule module. If the configured avatar catalog cannot provide one unique avatar per seat, GUI startup must fail clearly rather than reuse an avatar silently.

GUI display names follow the same presentation boundary through a separate
assignment service. The stored catalog contains exactly 50 unique first names
with broad international representation. Every name contains only Unicode
letters and at most eight Unicode code points; length is measured in code
points, not bytes or grapheme clusters. Bot names are assigned without
replacement and remain stable for one tournament. The human is rendered
exactly as `Human`; interactive CLI names and its `(you)` suffix remain
unchanged. Name selection uses the presentation-only `gui_names` RNG stream,
while avatars use `gui_avatars`. These streams are derived by stable names,
not creation order, so name consumption cannot perturb avatar assignment,
deck order, button choice, bot decisions, or simulation randomness. Neither
mapping is written to `Player`, `GameView`, match configuration, events, or
simulation artifacts.

`GuiMatchFactory` resolves the core RNG streams once, then derives a separate
presentation stream collection from that same effective seed. Only the core
collection enters `TournamentMatch`; the factory returns the match and
defensive copies of both visual mappings in `GuiMatchCreationResult`.
`GuiStartupConfigAdapter` retains those mappings for the tournament, and
`PokerTableController` reuses them for every recipient-safe rerender and layout
pass. This also gives an unseeded GUI tournament one shared nonzero effective
seed without placing `gui_names` or `gui_avatars` state in the core.

Live seat panels show stacks directly below player names, position badges, and two visible card backs for opponents until cards are legitimately revealed. The current public action appears on its own line below the seat. Folded or outbid seats remain visible in grayscale and hide their cards. The centered board/pot/wager zone is visually separate from seats. Human action controls are framed, explicit two-row controls beside the human seat; the ordered event feed is a high-contrast scrollable viewport on the other side. Showdown summaries are rendered above the corresponding revealed seat from the recipient-safe result, never from hidden core state.

### CLI adapter

1. Start through `godot --headless --path . --script res://scripts/cli/cli_app.gd`.
2. Display the defaults and offer an immediate start that supplies no overrides. If configuration is requested, allow participant count, starting stack, small blind, and big blind to be overridden independently; an empty field supplies no override.
3. Merge overrides onto a fresh default configuration. Report invalid explicit input and repeat setup until the complete configuration is valid. After validation succeeds, print its summary and require no further setup input.
4. Follow the common match API and render snapshots as text. In every player list, append the literal suffix `(you)` immediately after the display name of the one `PlayerView` whose human flag is true; never apply it to a bot. Format every visible card as `[Rank][Suit]` using the canonical Unicode suit glyphs, and format card collections as `[ Card1 | Card2 | CardN ]`, exactly as specified in `docs/POKERCARDS_IN_CLI.md`. Never render stable IDs, enum ordinals, or numeric rank/suit pairs to the player.
5. During play, read stdin only when the result is `WAITING_FOR_HUMAN`.
6. Parse `fold`, `check`, `call`, `bet <amount>`, `raise <amount>`, and `allin` into `PlayerAction`; report parsing or action errors and prompt again without crashing.
7. Map `quit` and `exit` directly to `request_quit()`.

`cli_app.gd` is the composition/process-exit entry point. `TerminalIO` is the only class that reads stdin or writes stdout, behind an injectable `CliIO` boundary used by `StartupConfigPrompt` and `CliCommandLoop`. `CommandParser` converts normalized terminal text to typed shell commands; poker-action parsing is added only when the corresponding core actions exist. Terminal input reads bytes through `OS.read_buffer_from_stdin()` so an intentional blank line remains distinguishable from EOF; EOF terminates cleanly rather than causing an input-retry loop. Blocking reads are permitted only in this headless adapter, never in `scripts/core/` or the GUI.

CLI card formatting belongs in a small presentation helper used by the renderer. It accepts `CardData` snapshots and produces UTF-8 text only; it must not mutate cards or influence comparisons, dealing, evaluation, or visibility. Collection formatting joins dynamically rendered cards with ` | ` and wraps them with `[ ` and ` ]`. It must not assume a fixed card width because rank `10` occupies one more character position than the other ranks.

CLI player labeling is also presentation-only. `PlayerView` carries the authoritative human flag already required by the recipient-safe view contract, and `CliRenderer` uses that flag to append `(you)` to the human display name. The renderer must not infer human identity from seat 0, `hero_seat`, the acting seat, a name string, or the presence of hole cards. This keeps the label correct if composition or recipient choices change later, while leaving player identity and poker rules independent of terminal wording.

The simulation CLI is a separate, non-interactive process adapter implemented at
`scripts/simulation/simulation_cli_app.gd`. It consumes a versioned batch
manifest and produces reproducible report artifacts; it never invokes the
interactive CLI's prompts or command loop. Its simulation-only composition
root may create an all-bot match, while normal GUI and CLI construction retain
the exactly-one-human invariant. Command-line parsing, artifact I/O, progress,
and report formatting remain outside `scripts/core/`; core continues to own
rules, seeded randomness, game progression, and recipient-safe views. The full
contract is in
[`Simulation_And_Evolutionary_Bot_Strategy.md`](Simulation_And_Evolutionary_Bot_Strategy.md).
Ordinary reports and traces never contain unrevealed opponent hole cards.
The adapter writes the complete `run` report only to `--output`; stdout is
reserved for one canonical validation/plan document, a compact completion
summary, an inspection summary, or a replay comparison according to the
selected command and format. Progress and diagnostics go to stderr.

Profile evolution is owned by a separate non-interactive external tool, not a
fourth game composition root. It operates only on immutable `BotProfile`
parameter vectors and versioned artifacts. Its contract covers generation
initialization, fitness evaluation, selection, crossover, bounded integer
mutation, lineage inspection, independent confirmation, and candidate export. It never generates or
rewrites GDScript model code, edits published profiles in place, or promotes a
candidate automatically. Promotion into the shared playable roster is a
reviewed source change.

The repository entry point is `tools/profile-evolution`, backed by the Python
3 standard-library package `tools/profile_evolution`; it is outside both the
Godot runtime and the simulation CLI. Its strict `argparse` interface exposes
`init-generation`, `evaluate-fitness`, `select`, `crossover`, `mutate`,
`build-lineage`, `inspect-lineage`, `confirm-candidate`, and
`prepare-promotion-review`, `finalize-promotion-review`, `publish-profile`,
and `export-candidates`. The older single-candidate `review-promotion` command
remains only for artifact compatibility; new workflows must use one
consolidated review. JSON
inputs must be UTF-8 objects without duplicate keys or non-finite numbers.
Every persisted artifact has an exact envelope of `schema_version`, `type`,
`tool_version`, object `payload`, and SHA-256 `checksum`.
Checksums cover sorted compact UTF-8 canonical JSON with one trailing newline
and omit the checksum member itself. Output publication rejects an existing
target and uses a flushed and synced temporary sibling followed by atomic
hard-link publication, cleanup, and parent-directory sync. This preserves the
no-clobber guarantee even when writers race.
The stable exit categories are success (`0`), invalid arguments or input
(`2`), I/O failure (`3`), and invariant/workflow-stage failure (`4`). The tool
never accepts roster, `.tres`, or source-code output destinations.

Candidate randomness uses the tool-owned SplitMix64 implementation with
rejection sampling for unbiased inclusive integer ranges; it never depends on
Python's `random` implementation. A `gene_bounds` artifact contains exactly
the four schema-2 strategy genes and inclusive integer minimum/maximum values
within `0..100`. A `generation_manifest` contains deterministic candidate IDs,
parentless snapshots, the bounds snapshot, generation seed, and initialization
records. `crossover` consumes a strict `selection` artifact, chooses two
distinct parents for each child, and records the source parent for every gene.
`mutate` consumes a generation or candidate batch plus a strict
`mutation_policy`; it records seed, gene, before value, requested integer
delta, bounded result, and whether clamping occurred for all four genes.
Generated collections, candidates, bounds, policies, selections, and creation
records reject missing and unknown fields. Candidate operations copy their
inputs and never change source profile snapshots. Stable input ordering, local
random-number consumption, content-derived IDs, and canonical artifact writes
make identical inputs and seeds byte-equivalent.

`evaluate-fitness` consumes one immutable generation manifest and a complete
set of schema-3 `SimulationReport` shards. It validates the simulation command
version, canonical manifest checksum, exact candidate snapshots, deterministic
plan identities, unique global tournament indexes, complete shard/plan
coverage, successful completion, finite metric inputs, bounded behavioral
rates, and every plan's minimum candidate sample threshold. Trace and card
data are not fitness inputs. Each candidate's six normalized per-tournament
components are recomputed from profile results rather than trusting stored
aggregates. Their arithmetic means and normal 95% confidence-interval
half-widths feed the documented weighted formula and capped mean uncertainty
penalty. The immutable `fitness` artifact records report and manifest
checksums, shard identities, regimes, plans, code revisions, component sample
counts, uncertainty, and explicit style checks. Candidates with insufficient
samples or invalid-action fallbacks are ineligible, have null fitness, and are
never assigned a rank. Input generation and report bytes are never modified.
Evaluator v1 requires `normal_95`; it rejects `bootstrap_95` rather than
silently calculating and labeling a different estimator. Simulation regimes
also enforce the product maximum of nine players.

`select` validates the complete fitness artifact and its envelope checksum,
then retains `ceil(population_size * elite_fraction)` candidates for an
inclusive fraction from `0.10` through `0.20`. Only eligible candidates with
finite numeric fitness may participate. Ordering is fitness descending with
candidate ID as the stable tie-breaker. Selection fails if rounding retains
fewer than two parents or if too few eligible candidates remain. The immutable
selection artifact embeds full candidate/result snapshots as historical
benchmarks, report evidence, bounds, source fitness checksum, and a
content-derived next-generation manifest identity. It remains directly
consumable by deterministic crossover and never mutates or ranks the source
fitness artifact.

The selection artifact's `next_generation_manifest` is authoritative for both
the generation number and ID. Crossover consumes that identity verbatim, and
mutation preserves it while publishing the final children as an evaluable
`generation_manifest`; intermediate crossover output remains a
`candidate_batch`. This prevents selection, crossover, mutation, evaluation,
and lineage from inventing different identities for one generation.

`build-lineage` accepts repeatable immutable history artifacts and rebuilds a
canonical `lineage_registry`; it never incrementally edits a registry. It
validates every envelope checksum, fitness-to-generation and
selection-to-fitness reference, candidate snapshot, parent edge, and
generation relationship. Missing parents and conflicting uses of one
candidate ID are rejected. Entries are ordered by candidate ID and contain
the profile snapshot, parent IDs, generation and bounds, complete creation
operation/seed/provenance, evaluation configuration and regime/plan IDs, code
revisions, report identities/checksums, metrics, samples, style evidence,
uncertainty, and champion selection history. `inspect-lineage` validates that
registry and emits a read-only JSON ancestry/evidence view; it writes no
artifact. Identical history artifacts produce byte-equivalent registries
regardless of input argument order.

`confirm-candidate` is the independent evidence gate between lineage and a
review export. It reuses the strict schema-2 evaluator separately for complete
mirrored and mixed-table report groups. Mirrored plans must be cyclic
heads-up matchups that cover every candidate seat against every declared
legacy profile and historical champion. Mixed plans must be cyclic tables of
at least three seats whose matchups contain the candidate plus both opponent
classes. All participants must have zero invalid-action fallbacks. Original,
mirrored, and mixed evidence use disjoint report and manifest checksums and
non-overlapping seed ranges; separate confirmation batches also have
non-overlapping seed ranges. The immutable confirmation records the exact
candidate/registry identity, per-mode metrics, samples, style evidence,
uncertainty, reports, and explicit eligibility reasons.

Confirmation also requires behavioral diversity before it can be eligible.
For every comparable declared legacy or historical-champion
`strategy_parameterized` profile, the tool records the L1 distance across the
four percentage genes. The nearest distance must be at least ten; the recorded
comparison is a deterministic personality-diversity proxy, while independent
simulation evidence remains the validity and performance proof. Every
confirmation is marked `review_required`. `prepare-promotion-review` writes one
editable plan listing all supplied candidates and their exact confirmation
checksums. The reviewer changes each candidate's single `decision` field from
`pending` to `approve` or `reject`, with optional display names and notes.
`finalize-promotion-review` requires a completed decision for every listed
candidate, verifies the plan against the complete supplied confirmation set,
and emits one immutable, reviewer-identified `promotion_review_batch`.
Approval cannot be finalized for ineligible evidence. These external records
deliberately have no dependency on, access to, or mutation path for
`PlayableBotRoster`.

`export-candidates` accepts a lineage registry, eligible confirmation
artifacts bound to that exact registry, and requested candidate IDs. It emits
only a versioned `candidate_bundle` marked `review_only`, including the exact
candidate, lineage, and confirmation snapshots. It cannot write roster or
`.tres` destinations and performs no promotion; Milestone 6 remains a reviewed
source-change workflow.

`publish-profile` is the one manual Resource-publication boundary. It accepts
the exact confirmation and the consolidated `promotion_review_batch`, selects
that candidate's approved decision, verifies the snapshot and checksum
binding, and writes a new versioned
`BotProfile` only at `resources/bot_profiles/published/<profile-id>.tres`.
Publication uses no-clobber atomic creation, so a published version cannot be
overwritten. It does not alter `PlayableBotRoster`; activation remains a
separate reviewed source change. The roster validates that its retained catalog
always includes the hand-authored Random, Tight Passive, and Loose Aggressive
profiles, preventing promotion from replacing the legacy personality set.

The executable Milestone 5 smoke history is preserved under
`examples/profile_evolution/milestone5`. It includes deterministic generation,
fitness, selection, crossover, mutation, and lineage artifacts plus real Godot
mirrored and mixed-table confirmation reports. Both smoke candidates were
correctly rejected after invalid-action fallbacks appeared in independent
evidence, so no review bundle or roster change was produced.

## 7. Commands, results, and events

Core mutations return typed results rather than printing or showing dialogs.

`StepResult` should include:

- status;
- optional action rejection;
- ordered domain events generated by the step;
- the current recipient-safe view when requested.

Useful domain events include:

- hand started;
- cards dealt;
- blinds posted;
- action applied or rejected;
- street changed;
- pot awarded;
- player eliminated;
- hand completed;
- tournament won;
- tournament quit.

Events support GUI animation, CLI narration, tests, and future replay diagnostics without making core logic depend on a renderer.

Events exposed to adapters must not contain unrevealed card values. Visible card data comes from the recipient-specific `GameView`; internal diagnostics that contain private cards must remain inside the core or test harness.

## 8. Configuration and construction

Use a typed configuration `Resource` as the source of defaults; its validated resolved snapshot is passed to the core:

- `player_count`: integer 2–9, default 6;
- `small_blind`: default 5;
- `big_blind`: default 10;
- `starting_stack`: default 1000, applied equally to every participant;
- `rng_seed`: 0 selects a time-based seed; every other value is deterministic and tests must use a nonzero value;
- `use_legacy_models`: false by default; permits the defined legacy-model
  share in product roster selection;
- `seat_agents`: complete seat-to-agent-ID mapping with exactly one `HumanAgent` in every valid v1 match;
- `tournament_mode`: only `single_table` is valid in v1.

Configuration crosses the startup boundary through four explicit types:

- `TournamentConfig` is the mutable editor-facing default/template `Resource`; it is never passed to a running match.
- `StartupOverrides` stores each optional user value with a separate presence flag, so an omitted value differs from an explicitly invalid zero. It also carries the explicit legacy-model opt-in.
- `ConfigResolver` merges defaults and overrides, performs authoritative validation, and returns typed field/error codes in `ConfigResolution`.
- `ResolvedTournamentConfig` is a defensive runtime snapshot with read-only public properties and copied collections. `TournamentMatch` will accept only this resolved type.

Changing the template, overrides, or a returned collection after resolution cannot alter the snapshot. This includes `use_legacy_models`, which is disabled by default and does not change poker rules. Model/profile ID lookup remains the responsibility of `AgentFactory` and `PlayableBotRoster` during product composition.

Before every tournament starts, both adapters may collect independent overrides for `player_count`, `starting_stack`, `small_blind`, and `big_blind`. No override is required. Each omitted field retains its value from `default_tournament_config.tres`, allowing a match to start with no supplied values or with only some fields overridden. Explicit values must be integers; participant count must be 2–9, starting stack and both blinds must be positive, and small blind must not exceed big blind. The adapters may perform the same checks for immediate feedback, but core validation of the fully resolved configuration remains authoritative.

The resolved values are copied into a fresh configuration before `TournamentMatch` is constructed and cannot change after `start()`. The resolved blind values are the starting blinds for level 1; `TournamentMatch` owns subsequent hand-based blind progression. The composition root builds the complete `seat_agents` map from `player_count`: seat 0 is the human and seats 1 through `player_count - 1` are bots. The default six-seat setup selects five strategic profiles; the optional legacy setting applies the documented family split without changing poker rules.

Validate configuration before any chips or cards are created. Invalid configuration returns a descriptive startup error.

An agent ID resolves in the composition layer to a concrete agent preset. `AgentFactory` creates the corresponding `HumanAgent` or concrete `BotAgent` subclass. For bots, that preset selects a `BotProfile`; the factory asks `DecisionModelRegistry` for a new model instance, validates the profile's parameter type and ranges, and injects the seat's RNG stream. This preserves the required `seat_agents: seat -> agent-id` contract while allowing model and behavior parameters to vary by preset. Core rule modules know neither concrete bot class names nor model IDs.

After resolving a time-based root seed when `rng_seed == 0`, derive separate RNG streams from the root seed for:

- deck shuffling;
- initial button selection;
- each randomized bot.

`RngStreamFactory` derives each stream from the effective seed plus a stable identity (`deck`, `initial_button`, or `bot:<seat>`), never from stream creation order. `RngStreams` retains the effective seed for diagnostics and owns the separate `RandomNumberGenerator` instances. Consuming one stream therefore cannot change future card order, button selection, or another bot's behavior. Tests compare reproducibility and independence rather than hard-coded random values because Godot's underlying RNG algorithm is not part of this project's contract.

Match startup fails with a descriptive configuration error for out-of-range startup choices, unknown model/profile IDs, mismatched parameter types, invalid ranges, missing seats, or duplicate seat assignments.

## 9. Recommended libraries and tools

Third-party code should solve a concrete project problem, support Godot 4.7 and GDScript, work headlessly where relevant, use a compatible license, and remain outside the domain model. Pin exact versions in source control and recheck compatibility before changing the Godot minor version.

The review below reflects the ecosystem as of 2026-10-15.

| Library or tool | Decision | Intended use |
| --- | --- | --- |
| [GUT 9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1) | Adopt | Unit and integration tests for GDScript. This release targets Godot 4.7, is MIT-licensed, and includes assertions, parameterized tests, doubles, a command-line runner, and JUnit XML output. |
| [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit) | Adopt as development tooling | Use `gdlint` for static checks and `gdformat --check` for consistent formatting. It is a Python development dependency and must not be included in game exports. Pin a stable `4.x` release when adding the development environment. |
| [GdUnit4 6.2.x](https://github.com/godot-gdunit-labs/gdUnit4) | Alternative, do not install alongside GUT | Also supports Godot 4.7 and offers fluent assertions, mocks, scene testing, and editor integration. Reconsider only before tests are written if the team strongly prefers its API. Maintaining two test frameworks would add cost without useful coverage. |
| [Godot State Charts 0.22.5+](https://github.com/derkork/godot-statecharts/blob/main/CHANGES.md) | Defer; optional for GUI flow only | It supports Godot 4.7 and can simplify declarative, editor-visible UI flows. Do not use it for `TournamentMatch`, `HandController`, or `BettingRound`: its Node-and-signal model would couple deterministic rules to the scene tree and make direct headless tests less clear. |
| Dependency-injection addons | Do not adopt for v1 | Constructor injection and the three composition roots are sufficient. An autoload or service-locator dependency would hide ownership and introduce global state. |
| General card-game frameworks | Do not adopt for v1 | Most target draggable hands, deck builders, or collectible-card rule scripting. Pokahdot needs a fixed 52-card deck, private two-card hands, and poker-specific betting; adapting a broad framework would be more work than the small `CardData`, `Deck`, and GUI views defined here. |

### 9.1 GUT integration

Vendor the pinned GUT addon under `addons/gut/` and retain its bundled license. GUT is a development dependency: exclude `addons/gut/` and `tests/` from release exports.

Configure `.gutconfig.json` to discover both `res://tests/unit/` and `res://tests/integration/`, include subdirectories, and exit after a run. The standard headless entry point is:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

Use GUT parameterized tests for evaluator categories, tie-break vectors, legal-action matrices, and contribution combinations. Use simple hand-written fakes for `Agent` and deck order by default; use GUT doubles only when a fake would duplicate substantial behavior. This keeps rule tests readable and avoids mocking internal implementation details.

The [GUT command-line runner](https://github.com/bitwes/Gut/blob/main/documentation/docs/Command-Line.md) returns a failing process status for failed tests and can emit JUnit XML when CI is introduced.

### 9.2 Built-in Godot facilities to prefer

Use engine facilities before adding another dependency:

- `Resource` and `.tres` for validated editor-facing configuration and static card metadata;
- `RefCounted` for core services and runtime values that do not belong in the scene tree;
- `RandomNumberGenerator` for injected deterministic streams;
- typed signals in GUI adapters for view events, while core orchestration continues to return typed results and domain events;
- `FileAccess` and `JSON` only if replay persistence is added later.

No external poker evaluator, event bus, logging framework, or command parser is recommended for v1. These areas are either part of the product's correctness boundary or small enough that a dependency would not reduce total effort.

## 10. Error handling and logging

- Expected user mistakes return typed validation errors.
- Broken invariants use assertions in development and return a terminal error where recovery is unsafe.
- Core code does not print. It emits results and events.
- GUI and CLI adapters decide how to display errors and warnings.
- Invalid bot output produces a warning event, then falls back to `fold`, or `check`/`call` when folding is unavailable according to the project rules.
- Every state mutation validates chip counts, active seat references, and card uniqueness in debug builds.

## 11. State invariants

The core maintains these invariants:

- Every card ID appears at most once across deck, board, and hole cards.
- Player stacks, bets, contributions, and pots are non-negative integers.
- During a non-aborted hand, total player stacks plus `PotManager`'s contribution ledger (the pot) equals the tournament's initial chip total.
- After normal settlement, the pot is empty and all chips are in player stacks.
- A busted player has stack 0 and is never dealt into a later hand.
- The configured player count and `starting_stack` equal the validated, default-resolved startup values and remain immutable; the blind-level state starts with the validated startup blinds and changes only at the hand-completion boundary; each live stack starts at `starting_stack` and then changes only through poker actions and pot awards.
- Exactly one seat acts at a time, or no seat acts while transitioning or finished.
- A view never contains unrevealed opponent hole cards.
- A finished tournament has exactly one end reason.
- `end_reason = winner` has one winner; `end_reason = player_quit` has no winner.

## 12. Directory structure

```text
.gutconfig.json
addons/
  gut/                    # pinned GUT development dependency
docs/
  ARCHITECTURE.md
  CliTasks.md
  CoreTasks.md
  GuiTasks.md
  POKERCARDS_IN_CLI.md
  ProjectDescription.md
  README.md
  SimCliTasks.md
  SimCoreTasks.md
  Simulation_And_Evolutionary_Bot_Strategy.md
  WEB_SETUP.md
  gui_scaling_best_practice.md
  arkiv/                  # superseded completed-history documents
scripts/
  core/
    config/
      tournament_config.gd
      startup_overrides.gd
      config_error.gd
      config_resolution.gd
      config_resolver.gd
      resolved_tournament_config.gd
    card_data.gd
    deck.gd
    chip_stack.gd
    player.gd
    player_action.gd
    table.gd
    betting_round.gd
    pot_manager.gd
    hand_evaluator.gd
    game_view.gd
    public_game_event.gd
    rng_stream_factory.gd
    rng_streams.gd
    hand_controller.gd
    match.gd
    agents/
      agent.gd
      human_agent.gd
      bot_agent.gd
      bot_profile.gd
      decision_model.gd
      decision_model_parameters.gd
      decision_model_registry.gd
      agent_factory.gd
      random_agent.gd
      tight_passive_agent.gd
      loose_aggressive_agent.gd
      decision_models/
        random_model.gd
        tight_passive_model.gd
        loose_aggressive_model.gd
        random_parameters.gd
        tight_passive_parameters.gd
        loose_aggressive_parameters.gd
  gui/
    startup_config_controller.gd
    table_controller.gd
  cli/
    cli_app.gd
    cli_card_formatter.gd
    cli_command.gd
    cli_command_loop.gd
    cli_input_line.gd
    cli_io.gd
    command_parser.gd
    startup_config_prompt.gd
    startup_prompt_result.gd
    terminal_io.gd
    cli_renderer.gd
  simulation/             # proposed non-interactive all-bot adapter
    simulation_cli_app.gd
    # manifest/report parsing, batch planning, and artifact I/O
resources/
  default_tournament_config.tres
  bot_profiles/
    random_default.tres
    tight_passive_default.tres
    loose_aggressive_default.tres
scenes/
  table.tscn
tests/
  unit/
  integration/
  support/
```

Additional small value/result classes may be added under `scripts/core/` when they remove ambiguous dictionaries. Avoid generic `utils.gd` modules; place behavior with the owning concept.

## 13. Testing architecture

Tests extend GUT's `GutTest`, run headless, and instantiate core classes directly. Tests must not require the main game scene unless they specifically verify a GUI adapter.

### 13.1 Unit tests

- deck reset plus shuffle produces exactly 52 unique cards, with deterministic order for a fixed seed;
- chip stack bounds;
- startup configuration defaults, complete omission, partial overrides, valid boundaries, invalid explicit values, and immutability after match start;
- hand category and tie-break comparisons, including that the five-high wheel beats king-high and loses to a six-high straight;
- betting legality and the fixed big-blind minimum raise increment, including the first preflop raise and subsequent raises after a larger full raise;
- short all-in raises do not reopen raising for a player who already called and matched the previous full raise;
- side-pot construction, eligibility, split pots, and odd chips, including A all-in for 40 versus B and C for 100, where A is eligible for only the 120-chip main pot;
- seat traversal and heads-up order;
- per-recipient hidden-card filtering before showdown;
- decision-model registration and profile parameter validation;
- deterministic decisions for a fixed view, profile, and RNG seed;
- model output limited to the legal actions present in `GameView`.
- CLI player-row formatting marks exactly the human `PlayerView` as `(you)`, leaves every bot unmarked, and remains correct across repeated snapshots and non-default table sizes.
- CLI card formatting for every rank and suit, including `10`, all four canonical Unicode suit glyphs, collection delimiters and brackets, and the absence of internal card codes in rendered output.
- GUI name-catalog validation for exactly 50 unique first names made only of
  Unicode letters and no longer than eight Unicode code points; deterministic
  `gui_names` assignment without replacement and independence from the
  `gui_avatars` and core RNG streams.
- GUI seat rendering uses assigned bot names and the exact human label at 2-,
  6-, and 9-seat tables; mappings remain stable across refresh and layout
  changes, and longest permitted names fit desktop and compact layouts without
  reducing player-facing text below 20 px.

### 13.2 Integration tests

- scripted complete hands with deterministic cards and actions;
- CLI and GUI startup adapters map omitted, partially overridden, and fully overridden input to equivalent resolved core configurations and keep invalid explicit input from constructing a match;
- CLI snapshots render hero cards, community cards, and legitimately revealed showdown cards in the format defined by `docs/POKERCARDS_IN_CLI.md`, while unrevealed opponent cards remain absent;
- CLI snapshots identify the human consistently as `(you)` before and after actions, across hands, and in final player summaries without marking any bot;
- non-default startup selections produce the selected participant count, equal initial stacks, and the selected starting blind postings through both adapter-independent drivers;
- player elimination followed by a hand whose deal, button, and blinds skip the busted seat;
- full tournament ending with the only chip-owning seat as winner;
- two bots using the same model with different profiles and independent RNG streams;
- different models running at different seats without changes to hand or betting orchestration;
- human quit before a hand, during a hand, and between hands, always producing `player_quit` with no winner or payout;
- identical outcomes for a fixed seed and scripted actions through GUI-independent and CLI-independent drivers;
- simulation-only all-bot construction while GUI and interactive CLI continue
  to reject zero-human configuration;
- simulation reports and all trace modes exclude unrevealed opponent cards;
- chip conservation after every completed hand.

Use test doubles for agents and a scripted deck seam in integration tests. Production code still uses the normal `Deck`; the seam exists at construction, not as test branches inside rule logic.

## 14. Extension points

The design intentionally allows later, post-v1 additions without changing poker rules:

- new agents through `AgentFactory`;
- new bot decision models through `DecisionModelRegistry`;
- new parameterized behaviors through typed `DecisionModelParameters` and reusable `BotProfile` Resources;
- alternate blind schedules owned by tournament orchestration (v1 uses the defined hand-based schedule);
- replay or audit logs from domain events;
- alternate presentation adapters;
- network input as another human-agent adapter (networking remains excluded from v1);
- additional tournament formats above `HandController`.

Cash-game accounting, networking, persistence, payouts, antes, and rebuys are outside v1 and must not complicate the first implementation.

## 15. Known trade-offs

- A step-based controller is more explicit than a coroutine-heavy implementation, but it is easier to test and works consistently in GUI and headless modes.
- Snapshot duplication allocates more data, but creates a strong privacy and mutation boundary. This cost is negligible for at most nine seats.
- Domain events add a small amount of structure, but prevent presentation concerns from leaking into the rules engine and provide useful test evidence.
- Hand-based blind levels keep progression deterministic while adapting the interval to the active table size at each level boundary.
- GUT and GDScript Toolkit reduce test and style boilerplate but add pinned development dependencies. Neither is part of the exported game or allowed to become a dependency of `scripts/core/`.
- The model/profile split adds a few small types, but avoids a growing hierarchy of nearly identical bot agents and makes behavior tunable without modifying model code.
