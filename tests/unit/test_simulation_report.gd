extends "res://tests/support/poker_gut_test.gd"

const REPORT_SCRIPT := preload("res://scripts/simulation/simulation_report.gd")


func test_report_mirrors_manifest_identity_and_maps_outcome_fields() -> void:
	var manifest := SimulationManifest.new()
	manifest.batch_id = &"report_batch"
	manifest.seed_start = 200
	manifest.profiles = [_profile(&"alpha"), _profile(&"beta")]
	manifest.regimes = [SimulationRegime.new(&"heads_up", 2, 20, 5, 10)]
	manifest.matchups = [SimulationMatchup.new(&"match", manifest.profiles)]
	manifest.evaluation_plans = [SimulationEvaluationPlan.new(&"plan", &"heads_up", [&"match"], 1)]
	var plan := manifest.build_plan()
	var batch := (
		SimulationBatchRunner
		. new()
		. run(
			ResolvedTournamentConfig.new(
				2, 20, 5, 10, 200, &"single_table", {0: &"random", 1: &"random"}
			),
			plan.inputs,
		)
	)

	var report: RefCounted = REPORT_SCRIPT.from_batch(manifest, SimulationShard.new(), batch)
	assert_true(report.validate().is_empty())
	assert_eq(report.manifest, manifest.canonical_dictionary())
	assert_eq(report.manifest_checksum, manifest.checksum())
	assert_eq(report.tournaments.size(), 1)
	assert_eq(report.tournaments[0].plan_id, "plan")
	assert_eq(report.tournaments[0].effective_seed, 200)
	assert_eq(report.tournaments[0].seat_map.size(), 2)
	assert_eq(report.tournaments[0].profile_results.size(), 2)
	assert_false(report.to_dictionary().has("hole_cards"))


func _profile(profile_id: StringName) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = profile_id
	profile.model_id = &"random"
	profile.parameters = RandomDecisionModelParameters.new()
	return profile
