extends "res://tests/support/poker_gut_test.gd"

const StrategyParametersScript := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)


func test_every_strategy_parameter_accepts_inclusive_boundaries() -> void:
	for field_name: StringName in _field_names():
		for boundary: int in [0, 100]:
			var parameters := StrategyParametersScript.new()
			parameters.set(field_name, boundary)

			assert_true(
				parameters.validate().is_empty(), "%s must accept %d." % [field_name, boundary]
			)


func test_every_strategy_parameter_rejects_negative_values() -> void:
	for field_name: StringName in _field_names():
		var parameters := StrategyParametersScript.new()
		parameters.set(field_name, -1)

		assert_false(parameters.validate().is_empty(), "%s must reject -1." % field_name)


func test_every_strategy_parameter_rejects_values_above_100() -> void:
	for field_name: StringName in _field_names():
		var parameters := StrategyParametersScript.new()
		parameters.set(field_name, 101)

		assert_false(parameters.validate().is_empty(), "%s must reject 101." % field_name)


func _field_names() -> Array[StringName]:
	return [
		&"tight_vs_loose",
		&"passive_vs_aggressive",
		&"call_vs_raise",
		&"bluff_rate",
	]
