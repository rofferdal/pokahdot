extends "res://tests/support/poker_gut_test.gd"

const PARSER_SCRIPT := preload("res://scripts/simulation/simulation_cli_argument_parser.gd")


func test_parser_accepts_run_dry_run_and_typed_shard_options() -> void:
	var result := (
		PARSER_SCRIPT
		. new()
		. parse(
			PackedStringArray(
				[
					"run",
					"--config",
					"manifest.json",
					"--dry-run",
					"--shard",
					"2/8",
					"--format",
					"json",
					"--trace",
					"sampled",
					"--trace-sample",
					"5",
				]
			)
		)
	)

	assert_true(result.is_ok())
	assert_eq(result.options.command, &"run")
	assert_eq(result.options.shard.index, 2)
	assert_eq(result.options.shard.count, 8)
	assert_eq(result.options.trace_mode, SimulationTraceConfig.Mode.SAMPLED)
	assert_eq(result.options.trace_sample_count, 5)
	assert_true(result.options.dry_run)


func test_parser_rejects_unknown_flags_missing_values_and_invalid_shards() -> void:
	var result := PARSER_SCRIPT.new().parse(
		PackedStringArray(["validate", "--config", "manifest.json", "--unknown", "--shard", "3/0"])
	)

	assert_false(result.is_ok())
	assert_has(result.errors, "Unknown simulation option: --unknown")
	assert_has(result.errors, "Shard count must be positive.")

	result = PARSER_SCRIPT.new().parse(PackedStringArray(["run", "--config"]))
	assert_false(result.is_ok())
	assert_has(result.errors, "Option --config requires a value.")
