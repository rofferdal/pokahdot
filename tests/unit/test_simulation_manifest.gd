extends "res://tests/support/poker_gut_test.gd"

const MANIFEST_SCRIPT := preload("res://scripts/simulation/simulation_manifest.gd")
const MANIFEST_GENERATOR_SCRIPT := preload(
	"res://scripts/simulation/simulation_manifest_generator.gd"
)
const ROSTER_MANIFEST_SETTINGS_SCRIPT := preload(
	"res://scripts/simulation/simulation_roster_manifest_settings.gd"
)


func test_roster_generator_creates_a_valid_schema_two_snapshot_manifest() -> void:
	var roster := PlayableBotRoster.new()
	var generated := MANIFEST_GENERATOR_SCRIPT.new().generate(roster)

	assert_true(generated.is_ok())
	assert_true(generated.errors.is_empty())
	assert_eq(generated.manifest.schema_version, SimulationManifest.SUPPORTED_SCHEMA_VERSION)
	assert_eq(generated.manifest.batch_id, &"roster_curated_v1")
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
	assert_eq(manifest.batch_id, &"roster_curated_v1")
	assert_eq(manifest.seed_start, 71001)
	assert_eq(manifest.regimes.size(), 1)
	var regime: SimulationRegime = manifest.regimes[0]
	assert_eq(regime.regime_id, &"roster_8_max")
	assert_eq(regime.player_count, 8)
	assert_eq(regime.starting_stack, 1000)
	assert_eq(regime.starting_small_blind, 5)
	assert_eq(regime.starting_big_blind, 10)
	assert_eq(manifest.matchups.size(), 1)
	assert_eq(manifest.matchups[0].matchup_id, &"active_roster")
	assert_eq(_profile_ids(manifest.matchups[0].get_profiles()), roster.get_profile_ids())
	assert_eq(manifest.evaluation_plans.size(), 1)
	var evaluation_plan: SimulationEvaluationPlan = manifest.evaluation_plans[0]
	assert_eq(evaluation_plan.tournament_count, 2520)
	assert_eq(evaluation_plan.minimum_profile_samples, 100)
	assert_eq(evaluation_plan.seat_rotation, SimulationEvaluationPlan.CYCLIC_ROTATION)
	var batch_plan: SimulationBatchPlan = manifest.build_plan()
	assert_true(batch_plan.is_valid())
	assert_eq(batch_plan.inputs.size(), 2520)
	var rotation_counts: Dictionary = {}
	for input: SimulationTournamentInput in batch_plan.inputs:
		rotation_counts[input.rotation] = int(rotation_counts.get(input.rotation, 0)) + 1
	for rotation: int in range(regime.player_count):
		assert_eq(rotation_counts.get(rotation, 0), 315)


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


func test_roster_generator_accepts_custom_planning_defaults_and_rejects_invalid_blinds() -> void:
	var settings: SimulationRosterManifestSettings = ROSTER_MANIFEST_SETTINGS_SCRIPT.new()
	settings.batch_id = &"custom_roster_baseline"
	settings.seed_start = 12
	settings.tournament_count = 160
	settings.starting_stack = 2000
	settings.starting_small_blind = 10
	settings.starting_big_blind = 20
	settings.minimum_profile_samples = 20
	var generated := MANIFEST_GENERATOR_SCRIPT.new().generate(PlayableBotRoster.new(), settings)

	assert_true(generated.is_ok())
	assert_eq(generated.manifest.batch_id, &"custom_roster_baseline")
	assert_eq(generated.manifest.seed_start, 12)
	assert_eq(generated.manifest.evaluation_plans[0].tournament_count, 160)
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
