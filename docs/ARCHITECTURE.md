# Pokahdot Architecture

Status: Proposed for the first playable version  
Last updated: 2026-10-15  
Requirements source: [`docs/ProjectDescription.md`](ProjectDescription.md)

## 1. Purpose

Pokahdot is a single-table No Limit Texas Hold'em tournament for one human player and automated opponents. The same deterministic game core must support both a Godot `Control`-based GUI and a headless terminal interface.

This document defines module boundaries, state ownership, runtime flow, and the contracts that presentation layers and agents use. If this document conflicts with `docs/ProjectDescription.md`, the project description wins.

## 2. Architectural drivers

- One rules implementation for GUI and CLI.
- Correct betting, all-in, side-pot, showdown, and tournament elimination behavior.
- No hidden-card leakage to agents or presentation layers.
- Replaceable bot strategies without changes to poker rules.
- Multiple decision-model implementations with independently tunable, per-seat behavior profiles.
- Deterministic runs when an RNG seed is supplied.
- A human action may arrive later without blocking Godot's main thread.
- The human may quit at any time without manufacturing a tournament winner.
- Core logic must be testable without loading scenes or reading stdin.

## 3. Architectural style

Use a small layered architecture with explicit ports between the game core and its adapters.

```text
GUI scenes and controllers       CLI parser and renderer
            \                         /
             \                       /
              Presentation adapters
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

The GUI and CLI are composition roots: each creates the configuration, players, agents, RNG streams, and `TournamentMatch`, then drives the same public API.

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
| Compose bots from agent, decision model, and profile | New decision algorithms and per-seat behavior can be added without changing poker rules or duplicating input/error handling. |
| Keep runtime state in core objects, not scenes or Resources | Scenes display state. Configuration and static card data may be Resources; mutable match state stays in dedicated runtime objects. |
| Use GUT as the test framework | Its Godot 4.7 release provides GDScript assertions, parameterized tests, doubles, headless execution, and JUnit output without adding runtime coupling. |

## 5. Core module responsibilities

### 5.1 `card_data.gd`

`CardData` is an immutable `Resource` value containing a stable card ID, rank, and suit. Equality and ordering use the stable ID and rank values, never display text or textures.

Card visuals are presentation metadata and must not be required by the evaluator or deck.

### 5.2 `deck.gd`

`Deck` owns the 52-card collection for one hand.

- Reset to exactly 52 unique cards.
- Shuffle through an injected `RandomNumberGenerator`.
- Draw cards without replacement.
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

`Table` owns seat ordering, button position, blind sizes, and active-seat traversal.

- All traversal helpers skip busted seats.
- The initial button is selected from active seats by injected RNG.
- Later hands move the button clockwise to the next active seat.
- Heads-up blind and action order are exposed as explicit helpers rather than scattered conditionals.

### 5.6 `player_action.gd`

`PlayerAction` contains an `ActionKind` and amount.

```text
FOLD, CHECK, CALL: amount = 0
BET, RAISE: amount = target total bet_this_round after the action
```

Using a target total avoids ambiguity after blinds or earlier contributions. `BettingRound` remains the authority for whether an action and amount are legal.

### 5.7 `betting_round.gd`

`BettingRound` owns one street's action state:

- acting seat;
- current bet;
- last full raise size;
- seats that still owe action;
- seats whose raise rights are open;
- legal action calculation;
- action application and next-seat selection;
- round completion.

Short all-in raises update the amount to call but do not reopen raise rights for players who already acted and matched the previous full raise. This rule must be represented directly in state, not inferred from action history in the UI.

Invalid actions return a typed rejection and leave all state unchanged. Bot fallback selection happens in `HandController`, not inside `BettingRound`.

### 5.8 `pot_manager.gd`

`PotManager` records total per-hand contributions by seat. It derives pot layers from unique contribution thresholds when a hand is settled.

For each layer:

1. Determine the next contribution threshold.
2. Include chips from every seat that contributed to that layer, including folded seats.
3. Mark only non-folded contributors as eligible winners.
4. Evaluate and award each pot independently.
5. Give an odd chip to the first eligible winner clockwise from the button.

This ledger-based design keeps side-pot construction independent of the order in which all-ins occurred.

### 5.9 `hand_evaluator.gd`

`HandEvaluator` is a pure service. It accepts five to seven cards and returns a comparable `HandRank` value containing:

- category;
- ordered tie-break values;
- the selected five cards for display and diagnostics.

It must not inspect players, stacks, pots, or UI state.

### 5.10 `game_view.gd`

`GameView` is a snapshot, never a live reference to mutable core collections. A factory builds it for a specific viewing seat.

It contains public table state, recipient hole cards, legal actions when applicable, public action history, tournament status, end reason, and only hole cards that are legitimately revealed at showdown. Public action history contains actions and public outcomes, never folded or unrevealed cards.

Collections exposed in a view are duplicated so a bot or UI cannot mutate core state indirectly.

### 5.11 `agents/agent.gd`

`Agent` defines one decision contract:

```gdscript
func choose_action(view: GameView) -> PlayerAction
```

Bot agents return synchronously in v1. They may depend on `GameView` and `PlayerAction`, but not on mutable `Table`, `Player`, `Deck`, or `PotManager` objects.

`HumanAgent` does not read devices or stdin. It acts as an input mailbox with `submit_action()` and `has_pending_action()`. `HandController` returns `WAITING_FOR_HUMAN` while the mailbox is empty and calls the common `choose_action()` contract only when an action is queued. The queued action is still validated by `BettingRound`; parsing it successfully does not make it legal.

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

The `RandomAgent`, `TightPassiveAgent`, and `LooseAggressiveAgent` names required for v1 are thin preset constructors around `BotAgent`, their corresponding decision models, and default profiles. Decision logic lives in model classes rather than those wrappers.

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

### 5.14 `match.gd`

`TournamentMatch` owns the tournament lifecycle:

```text
NOT_STARTED -> RUNNING -> FINISHED
                            |-- end_reason = winner
                            `-- end_reason = player_quit
```

Responsibilities:

- validate and freeze match configuration;
- create and advance hands;
- mark zero-stack players as busted after a completed hand;
- stop when one player has chips and record that seat as winner;
- accept `request_quit()` in every non-finished state;
- expose snapshots and domain events to adapters.

If the human quits during a hand, the hand becomes `ABORTED`. No pot is awarded and no winner is assigned. The final snapshot is diagnostic state only; chip conservation after an aborted hand is not used to determine tournament results.

## 6. Runtime control flow

The central API is step-based:

```gdscript
func start() -> StepResult
func advance_until_blocked() -> StepResult
func submit_human_action(action: PlayerAction) -> StepResult
func request_quit() -> StepResult
func get_view_for(seat: int) -> GameView
```

`advance_until_blocked()` performs automatic dealing, bot actions, street transitions, settlement, and tournament transitions until it reaches one of these boundaries:

- `WAITING_FOR_HUMAN`
- `HAND_COMPLETED`
- `TOURNAMENT_FINISHED`
- `ERROR`

The method may execute several bot turns synchronously, but it must have an iteration guard so a defect cannot freeze the application in an infinite transition loop.

Implementation proceeds through the CLI first. Each runnable core increment is exposed through the CLI and manually tested before the next increment. GUI implementation begins only after a complete single-table tournament is playable through the CLI and the automated and human CLI completion gates in `docs/TASKS.md` pass.

### GUI adapter

1. Create `TournamentMatch` and call `start()`.
2. Render the returned human `GameView`.
3. Enable only actions listed in `legal_actions`.
4. On a button press, create `PlayerAction`, submit it, and render the next result.
5. On `Avslutt`, confirm in the GUI and then call `request_quit()`.

### CLI adapter

1. Follow the same match API.
2. Render snapshots as text.
3. Read stdin only when the result is `WAITING_FOR_HUMAN`.
4. Parse input into `PlayerAction`; parsing errors never reach the core.
5. Map `quit` and `exit` directly to `request_quit()`.

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

Use a typed configuration `Resource` for editable defaults:

- player count;
- small and big blind;
- starting stack;
- RNG seed;
- agent specification per seat: human or bot, plus bot profile ID when applicable;
- tournament mode (`single_table`).

Validate configuration before any chips or cards are created. Invalid configuration returns a descriptive startup error.

An `AgentFactory` in the composition layer creates `HumanAgent` or `BotAgent` instances from seat specifications. For bots, it resolves the configured `BotProfile`, asks `DecisionModelRegistry` for a new model instance, validates the profile's parameter type and ranges, and injects the seat's RNG stream. Core rule modules know neither concrete bot class names nor model IDs.

For deterministic runs, derive separate RNG streams from the configured seed for:

- deck shuffling and initial button selection;
- each randomized bot.

This prevents a bot model or profile change from accidentally changing future card order or another bot's behavior. Match startup fails with a descriptive configuration error for unknown model/profile IDs, mismatched parameter types, invalid ranges, or duplicate seat assignments.

## 9. Recommended libraries and tools

Third-party code should solve a concrete project problem, support Godot 4.7 and GDScript, work headlessly where relevant, use a compatible license, and remain outside the domain model. Pin exact versions in source control and recheck compatibility before changing the Godot minor version.

The review below reflects the ecosystem as of 2026-10-15.

| Library or tool | Decision | Intended use |
| --- | --- | --- |
| [GUT 9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1) | Adopt | Unit and integration tests for GDScript. This release targets Godot 4.7, is MIT-licensed, and includes assertions, parameterized tests, doubles, a command-line runner, and JUnit XML output. |
| [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit) | Adopt as development tooling | Use `gdlint` for static checks and `gdformat --check` for consistent formatting. It is a Python development dependency and must not be included in game exports. Pin a stable `4.x` release when adding the development environment. |
| [GdUnit4 6.2.x](https://github.com/godot-gdunit-labs/gdUnit4) | Alternative, do not install alongside GUT | Also supports Godot 4.7 and offers fluent assertions, mocks, scene testing, and editor integration. Reconsider only before tests are written if the team strongly prefers its API. Maintaining two test frameworks would add cost without useful coverage. |
| [Godot State Charts 0.22.5+](https://github.com/derkork/godot-statecharts/blob/main/CHANGES.md) | Defer; optional for GUI flow only | It supports Godot 4.7 and can simplify declarative, editor-visible UI flows. Do not use it for `TournamentMatch`, `HandController`, or `BettingRound`: its Node-and-signal model would couple deterministic rules to the scene tree and make direct headless tests less clear. |
| Dependency-injection addons | Do not adopt for v1 | Constructor injection and the two composition roots are sufficient. An autoload or service-locator dependency would hide ownership and introduce global state. |
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
- During a non-aborted hand, total player stacks plus total hand contributions equals the tournament's initial chip total.
- After normal settlement, the pot is empty and all chips are in player stacks.
- A busted player has stack 0 and is never dealt into a later hand.
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
  ProjectDescription.md
  TASKS.md
scripts/
  core/
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
    table_controller.gd
  cli/
    cli_app.gd
    command_parser.gd
    text_renderer.gd
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

- deck uniqueness and deterministic shuffle;
- chip stack bounds;
- hand category and tie-break comparisons;
- betting legality, minimum raises, short all-ins, and raise-right reopening;
- side-pot construction, eligibility, split pots, and odd chips;
- seat traversal and heads-up order;
- per-recipient hidden-card filtering.
- decision-model registration and profile parameter validation;
- deterministic decisions for a fixed view, profile, and RNG seed;
- model output limited to the legal actions present in `GameView`.

### 13.2 Integration tests

- scripted complete hands with deterministic cards and actions;
- player elimination followed by a hand that skips the busted seat;
- full tournament ending with one winner;
- two bots using the same model with different profiles and independent RNG streams;
- different models running at different seats without changes to hand or betting orchestration;
- human quit before a hand, during human input, during bot progression, and between hands;
- identical outcomes for a fixed seed and scripted actions through GUI-independent and CLI-independent drivers;
- chip conservation after every completed hand.

Use test doubles for agents and a scripted deck seam in integration tests. Production code still uses the normal `Deck`; the seam exists at construction, not as test branches inside rule logic.

## 14. Extension points

The design intentionally allows later additions without changing poker rules:

- new agents through `AgentFactory`;
- new bot decision models through `DecisionModelRegistry`;
- new parameterized behaviors through typed `DecisionModelParameters` and reusable `BotProfile` Resources;
- blind schedules owned by tournament orchestration;
- replay or audit logs from domain events;
- alternate presentation adapters;
- network input as another human-agent adapter;
- additional tournament formats above `HandController`.

Cash-game accounting, networking, persistence, payouts, antes, and rebuys are outside v1 and must not complicate the first implementation.

## 15. Known trade-offs

- A step-based controller is more explicit than a coroutine-heavy implementation, but it is easier to test and works consistently in GUI and headless modes.
- Snapshot duplication allocates more data, but creates a strong privacy and mutation boundary. This cost is negligible for at most nine seats.
- Domain events add a small amount of structure, but prevent presentation concerns from leaking into the rules engine and provide useful test evidence.
- Fixed blinds can make tournaments long. Blind levels are deliberately deferred because the requirements define fixed blinds for v1.
- GUT and GDScript Toolkit reduce test and style boilerplate but add pinned development dependencies. Neither is part of the exported game or allowed to become a dependency of `scripts/core/`.
- The model/profile split adds a few small types, but avoids a growing hierarchy of nearly identical bot agents and makes behavior tunable without modifying model code.
