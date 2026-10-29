# Pokahdot Architecture

Status: Core, CLI, simulation, evolution, and responsive GUI implementations
are present. Automated layout coverage and historical manual acceptance have
separate scopes. Physical-phone acceptance limitations remain recorded in the
archived
[OptimizingPhoneGuiTasks.md](arkiv/OptimizingPhoneGuiTasks.md); phone landscape is
deferred. The [visual evidence contract](GUI_VISUAL_TESTING.md) owns acceptance
terminology and current profile coverage.
Last updated: 2026-10-26
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

Interactive CLI composition returns a `CliMatchCreationResult` containing the
constructed match, human seat, and startup diagnostics captured from the same
bot-profile selection pass. The `Seat agents:` report can therefore show each
bot's profile display name without reselecting profiles or changing the core's
stable in-hand `Player N` labels.

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
that hand in its safe `GameView`; `BotAgent` captures legal-action alternatives
and strategy traces only when simulation diagnostics are enabled. Product
agents retain no decision history or trace snapshots. The runner drains each
bot after every bounded advancement, so pending memory depends on that budget
rather than tournament length. Capture copies actions, legal alternatives and
traces; draining transfers ownership. A rejected request and its synchronous
fallback consume one snapshot, measuring the applied action without counting
a rejected bluff as executed. Each operation uses one event/profile snapshot.
The adapter
can therefore calculate survival, blind-normalized chip change, per-hand
VPIP/PFR, all-street bet/raise and call counts, action-opportunity rates,
call-versus-raise splits, eligible bluff frequency, and invalid-action
fallbacks without retaining cards or mutable core state. Measurement consumes
every applied decision independently of optional bounded trace sampling.
The collector also records each completed hand's newly zero-stack seats as an
elimination cohort. Final positions are assigned from those cohorts in reverse
chronological order; seats eliminated in the same hand share a competition
rank. `simulation_cli_v5` separates this evidence from older seat-ordered
reports, which remain immutable and require recomputation for promotion use.

`SimulationTraceConfig` restricts tracing to none, errors, or a bounded
deterministically sampled mode. `SimulationTraceEntry` contains strategy
branch/action metadata and hand outcomes only; it deliberately contains no
hole cards or deck data. Sampled mode uses deterministic reservoir sampling
over the total number of eligible entries, so early and late events have the
same retention probability. Execution failures retain already-collected safe
traces and the input's plan, regime, matchup-occurrence, and rotation identity
alongside their structured diagnostic. `SimulationAggregateCalculator` is the
collection adapter for `SimulationAggregateAccumulator`, which consumes one
tournament at a time. Per-group running totals and Welford moments retain no
outcomes or observation arrays. Both paths group completed outcomes by
profile, matchup, seat, regime, and evaluation plan using a completed
tournament and its effective seed as the independent statistical unit. Repeated profile seats and table-level groups are averaged
within a tournament before uncertainty is estimated, preventing correlated
seats from inflating sample counts. Behavioral rates divide summed raw
numerators by summed opportunity denominators for point estimates, while
their uncertainty uses per-tournament rates; tournaments with no opportunity
do not become artificial zero observations. Fewer than two units produce an
explicitly missing interval, and bounded components use a Wilson floor for
boundary samples. Aggregates also report summed counts, sample-threshold
eligibility, point fitness, and a separate finite-sample penalty. Public
all-ins are classified as calls, opening
bets, or raises from their target total relative to the street's prior wager.
`SimulationBatchResult` receives the manifest's per-plan minimums and applies
the strictest contributing plan minimum to each aggregate row; it has no
independent 30-sample default. Schema-2 plans accept only `normal_95`, matching
the Python evaluator; `bootstrap_95` is rejected at manifest validation.

`RngStreamFactory` derives every random stream from the effective tournament
seed and a stable name. In addition to deck, initial-button, and per-seat bot
streams, simulations receive `tournament_construction`,
`seat_profile_assignment`, and `trace_sampling` streams. `RngStreams` records
the algorithm version and derived seed for every name;
`SimulationMatchCreationResult` preserves that identity with the effective
seed and copied stream-seed map. New simulation runs use domain-separated SHA-256
derivation (`named_stream_sha256_v2`) over the exact signed seed and stream
name. Simulation replay selects the algorithm recorded by the source report.
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
silent defaults. `SimulationPlanCursor` owns a private manifest snapshot and
iterates only assigned global indexes, stepping by shard count. Direct
`SimulationManifest.input_at()` lookup resolves a plan-local index, matchup
occurrence, cyclic rotation and `seed_start + index` arithmetically; it never
constructs preceding inputs. `build_plan()` remains a compatibility collection
API that materializes only the assigned shard. CLI execution uses the cursor;
replay uses direct lookup. `SimulationCommandOptions` is the typed boundary
for strict CLI arguments.

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

`SimulationReport` schema 4 stores the canonical manifest snapshot and checksum beside
typed outcome mappings, aggregate groups, diagnostics, and recipient-safe
traces. Report writes use a temporary sibling followed by an atomic rename.
Command v6 also records executable provenance: Git revision, a SHA-256
fingerprint of dirty execution-relevant sources, engine version, and explicit
algorithm versions. Runs fail if provenance cannot be captured; fitness rejects
mixed-provenance shards, and replay explains every differing provenance field.
Older reports remain immutable historical artifacts rather than being backfilled.
It also records a deterministic roster provenance object derived from the
manifest's immutable profile snapshots, and every tournament records its
ordered selected profile IDs beside its seat map. This lets candidate
evaluations reproduce their profile collection without claiming they used the
product-curated roster. Normal GUI/interactive-CLI composition uses the
source-controlled `PlayableBotRoster.ROSTER_VERSION`; interactive diagnostics
record that version and the selected bot profile IDs.

Decision (2026-10-27): CLI runs checkpoint every completed tournament through
`SimulationCheckpointStore`, using an explicit directory or the default
`<output>.checkpoint`. The header binds the manifest checksum, complete
executable provenance, shard and trace settings. Explicit resume validates
these values and each immutable per-index record before reuse. Canonical
serialized tournament and trace strings preserve numeric spellings; temporary
siblings do not count as completed evidence. The streaming aggregate collector
rebuilds its bounded state in global-index order, giving resumed runs the same
metric accumulation order and tournament digests as uninterrupted runs.
`SimulationStreamReportWriter` streams the existing schema-4 report from those
records through a temporary sibling and atomic rename, then hashes the file in
fixed-size chunks. Checkpoint storage grows with evidence; execution memory
depends on the manifest, declared aggregate groups and one tournament, rather
than the planned count. The explicit collection APIs and report consumers may
still load complete collections when requested.

`SimulationReport.validate` is the common Godot boundary for direct consumers,
inspection and replay. Focused manifest, tournament and metric contracts check
untrusted field shapes before conversion, map reported indexes without
materializing the entire plan, and verify completed outcomes from their
primitive counters and terminal stacks. Default validation requires full
completed-shard coverage; checkpoint validation explicitly allows one partial
record while retaining its structural, plan and metric checks. Partial failure
diagnostics remain inspectable. Shared JSON conformance cases exercise the Godot boundary and
Python fitness, selection and confirmation consumers.

Decision (2026-10-26): simulation JSON uses the lossless seed range specified
in [the simulation contract](Simulation_And_Evolutionary_Bot_Strategy.md#21-batch-architecture-and-sharding),
while typed core RNG seeds retain their signed 64-bit domain. Report and CLI
serialization preserve full precision for parsed numeric values; historical
tournament-digest serialization is unchanged. Existing report bytes are never
rewritten to satisfy a newer validation policy.

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
Both run formats write throttled progress (completed/assigned, monotonic elapsed
time and throughput) to stderr; stdout carries only the result document or
text summary. Resume counts include reused records and timing covers the current
invocation. Replay honors the requested bounded trace policy through the same
runner and isolated trace RNG, recording policy/traces in its optional artifact.
Trace detail does not change outcome digests or provenance checks.

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
| Keep GUI action pacing in a Resource | Per-seat action pauses and the shared completed-hand pause for showdown or a pre-showdown winner are configurable without putting timers or presentation policy in poker rules. |
| Keep blind-level progression in the core | Hand-completion timing, active-player snapshots, and 125%-to-even rounding must be identical for GUI and CLI. |
| Enforce role-specific GUI text floors | Seat copy may scale to 18 logical/CSS px; card ranks and other GUI text retain 20 px, with 48×48 touch targets. |
| Use responsive Control layout guidance | `canvas_items` with `expand`, containers, anchors, and responsive margins govern layout adaptation; font and texture crispness is not assumed from stretch mode alone. |
| Give GUI geometry one owner | `GuiViewportAdapter` normalizes the real root Window to actual canvas CSS geometry on Web and client/current-window scale on native platforms. Startup, table and popups consume the same usable rectangle; fixture roots remain isolated. |
| Classify GUI layout from usable geometry with explicit supplemental overrides | Phone portrait, phone landscape, tablet, small-desktop, and desktop profiles derive from the canvas remaining after browser chrome and safe areas. Known device evidence may override ambiguous geometry; in particular, the observed 2388 x 1450 iPad fixture declares a tablet override instead of making every desktop window of that size a tablet. |
| Give manually positioned GUI regions one layout owner | The central board/pot/wager stack uses a plain `Control`; `PokerTableController` atomically assigns its centered bounds and its three child panel rectangles. A Godot `Container` must not compete with those explicit rectangles or resize the stack from late child minimum-size notifications. |
| Preserve mobile usability targets | Interactive controls provide at least 48 × 48 px touch targets, with approximately 160 × 50 px targets for horizontal text buttons where space allows. |
| Select numeric entry from the input source, not viewport geometry | A touch press opens the shared transactional in-canvas keypad on every layout profile; pointer focus leaves the native `LineEdit` available for physical-keyboard digits and editing keys, including on phone-sized windows. Project-level mouse-to-touch emulation stays disabled so a desktop Web click cannot be reclassified as a touch press. Done commits a touch draft and Cancel preserves the previously committed value. |
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

After a hand settles and zero-stack players are eliminated, `TournamentMatch` records the completed hand in the blind-level state. If the interval is reached, it calculates the next big blind as the smallest even integer greater than or equal to 125% of the current big blind and sets the small blind to exactly half of it. Growth uses checked arithmetic and saturates at 1,000,000 big blind (500,000 small blind); later levels still advance and reset their counters at that cap. The current hand keeps its posted blinds, so an increase is applied only when the next hand is initialized. The new level then captures the current active-player count and starts its completion counter at zero.

### 5.6 `player_action.gd`

`PlayerAction` contains an `PlayerAction.Kind` and amount.

```text
FOLD, CHECK, CALL: amount = 0
BET, RAISE: amount = target total bet_this_round after the action
```

For `BET` and `RAISE`, “total wager amount” means the player's target total contribution on the current street, not the number of additional chips to move. Using a target total avoids ambiguity after blinds or earlier contributions. `BettingRound` remains the authority for whether an action and amount are legal.

### 5.7 `betting_round.gd`

`BettingRound` owns one street's action state:

- acting seat;
- current bet;
- the minimum full-raise increment for this street, initialized to the table's
  big blind and updated after each full bet or raise;
- seats that still owe action;
- seats whose raise rights are open;
- legal action calculation;
- action application and next-seat selection;
- round completion.

A first preflop full raise must reach at least twice the big blind. Subsequent
full raises must reach at least `current_bet + minimum_full_raise_increment`.
An opening postflop bet must be at least one big blind and sets the increment
to its amount. Each full raise sets the increment to
`new_total - previous_current_bet`; each new street resets it. For example,
with a big blind of 10, a raise from 10 to 30 sets an increment of 20, making
the next minimum total 50. A short all-in raise below the applicable increment
updates the amount to call without changing that increment or reopening raise
rights for players who already acted and matched the previous full raise.
These rules must be represented directly in core state, not inferred from
action history in the UI.

Boundary initialization: `HandController` starts preflop with the nominal big
blind as the call total even when its posted contribution is short. A short
postflop opening all-in preserves the initial big-blind increment, so an
opening 5 / BB 10 permits a full raise to 15. Short increases never accumulate
to reopen closed rights; this includes a player who checked before a short
opening all-in. Only an individual full increase reopens rights.

The implementation tracks this increment directly and publishes saturated
minimum totals through `GameView`. If checked addition cannot represent a
full raise, ordinary Raise is unavailable; an All-in increase remains subject
to the short-increase and raise-rights rules. GUI, CLI and bots consume the
published limits without reconstructing increments from history. Regression
coverage and gate evidence are recorded in the
[archived minimum-raise backlog](arkiv/MinimumRaiseTasks.md).

Invalid actions return a typed rejection and leave all state unchanged. Bot
fallback selection happens in `HandController`, not inside `BettingRound`.
It is fold-first, then check, then call. The selected fallback is passed back
through normal validation; a rejected fallback returns an error and produces
no action-history, observer, contribution, or `ACTION_APPLIED` update.
`ACTION_REJECTED` retains the public requested action, validation code/message,
and the applied fallback kind and public street total when fallback succeeds.

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

Signature sketch (not a standalone script):

```text
func choose_action(view: GameView) -> PlayerAction
```

Bot agents return synchronously in v1. They may depend on `GameView` and `PlayerAction`, but not on mutable `Table`, `Player`, `Deck`, or `PotManager` objects.

`HumanAgent` does not read devices or stdin. It acts as an input mailbox with `submit_action()` and `has_pending_action()`. `HandController` returns `WAITING_FOR_HUMAN` while the mailbox is empty, thereby blocking hand progression without blocking Godot's main thread, and calls the common `choose_action()` contract only when an action is queued. The queued action is still validated by `BettingRound`; parsing it successfully does not make it legal.

### 5.12 Bot decision models and profiles

`BotAgent` implements the stable `Agent` contract and delegates the actual choice to one injected `DecisionModel`. This separates orchestration and safety behavior from poker strategy.

Signature sketch (not a standalone script):

```text
class_name DecisionModel

func configure(
    parameters: DecisionModelParameters,
    rng: RandomNumberGenerator,
) -> PackedStringArray

func choose_action(view: GameView) -> PlayerAction

func observe(record: PublicActionRecord) -> void
```

`configure()` is called exactly once and returns an empty array on success or descriptive validation errors on failure. Profiles cannot be changed during a tournament; start a new tournament to use different parameters.

`observe()` has a default no-op implementation. It allows future adaptive models to maintain private, per-seat memory from public actions without exposing core objects or hidden cards. `BotAgent` forwards applied public action records in action order. Each seat receives its own model instance; mutable model state is never shared between seats.

`PublicActionRecord` is the current immutable observation value: seat, action
kind, public amount, and record kind (`ACTION`, `SMALL_BLIND`, `BIG_BLIND`).
`HandController` forwards applied actions through agent `observe()`; blind
records appear in view history. Models do not receive a general event stream
for public cards, pot awards, eliminations, or street transitions. A richer
observation interface remains a proposed extension, not an implemented API.

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

The human Pot shortcut uses the displayed pre-action pot as its addition. Its
typed result carries `contribution=P` and `wager_total=H+P` separately so GUI
and CLI adapters cannot present the internal total as the observed amount. For
pot `P` and existing recipient street wager `H`, its one-pot target total is
`T = H + P`, which adds `P` chips and leaves a pot of `2P`; a half-pot strategy
target uses `H + floor(P / 2)` when that distinct strategy policy is selected.
Calculations use only the recipient-safe `GameView` and are clamped or
rejected according to the caller's documented policy without bypassing
`BettingRound` validation. This product shortcut intentionally differs from
the conventional Pot Limit post-call formula `H + P + 2C`.

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
The position ordinal is zero-based in actual action order for the current
street: the button/small blind acts first heads-up preflop, the first live seat
after the original big blind acts first multiway preflop, and the first live
seat after the button acts first postflop. Folded and busted seats are excluded
from both that order and the active-opponent count; all-in seats remain live
contenders. Effective stack is the smaller of the hero's stack and the largest
live opponent stack (or zero with no opponent), and big blind is the table's
published big-blind value rather than a wager target.
It copies those inputs into `HandPotentialEstimate` and neither accepts nor
retains `Table`, `Player`, `Deck`, `GameView`, GUI, CLI, or mutable match
references. Its preflop 0--100 heuristic weights pair strength (45%), rank
strength (30%), suitedness (10%), connectivity (10%), and position (5%).
Postflop it reports a bounded score plus made-hand class, direct/backdoor draw
quality, draw outs, public board texture, board-only status, and improvement
potential. Once five public cards exist, draw quality, draw outs, and
improvement potential are all zero: a missed river draw has no future-card
value, while made-hand and board-texture diagnostics remain available. The
estimate is a deterministic heuristic, not equity; it must not be rendered in
normal player UI or used to reveal unshown cards.

There is no experimental game mode. `TournamentConfig` defaults
`use_legacy_models` to false, `StartupOverrides` may explicitly select it,
and `ResolvedTournamentConfig` freezes the resolved value. The CLI reads
`--use-legacy-models` only from Godot user arguments after `--`; the GUI
presents an unchecked “Use legacy heuristic models” checkbox and clears it
when returning to startup. The option changes only product-roster selection;
poker-rule modules see only the completed agents and never a strategy-family
branch.

Model output is still validated by `BettingRound`. Invalid output produces the
standard public rejection diagnostic and fold-first validated fallback in
`HandController`, regardless of model implementation. Failure of the fallback
is an explicit step error, never false action progress. Network-backed or
asynchronous models are outside v1; they may later add a pending decision
result without changing poker rules or profile formats.

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

### 5.14 `tournament_match.gd`

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

Signature sketch (not a standalone script):

```text
func start(max_transitions: int = 32) -> StepResult
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

`HandController` shares one small-step operation between bulk advancement and
`advance_one_action()`: a step applies one action, advances one completed
betting street, settles a hand, or returns a blocking/error status. Bulk calls
consume pending human mailbox actions; GUI single-step calls always wait at a
human turn, leaving submission explicit. Nonpositive budgets retain the
existing normalization to one step. Starting the next hand preserves the
caller's budget after setup rather than substituting the default 32 steps.

The core checks a latched quit request before every state transition. GUI driving must use a bounded transition budget and yield back to Godot's event loop between budgets so the always-available quit control remains responsive. The CLI loops through bot progress without requesting stdin and accepts `quit`/`exit` whenever it is reading a human command.

The completed implementation history proceeded through the interactive CLI first, then the GUI, simulation, profile-evolution, and release-readiness phases. [`ReleaseReadinessTasks.md`](arkiv/ReleaseReadinessTasks.md) records the completed ordered release-readiness work, while the archived layer backlogs retain their task evidence. Completed historical sequencing is preserved under [`arkiv/`](arkiv/).

### GUI adapter

Planned GUI replacement (2026-10-27):
[`RestructureGuiTasks.md`](RestructureGuiTasks.md) leads the future presentation
structure: one geometry adapter/classification policy, pure view models,
component scenes, themes and container-owned layout. A complete GUI rewrite
is permitted; existing GUI code is reusable only where it fits that design.
The descriptions below remain the implemented baseline. Product behavior,
privacy, input transactions and useful verification coverage must survive;
legacy node structure and exact geometry are not architectural constraints.
No full replacement cutover or device acceptance is claimed by this decision.

Retirement decision (2026-10-28): build the replacement directly; do not continue
extracting legacy builders or layout helpers. RG-13 may provide a small temporary
policy bridge, while replacement compositions consume the unified policy
directly. The [backlog retirement map](RestructureGuiTasks.md#transitional-size-and-retirement-plan--2026-10-28)
names the old scenes, factories, geometry/style helpers and reference-specific
snapshot producers to remove at RG-54 after independent replacement coverage.
Keep the detached semantic snapshot API and useful independent pure services;
do not retain wrappers solely to keep old trees alive. Delete associated `.uid`
files only after references are removed. Compare production lines, custom layout
ownership and runtime construction at cutover; more reusable authored scenes
alone do not imply more custom code.

Planned control components (user clarification, 2026-10-28): `ActionButton`
provides shared rounded dark-green/white-text presentation for every visible
action, including Quit and keypad keys. `InputField` provides sharp-cornered
white/dark-green-text presentation for number/text entry and value surfaces.
Theme states retain that distinction. RG-30/RG-39 implement these reusable
views; input transactions, numeric validation and game submission stay in
controllers/adapters. This future contract supersedes the reference's visually
similar button/field styling.

Branding decision (2026-10-29, RG-11R5): `BrandLogo.tscn` is a reusable,
passive `TextureRect` backed by `gui_logo_texture.tres`.
`assets/images/Pokahdot_logo.png` is the transparent cutout of the supplied JPEG,
created with built-in image editing. The Atlas crops meaningful alpha bounds
with padding. A shared Compatibility `canvas_item` shader renders source RGBA
on Start and derives a restrained directional relief from alpha for the felt;
it does not remove a checkerboard at runtime. The table material and anchors
keep branding behind game content without changing component minimums or input.

The Start-screen logo is directly above the form on the dark background, with
no light backing panel and no scrollbar. A `CenterContainer`/box/grid hierarchy
owns geometry. Measured header fit yields optional description/title copy and
logo height before reducing essential content; fields/actions retain 20 px
text and 48 px targets. Normal Container re-sorting applies new minima without
manual child positioning. An earlier scroll prototype was rejected and removed,
including its unneeded clipping-observation extension.

Total text now uses a slightly darker muted grey (`#B8C3BB`) than the action
labels, while retaining its sharp, shorter dark-green face and 48 px hit area.
The table snapshot producer registers the actual table surface as `surface`;
unknown descendant diagnostics remain observable without inheriting a changed
child index when a decorative background is inserted. The recorded failure
registry receives only the explicitly reviewed role-prefix migration.

Phone-portrait redesign selected by the user (RG-11R6): full-screen green with
no felt rim/perimeter margins, measured clean opponent-seat rows, and the
community-card/pot/wager group directly above the human/action area. Preserve
clockwise identities, complete reserved status footprints, at most two opponent
seats per portrait row, recipient privacy and the approved 18 px seat-copy / 20 px card/other
text floors. Desktop branding remains as accepted. This is a selected visual
increment; authored replacement components and device acceptance remain in
their owning later tasks. The latest portrait review requires an odd opponent
count to start with one centered seat, equal in width to seats in paired rows;
this also applies to short portrait screens. Other compositions retain the
general maximum of three seats per row.
The reviewed implementation uses measured name/stack/card rows and permanently
reserved two-line status bands, with an 18 px fallback limited to seat copy.
Short-screen fit reduces internal padding and row gaps; card text stays at
20 px and interactive targets at 48 px. Actions share one row only when their
complete measured labels fit. The user accepted the review7 portrait captures
on 2026-10-29; this is visual acceptance of the current increment, not completion
of the later replacement or physical-device checks.
For a long seven-way winner summary that exhausts short-screen height, the
last measured seat candidate places the two revealed cards vertically beside
name/stack/role copy. It retains their 46×30 size and readable ranks, both
reserved status lines, and every named winner. Horizontal candidates keep
priority and are evaluated against the actual community/hero allocation.

Total-field refinement (2026-10-29, latest user review): Total uses light-grey
text/caret/placeholder on dark green, overriding the earlier white Total-field
palette only. Generic `InputField`/`NumberField` retain their white/dark-text
contract. Keep zero-radius corners and vertically center the field with Raise;
the drawn face is slightly shorter than neighboring actions. RG-11R4 uses
`StyleBoxFlat` vertical expansion margins of -4 per edge: a 48-unit allocated
field draws a centered 40-unit face while retaining its 48-unit hit area,
container allocation and font. No competing child-position owner or wrapper is
needed. Future RG-30/RG-39 represent this as a `WagerTotalField` theme variation.
The table Quit control now participates in `GuiTableActionControls`' existing
action-button style application, using the same rounded border and all five
interaction-state styles as Raise. It remains a tournament control in the
table/controller, not part of numeric entry.
The compact keypad's accepted side-by-side composition is explicitly
landscape-only, in addition to measured width/height fit; portrait retains its
accepted stacked utilities. This is not a fixed screen-dimension constraint.

Keypad utility refinement (2026-10-29): digits and explicit wager limits are
user-approved; editing/preset/Cancel/Done controls form a uniform, filled
rectangle. Tournament exit is not a responsibility of number entry. Remove
the keypad's Quit button, exit signal and table wiring (RG-11R2); retain the
table/menu exit flow. Cancel restores the exact committed field without
submission, while Done commits the draft for adapter validation. The keypad remains modal until
closed; tournament exit is reached after cancelling/closing it. RG-39/45
preserve these boundaries in the authored presentation replacement.

Preview-review contract (2026-10-29): event-log body text uses a dedicated
18 logical/CSS px typography role; headings, fields and action controls retain
20 px. This is a log-only exception to general non-seat text floors. Preserve
top and bottom alignment of the docked log, human panel and action area. Seat
geometry must clear the rounded felt border, including upper corner seats;
rectangular surface containment alone is insufficient. Numeric keypads keep
the digit grid `1 2 3 / 4 5 6 / 7 8 9` with `0` centered directly below `8`
in all orientations. Utility controls compose separately; do not reflow digits
into five columns. RG-11R implements the selected preview corrections before
continuing; replacement components/containers inherit these requirements in
RG-30/31/39/44/45/50/51. Revised implementation evidence belongs in the backlog.

Seat-row cap (2026-10-29, user confirmed): all replacement layouts enforce at
most three player seats per horizontal row on every screen/orientation and
supported count, including the hero when sharing that row. Pure slot plans
also enforce the later, stricter two-opponent cap in phone portrait, with a
centered single top seat for odd opponent counts. They
record row membership and preserve clockwise seat IDs; cosmetic staggering
does not satisfy the limit. Existing small-desktop and nine-seat wide/tablet
reference paths contain four-seat rows. They remain a documented legacy gap,
not accepted replacement behavior; implement the cap in RG-12/42/50–52 rather
than adding further legacy geometry owners.

The user reaffirmed on 2026-10-29 that legacy layout must not limit the new GUI
on any screen. Replacement containers may change positions, compositions,
breakpoints and node structure freely to meet the visual and responsive-fit
contracts. Retain independent behavior, privacy and input checks; migrate
incidental coordinate/hierarchy tests. Reference defects are neither target
constraints nor a prerequisite repair project before replacement work.

Phone fit is the priority constraint (user clarification, 2026-10-29): retain
the 2–7-player phone target in both orientations and 2–9 on tablets/desktops.
Use seven-player phone and nine-player wide fixtures early when measuring
component minima and action flow. Fit must preserve text floors, 48×48 targets
and the three-seat row cap. An infeasible viewport shows guidance without
changing active participants; the design is not a scaled-down desktop layout.

Additional presentation decisions (user clarification, 2026-10-28): a seat's
layout footprint includes its drawn panel and a permanently reserved below-panel
action/showdown band. The outer component/container minimum includes both.
Winning hand/result copy is bold and bright yellow (`#FFFF00`), including
split/side-pot recipients; emphasis comes from public award data, never rules
inside a view. Seat copy may scale to 18 logical/CSS px; card ranks and other
GUI text retain 20 px (except the later-approved 18 px log body), with 48×48
touch targets. The original reference used 20 px throughout; RG-20/30/31/41 implement the new role-aware
component contract.

The replacement may collapse a docked log when space is tight, while retaining
a reachable Log action/menu in every composition and completed-hand state.
Docked and overlay views share the same recipient-safe log model. RG-43–45
provide the trigger, reusable scrollable component and modal host, preserving
history, pause/focus behavior and privacy. The reference phone's omitted log
surface remains legacy behavior pending this implementation.

Planned card-component contract (user clarification, 2026-10-28):
`PlayingCard` is a standalone authored presentation scene with face, back and
empty states, backed by `CardFace`/`CardBack` scenes and a recipient-safe
`CardViewModel`. `CardRow` composes the same component for community, hero and
opponent cards. Board/seat/phone components use that public rendering API;
card views contain no game-rule or hidden-card visibility decisions. RG-20 and
RG-40 implement and test this boundary; the current factory remains reference
code pending that work.

Decision (2026-10-28, RG-01): `PokerTableController.get_layout_snapshot()`
and `StartupConfigController.get_layout_snapshot()` expose detached,
strongly typed `GuiLayoutSnapshot` values. Producers adapt the reference GUI;
consumers use semantic roles rather than widget paths. The API measures the
rendered tree without changing it or advancing a match. RG-02 shared invariant and browser observers consume this contract.

- All rectangle fields use the owning root viewport's logical coordinates.
  Control/canvas transforms and popup embedding origins are applied; usable
  geometry now comes from RG-11's shared app-root-local snapshot and is
  transformed into viewport space. The felt surface remains a separate nested
  rectangle. Standalone table fixtures use their full root rectangle; native
  popup coordinates convert through both popup and parent Window transforms.
- `elements` identifies center, board, pot, wager, action, event, quit, More,
  hero fields and action targets, including minimum Bet/Raise. `seats` is
  keyed by core seat ID and includes panel/status footprints, content fields,
  visual slots and actual card observations. Startup and modal observations
  have typed child snapshots. A measured descendant collection preserves
  diagnostics for unexpected children as well as registered semantic roles.
- Text measurements retain complete required copy, wrapping/line limits,
  font metrics and allocated local sizes. Rectangle coordinates, local
  text metrics, logical scale, effective font size and output font size are
  distinct values; RG-10 decides their physical/CSS interpretation. No new
  font is introduced.
- Card observations inspect actual children, including unexpected faces,
  rather than deriving visible cards from expected state. Unauthorized rank,
  suit text and tooltips are redacted throughout semantic and generic
  observations. Snapshots retain no nodes, fonts, textures, card resources,
  `GameView` or mutable core objects.
- Readiness requires mounted, valid geometry and no pending table layout;
  an unmounted/unbound table returns a nonready snapshot. Bounded multiframe
  settling remains a harness responsibility. Snapshots remain valid after
  rerendering or freeing their source scene.

Decision (2026-10-28, RG-02): shared invariant assertions, phone content
contracts, bounded harness settling and exported browser observers consume
semantic snapshots. `GuiSceneHarness` accepts an implementation-specific
fixture driver; the reference driver owns legacy scene setup and its exact
phone-density oracle. Replacement drivers supply their own bootstrap and
omit that reference-only pixel comparison. Overlay exceptions use semantic
kinds and remain fixture-specific. Capture manifests retain original case IDs
and fingerprint the reference driver and snapshot assertion helpers.

Browser observations serialize viewport-coordinate regions and semantic label
roles, and retain complete raw engine failures. Input checks read exact input
values, drafts, focus and modal targets through the same contract; their
reference-scene setup is isolated from observation. Test observers and fixture
drivers remain excluded from production exports. These checks do not establish
physical-device acceptance.

Decision (2026-10-28, RG-03): reference policy/fit characterization has a
step-80 exact registry and a separate step-20 diagnostic. Pure injected-surface
phone/grid/ring/six-seat probes do not claim to reproduce the final wide
controller's minimum-size/correction passes. A bounded real-scene and resize
matrix verifies actual text/minimum propagation, public-card privacy, core-seat
identity and complete safe-view immutability. The registry rejects changed
failure sets in both directions and fingerprints policy observations/input
identity. Known defects are recorded without accepting overlap, clipping or
unsupported sizes. Final support policy remains RG-10/RG-12 work.

Decision (2026-10-28, RG-10): responsive layout uses measured content and
available logical space, with desktop keyboard input and tablet/phone touch in
both orientations. Existing screen dimensions remain reproducible samples.
Phone landscape is an explicit replacement target per the user's clarification;
legacy diagnostic labels do not defer its implementation or acceptance.
The normalization below is implemented by RG-11; startup no longer owns
Window normalization.

**Units and scaling contract**

| Space | Meaning and conversion |
| --- | --- |
| Backing/client pixels | Native `Window.size` and DisplayServer client size; on Web, canvas backing width/height. Keep these separate from UI coordinates. |
| Web CSS pixels | Measure the actual canvas bounding rectangle. Browser requested size, visual viewport, nominal DPR and backing size remain independent evidence. |
| Native UI units | Client pixels divided by the current window's valid platform UI scale. macOS scales 1 and 2 were measured. Unavailable/invalid scale falls back to 1 with explicit provenance; this establishes no unmeasured platform density claim. |
| Root logical units | One CSS/native UI unit, with conservative integer virtual-base quantization of at most one unit per axis. Positive extents round down to avoid shrinking typography/targets below their floor. Preserve `canvas_items`, `expand`, scale factor 1 and the product's initial 1920×1080 client window. |
| Usable logical rectangle | Root geometry reduced once by measured insets/chrome constraints. Preserve its origin and convert into each layout's coordinates through transforms. |

The adapter owns runtime `Window.content_scale_size`; a design viewport never
substitutes for measured available space. Web uses actual canvas CSS extent,
not backing pixels divided by nominal DPR when those disagree. Native uses
current-window scale rather than physical DPI or an arbitrary screen index.
SubViewport/headless fixtures inject logical geometry and never normalize the
host application's Window. CLI and simulation composition paths remain untouched.

The reference's 20-unit theme font and 48×48 target are UI-space floors after
transforms. The replacement uses 18 units for seat copy, 20 for card/other text
and the same 48×48 targets.
Font size denotes the font em, not its glyph ink bounding box. Reflow content
instead of shrinking these floors. Native output is converted back through the
reported platform scale; Web output pairs each final-transform axis with that
axis's actual CSS/backing ratio. Combining unrelated scalar minima would
misstate fractional-DPR output. Normal floating-point transform noise has a
small numeric tolerance; the measured 0.05 CSS-pixel deficit below is a defect.
Input modality controls keypad/native editing independently of composition.

Measured examples (Godot 4.7.2, real Compatibility windows and Chromium 140):

- At a scale-1 1280×720 client window, the fixed 1920×1080 baseline produces
  minimum visible text of 14 backing pixels and a 46×32.67 Fold target.
  Matching virtual geometry to the window restores a 20-unit text floor and
  targets at least 48 units high.
- On the measured Retina display, the 1920×1080 client window divided by
  scale 2 yields 960×540 UI units. The density-normalized experiment renders
  minimum text at 40 backing pixels / 20 scale-derived points and targets at
  least 96 backing pixels / 48 points. A 1280×720 client window yields 640×360;
  the replacement must adapt its landscape composition to that logical space.
  Native OS frame bounds were unavailable; point sizes are derived from the
  reported scale, not independently measured frame coordinates.
- Web 1280×720 at DPR 2.625 has 3360×1890 backing pixels and 1280×720 logical
  CSS units: a 20-unit font renders at 52.5 backing pixels / 20 CSS pixels.
- A requested Web 390×844 at DPR 2.625 produces a 389×843 CSS canvas and
  1023×2215 backing pixels. The existing inferred 390×844 base shrinks text
  to about 19.95 CSS pixels and a target to 47.94 CSS pixels. The isolated
  actual-CSS-base experiment restores 20 CSS-pixel text and 48 CSS-pixel
  targets across rotation and resizing. RG-11 must close this measured gap.

Implemented ownership (RG-11): `GuiViewportAdapter`, authored under the main
GUI scene, owns runtime normalization and publishes immutable
`GuiViewportGeometry` values from pure Web/native/injected factories.
Startup's Center and the table root receive the same usable origin/extent;
startup retains its internal 12-unit margin. Snapshot producers transform that
available rectangle into root-viewport coordinates separately from the felt.
Pending geometry invalidates readiness until the new rectangle is applied.

The Web probe measures canvas/layout/visual rectangles and CSS `env()` insets,
then intersects those constraints once. Export metadata adds `viewport-fit=cover`.
Native mobile safe rectangles convert from global client pixels through the
window origin and actual quantized logical/backing axes; desktop client space
is already unobstructed. Window resize, display movement/density changes and
Web viewport events refresh the same source. Native handheld orientation uses
Godot's sensor setting; replacement landscape acceptance remains pending.

The supported GUI explicitly uses embedded subwindows
(`window/subwindows/embed_subwindows = true`). `GuiPopupPlacement` maps the same
usable rectangle into embedded popup coordinates and honors actual content
minimums; visible separate native popups are rejected. Read-only native
coordinate conversion remains available for diagnostics. A forced separate
native `PopupPanel` experiment clipped child controls on Retina and is broken,
unaccepted evidence, not a production rendering promise. RG-45 replaces legacy
popup presentation with the in-canvas overlay host. Keypad geometry updates preserve drafts
and focus; existing layout-profile exit cancellation remains unchanged.
The compact keypad uses smaller spacing and a 20-unit draft font, preserving
all controls/targets within a measured 302-unit safe height. Headless,
SubViewport and explicitly sized fixture roots do not modify the host Window;
CLI and simulation never instantiate this adapter.

**Content-driven minimums**

Minimum feasible dimensions are functions of count, density, required copy,
component minimums, selected action flow and safe areas. They are not device
resolution constants. Let `T` be the measured complete opponent token footprint,
`B` the board/pot/wager minimum, `H` the hero minimum, `A` the action minimum,
and `G` the applicable measured gaps/margins. Evaluate finite container plans:

| Composition / counts | Minimum feasibility definition |
| --- | --- |
| Phone portrait, 2–7 | Choose a fitting token-column count. Width contains each complete row plus `B`, `H` and `A`; height contains `ceil((count−1)/columns)` token rows plus `B + H + A + G`. Standard/compact/minimal densities change spacing and row plans; font/target floors remain constant. |
| Phone landscape, 2–7 | Evaluate horizontal board/opponent and action/hero regions. Width contains both region minima plus gaps; height contains the larger of opponent-grid-plus-board and action-flow-plus-hero minima. Choose columns and action rows from measured fit. |
| Wide, 2–9, either orientation | The seat-ring Container derives its minimum from complete seat/status footprints, center and lower regions, theme gaps and the count's template. Compact/regular density and action flow are finite measured candidates. Tablet portrait and landscape consume the same available-space contract. |
| Infeasible or invalid space | Preserve tournament/configuration state and show explicit resize/rotate guidance. Phone counts 8–9 require a feasible wider composition. Never hide required copy, clamp seat counts or scale text below its floor. |

The replacement must retain a feasible candidate as space grows, even when a
preferred size class changes. Component minimum-size propagation and Container
sorting own actual allocations. RG-12 and RG-40–52 implement and verify these
functions; no table of historical screen sizes replaces them. The reference
fit probe's 64 passing cases at 950×532 and 1250×700 demonstrate feasible logical
allocations for counts 2–9 and ordinary/large content; they are regression
samples. The recorded 650×900 and eight-player 1920×1080 defects remain open.

This policy follows [Godot's scaling guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html),
using the documented [Window virtual base](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-property-content-scale-size)
and [current-screen scale](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-screen-get-scale).
Renderer compatibility and the default font remain unchanged. Local raw evidence:
`localtmp/restructure_rg10/native/`, `web/` and `web-candidate/`.

1. Show a startup panel prefilled with 6 participants, 1000 chips, small blind 5, and big blind 10; starting immediately without editing is valid.
2. Validate edits locally for immediate feedback, then create a fresh validated match configuration and construct `TournamentMatch`; do not create players, chips, or cards while the input is invalid.
3. Call `start()` and render the returned human `GameView`: board, pots, stacks, current blinds, level progress, acting seat, hero cards, active/eliminated participants, and final winner when applicable. Opponent cards remain hidden unless the view explicitly reveals them.
4. Enable only actions listed in `legal_actions`; expose Fold, Check/Call, minimum Bet/Raise, an exact Pot bet/raise target, All-in, and free-entry amounts as applicable. The Pot control is a No Limit convenience preset. It displays contribution `P` and submits the paired street-total target `T = H + P`, where `P` is the bound view's pre-action pot and `H` is the hero's existing street wager. Thus it adds `P` chips and leaves a pot of `2P`; it is disabled unless that exact target is a legal bet or raise the hero can cover. The ordinary wager-validation path remains authoritative.
5. On a button press, create `PlayerAction`, submit it, and render the next result.
6. Keep tournament `Quit` reachable from the table/menu; confirm in the GUI and
   then call `request_quit()`. Close/cancel number entry before using that route;
   numeric keypads do not contain tournament-exit controls.

The startup panel and table are views in one scalable `Control`-based main scene with `canvas_items` stretch mode and `expand` aspect. Layouts use containers, anchors, and responsive margins rather than fixed pixel positioning. Stretch mode scales the 2D layout but does not by itself guarantee crisp text or textures; those depend on viewport configuration and source assets. Starting a new tournament returns to the startup panel so new values can be chosen.

The table view uses a green felt surface. Its layout has explicit, visually distinct zones for community cards, the current pot, and player wagers; player-seat panels are arranged around that surface. The layout is presentation-only: it reads board, pot, contribution, position, and action data from `GameView` and must not calculate poker state itself. The GUI maps the recipient's seat to the bottom visual position for readability while retaining each core seat ID and rendering its actual dealer and blind markers. The acting player is identified by a white seat frame three times thicker than an ordinary frame, without a redundant textual `ACT` marker. The recipient's stack/status and private hole cards appear in that bottom seat panel; individual cards are rendered as card faces. This visual remapping is local to the GUI presentation layer and must not mutate `GameView`, `Table`, player ordering, or poker position semantics.

Decision (2026-10-27, CODE-01): `PokerTableController` coordinates recipient-safe
binding, public-action lifetime, input submission and pacing. Presentation work
has typed component boundaries:

- `GuiTableSeatFactory` builds disposable `GuiTableSeatView` panels from the
  bound safe view and tournament-local name/avatar assignment snapshots.
  Each panel captures its name, stack, badge and card handles once; those handles
  die with the rebuilt widget. No widget retains an agent or mutable core state.
- `GuiTableActionControls` resolves authored action rows once and owns their
  copy, visibility, styling and reparenting. It does not submit actions.
- `GuiTableOverlayViews` owns detail selection by core seat ID, detail-widget
  construction, modal switching/visibility and overlay geometry. Controller
  callbacks and `GuiModalGuard` retain focus, pause/resume and quit coordination.
- `GuiTableLayoutPass` resolves profile classification, density/scales and
  measured center bounds for one layout operation. Root geometry selects the
  profile; inset surface geometry sizes its contents. `GuiTableSeatLayout`
  applies that pass to complete seat/status footprints. The controller applies
  center and lower-region bounds in ordered phases; phone and compact-desktop
  plans cross those boundaries as `GuiPhoneLayoutPlan` and
  `GuiSixSeatDesktopPlan`, rather than generic `RefCounted` objects.

`GuiTableStyle.MINIMUM_FONT_SIZE` is the shared table text floor. Existing
profile geometry and fallback clearance policies remain behaviorally unchanged;
this extraction does not certify additional physical-device acceptance or
introduce persistent caching of recipient views.

`GuiActionTimingConfig` at `resources/gui_action_timing_config.tres` controls nonblocking GUI pacing. Its default action pause is two seconds; `pause_seconds_by_seat` can override the duration for each bot seat (or the human seat) independently. The same pause is used after each community-card reveal. Milestone 3 requires the completed-hand presentation pause to use `showdown_pause_seconds`, which defaults to five seconds, both after showdown and when one player wins before showdown because every opponent folded. `GuiActionPacer` uses a scene-tree timer, then asks `TournamentMatch` for exactly one further automatic action. The core exposes that boundary but owns every deal, betting, settlement, and tournament transition; it contains no GUI timer dependency.

The initial native client window is 1920 by 1080, while the `Control` layout must
reflow without overlap at supported desktop and mobile aspect ratios. The
app-owned `Main/ViewportAdapter` Node applies the current measured logical base
and usable rectangle to startup and table; startup no longer normalizes the
Window. Web uses actual canvas CSS bounds, while the backing canvas remains
high resolution. `GuiWebViewportGeometry` is a legacy helper pending retirement.
The human recipient is visually anchored at the bottom; this is a
presentation mapping only and must not alter core seat identities or poker
positions. Desktop seat panels use equal wide dimensions across 2–9 seats,
with mirrored left/right placement where applicable; compact layouts may
change dimensions but retain readable names, stacks, markers, and cards. Tall
mobile portrait surfaces are detected from normalized size and aspect ratio,
then scale seats, cards, table zones, and action controls from the available
surface. In the reference implementation, event history remains visible on
non-phone layouts but has no phone field, drawer, menu entry, or capture state.
The planned replacement log-access contract above supersedes that omission.

Phone startup supports 2–7 participants and does not alter the resolved product
default of 6. Startup may show non-binding guidance that 4 participants are
recommended on a phone, but accepting defaults still creates a 6-player
tournament. Counts 8–9 remain valid on larger GUI profiles and other product
interfaces. The startup controller enforces the phone-only limit at its
presentation boundary without changing `ConfigResolver`: resizing preserves
entered text and active tournament state, and the phone form tells the user to
use a larger layout for 8 or 9 players. Phone composition uses standard density
for 2–4, compact density for 5–6, and minimal density for 7. The pure
`GuiPhoneSeatLayout` owns only presentation geometry. `PokerTableController`
consumes its rectangles for
phone opponent tokens while keeping the human seat at the bottom. Tokens omit
avatars but reserve readable width for the full assigned display name, numeric
stack, compact position and public-state badge, and two recipient-safe hidden
or legitimately revealed hole-card fields. Each token also owns a separate
compact action cell. It retains that seat's latest Check, Call, Bet, Raise,
All-in, or Fold for the current betting round; a later public action replaces
only the same seat's value. These action cells clear at the next street or hand
boundary, while durable Fold state remains in the independent public-state
badge. The controller derives all action copy from recipient-safe public action
history, and no presentation timer may expire it. A deliberate
tap opens a closeable detail panel whose selection is stored as a core seat ID,
not a node reference, so rerenders cannot attach details to the wrong player.
The reference phone composition does not instantiate or expose event history;
the underlying recipient-safe history remains unchanged. The replacement must
expose it through a Log action/menu whenever undocked. Numeric entry is selected
from the actual input event: touch opens
the transactional in-canvas keypad on every profile. Opening and draft edits
leave the original field text untouched, including invalid and whitespace-only
text; Cancel/dismissal preserves it exactly and only Done commits the draft.
Pointer focus and
physical-keyboard editing remain native even in a phone-sized window. Godot's
project-level mouse-to-touch emulation is disabled because browsers already
report the real pointer modality; genuine touchscreen events still follow the
touch path.
Supported chip values retain their complete integer spelling. A phone table can
accumulate up to 7,000,000 chips (9,000,000 on larger layouts), although startup
stacks and blinds are capped at 1,000,000. When an opponent's measured stack,
action and card fields cannot share the compact row, portrait tokens expand
from 60 to 86 logical pixels: current actions use a third row, replaced by
legitimately revealed cards at showdown. The same immutable phone plan reserves
a 96 px center with side-by-side exact Pot/Bet totals. Large hero actions share
a feedback row with concise turn state; More retains its own reserved width.
Measured name/role overflow also selects the 86 px composition.
`GuiPhoneTokenContentPlan` finitely assigns measured public fields to three
rows, retaining the name and stack in their first and second rows. Revealed
cards occupy the third row; position/state components can occupy separate
cells without losing their combined meaning. Layout resets all anchors and
component visibility before applying a fresh plan, including repeated resizes
without a new view. Ordinary content restores the compact composition without
mutating the view.

Larger layouts omit the redundant `chips` suffix from large stacks and split
long pot/blind information across two lines. Small-desktop and portrait-tablet
seats consistently use bare integer stacks at ordinary values too; each layout
refresh resolves the value by stable core seat ID. Compact tablet and
small-desktop large-value action rails keep two rows: Fold/Call/All-in and Min/Pot/Bet or
Raise. The wager button opens the existing keypad for free entry; both the
inline and keypad presets retain their exact core-validated targets. Full
desktop numeric controls retain inline input and use at least 20 px type.

Fixed card faces measure the widest rank (`10`) at the current font when
created, resized or rescaled. Portrait community cards use 48 × 54 px faces
with 5 px gaps; revealed opponent faces retain 46 × 30 px. Both leave at least
18 px for the suit at their supported fonts. This does not establish deferred
phone-landscape legibility: its narrower 38 px faces cannot satisfy the same
rank/suit widths.

Seven-seat full desktops with usable height below 1200 px reuse the nine-slot
ring footprint with two empty slots so required below-seat status bands remain
clear; taller canvases retain the ordinary ring.

At phone hand completion, the existing action-status region names every unique
pot winner in the default table presentation. Measured line breaks retain the
20 px floor and all recipient names within the full-width completed-hand
footer; the obsolete hero action badge yields to this result. Cards stay
visible and the ordinary completed-hand pause remains unchanged. The existing
72 × 48 button reads `Pots` and opens Hand summary directly for exact awards;
normal play restores `More` and its menu. Tournament-winner copy is retained.
Larger profiles restore their existing status presentation on profile changes.

The phone Hand summary is available directly from Pots after fold wins and
showdowns. It lists each main/side pot's total and named recipients with their
exact awarded shares (including odd chips), followed by recipient-safe hand
descriptions. It reads only `GameView` settlement records and revealed results;
fold wins never reveal private cards. Compact final-winner copy uses the same
GUI-assigned name as the seat.

`GuiModalGuard` owns table-modal input and reading pauses. Phone menu, hand
summary, seat detail, wager keypad, and quit confirmation are exclusive: opening
one replaces the previous surface without resuming play between them. A full
usable-table backdrop intercepts underlying pointer/touch input, keyboard focus
cycles within the active surface, and stray underlying action submissions are
rejected by the adapter. Closing restores the previous live focus target, with
More or the visible wager button as a fallback after a seat rebuild/profile
change. Every surface provides Close/Cancel. Number entry contains no tournament
Quit action; cancel/close it before using the table/menu Quit route. Other
reading/menu surfaces retain their explicit exit routes.

Presentation timers may expire while a modal is open, but their next core
advancement callback is retained until the last modal closes. It resumes once,
after the closing input event; switching surfaces never advances the hand.
Thus a completed-hand summary remains readable indefinitely. Confirmed quit
cancels held advancement. The same guard keeps table keypads and embedded quit
confirmation exclusive on larger profiles without adding pause state to core.
Escape dismisses the active surface without committing a keypad draft. The
engine's go-back notification follows the same dismissal path; automatic
`SceneTree.quit_on_go_back` is temporarily disabled and restored afterward.
Browser-history Back and physical-device navigation require device evidence;
they are not certified by synthetic engine-notification tests.

The phone More control occupies reserved space in the bottom action region,
never a perimeter seat slot. Phone quit confirmation uses a bounded in-canvas
panel with two explicit 48 px actions; desktop retains Godot's embedded
`ConfirmationDialog`, not a separate native OS window. The phone center plan
owns the complete board, pot, and current-wager
stack so its declared rectangle cannot hide child-panel overlap.
Profile changes rebuild the presentation from the unchanged `GameView`; full
desktop and tablet panels are restored when the current usable viewport is no
longer a phone. A presentation-only profile override supports device-backed
fixtures such as the observed high-resolution iPad without changing automatic
geometry classification, player limits, core seat IDs, or poker position.

`resources/gui_theme.tres` uses Godot's built-in plain non-serif UI font for both the startup screen and the table. Startup labels, numeric inputs, validation feedback, and the on-canvas keypad inherit that face, as do table labels and controls; presentation code must not introduce a serif face. Desktop table typography and line-art are configured at their source sizes rather than post-render scaled.

The reference theme adapts sizes with a 20 px floor, except event-log body
at 18 px after RG-11R. The
replacement permits seat copy to scale to 18 logical/CSS px; card ranks and
other GUI text retain 20 px, with the same log exception. Reflow uses measured minimums at those role-specific
floors. Mobile controls provide at least 48 × 48 px touch targets, with approximately 160 × 50 px targets for horizontal text buttons where space allows.

The sixteen `assets/avatars/*.png` sources are 64 × 64 pixels. Full seat
panels use base avatar regions of 112 × 112 logical pixels for opponents and
128 × 128 for the human (`GuiTableSeatFactory` constants); responsive layout
may scale or reflow them. Phone tokens omit avatars. Source pixels, logical
display size, and physical pixels at browser DPR are distinct quantities. At GUI tournament creation, a GUI-owned avatar assignment service selects distinct avatar asset IDs without replacement and retains its `seat -> avatar ID` mapping until that tournament ends. It uses a presentation-local RNG stream (injectable and seedable in adapter tests), never the core tournament RNG streams. The mapping is not stored in `Player`, `GameView`, match configuration, domain events, or any core rule module. If the configured avatar catalog cannot provide one unique avatar per seat, GUI startup must fail clearly rather than reuse an avatar silently.

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

Live seat panels show stacks directly below player names, position badges, and
two visible card backs for opponents until cards are legitimately revealed.
The Milestone 3 table uses one fixed-height status band permanently reserved
below every seat. During play it renders the current public action on one
line. At showdown, recipient-safe hand text replaces that action when available
and may use up to two lines; a seat without hand text retains a relevant latest
action such as `Fold`. With neither value, the band remains reserved and visually
blank. The band height never changes with its content, and its text retains the
20 px player-facing font floor. Folded or outbid seats remain visible in
grayscale and hide their cards. The centered board/pot/wager zone is visually
separate from seats and status bands. Human action controls are framed,
explicit two-row controls beside the human seat; the ordered event feed is a
high-contrast scrollable viewport on the other side. Status content comes only
from recipient-safe public actions and showdown results, never hidden core
state.

Small-desktop geometry treats each seat and status band as one footprint,
places the compact opponent seats around a bounded central board/pot/wager
stack, and reserves independent event, human-seat, and action regions. Tablet
composition is landscape-first but retains portrait regression support. Its
board/pot/wager stack stays centered on the usable table surface, the human is
bottom-center, and one layout owner places opponents on a deterministic
left/right-symmetric arc. A six-player table therefore has one bot at the upper
apex and two mirrored bot pairs. Compact tablet event history and actions own
balanced lower regions around the human; position markers remain in seat header
cells, and short-canvas status bands stay attached to their seats. These
compositions use compact seat content and concise control copy such as
`Call`, `Min <total>`, `Pot`, and `Total`, while retaining the 20 px text floor
and 48 px interactive-control height. The strict Milestone 3 matrix validates
these layouts alongside landscape tablet and desktop layouts for 2, 4, 6, and
9 players.

GUI gates and capture manifests share `GuiInvariantMatrixSuites` coverage.
One `GuiInvariantMatrixRunner` drives all four diagnostic suites, retaining the
additional `GuiPhoneMatrixContract` checks and historical entry points. The
[visual evidence contract](GUI_VISUAL_TESTING.md) owns case/version policy.

Refresh lifetime decision (2026-10-27): retain disposable seat/card widgets
and recipient-safe view binding. A test-only subclass and shared native/Web
fixture measure seeded turns, all-in runouts and cross-profile resizes with
real avatars, long names and maximum chip values. Across 120 samples in each
of nine workloads per runtime, refresh p95 reaches 5.9 ms on native Apple M4
Compatibility and 12.9 ms in exported Chromium; transition-layout p95 reaches
7.5/13.3 ms. These synchronous operations remain below the 16.7 ms investigation
threshold, and normal product updates retain their 2 s / 5 s pacing. The data
does not demonstrate a widget-retention benefit that warrants added lifetime
and invalidation policy. No whole-view cache or production reuse is added.
Whole-frame wall p95 sometimes exceeds that threshold and includes waiting and
deferred work; this is not a 60-fps guarantee. The Web software-backend sample
does not establish physical-device performance, and profiler-owned buffers
prevent a leak-freedom claim. Reopen targeted reuse with attributable slow-frame
evidence. See the [profiling runbook](../devdocs/how-to/running-and-testing.md#profile-gui-refresh-cost).

When a hand completes before showdown because every opponent has folded, the
GUI must render exactly `Winner` in the winning seat's shared status band, the
same location otherwise used for showdown hand text. That presentation remains
visible for the `showdown_pause_seconds` completed-hand pause before any next
hand begins. The GUI derives the winning seat from recipient-safe completed-hand
state and owns the display text and timer; neither concern enters the core.

### GUI visual-verification workflow

The supplemental browser-capture fixture is presentation-only public data.
Its isolated Web observer mounts production main to retain the real CSS/DPR
normalization path, reads full seat/status geometry and existing invariants,
and exposes no input/mutation API. Reports preserve failing cases and distinguish
new measured environments from unknown historical capture metadata; observers
are excluded from production exports and do not establish device acceptance.


The reusable GUI verification harness owns named logical-viewports and
deterministic presentation-state fixtures. Milestone 3 defines the complete
fixture catalog, including phone portrait, phone landscape, and browser-chrome
height changes, while requiring the desktop, tablet, and small-desktop cases
to pass. Milestone 4 implements the dedicated phone composition and is the
gate at which the full phone fixture subset must pass. Defining a phone fixture
in Milestone 3 therefore records a stable future input; it does not represent
acceptance of the pre-phone layout.

The canonical tablet fixtures use logical viewports of 768 x 1024 in portrait
and 1024 x 768 in landscape. Landscape is the primary iPad orientation. The
1194 x 696 reduced-height landscape regression models the logical game area
inferred from the reported Chrome screenshot and automatically classifies as
tablet; physical browser metrics remain required acceptance evidence. The
existing 2388 x 1450 landscape case remains
an additional observed-device regression, not a replacement for either
canonical logical size. Its fixture metadata supplies an explicit tablet
profile override: geometry alone classifies 2388 x 1450 as desktop because an
ordinary desktop window can have exactly those usable dimensions. The
canonical reduced-height browser-chrome fixtures are 390 x 744 in portrait and
844 x 330 in landscape. These named sizes are shared by geometry regressions
and screenshot capture so the two forms of evidence describe the same inputs.

Geometry, visibility, font, touch-target, and intersection assertions run in
the ordinary headless GUT suite. Rendered screenshots use a separate
rendering-enabled workflow because Godot's headless display driver uses the
dummy rendering driver and cannot produce representative pixels. The rendered
workflow uses the Compatibility renderer, waits for the completed draw before
reading the viewport texture, and records the commit plus fixture inputs in a
manifest. Screenshots support human review of hierarchy, density, contrast,
and proportion; brittle pixel equality is not the sole automated pass
condition.

Rendered review remains separate from headless CI. Pull requests run the
non-deploying `Validate pull request` workflow against the proposed merge,
with repository-read permission and pinned Godot 4.7.2. Its stable
`Checks and current layouts` status reports `release-candidate-gate` failures
before merge; maintainers may require that status through branch protection.
The gate runs the complete headless suite and `gui-current-invariant-gate`,
which includes the historical M3 and dedicated phone, iPad, and desktop
matrices, with clean-tree checks before and after. Diagnostic landscape
fixtures do not establish physical-device acceptance or change the deferred
phone-landscape support contract.

The separate `Exported Web input` PR job builds an isolated release export
of the production GUI with a test-only read-only observer. Pinned Chromium
receives actual pointer, touch and keyboard events; startup and seeded live
tournament fixtures verify keypad drafts, Cancel/Done, focus transitions and
core wager submission. The observer is excluded from production exports.
This regression does not establish physical-device acceptance.

`GuiSixSeatDesktopPlan` owns the complete seat/status footprints, center,
Quit and lower control rail for constrained six-seat desktop surfaces when
their measured minima fit. Its selection is separate from device profile;
changing this density composition rebuilds seat content. The controller
applies the resulting rectangles without running the legacy successive
collision resolvers. Other device profiles and surfaces that cannot fit the
complete plan retain their existing layout paths. Exported browser regressions
check footprint clearance and full clockwise core-seat order independently
from content fit and physical-device acceptance.

The small-desktop grid retains its authored occupied cells.
`TableSeatLayout.small_desktop_opponent_positions` sorts their centers clockwise
from the human's bottom position, using uniform authored footprints and a
deterministic cell-ID tie break. The controller assigns these positions by
relative core seat ID; dictionary/source-array order and optional folded or
revealed content cannot determine seat ownership.

Every push to `main`
automatically checks out the pushed SHA and runs `release-candidate-gate`,
followed by `web-release` for the Web export and export-output
validation. A successful run deploys that exact build to the rolling GitHub
Pages URL so developers can discover browser- and device-specific defects
early. Neither headless step claims to reproduce representative pixels.

Decision (2026-10-26): local Wi-Fi development uses a separate Python
standard-library build/server adapter under `tools/web_lan/`, following
[`LanTestTasks.md`](arkiv/LanTestTasks.md). It snapshots and exports the normal
production startup scene into ignored `localtmp/`, records commit/dirty-source
and engine identity, and publishes only verified builds. The server redirects
its latest entry point to an immutable build URL so rebuilds cannot mix asset
generations. A failed rebuild invalidates that entry point. Foreground serving
supports Ctrl+C and a private token-authenticated stop request, rather than
killing an unverified PID. Physical Wi-Fi/browser acceptance remains explicit
device evidence. This adapter leaves the clean release and deployment policy
unchanged.

LAN HTTPS follow-up: the exported 4.7.2 runtime requires a secure context at
the LAN address. The local CLI defaults to HTTPS, with an OpenSSL-generated
CA and SAN certificate under its ignored output root. Certificate generation
does not install trust. Account/device trust changes require the user's
explicit choice. A separate standard-library HTTP helper serves only public
CA files for device bootstrap. Shutdown verifies the configured CA and bind
hostname; normal asset responses verify their recorded payload hashes.

Rendered review is required for visual acceptance of an affected scope.
Deployment itself does not require manual hosted review, but a device support
claim needs recorded device evidence. Phone acceptance limitations are recorded
in the archived
[OptimizingPhoneGuiTasks.md](arkiv/OptimizingPhoneGuiTasks.md); historical iPad,
desktop, and LAN records have the distinct statuses listed in the
[visual contract](GUI_VISUAL_TESTING.md#current-support-and-acceptance). When that evidence is collected, the manifest,
review, deployment run, and hosted evidence should identify the same full
commit SHA. Avoid changing `main` during a hosted review because a later
successful push replaces the tested site; repeat affected checks rather than
mixing evidence from different commits. Manual deployment is an optional
operational mode documented in the
[manual-deployment how-to](../devdocs/how-to/switching-github-pages-to-manual-deployment.md)
and is enabled only by an explicit project-owner request.

### CLI adapter

1. Start through `godot --headless --path . --script res://scripts/cli/cli_app.gd`.
2. Display the defaults and offer an immediate start that supplies no overrides. If configuration is requested, allow participant count, starting stack, small blind, and big blind to be overridden independently; an empty field supplies no override.
3. Merge overrides onto a fresh default configuration. Report invalid explicit input and repeat only fields named by validation errors, retaining all other edits. Blank correction retains the displayed value. After validation succeeds, print its summary and require no further setup input.
4. Follow the common match API and render snapshots as text. In every player list, append the literal suffix `(you)` immediately after the display name of the one `PlayerView` whose human flag is true; never apply it to a bot. Format every visible card as `[Rank][Suit]` using the canonical Unicode suit glyphs, and format card collections as `[ Card1 | Card2 | CardN ]`, exactly as specified in `docs/POKERCARDS_IN_CLI.md`. Never render stable IDs, enum ordinals, or numeric rank/suit pairs to the player.
5. During play, read stdin only at `WAITING_FOR_HUMAN` or `HAND_COMPLETED`. Between hands, only blank input or `continue` advances; help, unknown commands and poker actions preserve the completed hand. At a human turn, blank input preserves the turn and `continue` reports a phase error.
6. Parse `fold`, `check`, `call`, `bet <amount>`, `raise <amount>`, and `allin` into `PlayerAction`; report parsing or action errors and prompt again without crashing.
7. Map `quit` and `exit` directly to `request_quit()`.

`cli_app.gd` is the composition/process-exit entry point. `TerminalIO` is the only class that reads stdin or writes stdout, behind an injectable `CliIO` boundary used by `StartupConfigPrompt` and `CliCommandLoop`. `CommandParser` converts normalized terminal text to typed shell commands; poker-action parsing is added only when the corresponding core actions exist. Terminal input reads bytes through `OS.read_buffer_from_stdin()` so an intentional blank line remains distinguishable from EOF; EOF terminates cleanly rather than causing an input-retry loop. Blocking reads are permitted only in this headless adapter, never in `scripts/core/` or the GUI.

`CliCommandLoop` returns distinct `COMPLETED`, `QUIT`, `EOF` and `ERROR` results. Normal completion, voluntary quit and EOF exit with status 0; startup and tournament failures exit with status 1. Recoverable input/action rejections keep prompting.

`CliStartupArguments` strictly parses `--help`, `--configure`, `--players`,
`--stack`, `--small-blind`, `--big-blind`, `--seed` and the legacy-roster flag.
It rejects duplicate/unknown switches and unsafe integer conversion; the entry
point applies options to a copy and validates the complete configuration through
`ConfigResolver` before prompting. Seed 0 remains time-based. `CliMatchFactory`
prints the effective seed and reproduction options from the same `RngStreams`
instance used for roster assignment and tournament construction, rather than
creating a separate time seed for diagnostics.

The product entry point enables compact rendering: full snapshots at hand
start/completion and incremental public history with board/pot/stacks/cards and
legal actions during play. `state` and `history` inspect the full recipient-safe
view or current hand history without advancement. The renderer resets its
history cursor at each new hand and match; explicit inspection does not consume
that cursor. Injected command loops may retain full rendering for callers that
need every snapshot. Reproduction requires the same source, roster and stdin
sequence; this is not a cross-version game-record format.

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
selected command and format. Both formats write throttled completed/total,
elapsed-time and throughput progress to stderr. Replay collects bounded safe
traces when explicitly requested, separately from its outcome digest. The
[stream/replay contract](Simulation_And_Evolutionary_Bot_Strategy.md#44-stdout-stderr-and---output)
specifies these boundaries.

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
`prepare-experiment`, `compare-experiment`, `init-generation`,
`evaluate-fitness`, `select`, `crossover`, `mutate`, `build-lineage`, `inspect-lineage`, `confirm-candidate`, and
`prepare-promotion-review`, `finalize-promotion-review`, `publish-profile`,
and `export-candidates`. The older single-candidate `review-promotion` command
remains only for artifact compatibility; new workflows must use one
consolidated review. JSON
inputs must be UTF-8 objects without duplicate keys or non-finite numbers.
`prepare-experiment --config PATH --output-dir DIR [--dry-run]` validates a
schema-1 experiment configuration against immutable lineage and benchmark
snapshots. One common heads-up evaluation cohort covers selected candidates
from any generation against the same benchmarks. Separate mirrored/mixed
manifests contain one candidate each, use independent seed blocks, and meet
cyclic seat/sample minimums. Historical champions require matching selected
lineage; prior evaluation ranges/RNG versions remain explicit compatibility
constraints. Dry-run writes nothing and reports artifacts, checksums, commands
and incompatibilities. Generated commands end at one pending consolidated
promotion review; they do not publish or decide approvals.

`compare-experiment --config PATH --report PATH... --output-dir DIR` requires
the exact generated common manifest, complete shards and matching current RNG
and executable provenance. Existing fitness validation recomputes each selected
candidate's results from raw tournament rows; eligible fitness sorts descending
with candidate ID as tie-breaker. Ineligible candidates remain unranked. The
comparison retains original generation/creation context, emits per-candidate
fitness bound to the original creation artifact, and appends this evidence to a
copied lineage registry for confirmation. It never fabricates a merged
population or compares unrelated historical score cohorts.

Multi-file experiment outputs reserve a new directory and publish complete
files through the shared no-clobber writer. `experiment.json` or
`comparison.json` is the readiness marker, committed last. Failure cleanup
removes known owned files only; competing files and uncertain post-publication
failures remain for inspection. Existing/dangling output symlinks are refused.
The [experiment guide](../devdocs/how-to/preparing-bot-experiments.md) specifies
the config and generated workflow.

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
set of schema-4 `SimulationReport` shards. It validates command v6, identical
executable provenance, canonical manifest checksum, exact candidate snapshots, deterministic
plan identities, unique global tournament indexes, complete shard/plan
coverage, successful completion, finite metric inputs, bounded behavioral
rates, and every plan's minimum candidate sample threshold. Trace and card
data are not fitness inputs. Each candidate's six normalized components are
recomputed from profile results rather than trusting stored aggregates, with
repeated candidate seats averaged into one observation per tournament/seed.
Their arithmetic means and normal 95% confidence-interval half-widths are
reported separately from the finite-sample penalty applied to point fitness.
Intervals are explicitly missing with fewer than two independent units. The
immutable `fitness` artifact records report and manifest
checksums, shard identities, regimes, plans, code revisions, component sample
counts, uncertainty, and explicit style checks. Candidates with insufficient
samples or invalid-action fallbacks are ineligible, have null fitness, and are
never assigned a rank. Input generation and report bytes are never modified.
Both schema-2 simulation plans and evaluator v1 require `normal_95`; they
reject `bootstrap_95` rather than silently calculating and labeling a
different estimator. Simulation regimes also enforce the product maximum of
nine players.

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
review export. It evaluates current schema-4 reports with schema-2 manifests in complete
mirrored and mixed-table report groups. Mirrored plans must be cyclic
heads-up matchups that cover every candidate seat against every declared
legacy profile and historical champion. Mixed plans must be cyclic tables of
at least three seats whose matchups contain the candidate plus both opponent
classes. All participants must have zero invalid-action fallbacks. Original,
mirrored, and mixed evidence use disjoint report and manifest checksums and
non-overlapping effective seed identities; separate confirmation batches do
the same. Confirmation interprets ranges using their recorded RNG derivation
version, so numerically disjoint legacy ranges that alias modulo 2147483647
are rejected. Evidence from different RNG derivation versions is incompatible.
The immutable confirmation records the exact
candidate/registry identity, per-mode metrics, samples, style evidence,
uncertainty, reports, and explicit eligibility reasons. Caller-selected plan
minimums remain exploratory and cannot relax the fixed
`promotion_evidence_v1` policy. Each confirmation matchup requires at least
300 completed candidate observations and at least 100 in every candidate seat
(therefore at least 600 at six seats and 900 at nine). For every declared
benchmark in a matchup, confirmation calculates paired per-tournament raw
composite differences and requires `mean_difference - normal_95_half_width`
to be strictly positive. Counts, comparisons, and pass states are retained in
the immutable confirmation artifact.

Confirmation also requires genetic diversity before it can be eligible.
For every comparable declared legacy or historical-champion
`strategy_parameterized` profile, the tool records the L1 distance across the
four percentage genes. The nearest distance must be at least ten; the recorded
comparison is explicitly genetic. Confirmation separately records
count-weighted VPIP, PFR, bet/raise frequency, bet frequency, and raise-share
measurements from the evidence reports. Every confirmation is marked
`review_required`. `prepare-promotion-review` writes one editable plan listing
all supplied candidates, their exact confirmation checksums, and a complete
pairwise proposed-roster review containing gene and measured-behavior
distances. The reviewer changes each candidate's single `decision` field from
`pending` to `approve` or `reject`, with optional display names and notes.
`finalize-promotion-review` requires a completed decision for every listed
candidate, recomputes the complete pairwise review from the supplied
confirmations, and emits one immutable, reviewer-labeled
`promotion_review_batch`.

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
`BotProfile` only at `resources/bot_profiles/published/<profile-id>.tres`, plus
an adjacent provenance sidecar binding its SHA-256 to the confirmation and
review checksums. Publication uses no-clobber creation for both files, so a published version cannot be
overwritten. It does not alter `PlayableBotRoster`; activation remains a
separate reviewed source change. Product policy retains the hand-authored Random, Tight Passive, and Loose
Aggressive profiles. The implementation checks for a non-empty legacy family
when legacy selection is enabled, not those three individual IDs. Checksums
bind artifact content and do not authenticate a reviewer's supplied label.

Python artifact, editable-review-plan and Resource publication share
`atomic_write.publish_bytes_no_replace`, which receives already serialized
bytes, flushes/syncs a temporary sibling and publishes with a no-replace hard
link. Serializers, parent-directory policy and structured error mapping remain
with their callers. Artifact/review writes sync the parent directory; Resource
publication preserves its existing file-sync policy and sidecar rollback.
Racing destinations remain untouched, and temporary files are cleaned on
failure; a directory-sync failure after publication retains the published file.

The executable Milestone 5 smoke history is preserved under
`examples/profile_evolution/milestone5`. It includes deterministic generation,
fitness, selection, crossover, mutation, and lineage artifacts plus real Godot
mirrored and mixed-table confirmation reports. Both smoke candidates were
correctly rejected after invalid-action fallbacks appeared in independent
evidence, so no review bundle or roster change was produced.

## 7. Commands, results, and events

Core mutations return typed results rather than printing or showing dialogs.

`StepResult` contains a typed `status` and a diagnostic `message`. It does not
embed views or events: adapters call `get_view_for(seat)` and `get_events()` on
`TournamentMatch`. `DomainEvent.Kind` includes hand start/completion, blinds,
dealing, applied/rejected actions, street/community changes, showdown start,
pot awards, and quit. Winner/elimination state is exposed in `GameView`; no
separate tournament-won or player-eliminated event kind currently exists.

Events support GUI animation, CLI narration, tests, and future replay diagnostics without making core logic depend on a renderer.

Events exposed to adapters must not contain unrevealed card values. Visible card data comes from the recipient-specific `GameView`; internal diagnostics that contain private cards must remain inside the core or test harness.

## 8. Configuration and construction

Use a typed configuration `Resource` as the source of defaults; its validated resolved snapshot is passed to the core:

- `player_count`: integer 2–9, default 6;
- `small_blind`: integer 1–1,000,000, default 5;
- `big_blind`: integer 1–1,000,000, default 10;
- `starting_stack`: integer 1–1,000,000, default 1000, applied equally to every participant;
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

Before every tournament starts, both adapters may collect independent overrides for `player_count`, `starting_stack`, `small_blind`, and `big_blind`. No override is required. Each omitted field retains its value from `default_tournament_config.tres`, allowing a match to start with no supplied values or with only some fields overridden. Explicit values must be integers; participant count must be 2–9, starting stack and both blinds must be 1–1,000,000, and small blind must not exceed big blind. Text adapters reject values outside signed 64-bit range before conversion, while core validation of the fully resolved configuration remains authoritative. With at most nine one-million-chip stacks, all legal runtime stack, bet, contribution, and pot totals remain far below the signed 64-bit limit. Simulation planning likewise checks `seed_start + tournament_index` before addition and rejects a plan whose effective seed would overflow or equal zero.

The resolved values are copied into a fresh configuration before `TournamentMatch` is constructed and cannot change after `start()`. The resolved blind values are the starting blinds for level 1; `TournamentMatch` owns subsequent hand-based blind progression. The composition root builds the complete `seat_agents` map from `player_count`: seat 0 is the human and seats 1 through `player_count - 1` are bots. The default six-seat setup selects five strategic profiles; the optional legacy setting applies the documented family split without changing poker rules.

Validate configuration before any chips or cards are created. Invalid configuration returns a descriptive startup error.

An agent ID resolves in the composition layer to a concrete agent preset. `AgentFactory` creates the corresponding `HumanAgent` or concrete `BotAgent` subclass. For bots, that preset selects a `BotProfile`; the factory asks `DecisionModelRegistry` for a new model instance, validates the profile's parameter type and ranges, and injects the seat's RNG stream. This preserves the required `seat_agents: seat -> agent-id` contract while allowing model and behavior parameters to vary by preset. Core rule modules know neither concrete bot class names nor model IDs.

After resolving a time-based root seed when `rng_seed == 0`, derive separate RNG streams from the root seed for:

- deck shuffling;
- initial button selection;
- each randomized bot.

`RngStreamFactory` derives each stream from the exact effective seed plus a stable identity (`deck`, `initial_button`, or `bot:<seat>`), never from stream creation order. Simulation composition selects `named_stream_sha256_v2`, a domain-separated SHA-256 derivation mapped to a positive 63-bit Godot RNG seed. `RngStreams` retains the effective seed and derivation version for diagnostics and owns the separate `RandomNumberGenerator` instances. Consuming one stream therefore cannot change future card order, button selection, or another bot's behavior. Interactive product composition retains `named_stream_v1` so existing product seeds do not silently change; simulation replay selects either version explicitly from provenance. Tests pin the legacy derivation vector while otherwise comparing reproducibility and independence because Godot's underlying RNG algorithm is not part of this project's contract.

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

This is a selective map of current entry points; use `rg --files scripts` for
the full inventory.

```text
scripts/core/
  card_data.gd
  game_view.gd
  public_action_record.gd
  domain_event.gd
  tournament_match.gd
  hand_controller.gd
  agents/
    agent.gd
    human_agent.gd
    bot_agent.gd
    decision_model.gd
    decision_model_registry.gd
    random_decision_model.gd
    random_decision_model_parameters.gd
    strategy_decision_model.gd
    strategy_decision_model_parameters.gd
scripts/gui/
  startup_config_controller.gd
  poker_table_controller.gd
  gui_table_seat_factory.gd
  gui_table_seat_view.gd
  gui_table_action_controls.gd
  gui_table_overlay_views.gd
  gui_table_layout_pass.gd
  gui_table_seat_layout.gd
scripts/cli/
  cli_app.gd
scripts/simulation/
  simulation_cli_app.gd
scenes/
  main.tscn
docs/
  README.md                 # current task index
  arkiv/                    # historical task records
```

Additional small value/result classes may be added under `scripts/core/` when they remove ambiguous dictionaries. Avoid generic `utils.gd` modules; place behavior with the owning concept.

## 13. Testing architecture

Tests extend GUT's `GutTest`, run headless, and instantiate core classes directly. Tests must not require the main game scene unless they specifically verify a GUI adapter.

### 13.1 Unit tests

- deck reset plus shuffle produces exactly 52 unique cards, with deterministic order for a fixed seed;
- chip stack bounds;
- startup configuration defaults, complete omission, partial overrides, valid boundaries, invalid explicit values, and immutability after match start;
- hand category and tie-break comparisons, including that the five-high wheel beats king-high and loses to a six-high straight;
- betting legality, a first preflop full raise to at least twice the big blind,
  subsequent raises using the previous full betting increment, postflop
  opening-bet increments, and increment reset on each street;
- short all-ins preserve the minimum full-raise increment, including when the
  short increment is at least one big blind but below the previous full increment;
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
  reducing text below the role-specific 18 px seat-copy / 20 px card/other
  floors, with the dedicated 18 px event-log body exception.

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
