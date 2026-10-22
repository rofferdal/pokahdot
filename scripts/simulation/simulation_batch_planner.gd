class_name SimulationBatchPlanner
extends RefCounted

## Produces stable tournament inputs from a global evaluation plan.
##
## Matchup occurrence is counted per selected matchup. Shards are deliberately
## applied only after planning so a shard cannot change matchup assignment,
## rotation, or effective seeds.

const BATCH_PLAN_SCRIPT := preload("res://scripts/simulation/simulation_batch_plan.gd")


func plan(
	config: ResolvedTournamentConfig,
	seed_start: int,
	matchups: Array[SimulationMatchup],
	indexes: Array[int],
) -> RefCounted:
	var errors := _validate(config, seed_start, matchups, indexes)
	if not errors.is_empty():
		return BATCH_PLAN_SCRIPT.new([], errors)
	var occurrences: Dictionary[StringName, int] = {}
	var inputs: Array[SimulationTournamentInput] = []
	for index: int in indexes:
		var matchup: SimulationMatchup = matchups[index % matchups.size()]
		var occurrence: int = occurrences.get(matchup.matchup_id, 0)
		occurrences[matchup.matchup_id] = occurrence + 1
		var rotation: int = occurrence % config.player_count
		inputs.append(
			SimulationTournamentInput.new(
				index,
				seed_start + index,
				matchup,
				_rotated_seats(matchup.get_profiles(), rotation),
				occurrence,
				rotation,
			)
		)
	return BATCH_PLAN_SCRIPT.new(inputs)


func filter_for_shard(
	planned_inputs: Array[SimulationTournamentInput], shard_index: int, shard_count: int
) -> Array[SimulationTournamentInput]:
	var filtered: Array[SimulationTournamentInput] = []
	if shard_count <= 0 or shard_index < 0 or shard_index >= shard_count:
		return filtered
	for input: SimulationTournamentInput in planned_inputs:
		if input != null and input.tournament_index % shard_count == shard_index:
			filtered.append(input)
	return filtered


func _validate(
	config: ResolvedTournamentConfig,
	seed_start: int,
	matchups: Array[SimulationMatchup],
	indexes: Array[int],
) -> PackedStringArray:
	var errors := PackedStringArray()
	if config == null:
		errors.append("A resolved tournament configuration is required.")
		return errors
	if matchups.is_empty():
		errors.append("At least one simulation matchup is required.")
	for matchup: SimulationMatchup in matchups:
		if matchup == null:
			errors.append("A simulation matchup is required.")
			continue
		errors.append_array(matchup.validate())
		if matchup.get_profiles().size() != config.player_count:
			errors.append("Every matchup must contain one profile for every configured seat.")
	var seen_indexes: Dictionary[int, bool] = {}
	for index: int in indexes:
		if index < 0:
			errors.append("Tournament index must be non-negative.")
		elif seen_indexes.has(index):
			errors.append("Tournament indexes must be unique.")
		else:
			seen_indexes[index] = true
			if seed_start + index == 0:
				errors.append("Simulation effective seeds must be non-zero.")
	return errors


func _rotated_seats(profiles: Array[BotProfile], rotation: int) -> Dictionary[int, BotProfile]:
	var seats: Dictionary[int, BotProfile] = {}
	for seat: int in range(profiles.size()):
		seats[seat] = profiles[(seat + rotation) % profiles.size()]
	return seats
