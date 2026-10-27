class_name SimulationCommandOptions
extends RefCounted

## Typed options passed from the simulation command adapter.

enum OutputFormat { JSON, TEXT }

var command: StringName = &""
var config_path: String = ""
var report_path: String = ""
var output_path: String = ""
var shard: SimulationShard = SimulationShard.new()
var format: OutputFormat = OutputFormat.JSON
var trace_mode: SimulationTraceConfig.Mode = SimulationTraceConfig.Mode.ERRORS
var trace_sample_count: int = 0
var dry_run: bool = false
var overwrite: bool = false
var checkpoint_path: String = ""
var resume: bool = false
var tournament_index: int = -1
var batch_id: StringName = &""
var seed_start: int = SimulationRosterManifestSettings.DEFAULT_SEED_START
var tournament_count: int = SimulationRosterManifestSettings.DEFAULT_TOURNAMENT_COUNT
var regime_preset: StringName = &"standard"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if (
		command
		not in [&"help", &"validate", &"run", &"inspect", &"replay", &"export-roster-manifest"]
	):
		errors.append("Unknown simulation command.")
	if shard == null:
		errors.append("A simulation shard is required.")
	else:
		errors.append_array(shard.validate())
	if format < OutputFormat.JSON or format > OutputFormat.TEXT:
		errors.append("Simulation output format is invalid.")
	if (
		trace_mode < SimulationTraceConfig.Mode.NONE
		or trace_mode > SimulationTraceConfig.Mode.SAMPLED
	):
		errors.append("Simulation trace mode is invalid.")
	if trace_sample_count < 0:
		errors.append("Simulation trace sample count cannot be negative.")
	if trace_mode == SimulationTraceConfig.Mode.SAMPLED and trace_sample_count <= 0:
		errors.append("Sampled traces require a positive sample count.")
	if command in [&"validate", &"run"] and config_path.is_empty():
		errors.append("The simulation command requires a manifest path.")
	if command == &"run" and not dry_run and output_path.is_empty():
		errors.append("The run command requires an output path.")
	if command == &"inspect" and report_path.is_empty():
		errors.append("The inspect command requires a report path.")
	if command == &"replay":
		if report_path.is_empty():
			errors.append("The replay command requires a report path.")
		if tournament_index < 0:
			errors.append("Replay requires a non-negative tournament index.")
	if command != &"run" and (resume or not checkpoint_path.is_empty()):
		errors.append("Checkpoint and resume options are supported only by run.")
	if dry_run and resume:
		errors.append("Resume cannot be combined with dry-run.")
	if command != &"run" and dry_run:
		errors.append("Dry-run is supported only by the run command.")
	if command == &"export-roster-manifest":
		if output_path.is_empty():
			errors.append("Exporting a roster manifest requires an output path.")
		if seed_start == 0:
			errors.append("Roster manifest seed must be non-zero.")
		if tournament_count <= 0:
			errors.append("Roster manifest tournament count must be positive.")
		if regime_preset != &"standard":
			errors.append("Roster manifest regime preset must be standard.")
	return errors


func trace_config() -> SimulationTraceConfig:
	return SimulationTraceConfig.new(trace_mode, trace_sample_count)
