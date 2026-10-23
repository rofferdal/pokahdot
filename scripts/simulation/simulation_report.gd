class_name SimulationReport
extends RefCounted

## Versioned report value produced from typed batch outcomes.
##
## The manifest snapshot is copied verbatim from the canonical manifest
## dictionary. Report serialization remains in the simulation adapter.

const REPORT_SCHEMA_VERSION: int = 1
const COMMAND_VERSION: StringName = &"simulation_cli_v1"
const REPORT_SCRIPT := preload("res://scripts/simulation/simulation_report.gd")

var report_schema_version: int = REPORT_SCHEMA_VERSION
var manifest: Dictionary = {}
var manifest_checksum: String
var code_revision: String
var command_version: StringName = COMMAND_VERSION
var shard: SimulationShard
var started_at: String
var finished_at: String
var tournaments: Array[Dictionary] = []
var aggregates: Dictionary = {}
var traces: Array[Dictionary] = []


static func from_batch(
	manifest_value: SimulationManifest,
	shard_value: SimulationShard,
	batch: SimulationBatchResult,
	started: String = "",
	finished: String = "",
	revision: String = "",
) -> RefCounted:
	var report = REPORT_SCRIPT.new()
	report.manifest = manifest_value.canonical_dictionary()
	report.manifest_checksum = manifest_value.checksum()
	report.code_revision = revision
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
	var errors := PackedStringArray()
	if report_schema_version != REPORT_SCHEMA_VERSION:
		errors.append("Unsupported simulation report schema version.")
	if manifest.is_empty():
		errors.append("Simulation report manifest is required.")
	if manifest_checksum.is_empty():
		errors.append("Simulation report manifest checksum is required.")
	if shard == null:
		errors.append("Simulation report shard is required.")
	else:
		errors.append_array(shard.validate())
	return errors


func to_dictionary() -> Dictionary:
	return {
		"report_schema_version": report_schema_version,
		"manifest": _copy_dictionary(manifest),
		"manifest_checksum": manifest_checksum,
		"code_revision": code_revision,
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
	report.report_schema_version = int(data.get("report_schema_version", 0))
	report.manifest = data.get("manifest", {}).duplicate(true)
	report.manifest_checksum = String(data.get("manifest_checksum", ""))
	report.code_revision = String(data.get("code_revision", ""))
	report.command_version = StringName(data.get("command_version", ""))
	var shard_data: Dictionary = data.get("shard", {})
	report.shard = SimulationShard.new(
		int(shard_data.get("index", -1)), int(shard_data.get("count", 0))
	)
	report.started_at = String(data.get("started_at", ""))
	report.finished_at = String(data.get("finished_at", ""))
	for tournament: Variant in data.get("tournaments", []):
		if typeof(tournament) == TYPE_DICTIONARY:
			report.tournaments.append(tournament.duplicate(true))
	report.aggregates = data.get("aggregates", {}).duplicate(true)
	for trace: Variant in data.get("traces", []):
		if typeof(trace) == TYPE_DICTIONARY:
			report.traces.append(trace.duplicate(true))
	return report


static func tournament_digest(tournament: Dictionary) -> String:
	var digest_input := {
		"tournament_index": float(tournament.get("tournament_index", -1)),
		"effective_seed": float(tournament.get("effective_seed", 0)),
		"seat_map": _normalized_seat_map(tournament.get("seat_map", [])),
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
		for key: String in [
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
			"aggressive_actions",
			"calls",
			"aggression_factor",
			"invalid_action_fallbacks",
		]:
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
					"aggressive_actions": metric.aggressive_actions,
					"calls": metric.calls,
					"aggression_factor": metric.aggression_factor,
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
