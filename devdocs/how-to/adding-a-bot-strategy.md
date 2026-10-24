# How-To Guide: Adding a New Bot Strategy

This guide walks you through creating a new bot decision model, defining its configuration parameters, saving a profile Resource, and writing a unit test for it.

---

## Architecture Overview

A bot strategy consists of three components:

1. **Parameters Resource** (`DecisionModelParameters`): Strongly typed variables configuring the strategy (e.g., bluff frequency, minimum call strength).
2. **Decision Model** (`DecisionModel`): The GDScript algorithm that inspects a `GameView` and returns a `PlayerAction`.
3. **Bot Profile** (`BotProfile`): An editor-saved `.tres` resource storing specific parameter values under a unique profile ID.

---

## Step 1: Create the Parameters Class

Create a new file in `scripts/core/agents/` extending `DecisionModelParameters`:

```gdscript
# scripts/core/agents/my_bot_decision_model_parameters.gd
class_name MyBotDecisionModelParameters
extends DecisionModelParameters

@export_range(0.0, 1.0, 0.01) var aggression_rate: float = 0.5
@export var min_call_chips: int = 50


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if aggression_rate < 0.0 or aggression_rate > 1.0:
		errors.append("aggression_rate must be between 0.0 and 1.0.")
	if min_call_chips < 0:
		errors.append("min_call_chips cannot be negative.")
	return errors
```

---

## Step 2: Implement the Decision Model

Create a script extending `DecisionModel`. Implement `configure()` and `choose_action()`:

```gdscript
# scripts/core/agents/my_bot_decision_model.gd
class_name MyBotDecisionModel
extends DecisionModel

var _params: MyBotDecisionModelParameters
var _rng: RandomNumberGenerator


func configure(
	parameters: DecisionModelParameters, model_rng: RandomNumberGenerator
) -> PackedStringArray:
	var errors := super.configure(parameters, model_rng)
	if not (parameters is MyBotDecisionModelParameters):
		errors.append("Expected MyBotDecisionModelParameters.")
	if errors.is_empty():
		_params = parameters as MyBotDecisionModelParameters
		_rng = model_rng
		is_configured = true
	return errors


func choose_action(view: GameView) -> PlayerAction:
	if view == null or view.legal_actions.is_empty():
		return null

	# If check is free, take it
	if PlayerAction.Kind.CHECK in view.legal_actions:
		# Maybe bet aggressively based on parameter
		if PlayerAction.Kind.BET in view.legal_actions and _rng.randf() < _params.aggression_rate:
			return PlayerAction.bet_to(view.minimum_wager_total)
		return PlayerAction.check_action()

	# Facing a bet: call if it doesn't exceed our threshold
	if PlayerAction.Kind.CALL in view.legal_actions:
		if view.call_amount <= _params.min_call_chips:
			return PlayerAction.call_action()

	# Otherwise fold
	return PlayerAction.fold_action()
```

---

## Step 3: Register the Model

Register the new model ID with `DecisionModelRegistry`:
- For playable games (GUI and CLI), register the script in [`PlayableBotRoster._create_registry()`](file:///Users/rofferdal/git/pokahdot/scripts/core/agents/playable_bot_roster.gd).
- For headless batch simulations, register it in [`SimulationMatchFactory._default_registry()`](file:///Users/rofferdal/git/pokahdot/scripts/simulation/simulation_match_factory.gd).

```gdscript
registry.register_model(
    &"my_bot",
    preload("res://scripts/core/agents/my_bot_decision_model.gd"),
    preload("res://scripts/core/agents/my_bot_decision_model_parameters.gd")
)
```

---

## Step 4: Create a Profile Resource

You can create a `.tres` resource in Godot or via GDScript:

```gdscript
var params := MyBotDecisionModelParameters.new()
params.aggression_rate = 0.75
params.min_call_chips = 100

var profile := BotProfile.new()
profile.profile_id = &"my_aggressive_bot"
profile.model_id = &"my_bot"
profile.parameters = params

ResourceSaver.save(profile, "res://resources/bot_profiles/my_aggressive_bot.tres")
```

---

## Step 5: Write a Unit Test

Create a unit test in `tests/unit/test_my_bot.gd` using GUT:

```gdscript
extends GutTest

const MyBotModelScript = preload("res://scripts/core/agents/my_bot_decision_model.gd")
const MyBotParamsScript = preload("res://scripts/core/agents/my_bot_decision_model_parameters.gd")


func test_my_bot_checks_when_legal() -> void:
	var model = MyBotModelScript.new()
	var params = MyBotParamsScript.new()
	params.aggression_rate = 0.0 # Never bet
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	var errors = model.configure(params, rng)
	assert_eq(errors.size(), 0, "Configuration should have no errors")

	# Mock a GameView with CHECK and FOLD legal
	var view = GameView.new()
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CHECK]

	var action = model.choose_action(view)
	assert_not_null(action, "Bot must return an action")
	assert_eq(action.kind, PlayerAction.Kind.CHECK, "Bot should check when aggression is 0")
```

Run your test:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_my_bot.gd
```

---

## Step 6: Establish an Evaluation Baseline

Before registering a new strategy profile in `PlayableBotRoster`, export the
current roster so its incumbents are captured as immutable simulation
snapshots:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  export-roster-manifest --output artifacts/roster_before_my_bot.json
```

After registering the model in both registries, create a separate manifest
that includes `my_aggressive_bot` and representative incumbents, validate it,
and run simulations. The roster export is intentionally not modified to add
the candidate; preserving the before-state makes a later product-level
comparison reproducible.
