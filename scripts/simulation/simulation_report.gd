class_name SimulationReport
extends RefCounted

## Versioned report value produced from typed batch outcomes.
##
## The manifest snapshot is copied verbatim from the canonical manifest
## dictionary. Report serialization remains in the simulation adapter.

const REPORT_SCHEMA_VERSION: int = 4
const COMMAND_VERSION: StringName = &"simulation_cli_v6"
const REPORT_SCRIPT := preload("res://scripts/simulation/simulation_report.gd")
const PROVENANCE_SCRIPT := preload("res://scripts/simulation/simulation_provenance.gd")
const TOURNAMENT_FIELDS := [
	"tournament_index",
	"plan_id",
	"plan_tournament_index",
	"regime_id",
	"matchup_id",
	"matchup_occurrence",
	"rotation",
	"effective_seed",
	"seat_map",
	"selected_profile_ids",
	"termination_reason",
	"winner_profile_id",
	"tournament_hand_count",
	"profile_results",
	"diagnostics",
]
const PROFILE_RESULT_FIELDS := [
	"seat",
	"profile_id",
	"finishing_position",
	"won_tournament",
	"top_third",
	"starting_stack",
	"final_stack",
	"chip_differential",
	"hands_survived",
	"tournament_hand_count",
	"survival_ratio",
	"blind_normalized_chip_sum",
	"hands_observed",
	"bnc_per_100",
	"vpip_hands",
	"vpip_rate",
	"pfr_hands",
	"pfr_rate",
	"bet_actions",
	"raise_actions",
	"aggressive_actions",
	"call_actions",
	"aggression_factor",
	"bet_raise_opportunities",
	"bet_raise_frequency",
	"check_bet_opportunities",
	"bets_at_check_bet_opportunity",
	"bet_frequency",
	"call_raise_opportunities",
	"calls_at_call_raise_opportunity",
	"raises_at_call_raise_opportunity",
	"raise_share",
	"eligible_bluff_opportunities",
	"bluff_actions",
	"eligible_bluff_frequency",
	"invalid_action_fallbacks",
]
const TOURNAMENT_INTEGER_FIELDS := [
	"tournament_index",
	"plan_tournament_index",
	"matchup_occurrence",
	"rotation",
	"effective_seed",
	"tournament_hand_count",
]
const TOURNAMENT_STRING_FIELDS := [
	"plan_id", "regime_id", "matchup_id", "termination_reason", "winner_profile_id"
]
const TOURNAMENT_ARRAY_FIELDS := [
	"seat_map", "selected_profile_ids", "profile_results", "diagnostics"
]
const PROFILE_RESULT_INTEGER_FIELDS := [
	"seat",
	"finishing_position",
	"starting_stack",
	"final_stack",
	"chip_differential",
	"hands_survived",
	"tournament_hand_count",
	"hands_observed",
	"vpip_hands",
	"pfr_hands",
	"bet_actions",
	"raise_actions",
	"aggressive_actions",
	"call_actions",
	"bet_raise_opportunities",
	"check_bet_opportunities",
	"bets_at_check_bet_opportunity",
	"call_raise_opportunities",
	"calls_at_call_raise_opportunity",
	"raises_at_call_raise_opportunity",
	"eligible_bluff_opportunities",
	"bluff_actions",
	"invalid_action_fallbacks",
]
const PROFILE_RESULT_NUMBER_FIELDS := [
	"survival_ratio",
	"blind_normalized_chip_sum",
	"bnc_per_100",
	"vpip_rate",
	"pfr_rate",
	"aggression_factor",
	"bet_raise_frequency",
	"bet_frequency",
	"raise_share",
	"eligible_bluff_frequency",
]
const PROFILE_RESULT_BOOLEAN_FIELDS := ["won_tournament", "top_third"]

var report_schema_version: int = REPORT_SCHEMA_VERSION
var manifest: Dictionary = {}
var manifest_checksum: String
var roster: Dictionary = {}
var code_revision: String
var execution_provenance: Dictionary = {}
var command_version: StringName = COMMAND_VERSION
var shard: SimulationShard
var started_at: String
var finished_at: String
var tournaments: Array[Dictionary] = []
var aggregates: Dictionary = {}
var traces: Array[Dictionary] = []
var _structural_errors := PackedStringArray()


static func from_batch(
	manifest_value: SimulationManifest,
	shard_value: SimulationShard,
	batch: SimulationBatchResult,
	started: String = "",
	finished: String = "",
	provenance_value: Dictionary = {},
) -> RefCounted:
	var report = REPORT_SCRIPT.new()
	var provenance := (
		PROVENANCE_SCRIPT.unavailable()
		if provenance_value.is_empty()
		else provenance_value.duplicate(true)
	)
	report.manifest = manifest_value.canonical_dictionary()
	report.manifest_checksum = manifest_value.checksum()
	report.roster = manifest_value.roster_provenance()
	report.execution_provenance = provenance
	report.code_revision = String(provenance.get("code_revision", ""))
	report.shard = SimulationShard.new(shard_value.index, shard_value.count)
	report.started_at = started
	report.finished_at = finished
	report.aggregates = _copy_dictionary(batch.aggregates)
	for outcome: SimulationTournamentOutcome in batch.outcomes:
		report.tournaments.append(_tournament_dictionary(outcome))
		for trace: SimulationTraceEntry in outcome.traces:
			report.traces.append(_trace_dictionary(trace))
	return report


func validate() -> PackedStringArray:
	var errors := _structural_errors.duplicate()
	if report_schema_version != REPORT_SCHEMA_VERSION:
		errors.append("Unsupported simulation report schema version.")
	if command_version != COMMAND_VERSION:
		errors.append("Unsupported simulation command version.")
	if manifest.is_empty():
		errors.append("Simulation report manifest is required.")
	if manifest_checksum.is_empty():
		errors.append("Simulation report manifest checksum is required.")
	errors.append_array(PROVENANCE_SCRIPT.validate(execution_provenance))
	if code_revision != execution_provenance.get("code_revision"):
		errors.append("Simulation code revision does not match execution provenance.")
	_validate_roster(roster, errors)
	_validate_roster_matches_manifest(roster, manifest, errors)
	if shard == null:
		errors.append("Simulation report shard is required.")
	else:
		errors.append_array(shard.validate())
	for tournament: Dictionary in tournaments:
		for field: String in TOURNAMENT_FIELDS:
			if not tournament.has(field):
				errors.append("Simulation tournament is missing field: %s" % field)
		for field: String in TOURNAMENT_INTEGER_FIELDS:
			_validate_integral_field(tournament, field, "Simulation tournament", errors)
		for field: String in TOURNAMENT_STRING_FIELDS:
			_validate_typed_field(tournament, field, TYPE_STRING, "Simulation tournament", errors)
		for field: String in TOURNAMENT_ARRAY_FIELDS:
			_validate_typed_field(tournament, field, TYPE_ARRAY, "Simulation tournament", errors)
		_validate_seat_map(tournament.get("seat_map"), errors)
		_validate_selected_profile_ids(tournament.get("selected_profile_ids"), errors)
		_validate_tournament_selection(tournament, errors)
		_validate_diagnostics(tournament.get("diagnostics"), errors)
		var profile_results: Variant = tournament.get("profile_results")
		if typeof(profile_results) != TYPE_ARRAY:
			errors.append("Simulation tournament profile_results must be an array.")
			continue
		for profile_result: Variant in profile_results:
			if typeof(profile_result) != TYPE_DICTIONARY:
				errors.append("Simulation profile result must be an object.")
				continue
			for field: String in PROFILE_RESULT_FIELDS:
				if not profile_result.has(field):
					errors.append("Simulation profile result is missing field: %s" % field)
			_validate_integral_fields(
				profile_result, PROFILE_RESULT_INTEGER_FIELDS, "Simulation profile result", errors
			)
			_validate_typed_field(
				profile_result, "profile_id", TYPE_STRING, "Simulation profile result", errors
			)
			for field: String in PROFILE_RESULT_NUMBER_FIELDS:
				_validate_number_field(profile_result, field, "Simulation profile result", errors)
			for field: String in PROFILE_RESULT_BOOLEAN_FIELDS:
				_validate_typed_field(
					profile_result, field, TYPE_BOOL, "Simulation profile result", errors
				)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"report_schema_version": report_schema_version,
		"manifest": _copy_dictionary(manifest),
		"manifest_checksum": manifest_checksum,
		"roster": _copy_dictionary(roster),
		"code_revision": code_revision,
		"execution_provenance": _copy_dictionary(execution_provenance),
		"command_version": String(command_version),
		"shard": shard.to_dictionary() if shard != null else {},
		"started_at": started_at,
		"finished_at": finished_at,
		"tournaments": tournaments.duplicate(true),
		"aggregates": _copy_dictionary(aggregates),
		"traces": traces.duplicate(true),
	}


func canonical_json() -> String:
	return JSON.stringify(to_dictionary())


func checksum() -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical_json().to_utf8_buffer())
	return context.finish().hex_encode()


static func from_dictionary(data: Dictionary) -> RefCounted:
	var report = REPORT_SCRIPT.new()
	var required_types := {
		"manifest": TYPE_DICTIONARY,
		"manifest_checksum": TYPE_STRING,
		"roster": TYPE_DICTIONARY,
		"code_revision": TYPE_STRING,
		"execution_provenance": TYPE_DICTIONARY,
		"command_version": TYPE_STRING,
		"shard": TYPE_DICTIONARY,
		"started_at": TYPE_STRING,
		"finished_at": TYPE_STRING,
		"tournaments": TYPE_ARRAY,
		"aggregates": TYPE_DICTIONARY,
		"traces": TYPE_ARRAY,
	}
	for field: String in required_types:
		if not data.has(field):
			report._structural_errors.append("Simulation report is missing field: %s" % field)
		elif typeof(data[field]) != required_types[field]:
			report._structural_errors.append("Simulation report field has invalid type: %s" % field)
	if not data.has("report_schema_version"):
		report._structural_errors.append(
			"Simulation report is missing field: report_schema_version"
		)
	elif (
		typeof(data.report_schema_version) not in [TYPE_INT, TYPE_FLOAT]
		or not is_equal_approx(data.report_schema_version, floor(data.report_schema_version))
	):
		report._structural_errors.append(
			"Simulation report field has invalid type: report_schema_version"
		)
	var schema_version_value: Variant = data.get("report_schema_version")
	report.report_schema_version = (
		int(schema_version_value) if _is_integral_number(schema_version_value) else 0
	)
	report.manifest = (
		data.manifest.duplicate(true) if typeof(data.get("manifest")) == TYPE_DICTIONARY else {}
	)
	report.manifest_checksum = (
		data.manifest_checksum if typeof(data.get("manifest_checksum")) == TYPE_STRING else ""
	)
	report.roster = (
		data.roster.duplicate(true) if typeof(data.get("roster")) == TYPE_DICTIONARY else {}
	)
	report.code_revision = (
		data.code_revision if typeof(data.get("code_revision")) == TYPE_STRING else ""
	)
	report.execution_provenance = (
		data.execution_provenance.duplicate(true)
		if typeof(data.get("execution_provenance")) == TYPE_DICTIONARY
		else {}
	)
	report.command_version = (
		StringName(data.command_version)
		if typeof(data.get("command_version")) == TYPE_STRING
		else &""
	)
	var shard_data: Dictionary = data.shard if typeof(data.get("shard")) == TYPE_DICTIONARY else {}
	for field: String in ["index", "count"]:
		if not shard_data.has(field):
			report._structural_errors.append("Simulation report shard is missing field: %s" % field)
		elif not _is_integral_number(shard_data[field]):
			report._structural_errors.append(
				"Simulation report shard field has invalid type: %s" % field
			)
	report.shard = (
		SimulationShard
		. new(
			(
				int(shard_data.get("index", -1))
				if _is_integral_number(shard_data.get("index"))
				else -1
			),
			int(shard_data.get("count", 0)) if _is_integral_number(shard_data.get("count")) else 0,
		)
	)
	report.started_at = data.started_at if typeof(data.get("started_at")) == TYPE_STRING else ""
	report.finished_at = data.finished_at if typeof(data.get("finished_at")) == TYPE_STRING else ""
	var tournament_values: Array = (
		data.tournaments if typeof(data.get("tournaments")) == TYPE_ARRAY else []
	)
	for tournament: Variant in tournament_values:
		if typeof(tournament) == TYPE_DICTIONARY:
			report.tournaments.append(tournament.duplicate(true))
		else:
			report._structural_errors.append("Simulation tournament must be an object.")
	report.aggregates = (
		data.aggregates.duplicate(true) if typeof(data.get("aggregates")) == TYPE_DICTIONARY else {}
	)
	var trace_values: Array = data.traces if typeof(data.get("traces")) == TYPE_ARRAY else []
	for trace: Variant in trace_values:
		if typeof(trace) == TYPE_DICTIONARY:
			report.traces.append(trace.duplicate(true))
		else:
			report._structural_errors.append("Simulation trace must be an object.")
	return report


static func _is_integral_number(value: Variant) -> bool:
	return (
		typeof(value) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(value))
		and is_equal_approx(float(value), floor(float(value)))
	)


static func _validate_integral_fields(
	data: Dictionary, fields: Array, context: String, errors: PackedStringArray
) -> void:
	for field: String in fields:
		_validate_integral_field(data, field, context, errors)


static func _validate_integral_field(
	data: Dictionary, field: String, context: String, errors: PackedStringArray
) -> void:
	if data.has(field) and not _is_integral_number(data[field]):
		errors.append("%s field has invalid type: %s" % [context, field])


static func _validate_number_field(
	data: Dictionary, field: String, context: String, errors: PackedStringArray
) -> void:
	if (
		data.has(field)
		and (typeof(data[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[field])))
	):
		errors.append("%s field has invalid type: %s" % [context, field])


static func _validate_typed_field(
	data: Dictionary,
	field: String,
	expected_type: int,
	context: String,
	errors: PackedStringArray,
) -> void:
	if data.has(field) and typeof(data[field]) != expected_type:
		errors.append("%s field has invalid type: %s" % [context, field])


static func _validate_seat_map(value: Variant, errors: PackedStringArray) -> void:
	if typeof(value) != TYPE_ARRAY:
		return
	for seat_data: Variant in value:
		if typeof(seat_data) != TYPE_DICTIONARY:
			errors.append("Simulation seat map entry must be an object.")
			continue
		if not seat_data.has("seat") or not seat_data.has("profile_id"):
			errors.append("Simulation seat map entry requires seat and profile_id.")
			continue
		_validate_integral_field(seat_data, "seat", "Simulation seat map entry", errors)
		_validate_typed_field(
			seat_data, "profile_id", TYPE_STRING, "Simulation seat map entry", errors
		)


static func _validate_roster(value: Dictionary, errors: PackedStringArray) -> void:
	for field: String in ["version", "profile_ids"]:
		if not value.has(field):
			errors.append("Simulation report roster is missing field: %s" % field)
	if value.has("version") and typeof(value.version) != TYPE_STRING:
		errors.append("Simulation report roster version must be a string.")
	_validate_selected_profile_ids(value.get("profile_ids"), errors, "Simulation report roster")


static func _validate_roster_matches_manifest(
	roster_value: Dictionary, manifest_value: Dictionary, errors: PackedStringArray
) -> void:
	var manifest_result := SimulationManifest.parse(manifest_value)
	if not manifest_result.is_ok():
		return
	var expected := manifest_result.manifest.roster_provenance()
	if roster_value.get("version") != expected.version:
		errors.append("Simulation report roster version does not match its manifest profiles.")
	if roster_value.get("profile_ids") != expected.profile_ids:
		errors.append("Simulation report roster profile IDs do not match its manifest profiles.")


static func _validate_selected_profile_ids(
	value: Variant, errors: PackedStringArray, context: String = "Simulation selected profile IDs"
) -> void:
	if typeof(value) != TYPE_ARRAY:
		errors.append("%s must be an array." % context)
		return
	for profile_id: Variant in value:
		if typeof(profile_id) != TYPE_STRING or String(profile_id).is_empty():
			errors.append("%s must contain non-empty strings." % context)


static func _validate_tournament_selection(
	tournament: Dictionary, errors: PackedStringArray
) -> void:
	if typeof(tournament.get("seat_map")) != TYPE_ARRAY:
		return
	var expected_ids: Array[String] = []
	for seat_data: Variant in tournament.seat_map:
		if (
			typeof(seat_data) != TYPE_DICTIONARY
			or typeof(seat_data.get("profile_id")) != TYPE_STRING
		):
			return
		expected_ids.append(seat_data.profile_id)
	if tournament.get("selected_profile_ids") != expected_ids:
		errors.append("Simulation selected profile IDs do not match the ordered seat map.")


static func _validate_diagnostics(value: Variant, errors: PackedStringArray) -> void:
	if typeof(value) != TYPE_ARRAY:
		return
	for diagnostic: Variant in value:
		if typeof(diagnostic) != TYPE_DICTIONARY:
			errors.append("Simulation diagnostic must be an object.")
			continue
		for field: String in ["stage", "message", "seat"]:
			if not diagnostic.has(field):
				errors.append("Simulation diagnostic is missing field: %s" % field)
		_validate_integral_field(diagnostic, "stage", "Simulation diagnostic", errors)
		_validate_typed_field(diagnostic, "message", TYPE_STRING, "Simulation diagnostic", errors)
		_validate_integral_field(diagnostic, "seat", "Simulation diagnostic", errors)


static func tournament_digest(tournament: Dictionary) -> String:
	var digest_input := {
		"tournament_index": float(tournament.get("tournament_index", -1)),
		"effective_seed": float(tournament.get("effective_seed", 0)),
		"seat_map": _normalized_seat_map(tournament.get("seat_map", [])),
		"selected_profile_ids": tournament.get("selected_profile_ids", []).duplicate(),
		"termination_reason": tournament.get("termination_reason", ""),
		"winner_profile_id": tournament.get("winner_profile_id", ""),
		"tournament_hand_count": float(tournament.get("tournament_hand_count", 0)),
		"profile_results": _normalized_profile_results(tournament.get("profile_results", [])),
	}
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(digest_input).to_utf8_buffer())
	return context.finish().hex_encode()


static func _normalized_seat_map(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for seat_data: Variant in value:
		if typeof(seat_data) != TYPE_DICTIONARY:
			continue
		result.append(
			{
				"seat": float(seat_data.get("seat", -1)),
				"profile_id": String(seat_data.get("profile_id", ""))
			}
		)
	return result


static func _normalized_profile_results(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile_data: Variant in value:
		if typeof(profile_data) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = {}
		for key: String in PROFILE_RESULT_FIELDS:
			var numeric_value: Variant = profile_data.get(key)
			normalized[key] = (
				float(numeric_value)
				if typeof(numeric_value) in [TYPE_INT, TYPE_FLOAT]
				else numeric_value
			)
		result.append(normalized)
	return result


static func _tournament_dictionary(outcome: SimulationTournamentOutcome) -> Dictionary:
	var winner_profile_id: String = ""
	if outcome.completion != null and outcome.completion.winner_seat >= 0:
		winner_profile_id = String(
			outcome.final_seat_mapping.get(outcome.completion.winner_seat, &"")
		)
	return {
		"tournament_index": outcome.tournament_index,
		"plan_id": String(outcome.plan_id),
		"plan_tournament_index": outcome.plan_tournament_index,
		"regime_id": String(outcome.regime_id),
		"matchup_id": String(outcome.matchup_id),
		"matchup_occurrence": outcome.matchup_occurrence,
		"rotation": outcome.rotation,
		"effective_seed": outcome.effective_seed,
		"seat_map": _seat_map(outcome.final_seat_mapping),
		"selected_profile_ids": _selected_profile_ids(outcome.final_seat_mapping),
		"termination_reason":
		String(outcome.completion.termination_reason) if outcome.completion != null else "",
		"winner_profile_id": winner_profile_id,
		"tournament_hand_count":
		outcome.completion.tournament_hand_count if outcome.completion != null else 0,
		"profile_results": _profile_results(outcome.metrics),
		"diagnostics": _diagnostics(outcome.diagnostics),
	}


static func _seat_map(mapping: Dictionary[int, StringName]) -> Array[Dictionary]:
	var seats: Array[int] = []
	for seat: int in mapping:
		seats.append(seat)
	seats.sort()
	var result: Array[Dictionary] = []
	for seat: int in seats:
		result.append({"seat": seat, "profile_id": String(mapping[seat])})
	return result


static func _selected_profile_ids(mapping: Dictionary[int, StringName]) -> Array[String]:
	var result: Array[String] = []
	for seat_data: Dictionary in _seat_map(mapping):
		result.append(seat_data.profile_id)
	return result


static func _profile_results(metrics: Dictionary) -> Array[Dictionary]:
	var seats: Array[int] = []
	for seat: int in metrics:
		seats.append(seat)
	seats.sort()
	var result: Array[Dictionary] = []
	for seat: int in seats:
		var metric: SimulationSeatMetrics = metrics[seat]
		(
			result
			. append(
				{
					"seat": metric.seat,
					"profile_id": String(metric.profile_id),
					"finishing_position": metric.finishing_position,
					"won_tournament": metric.won_tournament,
					"top_third": metric.top_third,
					"starting_stack": metric.starting_stack,
					"final_stack": metric.final_stack,
					"chip_differential": metric.chip_differential,
					"hands_survived": metric.hands_survived,
					"tournament_hand_count": metric.tournament_hand_count,
					"survival_ratio": metric.survival_ratio,
					"blind_normalized_chip_sum": metric.blind_normalized_chip_sum,
					"hands_observed": metric.hands_observed,
					"bnc_per_100": metric.bnc_per_100,
					"vpip_hands": metric.vpip_hands,
					"vpip_rate": metric.vpip_rate,
					"pfr_hands": metric.pfr_hands,
					"pfr_rate": metric.pfr_rate,
					"bet_actions": metric.bet_actions,
					"raise_actions": metric.raise_actions,
					"aggressive_actions": metric.aggressive_actions,
					"call_actions": metric.call_actions,
					"aggression_factor": metric.aggression_factor,
					"bet_raise_opportunities": metric.bet_raise_opportunities,
					"bet_raise_frequency": metric.bet_raise_frequency,
					"check_bet_opportunities": metric.check_bet_opportunities,
					"bets_at_check_bet_opportunity": metric.bets_at_check_bet_opportunity,
					"bet_frequency": metric.bet_frequency,
					"call_raise_opportunities": metric.call_raise_opportunities,
					"calls_at_call_raise_opportunity": metric.calls_at_call_raise_opportunity,
					"raises_at_call_raise_opportunity": metric.raises_at_call_raise_opportunity,
					"raise_share": metric.raise_share,
					"eligible_bluff_opportunities": metric.eligible_bluff_opportunities,
					"bluff_actions": metric.bluff_actions,
					"eligible_bluff_frequency": metric.eligible_bluff_frequency,
					"invalid_action_fallbacks": metric.invalid_action_fallbacks,
				}
			)
		)
	return result


static func _diagnostics(diagnostics: Array[SimulationDiagnostic]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for diagnostic: SimulationDiagnostic in diagnostics:
		result.append(
			{"stage": diagnostic.stage, "message": diagnostic.message, "seat": diagnostic.seat}
		)
	return result


static func _trace_dictionary(trace: SimulationTraceEntry) -> Dictionary:
	return {
		"kind": trace.kind,
		"tournament_index": trace.tournament_index,
		"hand_number": trace.hand_number,
		"seat": trace.seat,
		"profile_id": String(trace.profile_id),
		"street": String(trace.street),
		"selected_branch": String(trace.selected_branch),
		"hand_potential_band": String(trace.hand_potential_band),
		"action_kind": trace.action_kind,
		"action_amount": trace.action_amount,
		"winner_seat": trace.winner_seat,
		"termination_reason": String(trace.termination_reason),
		"message": trace.message,
	}


static func _copy_dictionary(source: Dictionary) -> Dictionary:
	return source.duplicate(true)
