extends "res://tests/support/poker_gut_test.gd"

const STRATEGY_MODEL_SCRIPT := preload("res://scripts/core/agents/strategy_decision_model.gd")
const STRATEGY_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)


func test_strategy_profiles_have_documented_ids_model_and_parameters() -> void:
	var expected_profiles := {
		&"nit_caller": [15, 20, 20, 2],
		&"tight_aggressive": [30, 75, 70, 8],
		&"loose_passive": [75, 25, 15, 5],
		&"loose_aggressive": [80, 85, 85, 22],
		&"balanced": [50, 55, 50, 12],
	}

	for profile_id: StringName in expected_profiles:
		var profile := load("res://resources/bot_profiles/%s.tres" % profile_id) as BotProfile
		var parameters := profile.parameters as DecisionModelParameters

		assert_not_null(profile)
		assert_eq(profile.profile_id, profile_id)
		assert_eq(profile.model_id, &"strategy_parameterized")
		assert_eq(
			[
				parameters.get("tight_vs_loose"),
				parameters.get("passive_vs_aggressive"),
				parameters.get("call_vs_bet"),
				parameters.get("bluff_rate"),
			],
			expected_profiles[profile_id]
		)


func test_registry_creates_fresh_strategy_models_for_strategy_parameters() -> void:
	var registry := DecisionModelRegistry.new()

	assert_true(
		registry.register_model(
			&"strategy_parameterized", STRATEGY_MODEL_SCRIPT, STRATEGY_PARAMETERS_SCRIPT
		)
	)
	assert_true(
		registry.accepts_parameters(&"strategy_parameterized", _balanced_profile().parameters)
	)
	assert_false(
		registry.accepts_parameters(&"strategy_parameterized", RandomDecisionModelParameters.new())
	)
	assert_ne(
		registry.create_model(&"strategy_parameterized"),
		registry.create_model(&"strategy_parameterized")
	)


func _balanced_profile() -> BotProfile:
	return load("res://resources/bot_profiles/balanced.tres") as BotProfile
