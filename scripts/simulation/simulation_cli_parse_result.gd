class_name SimulationCliParseResult
extends RefCounted

## Typed result of strict simulation CLI argument parsing.

var options: SimulationCommandOptions
var errors: PackedStringArray


func _init(
	parsed_options: SimulationCommandOptions = null, parse_errors: PackedStringArray = []
) -> void:
	options = parsed_options
	errors = parse_errors.duplicate()


func is_ok() -> bool:
	return options != null and errors.is_empty()
