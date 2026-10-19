# Pokahdot Architecture

Status: Implemented through GUI Milestone 4.6 and automated Stratmilestone2; final human release and strategy verification remain
Last updated: 2026-10-19
Requirements source: [`docs/ProjectDescription.md`](ProjectDescription.md)

## 1. Purpose

Pokahdot is a single-table No Limit Texas Hold'em tournament for one human player and automated opponents. The same deterministic game core must support both a Godot `Control`-based GUI and a headless terminal interface.

This document defines module boundaries, state ownership, runtime flow, and the contracts that presentation layers and agents use. `docs/ProjectDescription.md` is normative; this document may refine implementation structure but must not add or change game rules.

The v1 boundary is one single-table tournament with 2–9 participants, equal starting stacks, exactly one human, and bots in every other seat. Before each tournament starts, the human may optionally override the participant count, common starting stack, small blind, and big blind; omitted values use defaults, and the resolved values are then fixed for that tournament. V1 has no cash-game accounting, buy-ins, cash-out, rebuys, antes, rake, blind levels, action timer, network play, or prize payout. Normal play ends only when one participant has chips; a human-requested quit ends it without a winner. The project uses Godot 4, GDScript, and the Compatibility renderer, with no C# or platform-specific plugins.

## 2. Architectural drivers

- One rules implementation for GUI and CLI.
- Correct betting, all-in, side-pot, showdown, and tournament elimination behavior.
- No hidden-card leakage to agents or presentation layers.
- Replaceable bot strategies without changes to poker rules.
- Multiple decision-model implementations with independently tunable, per-seat behavior profiles.
- Optional startup overrides, with defaults, for participant count, common starting stack, and both blind sizes in GUI and CLI.
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
| Build a validated configuration before constructing a match | GUI and CLI can merge optional startup overrides onto defaults without permitting partially configured game state. |
| Compose bots from agent, decision model, and profile | New decision algorithms and per-seat behavior can be added without changing poker rules or duplicating input/error handling. |
| Keep runtime state in core objects, not scenes or Resources | Scenes display state. Configuration and static card data may be Resources; mutable match state stays in dedicated runtime objects. |
| Keep avatar selection in the GUI presentation layer | Avatar identity is visual-only and must not affect `Player`, `GameView`, tournament configuration, or core RNG streams. |
| Keep GUI action pacing in a Resource | Per-seat visual pauses are configurable without putting timers or presentation policy in poker rules. |
| Enforce a 20 px minimum for player-facing GUI text | Controls may reflow for compact screens, but readable text must not be reduced below the desktop opponent-name baseline. |
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
- legal actions, including call size and minimum/maximum bet or raise totals;
- public action history and recipient-safe showdown results, including category, ordered tie-break values, and the selected five cards for each legitimately revealed hand;
- hand number, tournament status, end reason, and optional winner.

Public action history contains only actions and public outcomes. Opponent hole cards appear only at showdown, or at `hand_end` when those cards were actually shown; folded or otherwise unrevealed cards never appear.

Collections exposed in a view are duplicated so a bot or UI cannot mutate core state indirectly.

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

`RandomAgent`, `TightPassiveAgent`, and `LooseAggressiveAgent` are separate concrete classes in the required separate files. Each extends `BotAgent` as a thin preset subclass that supplies its corresponding decision model and default profile; decision logic remains in the model class. The default six-seat setup uses seat 0 for `HumanAgent`, seats 1–5 for these bot classes, and at least two different concrete bot classes.

`StrategyDecisionModel` is the first parameterized strategy model, registered as
`strategy_parameterized`. Its typed `StrategyDecisionModelParameters` Resource
contains inclusive integer percentages for `tight_vs_loose`,
`passive_vs_aggressive`, `call_vs_bet`, and `bluff_rate`. The model receives
only its per-seat injected RNG and recipient-safe `GameView`; it has no access
to opponents' hole cards, the deck, or mutable poker state. Its initial
foundation uses a conservative legal check/call/fold baseline while later
strategy milestones add public hand-potential estimation and wagering policy.
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
When both passive and aggressive actions are
legal, continuation consumes separate injected-RNG rolls: the first applies
`passive_vs_aggressive` as pressure desire and the second applies
`call_vs_bet` as style preference. If only one action class is legal, that
class is selected without a roll. Aggressive continuation uses the estimator's
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

Experimental parameterized models are opt-in. `TournamentConfig` defaults
`allow_experimental_models` to false, `StartupOverrides` can explicitly select
it, and `ResolvedTournamentConfig` freezes the resolved value. The CLI reads
`--allow-experimental-models` only from Godot user arguments after `--`; the
GUI presents an unchecked “Allow experimental models” checkbox and clears it
when returning to startup. Roster selection remains in the CLI and GUI
composition roots: disabled keeps the legacy production roster, while enabled
uses the documented mixed parameterized profiles. Poker-rule modules only see
the constructed agents, never a strategy-selection branch.

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

Implementation proceeds through the CLI first. Each runnable core increment is exposed through the CLI and manually tested before the next increment. GUI implementation begins only after a complete single-table tournament is playable through the CLI and the automated and human CLI completion gates in `docs/TASKS.md` pass.

### GUI adapter

1. Show a startup panel prefilled with 6 participants, 1000 chips, small blind 5, and big blind 10; starting immediately without editing is valid.
2. Validate edits locally for immediate feedback, then create a fresh validated match configuration and construct `TournamentMatch`; do not create players, chips, or cards while the input is invalid.
3. Call `start()` and render the returned human `GameView`: board, pots, stacks, selected fixed blinds, acting seat, hero cards, active/eliminated participants, and final winner when applicable. Opponent cards remain hidden unless the view explicitly reveals them.
4. Enable only actions listed in `legal_actions`; expose Fold, Check/Call, and Bet/Raise with minimum, half-pot, pot, all-in, and free-entry amounts as applicable.
5. On a button press, create `PlayerAction`, submit it, and render the next result.
6. Keep `Quit` available at all times; confirm in the GUI and then call `request_quit()`.

The startup panel and table are views in one scalable `Control`-based main scene with the `canvas_items` stretch mode. Starting a new tournament returns to the startup panel so new values can be chosen.

The table view uses a green felt surface. Its layout has explicit, visually distinct zones for community cards, the current pot, and player wagers; player-seat panels are arranged around that surface. The layout is presentation-only: it reads board, pot, contribution, position, and action data from `GameView` and must not calculate poker state itself. The GUI maps the recipient's seat to the bottom visual position for readability while retaining each core seat ID and rendering its actual dealer, blind, and acting markers. The recipient's stack/status and private hole cards appear in that bottom seat panel; individual cards are rendered as card faces. This visual remapping is local to `PokerTableController` and must not mutate `GameView`, `Table`, player ordering, or poker position semantics.

`GuiActionTimingConfig` at `resources/gui_action_timing_config.tres` controls nonblocking GUI pacing. Its default action pause is two seconds; `pause_seconds_by_seat` can override the duration for each bot seat (or the human seat) independently. The same pause is used after each community-card reveal, while `showdown_pause_seconds` defaults to five seconds before a new hand begins. `GuiActionPacer` uses a scene-tree timer, then asks `TournamentMatch` for exactly one further automatic action. The core exposes that boundary but owns every deal, betting, settlement, and tournament transition; it contains no GUI timer dependency.

The default game viewport is 1920 by 1080, while the `Control` layout must reflow without overlap at supported desktop and mobile aspect ratios. The human recipient is visually anchored at the bottom; this is a presentation mapping only and must not alter core seat identities or poker positions. Desktop seat panels use equal wide dimensions across 2–9 seats, with mirrored left/right placement where applicable; compact layouts may change dimensions but retain readable names, stacks, markers, and cards. Tall mobile portrait surfaces are detected from their aspect ratio, not just logical canvas width, then scale seats, cards, table zones, event history, and action controls from the available surface so a high-DPI Web canvas does not retain desktop-sized controls inside unused felt.

Each seat panel displays one distinct avatar sourced at 32 by 32 pixels and enlarged for readable presentation (currently 56 pixels for opponents and 64 pixels for the human). At GUI tournament creation, a GUI-owned avatar assignment service selects distinct avatar asset IDs without replacement and retains its `seat -> avatar ID` mapping until that tournament ends. It uses a presentation-local RNG stream (injectable and seedable in adapter tests), never the core tournament RNG streams. The mapping is not stored in `Player`, `GameView`, match configuration, domain events, or any core rule module. If the configured avatar catalog cannot provide one unique avatar per seat, GUI startup must fail clearly rather than reuse an avatar silently.

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
- `seat_agents`: complete seat-to-agent-ID mapping with exactly one `HumanAgent` in every valid v1 match;
- `tournament_mode`: only `single_table` is valid in v1.

Configuration crosses the startup boundary through four explicit types:

- `TournamentConfig` is the mutable editor-facing default/template `Resource`; it is never passed to a running match.
- `StartupOverrides` stores each optional user value with a separate presence flag, so an omitted value differs from an explicitly invalid zero. It also carries the explicit experimental-model opt-in.
- `ConfigResolver` merges defaults and overrides, performs authoritative validation, and returns typed field/error codes in `ConfigResolution`.
- `ResolvedTournamentConfig` is a defensive runtime snapshot with read-only public properties and copied collections. `TournamentMatch` will accept only this resolved type.

Changing the template, overrides, or a returned collection after resolution cannot alter the snapshot. This includes `allow_experimental_models`, which is disabled by default and does not change poker rules. Milestone 0 validates scalar values and the structural seat map; model/profile ID lookup remains the responsibility of `AgentFactory` when agents are implemented.

Before every tournament starts, both adapters may collect independent overrides for `player_count`, `starting_stack`, `small_blind`, and `big_blind`. No override is required. Each omitted field retains its value from `default_tournament_config.tres`, allowing a match to start with no supplied values or with only some fields overridden. Explicit values must be integers; participant count must be 2–9, starting stack and both blinds must be positive, and small blind must not exceed big blind. The adapters may perform the same checks for immediate feedback, but core validation of the fully resolved configuration remains authoritative.

The resolved values are copied into a fresh configuration before `TournamentMatch` is constructed and cannot change after `start()`. Blinds remain constant for that tournament. The composition root builds the complete `seat_agents` map from `player_count`: seat 0 is the human and seats 1 through `player_count - 1` are bots. The default six-seat setup uses at least two of the three required concrete bot classes; smaller and larger tables use the same registered presets without changing poker rules.

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
- During a non-aborted hand, total player stacks plus `PotManager`'s contribution ledger (the pot) equals the tournament's initial chip total.
- After normal settlement, the pot is empty and all chips are in player stacks.
- A busted player has stack 0 and is never dealt into a later hand.
- The configured player count, `starting_stack`, `small_blind`, and `big_blind` equal the validated, default-resolved startup values and remain immutable; each live stack starts at `starting_stack` and then changes only through poker actions and pot awards.
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
  POKERCARDS_IN_CLI.md
  ProjectDescription.md
  TASKS.md
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

### 13.2 Integration tests

- scripted complete hands with deterministic cards and actions;
- CLI and GUI startup adapters map omitted, partially overridden, and fully overridden input to equivalent resolved core configurations and keep invalid explicit input from constructing a match;
- CLI snapshots render hero cards, community cards, and legitimately revealed showdown cards in the format defined by `docs/POKERCARDS_IN_CLI.md`, while unrevealed opponent cards remain absent;
- CLI snapshots identify the human consistently as `(you)` before and after actions, across hands, and in final player summaries without marking any bot;
- non-default startup selections produce the selected participant count, equal initial stacks, and fixed blind postings through both adapter-independent drivers;
- player elimination followed by a hand whose deal, button, and blinds skip the busted seat;
- full tournament ending with the only chip-owning seat as winner;
- two bots using the same model with different profiles and independent RNG streams;
- different models running at different seats without changes to hand or betting orchestration;
- human quit before a hand, during a hand, and between hands, always producing `player_quit` with no winner or payout;
- identical outcomes for a fixed seed and scripted actions through GUI-independent and CLI-independent drivers;
- chip conservation after every completed hand.

Use test doubles for agents and a scripted deck seam in integration tests. Production code still uses the normal `Deck`; the seam exists at construction, not as test branches inside rule logic.

## 14. Extension points

The design intentionally allows later, post-v1 additions without changing poker rules:

- new agents through `AgentFactory`;
- new bot decision models through `DecisionModelRegistry`;
- new parameterized behaviors through typed `DecisionModelParameters` and reusable `BotProfile` Resources;
- blind schedules owned by tournament orchestration (v1 keeps blinds fixed);
- replay or audit logs from domain events;
- alternate presentation adapters;
- network input as another human-agent adapter (networking remains excluded from v1);
- additional tournament formats above `HandController`.

Cash-game accounting, networking, persistence, payouts, antes, and rebuys are outside v1 and must not complicate the first implementation.

## 15. Known trade-offs

- A step-based controller is more explicit than a coroutine-heavy implementation, but it is easier to test and works consistently in GUI and headless modes.
- Snapshot duplication allocates more data, but creates a strong privacy and mutation boundary. This cost is negligible for at most nine seats.
- Domain events add a small amount of structure, but prevent presentation concerns from leaking into the rules engine and provide useful test evidence.
- Fixed blinds can make tournaments long. Blind levels are deliberately deferred because the requirements define fixed blinds for v1.
- GUT and GDScript Toolkit reduce test and style boilerplate but add pinned development dependencies. Neither is part of the exported game or allowed to become a dependency of `scripts/core/`.
- The model/profile split adds a few small types, but avoids a growing hierarchy of nearly identical bot agents and makes behavior tunable without modifying model code.
