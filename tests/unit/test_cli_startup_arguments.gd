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
