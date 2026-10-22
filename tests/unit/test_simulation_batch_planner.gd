extends "res://tests/support/poker_gut_test.gd"

const PLANNER_SCRIPT := preload("res://scripts/simulation/simulation_batch_planner.gd")


func test_interleaved_matchups_use_each_matchups_own_occurrence_for_rotation() -> void:
	var planner := PLANNER_SCRIPT.new()
	var plan := planner.plan(_config(), 1000, [_matchup(&"a", [&"a0", &"a1"]), _matchup(&"b", [&"b0", &"b1"])], [0, 1, 2, 3, 4, 5])

	assert_true(plan.is_valid())
	assert_eq(_plan_summary(plan.inputs), [
		"0:a:0:0:a0,a1", "1:b:0:0:b0,b1", "2:a:1:1:a1,a0",
		"3:b:1:1:b1,b0", "4:a:2:0:a0,a1", "5:b:2:0:b0,b1",
	])


func test_full_rotation_is_balanced_and_seeded_from_global_indexes() -> void:
	var plan := PLANNER_SCRIPT.new().plan(_config(), 2000, [_matchup(&"a", [&"a0", &"a1"])], [0, 1, 2, 3])

	assert_true(plan.is_valid())
	assert_eq(_plan_summary(plan.inputs), [
		"0:a:0:0:a0,a1", "1:a:1:1:a1,a0", "2:a:2:0:a0,a1", "3:a:3:1:a1,a0",
	])
	assert_eq(plan.inputs[3].effective_seed, 2003)


func test_shard_filters_global_plan_without_replanning_indexes() -> void:
	var planner := PLANNER_SCRIPT.new()
	var global_plan := planner.plan(_config(), 3000, [_matchup(&"a", [&"a0", &"a1"]), _matchup(&"b", [&"b0", &"b1"])], [0, 1, 2, 3, 4, 5])
	var shard := planner.filter_for_shard(global_plan.inputs, 1, 3)

	assert_eq(_plan_summary(shard), ["1:b:0:0:b0,b1", "4:a:2:0:a0,a1"])
	assert_eq(shard[0].effective_seed, 3001)
	assert_eq(shard[1].effective_seed, 3004)


func _config() -> ResolvedTournamentConfig:
	return ResolvedTournamentConfig.new(2, 20, 5, 10, 1, &"single_table", {0: &"random", 1: &"random"})


func _matchup(id: StringName, profile_ids: Array[StringName]) -> SimulationMatchup:
	var profiles: Array[BotProfile] = []
	for profile_id: StringName in profile_ids:
		var profile := BotProfile.new()
		profile.profile_id = profile_id
		profile.model_id = &"random"
		profile.parameters = RandomDecisionModelParameters.new()
		profiles.append(profile)
	return SimulationMatchup.new(id, profiles)


func _plan_summary(inputs: Array[SimulationTournamentInput]) -> Array[String]:
	var result: Array[String] = []
	for input: SimulationTournamentInput in inputs:
		var seats := input.get_seat_profiles()
		result.append("%d:%s:%d:%d:%s,%s" % [input.tournament_index, input.matchup.matchup_id, input.matchup_occurrence, input.rotation, seats[0].profile_id, seats[1].profile_id])
	return result
