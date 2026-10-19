extends "res://tests/support/poker_gut_test.gd"

const CliStartupArgumentsScript := preload("res://scripts/cli/cli_startup_arguments.gd")


func test_experimental_models_are_disabled_when_the_flag_is_absent() -> void:
	assert_false(CliStartupArgumentsScript.allow_experimental_models([]))
	assert_false(CliStartupArgumentsScript.allow_experimental_models(["--other-option"]))


func test_experimental_models_are_enabled_by_the_exact_user_flag() -> void:
	assert_true(
		CliStartupArgumentsScript.allow_experimental_models(["--allow-experimental-models"])
	)
	assert_true(
		CliStartupArgumentsScript.allow_experimental_models(
			["--another-option", "--allow-experimental-models"]
		)
	)
