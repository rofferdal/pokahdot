extends "res://tests/support/poker_gut_test.gd"


func test_defaults_resolve_to_the_specified_configuration() -> void:
	var defaults: TournamentConfig = TournamentConfig.new()
	var overrides: StartupOverrides = StartupOverrides.new()
	var resolution: ConfigResolution = ConfigResolver.new().resolve(defaults, overrides)

	assert_true(resolution.is_ok())
	var config: ResolvedTournamentConfig = resolution.get_config()
	assert_eq(config.player_count, 6)
	assert_eq(config.starting_stack, 1000)
	assert_eq(config.small_blind, 5)
	assert_eq(config.big_blind, 10)
	assert_eq(config.rng_seed, 0)
	assert_eq(config.tournament_mode, &"single_table")
	assert_false(config.allow_experimental_models)


func test_default_resource_resolves_without_overrides() -> void:
	var defaults := load("res://resources/default_tournament_config.tres") as TournamentConfig
	var resolution: ConfigResolution = ConfigResolver.new().resolve(defaults, null)

	assert_not_null(defaults)
	assert_true(resolution.is_ok())
	assert_eq(resolution.get_config().player_count, 6)
	assert_eq(resolution.get_config().starting_stack, 1000)
	assert_eq(resolution.get_config().small_blind, 5)
	assert_eq(resolution.get_config().big_blind, 10)


func test_default_seat_agents_have_one_human_at_seat_zero() -> void:
	var resolution: ConfigResolution = _resolve_without_overrides()
	var config: ResolvedTournamentConfig = resolution.get_config()
	var seat_agents: Dictionary = config.seat_agents
	var human_seat_count: int = 0

	assert_eq(seat_agents.size(), config.player_count)
	for seat: int in range(config.player_count):
		assert_true(seat_agents.has(seat), "missing default agent for seat %d" % seat)
		var agent_id: StringName = StringName(str(seat_agents[seat]))
		if agent_id == &"human":
			human_seat_count += 1
			assert_eq(seat, 0)

	assert_eq(human_seat_count, 1)


func test_player_count_override_is_applied_independently() -> void:
	var overrides: StartupOverrides = StartupOverrides.new()
	overrides.set_player_count(9)

	var config: ResolvedTournamentConfig = _resolve(overrides).get_config()
	assert_eq(config.player_count, 9)
	assert_eq(config.starting_stack, 1000)
	assert_eq(config.small_blind, 5)
	assert_eq(config.big_blind, 10)


func test_starting_stack_override_is_applied_independently() -> void:
	var overrides: StartupOverrides = StartupOverrides.new()
	overrides.set_starting_stack(777)

	var config: ResolvedTournamentConfig = _resolve(overrides).get_config()
	assert_eq(config.player_count, 6)
	assert_eq(config.starting_stack, 777)
	assert_eq(config.small_blind, 5)
	assert_eq(config.big_blind, 10)


func test_small_blind_override_is_applied_independently() -> void:
	var overrides: StartupOverrides = StartupOverrides.new()
	overrides.set_small_blind(7)

	var config: ResolvedTournamentConfig = _resolve(overrides).get_config()
	assert_eq(config.player_count, 6)
	assert_eq(config.starting_stack, 1000)
	assert_eq(config.small_blind, 7)
	assert_eq(config.big_blind, 10)


func test_big_blind_override_is_applied_independently() -> void:
	var overrides: StartupOverrides = StartupOverrides.new()
	overrides.set_big_blind(20)

	var config: ResolvedTournamentConfig = _resolve(overrides).get_config()
	assert_eq(config.player_count, 6)
	assert_eq(config.starting_stack, 1000)
	assert_eq(config.small_blind, 5)
	assert_eq(config.big_blind, 20)


func test_player_count_boundaries_are_accepted() -> void:
	var minimum: StartupOverrides = StartupOverrides.new()
	minimum.set_player_count(2)
	assert_true(_resolve(minimum).is_ok())
	assert_eq(_resolve(minimum).get_config().player_count, 2)

	var maximum: StartupOverrides = StartupOverrides.new()
	maximum.set_player_count(9)
	assert_true(_resolve(maximum).is_ok())
	assert_eq(_resolve(maximum).get_config().player_count, 9)


func test_player_count_out_of_range_is_rejected() -> void:
	for invalid_count: int in [1, 10]:
		var overrides: StartupOverrides = StartupOverrides.new()
		overrides.set_player_count(invalid_count)
		var resolution: ConfigResolution = _resolve(overrides)
		assert_false(resolution.is_ok(), "player count %d" % invalid_count)
		assert_true(resolution.has_error(ConfigError.Code.PLAYER_COUNT_OUT_OF_RANGE))


func test_non_positive_starting_stack_is_rejected() -> void:
	for invalid_stack: int in [0, -1]:
		var overrides: StartupOverrides = StartupOverrides.new()
		overrides.set_starting_stack(invalid_stack)
		var resolution: ConfigResolution = _resolve(overrides)
		assert_false(resolution.is_ok(), "starting stack %d" % invalid_stack)
		assert_true(resolution.has_error(ConfigError.Code.STARTING_STACK_NOT_POSITIVE))


func test_non_positive_small_blind_is_rejected() -> void:
	for invalid_blind: int in [0, -1]:
		var overrides: StartupOverrides = StartupOverrides.new()
		overrides.set_small_blind(invalid_blind)
		var resolution: ConfigResolution = _resolve(overrides)
		assert_false(resolution.is_ok(), "small blind %d" % invalid_blind)
		assert_true(resolution.has_error(ConfigError.Code.SMALL_BLIND_NOT_POSITIVE))


func test_non_positive_big_blind_is_rejected() -> void:
	for invalid_blind: int in [0, -1]:
		var overrides: StartupOverrides = StartupOverrides.new()
		overrides.set_big_blind(invalid_blind)
		var resolution: ConfigResolution = _resolve(overrides)
		assert_false(resolution.is_ok(), "big blind %d" % invalid_blind)
		assert_true(resolution.has_error(ConfigError.Code.BIG_BLIND_NOT_POSITIVE))


func test_small_blind_greater_than_big_blind_is_rejected() -> void:
	var overrides: StartupOverrides = StartupOverrides.new()
	overrides.set_small_blind(11)
	overrides.set_big_blind(10)
	var resolution: ConfigResolution = _resolve(overrides)

	assert_false(resolution.is_ok())
	assert_true(resolution.has_error(ConfigError.Code.SMALL_BLIND_EXCEEDS_BIG_BLIND))


func test_explicit_zero_is_invalid_while_omission_uses_defaults() -> void:
	var omitted: ConfigResolution = _resolve_without_overrides()
	assert_true(omitted.is_ok())
	assert_eq(omitted.get_config().player_count, 6)
	assert_eq(omitted.get_config().starting_stack, 1000)
	assert_eq(omitted.get_config().small_blind, 5)
	assert_eq(omitted.get_config().big_blind, 10)

	var zero_player_count: StartupOverrides = StartupOverrides.new()
	zero_player_count.set_player_count(0)
	assert_true(_resolve(zero_player_count).has_error(ConfigError.Code.PLAYER_COUNT_OUT_OF_RANGE))

	var zero_stack: StartupOverrides = StartupOverrides.new()
	zero_stack.set_starting_stack(0)
	assert_true(_resolve(zero_stack).has_error(ConfigError.Code.STARTING_STACK_NOT_POSITIVE))

	var zero_small_blind: StartupOverrides = StartupOverrides.new()
	zero_small_blind.set_small_blind(0)
	assert_true(_resolve(zero_small_blind).has_error(ConfigError.Code.SMALL_BLIND_NOT_POSITIVE))

	var zero_big_blind: StartupOverrides = StartupOverrides.new()
	zero_big_blind.set_big_blind(0)
	assert_true(_resolve(zero_big_blind).has_error(ConfigError.Code.BIG_BLIND_NOT_POSITIVE))


func test_starting_stack_smaller_than_big_blind_is_accepted() -> void:
	var overrides: StartupOverrides = StartupOverrides.new()
	overrides.set_starting_stack(5)
	overrides.set_big_blind(10)

	var resolution: ConfigResolution = _resolve(overrides)
	assert_true(resolution.is_ok())
	assert_eq(resolution.get_config().starting_stack, 5)


func test_total_chip_overflow_is_rejected() -> void:
	var overrides: StartupOverrides = StartupOverrides.new()
	overrides.set_player_count(2)
	overrides.set_starting_stack(1 << 62)
	var resolution: ConfigResolution = _resolve(overrides)

	assert_false(resolution.is_ok())
	assert_true(resolution.has_error(ConfigError.Code.TOTAL_CHIPS_OVERFLOW))


func test_snapshot_is_independent_of_defaults_overrides_and_returned_seat_dictionary() -> void:
	var defaults: TournamentConfig = TournamentConfig.new()
	var overrides: StartupOverrides = StartupOverrides.new()
	overrides.set_player_count(2)
	overrides.set_starting_stack(500)
	var resolution: ConfigResolution = ConfigResolver.new().resolve(defaults, overrides)
	var config: ResolvedTournamentConfig = resolution.get_config()
	var returned_seat_agents: Dictionary = config.seat_agents

	defaults.player_count = 9
	defaults.starting_stack = 9999
	defaults.allow_experimental_models = true
	overrides.set_player_count(9)
	overrides.set_starting_stack(9999)
	returned_seat_agents[0] = &"bot"
	returned_seat_agents[1] = &"bot"

	assert_eq(config.player_count, 2)
	assert_eq(config.starting_stack, 500)
	assert_false(config.allow_experimental_models)
	assert_eq(config.seat_agents[0], &"human")


func test_experimental_model_option_is_preserved_in_the_immutable_snapshot() -> void:
	var defaults := TournamentConfig.new()
	var overrides := StartupOverrides.new()
	overrides.set_allow_experimental_models(true)
	var config: ResolvedTournamentConfig = (
		ConfigResolver.new().resolve(defaults, overrides).get_config()
	)

	assert_true(config.allow_experimental_models)
	defaults.allow_experimental_models = false
	overrides.set_allow_experimental_models(false)
	assert_true(config.allow_experimental_models)


func test_unsupported_tournament_mode_is_rejected() -> void:
	var defaults: TournamentConfig = TournamentConfig.new()
	defaults.tournament_mode = &"cash_game"
	var resolution: ConfigResolution = (
		ConfigResolver
		. new()
		. resolve(
			defaults,
			StartupOverrides.new(),
		)
	)

	assert_false(resolution.is_ok())
	assert_true(resolution.has_error(ConfigError.Code.UNSUPPORTED_TOURNAMENT_MODE))


func test_invalid_seat_agents_are_rejected() -> void:
	var defaults: TournamentConfig = TournamentConfig.new()
	defaults.seat_agents = {0: &"bot", 1: &"human"}
	var resolution: ConfigResolution = (
		ConfigResolver
		. new()
		. resolve(
			defaults,
			StartupOverrides.new(),
		)
	)

	assert_false(resolution.is_ok())
	assert_true(resolution.has_error(ConfigError.Code.INVALID_SEAT_AGENTS))


func _resolve_without_overrides() -> ConfigResolution:
	return ConfigResolver.new().resolve(TournamentConfig.new(), StartupOverrides.new())


func _resolve(overrides: StartupOverrides) -> ConfigResolution:
	return ConfigResolver.new().resolve(TournamentConfig.new(), overrides)
