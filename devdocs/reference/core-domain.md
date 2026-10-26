# Core Domain Reference

This document provides a concise, instructive reference for the core domain types, data models, and API contracts located in `scripts/core/`.

---

## 1. Domain Entities & State Types

### `TournamentMatch` (`scripts/core/tournament_match.gd`)
The top-level orchestrator of a single-table tournament.

- **State Enum (`TournamentMatch.State`)**:
  - `NOT_STARTED`: Created but uninitialized.
  - `RUNNING`: Tournament in progress across consecutive hands.
  - `FINISHED`: Concluded (either via winner elimination or player quit).
- **Key Methods**:
  - `start(max_transitions: int = 32) -> StepResult`: Initializes the table and begins Hand 1.
  - `advance_until_blocked(max_transitions: int = 32) -> StepResult`: Advances until human input is required, a hand completes, or the tournament finishes.
  - `advance_one_action() -> StepResult`: Advances by a single discrete poker action.
  - `submit_human_action(action: PlayerAction) -> StepResult`: Submits the human move and advances until blocked.
  - `request_quit() -> StepResult`: Instantly aborts the active hand and finishes the tournament without a winner (`end_reason = &"player_quit"`).
  - `get_view_for(seat: int) -> GameView`: Returns the recipient-safe snapshot for a seat.

### `HandController` (`scripts/core/hand_controller.gd`)
Controls the lifecycle and action flow of an individual hand.

- **State Enum (`HandController.State`)**:
  - `NOT_STARTED`: Fresh hand instance.
  - `PREFLOP`: Blinds posted, 2 hole cards dealt, preflop betting active.
  - `FLOP`: 3 community cards dealt, postflop betting active.
  - `TURN`: 4th community card dealt, betting active.
  - `RIVER`: 5th community card dealt, final betting active.
  - `SHOWDOWN`: Active players reveal cards; hands evaluated; pots awarded.
  - `COMPLETE`: Hand settled; chips credited.
  - `ABORTED`: Terminated early (e.g. human quit).

### `Table` (`scripts/core/table.gd`)
Manages table seating and clockwise traversal.

- `players: Array[Player]`: Fixed seat array (length 2–9).
- `button_seat: int`: Current dealer button index.
- `active_seats() -> Array[int]`: Returns seats where `player.busted == false`.
- `advance_button() -> void`: Moves the button to the next active seat clockwise.
- `first_to_act_preflop() -> int`: Left of Big Blind (or Button heads-up).
- `first_to_act_postflop() -> int`: Small Blind (or first active seat clockwise from Button).

### `Player` (`scripts/core/player.gd`)
Represents a participant's runtime state at the table.

- `seat: int`: 0-based seat index.
- `stack: int`: Current chip count (integer only).
- `bet_this_round: int`: Chips committed during the current betting street.
- `total_invested_in_hand: int`: Total chips committed across all streets of this hand.
- `folded: bool`: True if the player folded this hand.
- `all_in: bool`: True if the player has committed their entire stack.
- `busted: bool`: True if the player has 0 chips at hand completion.

---

## 2. Wagering & Pot Settlement

### `PlayerAction` (`scripts/core/player_action.gd`)
Encapsulates an intended move. Amounts use the **target total** convention.

- **Kinds (`PlayerAction.Kind`)**:
  - `FOLD`: Abandon the hand and forfeit previous bets.
  - `CHECK`: Pass the action when `bet_this_round == current_bet`.
  - `CALL`: Match the current wager (`min(stack, current_bet - bet_this_round)`).
  - `BET`: Initiate betting postflop when `current_bet == 0` (min: 1 BB).
  - `RAISE`: Increase the current bet when `current_bet > 0`.
  - `ALL_IN`: Commit entire remaining stack.
- **Factory Helpers**:
  - `PlayerAction.fold_action()`
  - `PlayerAction.check_action()`
  - `PlayerAction.call_action()`
  - `PlayerAction.bet_to(target_amount: int)`
  - `PlayerAction.raise_to(target_amount: int)`
  - `PlayerAction.all_in_action()`

### `BettingRound` (`scripts/core/betting_round.gd`)
Enforces action validity for one betting street.

- `acting_seat: int`: Seat currently holding the action (`Table.NO_SEAT` if complete).
- `current_bet: int`: Highest target total wager on this street.
- `call_amount(seat: int) -> int`: Incremental chips required to call.
- `minimum_wager_total() -> int`: Minimum valid bet or raise total.
- `maximum_wager_total(seat: int) -> int`: Full stack all-in total (`stack + bet_this_round`).
- `legal_actions(seat: int) -> Array[PlayerAction.Kind]`: List of permitted actions for the active seat.
- `can_raise(seat: int) -> bool`: False if an opponent's under-sized all-in did not reopen raising.

### `PotManager` (`scripts/core/pot_manager.gd`)
Tracks contributions and derives main and side pots.

- `contributions: Dictionary[int, int]`: Maps seat indices to total hand chips invested.
- `derive_pots(players: Array[Player]) -> Array[PotLayer]`: Breaks contributions into layered pots.
- `award_showdown(players, hand_ranks, button_seat) -> Array[PotAward]`: Distributes chips to best eligible hands, handling ties and odd chips.

---

## 3. Cards & Evaluation

### `CardData` (`scripts/core/card_data.gd`)
Immutable `Resource` representing a playing card.

- `card_id: StringName`: Unique ID, e.g., `&"As"`, `&"Td"`, `&"2c"`.
- `rank: int`: Numeric value (2–14, where Ace = 14).
- `suit: StringName`: `&"clubs"`, `&"diamonds"`, `&"hearts"`, or `&"spades"`.

### `HandEvaluator` (`scripts/core/hand_evaluator.gd`)
Stateless evaluator for Texas Hold'em.

- `evaluate(cards: Array[CardData]) -> HandRank`: Takes 5 to 7 cards and returns the strongest 5-card combination.

### `HandRank` (`scripts/core/hand_rank.gd`)
Strongly typed evaluation outcome.

- **Categories (`HandRank.Category`)**:
  `HIGH_CARD`, `ONE_PAIR`, `TWO_PAIR`, `THREE_OF_A_KIND`, `STRAIGHT`, `FLUSH`, `FULL_HOUSE`, `FOUR_OF_A_KIND`, `STRAIGHT_FLUSH`, `ROYAL_FLUSH`.
- `compare_to(other: HandRank) -> int`:
  Returns `> 0` if stronger, `< 0` if weaker, `0` if tied. Handles kickers automatically.

---

## 4. Snapshots & Views

### `StepResult` (`scripts/core/step_result.gd`)
The return value of all stepping operations (`start`, `advance_until_blocked`, etc.).

- **Statuses (`StepResult.Status`)**:
  - `WAITING_FOR_HUMAN`: Engine paused; waiting for human input at `acting_seat`.
  - `HAND_COMPLETED`: Hand finished; chips awarded; waiting to advance to next hand.
  - `TOURNAMENT_FINISHED`: Only one player remains or human quit.
  - `YIELDED`: Engine stepped one discrete transition; ready to step again.
  - `ERROR`: An invalid operation or configuration error occurred.

### `GameView` (`scripts/core/game_view.gd`)
The recipient-specific, read-only snapshot provided to agents and UI.

| Property | Type | Description |
| :--- | :--- | :--- |
| `street` | `StringName` | `&"preflop"`, `&"flop"`, `&"turn"`, `&"river"`. |
| `hero_seat` | `int` | Seat index of the recipient. |
| `hero_hole_cards` | `Array[CardData]` | Recipient's hole cards (only non-empty for hero). |
| `revealed_hole_cards` | `Dictionary[int, Array]` | Showdown cards (empty until showdown). |
| `community_cards` | `Array[CardData]` | Public face-up board cards. |
| `acting_seat` | `int` | Seat whose turn it is to act. |
| `legal_actions` | `Array[PlayerAction.Kind]` | Allowed actions for the acting seat. |
| `pot_amount` | `int` | Total chips in the pot. |
| `call_amount` | `int` | Cost to call for the hero. |
| `minimum_wager_total`| `int` | Minimum bet/raise total. |
| `maximum_wager_total`| `int` | All-in wager total. |
| `seats` | `Array[PlayerView]` | Public info for all seats (stacks, bets, folded/busted status). |

GUI and strategic-agent pot-size presets derive target totals entirely from
this recipient-safe snapshot. With pot `P`, the recipient's existing street
wager `H`, and call amount `C`, an exact pot-sized target is `H + P + 2C`.
This is a No Limit sizing convenience; `BettingRound` still validates the
result against `minimum_wager_total`, `maximum_wager_total`, and legal actions.

---

## 5. Agent, Strategy & Catalog Domain

### `PlayableBotRoster` (`scripts/core/agents/playable_bot_roster.gd`)
The centralized, curated bot catalog used by GUI and CLI presentation layers.

- **Constants**:
  - `ROSTER_VERSION: StringName`: Current catalog release version (`&"curated_v2"`).
  - `DEFAULT_PROFILE_PATHS`: Array of default `.tres` resource paths loaded into the roster.
  - `MAX_PLAYABLE_BOT_COUNT`: Maximum bots selectable for one tournament (8).
  - `MAX_STRATEGIC_PROFILE_COUNT`: Maximum `StrategyDecisionModel`-based profiles in the playable product roster (25). This bound does not apply to non-strategic profiles or to simulation manifests.
- **Key Methods**:
  - `validate() -> PackedStringArray`: Validates catalog bounds, profile uniqueness, model creation, and that the strategic family is non-empty.
  - `is_strategic_profile(profile: BotProfile) -> bool`: Classifies a profile from its registered model implementation. Only `StrategyDecisionModel` profiles are strategic; all others are legacy heuristics.
  - `select(count: int, rng: RandomNumberGenerator, use_legacy_models: bool = false) -> PlayableBotRosterSelection`: Deterministically selects strategic profiles only by default. With legacy models enabled, it selects `ceil(count / 2)` legacy profiles and the remainder strategic, exhausting each assigned family before repeating a profile.
  - `create_bot(profile: BotProfile, rng: RandomNumberGenerator) -> AgentCreationResult`: Instantiates a concrete `BotAgent` from a profile.
  - `get_catalog_profiles() -> Array[BotProfile]`: Returns a deep-copied snapshot of every catalog profile. This is the only catalog-reading API used to bootstrap a roster simulation manifest; neither the manifest nor a simulation can retain a live catalog Resource.
  - `get_profile_ids() -> Array[StringName]`: Returns all catalog profile IDs.
  - `get_roster_version() -> StringName`: Returns current roster version.

### `PlayableBotRosterSelection` (`scripts/core/agents/playable_bot_roster_selection.gd`)
Result object returned by `PlayableBotRoster.select()`.

- `is_ok() -> bool`: True if selection completed without errors.
- `get_profiles() -> Array[BotProfile]`: Returns deep copies of the selected profiles.
- `errors: PackedStringArray`: Diagnostic error messages if selection failed.

### `DecisionModelRegistry` (`scripts/core/agents/decision_model_registry.gd`)
Registry mapping model IDs (`StringName`) to their GDScript model and parameter constructors.

- `register_model(model_id, model_script, parameters_script) -> void`
- `create_model(model_id) -> DecisionModel`
- `create_parameters(model_id) -> DecisionModelParameters`

### `BotProfile` (`scripts/core/agents/bot_profile.gd`)
Custom `Resource` linking a stable profile identifier, model ID, display name, and parameter resource.

- `profile_id: StringName`: e.g. `&"balanced"`, `&"nit_caller"`, `&"solid_tag__v1"`.
- `model_id: StringName`: e.g. `&"strategy_parameterized"`, `&"random"`.
- `display_name: String`: Human-readable label.
- `parameters: DecisionModelParameters`: Typed parameter payload.
