extends "res://tests/support/poker_gut_test.gd"

const MANIFEST_SCRIPT := preload("res://scripts/simulation/simulation_manifest.gd")


func test_manifest_round_trips_canonical_identity_and_builds_global_plan() -> void:
	var manifest := MANIFEST_SCRIPT.new()
	manifest.batch_id = &"batch_one"
	manifest.seed_start = 1000
	manifest.profiles = [_profile(&"alpha", 20), _profile(&"beta", 40)]
	manifest.regimes = [SimulationRegime.new(&"heads_up", 2, 100, 5, 10)]
	manifest.matchups = [SimulationMatchup.new(&"alpha_beta", manifest.profiles)]
	manifest.evaluation_plans = [
		SimulationEvaluationPlan.new(
			&"confirmation", &"heads_up", [&"alpha_beta"], 4, 2, &"normal_95"
		)
	]

	assert_true(manifest.validate().is_empty())
	var plan := manifest.build_plan()
	assert_true(plan.is_valid())
	assert_eq(plan.inputs.size(), 4)
	assert_eq(plan.inputs[0].plan_id, &"confirmation")
	assert_eq(plan.inputs[3].plan_tournament_index, 3)
	assert_eq(plan.inputs[3].effective_seed, 1003)
	assert_eq(plan.inputs[1].rotation, 1)
	assert_eq(plan.inputs[1].get_seat_profiles()[0].profile_id, &"beta")

	var parsed := MANIFEST_SCRIPT.parse(manifest.canonical_dictionary())
	assert_true(parsed.is_ok())
	assert_eq(parsed.manifest.canonical_json(), manifest.canonical_json())
	assert_eq(parsed.manifest.checksum(), manifest.checksum())


func test_manifest_rejects_unknown_fields_and_fractional_parameters() -> void:
	var data := {
		"schema_version": 1,
		"batch_id": "invalid",
		"seed_start": 100,
		"unexpected": true,
		"profiles":
		[
			{
				"profile_id": "alpha",
				"model_id": "strategy_parameterized",
				"parameters":
				{
					"tight_vs_loose": 20.5,
					"passive_vs_aggressive": 40,
					"call_vs_bet": 50,
					"bluff_rate": 10,
				},
			}
		],
		"regimes": [],
		"matchups": [],
		"evaluation_plans": [],
	}

	var parsed := MANIFEST_SCRIPT.parse(data)
	assert_false(parsed.is_ok())
	assert_has(parsed.errors, "Unknown manifest field: unexpected")

	data.erase("unexpected")
	parsed = MANIFEST_SCRIPT.parse(data)
	assert_false(parsed.is_ok())
	assert_has(parsed.errors, "Parameter tight_vs_loose must be an integer.")


func test_shard_contract_filters_without_replanning() -> void:
	var shard := SimulationShard.new(1, 3)
	assert_true(shard.validate().is_empty())
	assert_true(shard.contains(1))
	assert_true(shard.contains(4))
	assert_false(shard.contains(2))
	assert_eq(shard.to_dictionary(), {"index": 1, "count": 3})


func _profile(profile_id: StringName, tightness: int) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = profile_id
	profile.model_id = &"strategy_parameterized"
	var parameters := StrategyDecisionModelParameters.new()
	parameters.tight_vs_loose = tightness
	profile.parameters = parameters
	return profile
