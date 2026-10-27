class_name SimulationCheckpointStore
extends RefCounted

## Durable, per-index simulation records. Memory is bounded by one tournament.
## Temporary siblings are never read as completed evidence.

const SCHEMA_VERSION: int = 1
const HEADER_NAME: String = "header.json"
const TRACE_STRING_FIELDS: Array[String] = [
	"profile_id",
	"street",
	"selected_branch",
	"hand_potential_band",
	"termination_reason",
	"message",
]
const TRACE_INTEGER_FIELDS: Array[String] = [
	"kind",
	"tournament_index",
	"hand_number",
	"seat",
	"action_kind",
	"action_amount",
	"winner_seat",
]
const REPORT_SCRIPT := preload("res://scripts/simulation/simulation_report.gd")

var error_message: String = ""
var started_at: String = ""
var _directory: String
var _identity: Dictionary
var _identity_checksum: String
var _metadata: Dictionary


func initialize(
	directory: String,
	manifest: SimulationManifest,
	shard: SimulationShard,
	provenance: Dictionary,
	trace: SimulationTraceConfig,
	resume: bool,
) -> bool:
	_directory = ProjectSettings.globalize_path(directory)
	_identity = {
		"manifest_checksum": manifest.checksum(),
		"execution_provenance": provenance.duplicate(true),
		"shard": shard.to_dictionary(),
		"trace":
		{"mode": trace.mode, "max_entries_per_tournament": trace.max_entries_per_tournament},
	}
	_identity_checksum = _hash(JSON.stringify(_identity, "", true))
	var header_path := _directory.path_join(HEADER_NAME)
	if resume:
		var header := _read_dictionary(header_path)
		if header.is_empty():
			return false
		if (
			header.size() != 4
			or header.get("checkpoint_schema_version") != SCHEMA_VERSION
			or (not _identity_matches(header.get("identity")))
			or header.get("identity_checksum") != _identity_checksum
			or typeof(header.get("started_at")) != TYPE_STRING
		):
			return _fail(
				"Checkpoint identity does not match manifest, provenance, shard or trace settings."
			)
		started_at = header.started_at
	else:
		if FileAccess.file_exists(header_path):
			return _fail("Checkpoint already exists; use --resume or a new --checkpoint directory.")
		if DirAccess.make_dir_recursive_absolute(_directory) != OK:
			return _fail("Unable to create checkpoint directory: %s" % _directory)
		started_at = Time.get_datetime_string_from_system(true)
		if not _publish(
			header_path,
			(
				JSON
				. stringify(
					{
						"checkpoint_schema_version": SCHEMA_VERSION,
						"identity": _identity,
						"identity_checksum": _identity_checksum,
						"started_at": started_at,
					},
					"",
					true,
					true
				)
			)
		):
			return false
	var empty_batch := SimulationBatchResult.new()
	_metadata = (
		REPORT_SCRIPT
		. from_batch(manifest, shard, empty_batch, started_at, "", provenance)
		. to_dictionary()
	)
	return true


func _identity_matches(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var actual: Dictionary = value.duplicate(true)
	for section: String in ["shard", "trace"]:
		if typeof(actual.get(section)) != TYPE_DICTIONARY:
			return false
		for field: String in _identity[section]:
			var number: Variant = actual[section].get(field)
			if number != _identity[section][field]:
				return false
			actual[section][field] = _identity[section][field]
	return JSON.stringify(actual, "", true, true) == JSON.stringify(_identity, "", true, true)


func has_record(index: int) -> bool:
	return FileAccess.file_exists(_record_path(index))


func save_outcome(outcome: SimulationTournamentOutcome) -> bool:
	var traces: Array[Dictionary] = []
	for trace: SimulationTraceEntry in outcome.traces:
		traces.append(REPORT_SCRIPT._trace_dictionary(trace))
	var tournament_json := JSON.stringify(
		REPORT_SCRIPT._tournament_dictionary(outcome), "", true, true
	)
	var traces_json := JSON.stringify(traces, "", true, true)
	# Preserve original canonical numeric spellings across JSON parsing on resume.
	var record := {
		"checkpoint_schema_version": SCHEMA_VERSION,
		"identity_checksum": _identity_checksum,
		"tournament_json": tournament_json,
		"traces_json": traces_json,
	}
	record["checksum"] = _hash(JSON.stringify(record, "", true))
	return _publish(_record_path(outcome.tournament_index), JSON.stringify(record, "", true, true))


# gdlint: disable=max-returns
func load_record(index: int) -> Dictionary:
	var record := _read_dictionary(_record_path(index))
	if record.is_empty():
		return {}
	var checksum: Variant = record.get("checksum")
	record.erase("checksum")
	if record.get("checkpoint_schema_version") == SCHEMA_VERSION:
		record["checkpoint_schema_version"] = SCHEMA_VERSION
	if (
		record.size() != 4
		or record.get("checkpoint_schema_version") != SCHEMA_VERSION
		or record.get("identity_checksum") != _identity_checksum
		or typeof(record.get("tournament_json")) != TYPE_STRING
		or typeof(record.get("traces_json")) != TYPE_STRING
		or checksum != _hash(JSON.stringify(record, "", true))
	):
		_fail("Invalid checkpoint record or checksum at tournament %d." % index)
		return {}
	var tournament_parser := JSON.new()
	var trace_parser := JSON.new()
	if (
		tournament_parser.parse(record.tournament_json) != OK
		or trace_parser.parse(record.traces_json) != OK
	):
		_fail("Checkpoint tournament or traces contain invalid JSON at index %d." % index)
		return {}
	var tournament: Variant = tournament_parser.data
	var traces: Variant = trace_parser.data
	if typeof(tournament) != TYPE_DICTIONARY or typeof(traces) != TYPE_ARRAY:
		_fail("Checkpoint tournament and traces have invalid types at index %d." % index)
		return {}
	var partial := _metadata.duplicate(true)
	partial.tournaments = [tournament]
	partial.traces = traces
	var report := REPORT_SCRIPT.from_dictionary(partial)
	var errors: PackedStringArray = report.validate(false)
	if not errors.is_empty() or tournament.get("tournament_index") != index:
		_fail("Invalid checkpoint tournament %d: %s" % [index, "; ".join(errors)])
		return {}
	if not _validate_traces(traces, index):
		return {}
	record["tournament"] = tournament
	record["traces"] = traces
	return record


func report_metadata(aggregates: Dictionary, finished_at: String) -> Dictionary:
	var document := _metadata.duplicate(true)
	document.aggregates = aggregates.duplicate(true)
	document.finished_at = finished_at
	return document


# gdlint: disable=max-returns
func _validate_traces(traces: Array, index: int) -> bool:
	var trace_config: Dictionary = _identity.trace
	if trace_config.mode == SimulationTraceConfig.Mode.NONE and not traces.is_empty():
		return _fail("Checkpoint contains traces while tracing is disabled.")
	if (
		trace_config.mode == SimulationTraceConfig.Mode.SAMPLED
		and traces.size() > trace_config.max_entries_per_tournament
	):
		return _fail("Checkpoint exceeds its sampled trace limit.")
	for trace: Variant in traces:
		if typeof(trace) != TYPE_DICTIONARY or trace.get("tournament_index") != index:
			return _fail("Checkpoint trace does not match its tournament index.")
		if trace.size() != TRACE_INTEGER_FIELDS.size() + TRACE_STRING_FIELDS.size():
			return _fail("Checkpoint trace fields are invalid.")
		for field: String in TRACE_STRING_FIELDS:
			if typeof(trace.get(field)) != TYPE_STRING:
				return _fail("Checkpoint trace requires string field: %s." % field)
		for field: String in TRACE_INTEGER_FIELDS:
			if not SimulationReport._is_integral_number(trace.get(field)):
				return _fail("Checkpoint trace requires integer field: %s." % field)
		if int(trace.kind) < 0 or int(trace.kind) > SimulationTraceEntry.Kind.ERROR:
			return _fail("Checkpoint trace kind is invalid.")
		if (
			trace_config.mode == SimulationTraceConfig.Mode.ERRORS
			and trace.kind != SimulationTraceEntry.Kind.ERROR
		):
			return _fail("Errors-only checkpoints cannot contain sampled decision traces.")
	return true


func _record_path(index: int) -> String:
	return _directory.path_join("%d.json" % index)


func _read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Unable to read checkpoint: %s" % path)
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		_fail("Checkpoint must contain a JSON object: %s" % path)
		return {}
	return parser.data


func _publish(path: String, content: String) -> bool:
	if FileAccess.file_exists(path):
		return _fail("Checkpoint records are immutable; file already exists: %s" % path)
	var temporary := "%s.tmp.%d.%d" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("Unable to create checkpoint temporary file: %s" % temporary)
	file.store_string(content)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("Unable to publish checkpoint: %s" % path)
	return true


func _fail(message: String) -> bool:
	error_message = message
	return false


static func _hash(content: String) -> String:
	return content.sha256_text()
