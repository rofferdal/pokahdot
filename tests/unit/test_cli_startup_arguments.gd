extends "res://tests/support/poker_gut_test.gd"

const CliStartupArgumentsScript := preload("res://scripts/cli/cli_startup_arguments.gd")


func test_legacy_models_are_disabled_when_the_flag_is_absent() -> void:
	assert_false(CliStartupArgumentsScript.use_legacy_models([]))
	assert_false(CliStartupArgumentsScript.use_legacy_models(["--other-option"]))
	assert_false(CliStartupArgumentsScript.use_legacy_models(["--allow-experimental-models"]))


func test_legacy_models_are_enabled_by_the_exact_user_flag() -> void:
	assert_true(CliStartupArgumentsScript.use_legacy_models(["--use-legacy-models"]))
	assert_true(
		CliStartupArgumentsScript.use_legacy_models(["--another-option", "--use-legacy-models"])
	)


func test_strict_options_copy_and_validate_configuration_without_mutating_defaults() -> void:
	var defaults := TournamentConfig.new()
	var options := CliStartupArgumentsScript.parse(
		[
			"--players",
			"3",
			"--stack",
			"200",
			"--small-blind",
			"10",
			"--big-blind",
			"20",
			"--seed",
			"-42",
			"--configure",
			"--use-legacy-models"
		]
	)
	assert_true(options.errors.is_empty())
	assert_true(options.configure)
	var configured := options.apply_to(defaults)
	var resolved := ConfigResolver.new().resolve(configured, null)
	assert_true(resolved.is_ok())
	assert_eq(configured.player_count, 3)
	assert_eq(configured.starting_stack, 200)
	assert_eq(configured.small_blind, 10)
	assert_eq(configured.big_blind, 20)
	assert_eq(configured.rng_seed, -42)
	assert_true(configured.use_legacy_models)
	assert_eq(defaults.player_count, 6)
	assert_eq(defaults.rng_seed, 0)


func test_strict_options_reject_unknown_duplicate_missing_fractional_and_overflow() -> void:
	for arguments: PackedStringArray in [
		["--typo"],
		["--seed"],
		["--seed", "1.5"],
		["--seed", "9223372036854775808"],
		["--seed", "-9223372036854775809"],
		["--players", "3", "--players", "4"],
		["--help", "--help"],
		["--seed", "--configure"],
		["--seed", "2", "stray"]
	]:
		assert_false(CliStartupArgumentsScript.parse(arguments).errors.is_empty(), str(arguments))


func test_seed_boundaries_and_help_are_accepted() -> void:
	for seed_text: String in ["0", "-9223372036854775808", "9223372036854775807"]:
		var options := CliStartupArgumentsScript.parse(["--seed", seed_text])
		assert_true(options.errors.is_empty())
		assert_eq(options.apply_to(TournamentConfig.new()).rng_seed, seed_text.to_int())
	assert_true(CliStartupArgumentsScript.parse(["--help"]).show_help)


func test_semantic_option_errors_use_core_config_validation() -> void:
	for arguments: PackedStringArray in [
		["--players", "1"], ["--stack", "1000001"], ["--small-blind", "20"], ["--big-blind", "0"]
	]:
		var options := CliStartupArgumentsScript.parse(arguments)
		assert_false(
			ConfigResolver.new().resolve(options.apply_to(TournamentConfig.new()), null).is_ok()
		)
