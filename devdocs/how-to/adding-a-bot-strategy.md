# How-To Guide: Adding a New Bot Strategy

This guide walks you through creating a new bot decision model, defining its configuration parameters, saving a profile Resource, and writing a unit test for it.

The `MyBot*` classes below are a proposed extension, not existing repository
APIs or registered models. Create the two scripts before running the test.
Registration and profile-saving snippets are integration fragments; their
`registry` and output directory must already exist.

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
	if not is_finite(aggression_rate) or aggression_rate < 0.0 or aggression_rate > 1.0:
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
	is_configured = errors.is_empty()
	if is_configured:
		_params = parameters as MyBotDecisionModelParameters
		_rng = model_rng
	return errors


func choose_action(view: GameView) -> PlayerAction:
	if not is_configured or view == null or view.legal_actions.is_empty():
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

	if PlayerAction.Kind.FOLD in view.legal_actions:
		return PlayerAction.fold_action()
	return null
```

---

## Step 3: Register the Model

Register the new model ID with `DecisionModelRegistry`:
- For playable games (GUI and CLI), register the script in [`PlayableBotRoster._create_registry()`](../../scripts/core/agents/playable_bot_roster.gd).
- For headless batch simulations, register it in [`SimulationMatchFactory._default_registry()`](../../scripts/simulation/simulation_match_factory.gd).

```gdscript
var registered: bool = registry.register_model(
    &"my_bot",
    preload("res://scripts/core/agents/my_bot_decision_model.gd"),
    preload("res://scripts/core/agents/my_bot_decision_model_parameters.gd")
)
assert(registered, "Model registration failed; check the ID and scripts.")
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

profile.display_name = "My aggressive bot"
var save_error: Error = ResourceSaver.save(
    profile, "res://resources/bot_profiles/my_aggressive_bot.tres"
)
assert(save_error == OK, "Profile save failed: %s" % error_string(save_error))
```

---

## Step 5: Write a Unit Test

Create a unit test in `tests/unit/test_my_bot.gd` using GUT:

```gdscript
extends GutTest

const MyBotModelScript = preload("res://scripts/core/agents/my_bot_decision_model.gd")
const MyBotParamsScript = preload("res://scripts/core/agents/my_bot_decision_model_parameters.gd")


func test_my_bot_checks_when_legal() -> void:
	var model: DecisionModel = MyBotModelScript.new()
	var params: MyBotDecisionModelParameters = MyBotParamsScript.new()
	params.aggression_rate = 0.0 # Never bet
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42

	var errors: PackedStringArray = model.configure(params, rng)
	assert_eq(errors.size(), 0, "Configuration should have no errors")

	# Synthetic unit-test fixture; product adapters receive core-built views.
	var view: GameView = GameView.new()
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CHECK]

	var action: PlayerAction = model.choose_action(view)
	assert_not_null(action, "Bot must return an action")
	assert_eq(action.kind, PlayerAction.Kind.CHECK, "Bot should check when aggression is 0")
```

Run your test:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_my_bot.gd
```

---

## Step 6: Establish an Evaluation Baseline

Each `StrategyDecisionModel`-based profile added to `PlayableBotRoster` uses one
of the 25 product strategic-roster slots. Replace or remove an existing
strategic product profile before adding a 26th one. This product constraint
does not limit profiles in manually authored simulation manifests or
profile-evolution experiments.

Before registering a new strategy profile in `PlayableBotRoster`, export the
current roster so its incumbents are captured as immutable simulation
snapshots:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  export-roster-manifest --output artifacts/roster_before_my_bot.json
```

A new decision model also requires explicit snapshot serialization support in
`SimulationManifest` and matching Python validators before it can appear in a
simulation manifest. Registry registration alone does not extend the manifest
contract. The external evolution tool currently accepts only the four
`strategy_parameterized` genes; it cannot evolve arbitrary new model parameters.
After implementing and testing those boundaries, create a separate manifest
with the candidate and representative incumbents, validate it, and run
simulations. The roster export is intentionally not modified to add
the candidate; preserving the before-state makes a later product-level
comparison reproducible.
