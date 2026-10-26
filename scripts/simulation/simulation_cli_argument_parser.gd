class_name SimulationCliArgumentParser
extends RefCounted

## Strict parser for the non-interactive simulation process adapter.

const OPTIONS_SCRIPT := preload("res://scripts/simulation/simulation_command_options.gd")
const RESULT_SCRIPT := preload("res://scripts/simulation/simulation_cli_parse_result.gd")


func parse(arguments: PackedStringArray) -> RefCounted:
	var errors := PackedStringArray()
	if arguments.is_empty():
		return RESULT_SCRIPT.new(_options(&"help"), errors)
	var command := StringName(arguments[0].to_lower())
	var options: SimulationCommandOptions = _options(command)
	var seen: Dictionary = {}
	var index: int = 1
	while index < arguments.size():
		var flag := String(arguments[index])
		if seen.has(flag):
			errors.append("Option %s was specified more than once." % flag)
			index += 1
			continue
		seen[flag] = true
		if flag in ["--dry-run", "--overwrite"]:
			if flag == "--dry-run":
				options.dry_run = true
			else:
				options.overwrite = true
			index += 1
			continue
		if (
			flag
			not in [
				"--config",
				"--output",
				"--report",
				"--format",
				"--shard",
				"--trace",
				"--trace-sample",
				"--tournament-index",
				"--batch-id",
				"--seed",
				"--tournament-count",
				"--regime-preset",
			]
		):
			errors.append("Unknown simulation option: %s" % flag)
			index += 1
			continue
		if index + 1 >= arguments.size() or String(arguments[index + 1]).begins_with("--"):
			errors.append("Option %s requires a value." % flag)
			index += 1
			continue
		var value := String(arguments[index + 1])
		match flag:
			"--config":
				options.config_path = value
			"--output":
				options.output_path = value
			"--report":
				options.report_path = value
			"--format":
				if value == "json":
					options.format = SimulationCommandOptions.OutputFormat.JSON
				elif value == "text":
					options.format = SimulationCommandOptions.OutputFormat.TEXT
				else:
					errors.append("Format must be json or text.")
			"--shard":
				var shard_result := _parse_shard(value)
				errors.append_array(shard_result.errors)
				if shard_result.shard != null:
					options.shard = shard_result.shard
			"--trace":
				match value:
					"none":
						options.trace_mode = SimulationTraceConfig.Mode.NONE
					"errors":
						options.trace_mode = SimulationTraceConfig.Mode.ERRORS
					"sampled":
						options.trace_mode = SimulationTraceConfig.Mode.SAMPLED
					_:
						errors.append("Trace mode must be none, errors, or sampled.")
			"--trace-sample":
				if not IntegerBounds.fits_signed_64_bit_text(value):
					errors.append("Trace sample count must be an integer.")
				else:
					options.trace_sample_count = value.to_int()
			"--tournament-index":
				if not IntegerBounds.fits_signed_64_bit_text(value):
					errors.append("Tournament index must be an integer.")
				else:
					options.tournament_index = value.to_int()
			"--batch-id":
				options.batch_id = StringName(value)
			"--seed":
				if not IntegerBounds.fits_signed_64_bit_text(value):
					errors.append("Roster manifest seed must be an integer.")
				else:
					options.seed_start = value.to_int()
			"--tournament-count":
				if not IntegerBounds.fits_signed_64_bit_text(value):
					errors.append("Roster manifest tournament count must be an integer.")
				else:
					options.tournament_count = value.to_int()
			"--regime-preset":
				options.regime_preset = StringName(value)
		index += 2
	var option_errors := options.validate()
	errors.append_array(option_errors)
	return RESULT_SCRIPT.new(options if errors.is_empty() else null, errors)


func _options(command: StringName) -> SimulationCommandOptions:
	var options: SimulationCommandOptions = OPTIONS_SCRIPT.new()
	options.command = command
	return options


func _parse_shard(value: String) -> RefCounted:
	var result := {"shard": null, "errors": PackedStringArray()}
	var parts := value.split("/")
	if (
		parts.size() != 2
		or not IntegerBounds.fits_signed_64_bit_text(parts[0])
		or not IntegerBounds.fits_signed_64_bit_text(parts[1])
	):
		result.errors.append("Shard must use the index/count form.")
		return _dictionary_result(result)
	result.shard = SimulationShard.new(parts[0].to_int(), parts[1].to_int())
	return _dictionary_result(result)


func _dictionary_result(value: Dictionary) -> RefCounted:
	var result := ShardParseResult.new()
	result.shard = value.shard
	result.errors = value.errors
	return result


class ShardParseResult:
	extends RefCounted
	var shard: SimulationShard
	var errors: PackedStringArray
