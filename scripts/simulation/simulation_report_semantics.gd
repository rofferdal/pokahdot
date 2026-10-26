class_name SimulationReportSemantics
extends RefCounted

## Semantic report checks shared by inspect, replay, and direct report consumers.
## Work is bounded by the supplied manifest and result rows, not planned count.

const METRICS := preload("res://scripts/simulation/simulation_report_metric_contract.gd")


static func validate(data: Dictionary, manifest: SimulationManifest) -> PackedStringArray:
	var errors := PackedStringArray()
	if data.manifest_checksum != manifest.checksum():
		errors.append("Report manifest checksum does not match its manifest.")
	var seen: Dictionary[int, bool] = {}
	var all_completed: bool = true
	for tournament: Dictionary in data.tournaments:
		var index: int = int(tournament.tournament_index)
		if seen.has(index):
			errors.append("Simulation tournament indexes must be unique.")
		seen[index] = true
		if index < 0 or index % data.shard.count != data.shard.index:
			errors.append("Simulation tournament does not belong to this shard.")
		var expected: Dictionary = _mapping_for_index(manifest, index)
		if expected.is_empty():
			errors.append("Simulation tournament index is outside its manifest plan.")
			continue
		var identity_valid: bool = true
		for field: String in expected.identity:
			var matches: bool = (
				_seat_maps_match(tournament[field], expected.identity[field])
				if field == "seat_map"
				else tournament[field] == expected.identity[field]
			)
			if not matches:
				errors.append("Simulation tournament %s does not match its plan." % field)
				identity_valid = false
		if not identity_valid:
			continue
		if tournament.termination_reason == "winner":
			errors.append_array(METRICS.validate(tournament, expected.regime))
		else:
			all_completed = false
			if (
				tournament.termination_reason != ""
				or tournament.diagnostics.is_empty()
				or tournament.winner_profile_id != ""
				or not tournament.profile_results.is_empty()
			):
				errors.append(
					"Failed simulation outcomes require empty results and safe diagnostics."
				)
	# Failed diagnostic reports may retain a partial collection. Fully completed
	# evidence must include every tournament assigned to this shard exactly once.
	if all_completed:
		var total: int = 0
		for plan: SimulationEvaluationPlan in manifest.evaluation_plans:
			total += plan.tournament_count
		var expected_count: int = 0
		if total > data.shard.index:
			expected_count = 1 + (total - 1 - int(data.shard.index)) / int(data.shard.count)
		if seen.size() != expected_count:
			errors.append("Completed simulation report does not cover its complete planned shard.")
	return errors


static func _seat_maps_match(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index: int in range(actual.size()):
		if (
			actual[index].size() != 2
			or actual[index].seat != expected[index].seat
			or actual[index].profile_id != expected[index].profile_id
		):
			return false
	return true


static func _mapping_for_index(manifest: SimulationManifest, index: int) -> Dictionary:
	if index < 0:
		return {}
	var offset: int = 0
	for plan: SimulationEvaluationPlan in manifest.evaluation_plans:
		if index - offset >= plan.tournament_count:
			offset += plan.tournament_count
			continue
		var local: int = index - offset
		var matchup_id: StringName = plan.matchup_ids[local % plan.matchup_ids.size()]
		var regime: SimulationRegime
		for candidate: SimulationRegime in manifest.regimes:
			if candidate.regime_id == plan.regime_id:
				regime = candidate
		var matchup: SimulationMatchup
		for candidate: SimulationMatchup in manifest.matchups:
			if candidate.matchup_id == matchup_id:
				matchup = candidate
		var occurrence: int = local / plan.matchup_ids.size()
		var rotation: int = occurrence % regime.player_count
		var source: Array[BotProfile] = matchup.get_profiles()
		var seats: Array[Dictionary] = []
		var ids: Array[String] = []
		for seat: int in range(regime.player_count):
			var id: String = source[(seat + rotation) % regime.player_count].profile_id
			seats.append({"seat": seat, "profile_id": id})
			ids.append(id)
		return {
			"regime": regime,
			"identity":
			{
				"tournament_index": index,
				"plan_id": String(plan.plan_id),
				"plan_tournament_index": local,
				"regime_id": String(plan.regime_id),
				"matchup_id": String(matchup_id),
				"matchup_occurrence": occurrence,
				"rotation": rotation,
				"effective_seed": manifest.seed_start + index,
				"seat_map": seats,
				"selected_profile_ids": ids,
			},
		}
	return {}
