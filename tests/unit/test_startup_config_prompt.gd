extends "res://tests/support/poker_gut_test.gd"


func test_immediate_blank_starts_with_all_defaults() -> void:
	var io := FakeCliIO.new()
	io.queue_blank_line()

	var result: StartupPromptResult = _run_prompt(io)

	assert_true(result.is_ready())
	assert_config_values(result.config, 6, 1000, 5, 10)
	assert_true(io.contains_write("Defaults: 6 players, 1000 chips, blinds 5/10"))
	assert_true(io.contains_write("  Players: 6"))
	assert_true(io.contains_write("  Starting stack: 1000"))
	assert_true(io.contains_write("  Blinds: 5/10"))
	assert_true(io.contains_write("  Experimental models: disabled"))


func test_experimental_model_opt_in_is_resolved_and_reported() -> void:
	var io := FakeCliIO.new()
	io.queue_blank_line()

	var result := _run_prompt(io, null, true)

	assert_true(result.is_ready())
	assert_true(result.config.allow_experimental_models)
	assert_true(io.contains_write("  Experimental models: enabled"))


func test_partial_override_keeps_omitted_defaults() -> void:
	var io := FakeCliIO.new()
	io.queue_line("configure")
	io.queue_blank_line()
	io.queue_line("750")
	io.queue_blank_line()
	io.queue_blank_line()

	var result: StartupPromptResult = _run_prompt(io)

	assert_true(result.is_ready())
	assert_config_values(result.config, 6, 750, 5, 10)
	assert_true(io.contains_write("  Players: 6"))
	assert_true(io.contains_write("  Starting stack: 750"))
	assert_true(io.contains_write("  Blinds: 5/10"))


func test_full_valid_overrides_are_reported_in_summary() -> void:
	var io := FakeCliIO.new()
	io.queue_line("configure")
	io.queue_line("9")
	io.queue_line("500")
	io.queue_line("10")
	io.queue_line("20")

	var result: StartupPromptResult = _run_prompt(io)

	assert_true(result.is_ready())
	assert_config_values(result.config, 9, 500, 10, 20)
	assert_true(io.contains_write("  Players: 9"))
	assert_true(io.contains_write("  Starting stack: 500"))
	assert_true(io.contains_write("  Blinds: 10/20"))


func test_short_stack_preset_uses_fixed_values_without_changing_defaults() -> void:
	var defaults := TournamentConfig.new()
	var io := FakeCliIO.new()
	io.queue_line("short-stack")

	var result: StartupPromptResult = _run_prompt(io, defaults)

	assert_true(result.is_ready())
	assert_config_values(result.config, 3, 20, 5, 10)
	assert_eq(result.config.rng_seed, 991)
	assert_eq(defaults.player_count, 6)
	assert_eq(defaults.starting_stack, 1000)
	assert_eq(defaults.small_blind, 5)
	assert_eq(defaults.big_blind, 10)
	assert_eq(defaults.rng_seed, 0)
	assert_true(io.contains_write("Short-stack manual-test preset selected (seed 991)."))


func test_invalid_non_integer_retries_the_same_field() -> void:
	var io := FakeCliIO.new()
	io.queue_line("configure")
	io.queue_line("not-a-number")
	io.queue_line("3")
	io.queue_blank_line()
	io.queue_blank_line()
	io.queue_blank_line()

	var result: StartupPromptResult = _run_prompt(io)

	assert_true(result.is_ready())
	assert_config_values(result.config, 3, 1000, 5, 10)
	assert_eq(io.count_writes_containing("Players [6]:"), 2)
	assert_true(
		io.contains_write("Enter a whole number, leave blank for the default, or type quit.")
	)


func test_integer_outside_signed_64_bit_range_retries_without_conversion() -> void:
	var io := FakeCliIO.new()
	io.queue_line("configure")
	io.queue_line("9223372036854775808")
	io.queue_line("3")
	io.queue_blank_line()
	io.queue_blank_line()
	io.queue_blank_line()

	var result: StartupPromptResult = _run_prompt(io)

	assert_true(result.is_ready())
	assert_config_values(result.config, 3, 1000, 5, 10)
	assert_eq(io.count_writes_containing("Players [6]:"), 2)
	assert_true(
		io.contains_write("Enter a whole number, leave blank for the default, or type quit.")
	)


func test_invalid_resolved_values_report_error_without_exposing_config_before_retry() -> void:
	var io := FakeCliIO.new()
	io.queue_line("configure")
	io.queue_line("3")
	io.queue_line("100")
	io.queue_line("20")
	io.queue_line("10")
	io.queue_line("3")
	io.queue_line("100")
	io.queue_line("5")
	io.queue_line("10")

	var result: StartupPromptResult = _run_prompt(io)

	assert_true(result.is_ready())
	assert_config_values(result.config, 3, 100, 5, 10)
	assert_true(io.contains_write("Invalid tournament configuration:"))
	assert_true(io.contains_write("  small_blind: Small blind cannot exceed big blind."))
	assert_eq(io.count_writes_containing("Tournament configuration:"), 1)
	assert_true(
		(
			io.writes.find("Invalid tournament configuration:")
			< io.writes.find("Tournament configuration:")
		)
	)


func test_quit_returns_quit_without_config() -> void:
	var io := FakeCliIO.new()
	io.queue_line("quit")

	var result: StartupPromptResult = _run_prompt(io)

	assert_eq(result.status, StartupPromptResult.Status.QUIT)
	assert_false(result.is_ready())
	assert_null(result.config)
	assert_true(io.contains_write("Startup cancelled."))


func test_quit_during_configuration_returns_quit_without_config() -> void:
	var io := FakeCliIO.new()
	io.queue_line("configure")
	io.queue_line("quit")

	var result: StartupPromptResult = _run_prompt(io)

	assert_eq(result.status, StartupPromptResult.Status.QUIT)
	assert_false(result.is_ready())
	assert_null(result.config)
	assert_true(io.contains_write("Startup cancelled."))


func test_eof_returns_eof_without_config() -> void:
	var io := FakeCliIO.new()
	io.queue_eof()

	var result: StartupPromptResult = _run_prompt(io)

	assert_eq(result.status, StartupPromptResult.Status.EOF)
	assert_false(result.is_ready())
	assert_null(result.config)
	assert_true(io.contains_write("Input closed before startup completed."))


func test_eof_during_configuration_returns_eof_without_config() -> void:
	var io := FakeCliIO.new()
	io.queue_line("configure")
	io.queue_eof()

	var result: StartupPromptResult = _run_prompt(io)

	assert_eq(result.status, StartupPromptResult.Status.EOF)
	assert_false(result.is_ready())
	assert_null(result.config)
	assert_true(io.contains_write("Input closed before startup completed."))


func test_malformed_defaults_return_error_without_config() -> void:
	var defaults := TournamentConfig.new()
	defaults.small_blind = 20
	defaults.big_blind = 10
	var io := FakeCliIO.new()
	io.queue_blank_line()

	var result: StartupPromptResult = _run_prompt(io, defaults)

	assert_eq(result.status, StartupPromptResult.Status.ERROR)
	assert_false(result.is_ready())
	assert_null(result.config)
	assert_true(io.contains_write("Invalid tournament configuration:"))
	assert_true(io.contains_write("  small_blind: Small blind cannot exceed big blind."))


func _run_prompt(
	io: FakeCliIO,
	defaults: TournamentConfig = null,
	allow_experimental_models: bool = false,
) -> StartupPromptResult:
	var prompt := StartupConfigPrompt.new(io)
	var prompt_defaults: TournamentConfig = defaults
	if prompt_defaults == null:
		prompt_defaults = TournamentConfig.new()
	return prompt.run(prompt_defaults, allow_experimental_models)


func assert_config_values(
	config: ResolvedTournamentConfig,
	expected_player_count: int,
	expected_starting_stack: int,
	expected_small_blind: int,
	expected_big_blind: int,
) -> void:
	assert_not_null(config)
	assert_eq(config.player_count, expected_player_count)
	assert_eq(config.starting_stack, expected_starting_stack)
	assert_eq(config.small_blind, expected_small_blind)
	assert_eq(config.big_blind, expected_big_blind)
