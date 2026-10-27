extends "res://tests/support/poker_gut_test.gd"

const MANIFEST_SCRIPT := preload("res://scripts/simulation/simulation_manifest.gd")
const MANIFEST_GENERATOR_SCRIPT := preload(
	"res://scripts/simulation/simulation_manifest_generator.gd"
)
const ROSTER_MANIFEST_SETTINGS_SCRIPT := preload(
	"res://scripts/simulation/simulation_roster_manifest_settings.gd"
)
const BATCH_RUNNER_SCRIPT := preload("res://scripts/simulation/simulation_batch_runner.gd")


func test_evaluation_plan_rejects_unimplemented_bootstrap_estimator() -> void:
	var plan := SimulationEvaluationPlan.new(
		&"bootstrap", &"regime", [&"matchup"], 10, 1, &"bootstrap_95"
	)

	assert_has(plan.validate(), "Only the normal_95 uncertainty estimator is supported.")


func test_roster_generator_creates_a_valid_schema_two_snapshot_manifest() -> void:
	var roster := PlayableBotRoster.new()
	var generated := MANIFEST_GENERATOR_SCRIPT.new().generate(roster)

	assert_true(generated.is_ok())
	assert_true(generated.errors.is_empty())
	assert_eq(generated.manifest.schema_version, SimulationManifest.SUPPORTED_SCHEMA_VERSION)
	assert_eq(generated.manifest.batch_id, &"roster_curated_v2")
	assert_eq(_profile_ids(generated.manifest.profiles), roster.get_profile_ids())
	assert_eq(
		_unique_model_ids(generated.manifest.profiles),
		[&"random", &"tight_passive", &"loose_aggressive", &"strategy_parameterized"]
	)
	var catalog_profiles := roster.get_catalog_profiles()
	assert_ne(generated.manifest.profiles[0], catalog_profiles[0])
	assert_ne(generated.manifest.profiles[0].parameters, catalog_profiles[0].parameters)
	generated.manifest.profiles[0].display_name = "Mutated Simulation Snapshot"
	assert_eq(roster.get_catalog_profiles()[0].display_name, "Random")
	assert_true(generated.manifest.validate().is_empty())
	assert_true(generated.manifest.build_plan().is_valid())
	var parsed := MANIFEST_SCRIPT.parse(generated.manifest.canonical_dictionary())
	assert_true(parsed.is_ok())
	assert_eq(parsed.manifest.canonical_json(), generated.manifest.canonical_json())
	assert_eq(parsed.manifest.checksum(), generated.manifest.checksum())
	assert_eq(generated.manifest.checksum().length(), 64)
	var checksum_context := HashingContext.new()
	checksum_context.start(HashingContext.HASH_SHA256)
	checksum_context.update(generated.manifest.canonical_json().to_utf8_buffer())
	assert_eq(generated.manifest.checksum(), checksum_context.finish().hex_encode())


func test_roster_generator_default_plan_balances_all_roster_seats() -> void:
	var roster := PlayableBotRoster.new()
	var generated := MANIFEST_GENERATOR_SCRIPT.new().generate(roster)

	assert_true(generated.is_ok())
	var manifest: SimulationManifest = generated.manifest
	assert_eq(manifest.batch_id, &"roster_curated_v2")
	assert_eq(manifest.seed_start, 71001)
	assert_eq(manifest.regimes.size(), 1)
	var regime: SimulationRegime = manifest.regimes[0]
	assert_eq(regime.regime_id, &"roster_9_max")
	assert_eq(regime.player_count, 9)
	assert_eq(regime.starting_stack, 1000)
	assert_eq(regime.starting_small_blind, 5)
	assert_eq(regime.starting_big_blind, 10)
	assert_eq(manifest.matchups.size(), 18)
	_assert_equal_appearances_and_complete_pair_coverage(manifest, roster.get_profile_ids(), 9)
	assert_eq(manifest.evaluation_plans.size(), 1)
	var evaluation_plan: SimulationEvaluationPlan = manifest.evaluation_plans[0]
	assert_eq(evaluation_plan.tournament_count, 2520)
	assert_eq(evaluation_plan.minimum_profile_samples, 100)
	assert_eq(evaluation_plan.seat_rotation, SimulationEvaluationPlan.CYCLIC_ROTATION)
	var batch_plan: SimulationBatchPlan = manifest.build_plan()
	assert_true(batch_plan.is_valid())
	assert_eq(batch_plan.inputs.size(), 2520)
	var profile_seat_counts: Dictionary = {}
	for input: SimulationTournamentInput in batch_plan.inputs:
		var seat_profiles := input.get_seat_profiles()
		for seat: int in seat_profiles:
			var profile: BotProfile = seat_profiles[seat]
			var key := "%s:%d" % [profile.profile_id, seat]
			profile_seat_counts[key] = int(profile_seat_counts.get(key, 0)) + 1
	for profile_id: StringName in roster.get_profile_ids():
		for seat: int in range(regime.player_count):
			assert_eq(profile_seat_counts.get("%s:%d" % [profile_id, seat], 0), 140)


func test_roster_generator_defaults_are_balanced_for_a_three_profile_roster() -> void:
	var catalog_profiles := PlayableBotRoster.new().get_catalog_profiles()
	var three_profile_roster := PlayableBotRoster.new(
		[catalog_profiles[0], catalog_profiles[1], catalog_profiles[2]], null, false
	)
	var generated := MANIFEST_GENERATOR_SCRIPT.new().generate(three_profile_roster)

	assert_true(generated.is_ok())
	assert_eq(generated.manifest.regimes[0].player_count, 3)
	assert_eq(generated.manifest.evaluation_plans[0].tournament_count, 2520)
	var batch_plan: SimulationBatchPlan = generated.manifest.build_plan()
	assert_true(batch_plan.is_valid())
	var rotation_counts: Dictionary = {}
	for input: SimulationTournamentInput in batch_plan.inputs:
		rotation_counts[input.rotation] = int(rotation_counts.get(input.rotation, 0)) + 1
	for rotation: int in range(3):
		assert_eq(rotation_counts.get(rotation, 0), 840)

	var settings := ROSTER_MANIFEST_SETTINGS_SCRIPT.new()
	settings.minimum_profile_samples = 2520
	assert_true(MANIFEST_GENERATOR_SCRIPT.new().generate(three_profile_roster, settings).is_ok())
	settings.minimum_profile_samples = 2521
	var insufficient := MANIFEST_GENERATOR_SCRIPT.new().generate(three_profile_roster, settings)
	assert_false(insufficient.is_ok())
	assert_has(
		insufficient.errors,
		"Roster manifest minimum profile samples exceed per-profile tournaments.",
	)


func test_roster_generator_accepts_custom_planning_defaults_and_rejects_invalid_blinds() -> void:
	var settings: SimulationRosterManifestSettings = ROSTER_MANIFEST_SETTINGS_SCRIPT.new()
	settings.batch_id = &"custom_roster_baseline"
	settings.seed_start = 12
	settings.tournament_count = 180
	settings.starting_stack = 2000
	settings.starting_small_blind = 10
	settings.starting_big_blind = 20
	settings.minimum_profile_samples = 20
	var generated := MANIFEST_GENERATOR_SCRIPT.new().generate(PlayableBotRoster.new(), settings)

	assert_true(generated.is_ok())
	assert_eq(generated.manifest.batch_id, &"custom_roster_baseline")
	assert_eq(generated.manifest.seed_start, 12)
	assert_eq(generated.manifest.evaluation_plans[0].tournament_count, 180)
	assert_eq(generated.manifest.evaluation_plans[0].minimum_profile_samples, 20)
	assert_eq(generated.manifest.regimes[0].starting_stack, 2000)
	assert_eq(generated.manifest.regimes[0].starting_small_blind, 10)
	assert_eq(generated.manifest.regimes[0].starting_big_blind, 20)

	settings.starting_small_blind = 21
	generated = MANIFEST_GENERATOR_SCRIPT.new().generate(PlayableBotRoster.new(), settings)
	assert_false(generated.is_ok())
	assert_eq(generated.manifest, null)
	assert_has(
		generated.errors, "Roster manifest starting small blind cannot exceed the big blind."
	)

	settings.starting_small_blind = 10
	settings.regime_preset = &"unsupported"
	generated = MANIFEST_GENERATOR_SCRIPT.new().generate(PlayableBotRoster.new(), settings)
	assert_false(generated.is_ok())
	assert_eq(generated.manifest, null)
	assert_has(generated.errors, "Roster manifest regime preset must be standard.")


func test_manifest_rejects_model_parameter_type_mismatches() -> void:
	var generated := MANIFEST_GENERATOR_SCRIPT.new().generate(PlayableBotRoster.new())
	assert_true(generated.is_ok())
	var random_profile: BotProfile = generated.manifest.profiles[0]
	random_profile.parameters = StrategyDecisionModelParameters.new()

	assert_has(
		generated.manifest.validate(),
		"Profile random_default parameters do not match model ID: random."
	)


func test_manifest_canonical_json_and_checksum_ignore_input_dictionary_order() -> void:
	var generated := MANIFEST_GENERATOR_SCRIPT.new().generate(PlayableBotRoster.new())
	assert_true(generated.is_ok())
	var canonical: Dictionary = generated.manifest.canonical_dictionary()
	var reordered: Dictionary = {
		"evaluation_plans": canonical.evaluation_plans,
		"matchups": canonical.matchups,
		"regimes": canonical.regimes,
		"profiles": canonical.profiles,
		"seed_start": canonical.seed_start,
		"batch_id": canonical.batch_id,
		"schema_version": canonical.schema_version,
	}
	var first_profile: Dictionary = reordered.profiles[0]
	reordered.profiles[0] = {
		"parameters": first_profile.parameters,
		"model_id": first_profile.model_id,
		"profile_id": first_profile.profile_id,
	}
	var parsed := MANIFEST_SCRIPT.parse(reordered)

	assert_true(parsed.is_ok())
	assert_eq(parsed.manifest.canonical_json(), generated.manifest.canonical_json())
	assert_eq(parsed.manifest.checksum(), generated.manifest.checksum())


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


func _assert_equal_appearances_and_complete_pair_coverage(
	manifest: SimulationManifest, profile_ids: Array[StringName], expected_appearances: int
) -> void:
	var appearances: Dictionary[StringName, int] = {}
	var pairs: Dictionary[String, bool] = {}
	for matchup: SimulationMatchup in manifest.matchups:
		var matchup_ids := _profile_ids(matchup.get_profiles())
		assert_eq(matchup_ids.size(), 9)
		for profile_id: StringName in matchup_ids:
			appearances[profile_id] = int(appearances.get(profile_id, 0)) + 1
		for left_index: int in range(matchup_ids.size()):
			for right_index: int in range(left_index + 1, matchup_ids.size()):
				var pair := [String(matchup_ids[left_index]), String(matchup_ids[right_index])]
				pair.sort()
				pairs["%s|%s" % pair] = true
	for profile_id: StringName in profile_ids:
		assert_eq(appearances.get(profile_id, 0), expected_appearances)
	assert_eq(pairs.size(), profile_ids.size() * (profile_ids.size() - 1) / 2)


func test_manifest_rejects_unknown_fields_and_fractional_parameters() -> void:
	var data := {
		"schema_version": 2,
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
					"call_vs_raise": 50,
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


func test_schema_two_rejects_legacy_or_incomplete_strategy_snapshots() -> void:
	var data := {
		"schema_version": 1,
		"batch_id": "legacy",
		"seed_start": 100,
		"profiles": [],
		"regimes": [],
		"matchups": [],
		"evaluation_plans": [],
	}
	var parsed := MANIFEST_SCRIPT.parse(data)
	assert_false(parsed.is_ok())
	assert_has(parsed.errors, "Unsupported simulation manifest schema version.")

	data.schema_version = 2
	data.profiles = [
		{
			"profile_id": "legacy_strategy",
			"model_id": "strategy_parameterized",
			"parameters":
			{
				"tight_vs_loose": 50,
				"passive_vs_aggressive": 50,
				"call_vs_bet": 50,
				"bluff_rate": 10,
			},
		}
	]
	parsed = MANIFEST_SCRIPT.parse(data)
	assert_false(parsed.is_ok())
	assert_has(parsed.errors, "Unknown parameter field: call_vs_bet")
	assert_has(parsed.errors, "Missing parameter field: call_vs_raise")


func test_simulation_accepts_more_than_the_product_strategic_roster_limit() -> void:
	var manifest := MANIFEST_SCRIPT.new()
	manifest.batch_id = &"simulation_over_product_capacity"
	manifest.seed_start = 2500
	for index: int in range(26):
		manifest.profiles.append(_profile(StringName("strategic_%d" % index), 50))
	manifest.regimes = [SimulationRegime.new(&"heads_up", 2, 20, 5, 10)]
	manifest.matchups = [
		SimulationMatchup.new(&"first_two", [manifest.profiles[0], manifest.profiles[1]])
	]
	manifest.evaluation_plans = [
		SimulationEvaluationPlan.new(&"one_match", &"heads_up", [&"first_two"], 1, 1, &"normal_95")
	]

	var parsed := MANIFEST_SCRIPT.parse(manifest.canonical_dictionary())
	assert_true(parsed.is_ok())
	var plan: SimulationBatchPlan = parsed.manifest.build_plan()
	assert_true(plan.is_valid())
	assert_eq(plan.inputs.size(), 1)
	var result := (
		BATCH_RUNNER_SCRIPT
		. new()
		. run(
			ResolvedTournamentConfig.new(
				2,
				20,
				5,
				10,
				2500,
				&"single_table",
				{0: &"strategy_parameterized", 1: &"strategy_parameterized"}
			),
			plan.inputs,
		)
	)
	assert_true(result.is_success())


func test_shard_contract_filters_without_replanning() -> void:
	var shard := SimulationShard.new(1, 3)
	assert_true(shard.validate().is_empty())
	assert_true(shard.contains(1))
	assert_true(shard.contains(4))
	assert_false(shard.contains(2))
	assert_eq(shard.to_dictionary(), {"index": 1, "count": 3})


func test_cursor_constructs_only_assigned_billion_scale_indexes() -> void:
	var manifest := _cursor_manifest()
	manifest.evaluation_plans[0].tournament_count = 1000000001
	var cursor := manifest.create_cursor(SimulationShard.new(999999999, 1000000000))
	assert_true(cursor.errors.is_empty())
	assert_eq(cursor.assigned_count, 1)
	assert_true(cursor.has_next())
	var input := cursor.next_input()
	assert_eq(input.tournament_index, 999999999)
	assert_eq(input.effective_seed, 1000000999)
	assert_eq(input.matchup_occurrence, 499999999)
	assert_eq(input.rotation, 1)
	assert_eq(input.get_seat_profile_ids(), {0: &"alpha", 1: &"beta"})
	assert_false(cursor.has_next())
	assert_null(cursor.next_input())
	var collected := manifest.build_plan(SimulationShard.new(999999999, 1000000000))
	assert_eq(collected.inputs.size(), 1)
	assert_eq(collected.inputs[0].tournament_index, 999999999)


func test_cursor_preserves_global_and_plan_local_identity_across_boundaries() -> void:
	var manifest := _cursor_manifest()
	manifest.evaluation_plans.append(
		SimulationEvaluationPlan.new(&"second", &"heads_up", [&"beta_alpha"], 4, 2, &"normal_95")
	)
	var cursor := manifest.create_cursor(SimulationShard.new(1, 3))
	assert_eq(cursor.assigned_count, 3)
	for expected_index: int in [1, 4, 7]:
		var input := cursor.next_input()
		var direct := manifest.input_at(expected_index)
		assert_eq(input.tournament_index, expected_index)
		assert_eq(input.plan_id, direct.plan_id)
		assert_eq(input.plan_tournament_index, direct.plan_tournament_index)
		assert_eq(input.matchup_occurrence, direct.matchup_occurrence)
		assert_eq(input.rotation, direct.rotation)
		assert_eq(input.get_seat_profile_ids(), direct.get_seat_profile_ids())
	assert_false(cursor.has_next())
	assert_eq(manifest.input_at(5).plan_tournament_index, 0)
	assert_eq(manifest.input_at(5).rotation, 0)
	assert_null(manifest.input_at(-1))
	assert_null(manifest.input_at(9))


func test_cursor_snapshots_manifest_and_rejects_invalid_shards() -> void:
	var manifest := _cursor_manifest()
	var cursor := manifest.create_cursor()
	manifest.seed_start = 9000
	manifest.matchups[0].matchup_id = &"mutated"
	var exposed := cursor.next_input()
	assert_eq(exposed.effective_seed, 1000)
	exposed.matchup.matchup_id = &"exposed mutation"
	exposed.regime.starting_stack = 99999
	assert_eq(cursor.next_input().matchup.matchup_id, &"beta_alpha")
	var later := cursor.next_input()
	assert_eq(later.matchup.matchup_id, &"alpha_beta")
	assert_eq(later.regime.starting_stack, 100)
	var invalid := manifest.create_cursor(SimulationShard.new(0, 0))
	assert_false(invalid.errors.is_empty())
	assert_false(invalid.has_next())
	assert_null(invalid.next_input())


func _cursor_manifest() -> SimulationManifest:
	var manifest := SimulationManifest.new()
	manifest.batch_id = &"cursor"
	manifest.seed_start = 1000
	manifest.profiles = [_profile(&"alpha", 20), _profile(&"beta", 40)]
	manifest.regimes = [SimulationRegime.new(&"heads_up", 2, 100, 5, 10)]
	manifest.matchups = [
		SimulationMatchup.new(&"alpha_beta", manifest.profiles),
		SimulationMatchup.new(&"beta_alpha", [manifest.profiles[1], manifest.profiles[0]]),
	]
	manifest.evaluation_plans = [
		SimulationEvaluationPlan.new(
			&"first", &"heads_up", [&"alpha_beta", &"beta_alpha"], 5, 2, &"normal_95"
		)
	]
	return manifest


func _profile(profile_id: StringName, tightness: int) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = profile_id
	profile.model_id = &"strategy_parameterized"
	var parameters := StrategyDecisionModelParameters.new()
	parameters.tight_vs_loose = tightness
	profile.parameters = parameters
	return profile


func _profile_ids(profiles: Array[BotProfile]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for profile: BotProfile in profiles:
		ids.append(profile.profile_id)
	return ids


func _unique_model_ids(profiles: Array[BotProfile]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for profile: BotProfile in profiles:
		if profile.model_id not in ids:
			ids.append(profile.model_id)
	return ids
