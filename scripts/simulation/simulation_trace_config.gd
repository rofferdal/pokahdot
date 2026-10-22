class_name SimulationTraceConfig
extends RefCounted

## Bounded, simulation-only trace policy.

enum Mode { NONE, ERRORS, SAMPLED }

var mode: Mode
var max_entries_per_tournament: int


func _init(trace_mode: Mode = Mode.NONE, entry_limit: int = 0) -> void:
	mode = trace_mode
	max_entries_per_tournament = entry_limit


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if mode < Mode.NONE or mode > Mode.SAMPLED:
		errors.append("Simulation trace mode is invalid.")
	if max_entries_per_tournament < 0:
		errors.append("Simulation trace entry limit cannot be negative.")
	if mode == Mode.SAMPLED and max_entries_per_tournament <= 0:
		errors.append("Sampled traces require a positive entry limit.")
	return errors


func is_enabled() -> bool:
	return mode != Mode.NONE
