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


func test_parser_accepts_typed_roster_manifest_export_options() -> void:
	var result := (
		PARSER_SCRIPT
		. new()
		. parse(
			PackedStringArray(
				[
					"export-roster-manifest",
					"--output",
					"roster.json",
					"--overwrite",
					"--batch-id",
					"baseline",
					"--seed",
					"801",
					"--tournament-count",
					"160",
					"--regime-preset",
					"standard",
					"--format",
					"text",
				]
			)
		)
	)

	assert_true(result.is_ok())
	assert_eq(result.options.command, &"export-roster-manifest")
	assert_eq(result.options.output_path, "roster.json")
	assert_true(result.options.overwrite)
	assert_eq(result.options.batch_id, &"baseline")
	assert_eq(result.options.seed_start, 801)
	assert_eq(result.options.tournament_count, 160)
	assert_eq(result.options.regime_preset, &"standard")
	assert_eq(result.options.format, SimulationCommandOptions.OutputFormat.TEXT)


func test_parser_rejects_invalid_or_incomplete_roster_manifest_export_options() -> void:
	var result := PARSER_SCRIPT.new().parse(PackedStringArray(["export-roster-manifest"]))

	assert_false(result.is_ok())
	assert_has(result.errors, "Exporting a roster manifest requires an output path.")

	result = (
		PARSER_SCRIPT
		. new()
		. parse(
			PackedStringArray(
				[
					"export-roster-manifest",
					"--output",
					"roster.json",
					"--seed",
					"zero",
					"--tournament-count",
					"-1",
					"--regime-preset",
					"heads-up",
					"--output",
					"duplicate.json",
				]
			)
		)
	)

	assert_false(result.is_ok())
	assert_has(result.errors, "Roster manifest seed must be an integer.")
	assert_has(result.errors, "Roster manifest tournament count must be positive.")
	assert_has(result.errors, "Roster manifest regime preset must be standard.")
	assert_has(result.errors, "Option --output was specified more than once.")

	result = (
		PARSER_SCRIPT
		. new()
		. parse(
			PackedStringArray(
				[
					"export-roster-manifest",
					"--output",
					"roster.json",
					"--seed",
					"9223372036854775808",
				]
			)
		)
	)
	assert_false(result.is_ok())
	assert_has(result.errors, "Roster manifest seed must be an integer.")


func test_parser_accepts_explicit_checkpoint_resume_and_rejects_wrong_commands() -> void:
	var parsed := (
		PARSER_SCRIPT
		. new()
		. parse(
			PackedStringArray(
				[
					"run",
					"--config",
					"manifest.json",
					"--output",
					"report.json",
					"--checkpoint",
					"localtmp/experiment",
					"--resume",
				]
			)
		)
	)
	assert_true(parsed.is_ok())
	assert_true(parsed.options.resume)
	assert_eq(parsed.options.checkpoint_path, "localtmp/experiment")
	for command: String in ["help", "validate", "inspect", "replay", "export-roster-manifest"]:
		parsed = (
			PARSER_SCRIPT
			. new()
			. parse(
				PackedStringArray(
					[
						command,
						"--config",
						"manifest.json",
						"--checkpoint",
						"somewhere",
						"--resume",
					]
				)
			)
		)
		assert_false(parsed.is_ok(), command)
		assert_has(parsed.errors, "Checkpoint and resume options are supported only by run.")


func test_parser_rejects_resume_dry_run_and_missing_checkpoint_value() -> void:
	var parsed := (
		PARSER_SCRIPT
		. new()
		. parse(
			PackedStringArray(
				[
					"run",
					"--config",
					"manifest.json",
					"--dry-run",
					"--resume",
				]
			)
		)
	)
	assert_false(parsed.is_ok())
	assert_has(parsed.errors, "Resume cannot be combined with dry-run.")
	parsed = (
		PARSER_SCRIPT
		. new()
		. parse(
			PackedStringArray(
				[
					"run",
					"--config",
					"manifest.json",
					"--output",
					"report.json",
					"--checkpoint",
				]
			)
		)
	)
	assert_false(parsed.is_ok())
	assert_has(parsed.errors, "Option --checkpoint requires a value.")
