extends "res://tests/support/poker_gut_test.gd"

const GuiMatchFactoryScript := preload("res://scripts/gui/gui_match_factory.gd")
const GuiStartupConfigAdapterScript := preload("res://scripts/gui/gui_startup_config_adapter.gd")


func test_default_form_starts_with_resolved_defaults() -> void:
	var factory = GuiMatchFactoryScript.new()
	var adapter = GuiStartupConfigAdapterScript.new(TournamentConfig.new(), factory)

	assert_true(adapter.try_start())
	assert_eq(factory.creation_count, 1)
	assert_not_null(adapter.match_instance)
	assert_config(adapter.resolved_config, 6, 1000, 5, 10)


func test_each_partial_override_preserves_the_other_defaults() -> void:
	var cases: Array[Dictionary] = [
		{"field": &"player_count", "value": "3", "expected": [3, 1000, 5, 10]},
		{"field": &"starting_stack", "value": "750", "expected": [6, 750, 5, 10]},
		{"field": &"small_blind", "value": "7", "expected": [6, 1000, 7, 10]},
		{"field": &"big_blind", "value": "20", "expected": [6, 1000, 5, 20]},
	]
	for test_case: Dictionary in cases:
		var adapter = GuiStartupConfigAdapterScript.new()
		adapter.set("%s_text" % test_case.field, test_case.value)

		assert_true(adapter.try_start(), str(test_case.field))
		var expected: Array = test_case.expected
		assert_config(adapter.resolved_config, expected[0], expected[1], expected[2], expected[3])


func test_full_valid_override_creates_a_fresh_resolved_configuration() -> void:
	var defaults := TournamentConfig.new()
	var adapter = GuiStartupConfigAdapterScript.new(defaults)
	adapter.player_count_text = "9"
	adapter.starting_stack_text = "500"
	adapter.small_blind_text = "10"
	adapter.big_blind_text = "20"

	assert_true(adapter.try_start())
	assert_config(adapter.resolved_config, 9, 500, 10, 20)
	defaults.starting_stack = 1
	assert_eq(adapter.resolved_config.starting_stack, 500)


func test_invalid_text_and_cross_field_values_show_inline_errors_without_match_creation() -> void:
	var factory = GuiMatchFactoryScript.new()
	var adapter = GuiStartupConfigAdapterScript.new(TournamentConfig.new(), factory)
	adapter.starting_stack_text = "chips"

	assert_false(adapter.try_start())
	assert_eq(adapter.error_for(&"starting_stack"), "Starting stack must be a whole number.")
	assert_eq(factory.creation_count, 0)
	assert_null(adapter.match_instance)

	adapter.starting_stack_text = "1000"
	adapter.small_blind_text = "20"
	adapter.big_blind_text = "10"
	assert_false(adapter.try_start())
	assert_eq(adapter.error_for(&"small_blind"), "Small blind cannot exceed big blind.")
	assert_eq(factory.creation_count, 0)
	assert_null(adapter.match_instance)


func assert_config(
	config: ResolvedTournamentConfig,
	player_count: int,
	starting_stack: int,
	small_blind: int,
	big_blind: int,
) -> void:
	assert_not_null(config)
	assert_eq(config.player_count, player_count)
	assert_eq(config.starting_stack, starting_stack)
	assert_eq(config.small_blind, small_blind)
	assert_eq(config.big_blind, big_blind)
