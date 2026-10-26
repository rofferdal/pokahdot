extends "res://tests/support/poker_gut_test.gd"

const GuiMatchFactoryScript := preload("res://scripts/gui/gui_match_factory.gd")
const GuiStartupConfigAdapterScript := preload("res://scripts/gui/gui_startup_config_adapter.gd")
const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const GuiNameCatalogScript := preload("res://scripts/gui/gui_name_catalog.gd")
const NameAssignmentServiceScript := preload("res://scripts/gui/name_assignment_service.gd")
const AvatarAssignmentServiceScript := preload("res://scripts/gui/avatar_assignment_service.gd")


func test_default_form_starts_with_resolved_defaults() -> void:
	var factory = GuiMatchFactoryScript.new()
	var adapter = GuiStartupConfigAdapterScript.new(TournamentConfig.new(), factory)

	assert_true(adapter.try_start())
	assert_eq(factory.creation_count, 1)
	assert_not_null(adapter.match_instance)
	assert_config(adapter.resolved_config, 6, 1000, 5, 10)
	assert_false(adapter.resolved_config.use_legacy_models)
	assert_eq(_bot_model_ids(adapter.match_instance, 6).count(&"strategy_parameterized"), 5)


func test_legacy_model_opt_in_resolves_and_resets_to_disabled() -> void:
	var adapter = GuiStartupConfigAdapterScript.new()
	adapter.use_legacy_models = true

	assert_true(adapter.try_start())
	assert_true(adapter.resolved_config.use_legacy_models)
	adapter.use_legacy_models = false
	assert_true(adapter.resolved_config.use_legacy_models)

	adapter.reset_to_defaults()
	assert_false(adapter.use_legacy_models)


func test_legacy_model_opt_in_uses_the_shared_split_for_representative_table_sizes() -> void:
	for player_count: int in [2, 6, 9]:
		var defaults := TournamentConfig.new()
		defaults.player_count = player_count
		defaults.rng_seed = 801
		var adapter = GuiStartupConfigAdapterScript.new(defaults)
		adapter.use_legacy_models = true

		assert_true(adapter.try_start(), "player count %d" % player_count)
		var model_ids := _bot_model_ids(adapter.match_instance, player_count)
		var bot_count: int = player_count - 1
		var legacy_count: int = bot_count - model_ids.count(&"strategy_parameterized")
		assert_eq(legacy_count, (bot_count + 1) / 2, "player count %d" % player_count)
		assert_eq(model_ids.count(&"strategy_parameterized"), bot_count - legacy_count)


func test_fixed_seed_reproduces_gui_legacy_model_selection() -> void:
	var defaults := TournamentConfig.new()
	defaults.player_count = 9
	defaults.rng_seed = 802
	var first = GuiStartupConfigAdapterScript.new(defaults)
	var second = GuiStartupConfigAdapterScript.new(defaults)
	first.use_legacy_models = true
	second.use_legacy_models = true

	assert_true(first.try_start())
	assert_true(second.try_start())
	assert_eq(_bot_profile_ids(first.match_instance, 9), _bot_profile_ids(second.match_instance, 9))


func test_fixed_seed_reproduces_gui_name_and_avatar_assignments() -> void:
	var defaults := TournamentConfig.new()
	defaults.player_count = 9
	defaults.rng_seed = 803
	var first = GuiStartupConfigAdapterScript.new(defaults)
	var second = GuiStartupConfigAdapterScript.new(defaults)

	assert_true(first.try_start())
	assert_true(second.try_start())
	assert_eq(first.effective_seed, 803)
	assert_eq(first.name_assignments, second.name_assignments)
	assert_eq(first.avatar_assignments, second.avatar_assignments)
	assert_eq(first.name_assignments[0], "Human")
	var unique_bot_names: Dictionary[String, bool] = {}
	for seat: int in range(1, 9):
		unique_bot_names[first.name_assignments[seat]] = true
	assert_eq(unique_bot_names.size(), 8)


func test_zero_seed_uses_one_effective_seed_for_both_named_presentation_streams() -> void:
	var defaults := TournamentConfig.new()
	defaults.player_count = 6
	defaults.rng_seed = 0
	var seed_provider := func() -> int: return 2468
	var factory = (
		GuiMatchFactoryScript
		. new(
			null,
			null,
			null,
			RngStreamFactory.new(seed_provider),
		)
	)
	var adapter = GuiStartupConfigAdapterScript.new(defaults, factory)

	assert_true(adapter.try_start())
	assert_eq(adapter.effective_seed, 2468)
	var presentation_streams: RngStreams = (
		RngStreamFactory
		. new()
		. create_named(
			2468,
			PackedStringArray(
				[
					NameAssignmentServiceScript.RNG_STREAM_ID,
					AvatarAssignmentServiceScript.RNG_STREAM_ID,
				]
			),
		)
	)
	var expected_names: NameAssignmentResult = (
		NameAssignmentServiceScript
		. new()
		. assign_for_tournament(
			6,
			0,
			presentation_streams.get_rng(NameAssignmentServiceScript.RNG_STREAM_ID),
		)
	)
	var expected_avatars: AvatarAssignmentResult = (
		AvatarAssignmentServiceScript
		. new()
		. assign_for_tournament(
			6,
			presentation_streams.get_rng(AvatarAssignmentServiceScript.RNG_STREAM_ID),
		)
	)
	assert_eq(adapter.name_assignments, expected_names.assignments)
	assert_eq(adapter.avatar_assignments, expected_avatars.assignments)


func test_invalid_gui_name_catalog_stops_creation_with_a_form_error() -> void:
	var invalid_names: PackedStringArray = GuiNameCatalogScript.default_names()
	invalid_names.remove_at(invalid_names.size() - 1)
	var factory = (
		GuiMatchFactoryScript
		. new(
			null,
			NameAssignmentServiceScript.new(GuiNameCatalogScript.new(invalid_names)),
		)
	)
	var adapter = GuiStartupConfigAdapterScript.new(TournamentConfig.new(), factory)

	assert_false(adapter.try_start())
	assert_null(adapter.match_instance)
	assert_null(adapter.resolved_config)
	assert_eq(adapter.name_assignments, {})
	assert_eq(adapter.avatar_assignments, {})
	assert_eq(
		adapter.error_for(&"form"),
		"GUI name catalog must contain exactly 50 names; found 49.",
	)


func test_invalid_gui_avatar_catalog_stops_creation_with_a_form_error() -> void:
	var invalid_catalog := GuiAvatarCatalogScript.new(PackedStringArray(["one_avatar"]))
	var factory = (
		GuiMatchFactoryScript
		. new(
			null,
			null,
			AvatarAssignmentServiceScript.new(invalid_catalog),
		)
	)
	var adapter = GuiStartupConfigAdapterScript.new(TournamentConfig.new(), factory)

	assert_false(adapter.try_start())
	assert_null(adapter.match_instance)
	assert_null(adapter.resolved_config)
	assert_eq(adapter.name_assignments, {})
	assert_eq(adapter.avatar_assignments, {})
	assert_eq(
		adapter.error_for(&"form"),
		"Avatar catalog has 1 assets but 6 seats require distinct avatars.",
	)


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

	adapter.small_blind_text = "5"
	adapter.big_blind_text = "10"
	adapter.starting_stack_text = "9223372036854775808"
	assert_false(adapter.try_start())
	assert_eq(adapter.error_for(&"starting_stack"), "Starting stack must be a whole number.")

	adapter.starting_stack_text = "1000001"
	assert_false(adapter.try_start())
	assert_eq(adapter.error_for(&"starting_stack"), "Starting stack cannot exceed 1000000.")


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


func _bot_model_ids(match_instance: TournamentMatch, player_count: int) -> Array[StringName]:
	var model_ids: Array[StringName] = []
	for seat: int in range(1, player_count):
		var agent := match_instance.get_agent_for_simulation(seat) as BotAgent
		assert_not_null(agent, "seat %d" % seat)
		model_ids.append(agent.model_id)
	return model_ids


func _bot_profile_ids(match_instance: TournamentMatch, player_count: int) -> Array[StringName]:
	var profile_ids: Array[StringName] = []
	for seat: int in range(1, player_count):
		var agent := match_instance.get_agent_for_simulation(seat) as BotAgent
		assert_not_null(agent, "seat %d" % seat)
		profile_ids.append(agent.profile_id)
	return profile_ids
