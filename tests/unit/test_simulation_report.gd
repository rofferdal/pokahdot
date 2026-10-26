extends "res://tests/support/poker_gut_test.gd"

const REPORT_SCRIPT := preload("res://scripts/simulation/simulation_report.gd")
const PROVENANCE_SCRIPT := preload("res://scripts/simulation/simulation_provenance.gd")


func test_roster_provenance_matches_the_cross_language_fixture() -> void:
	var file := FileAccess.open("res://tests/fixtures/roster_provenance_v1.json", FileAccess.READ)
	assert_not_null(file)
	var fixture: Dictionary = JSON.parse_string(file.get_as_text())
	var alpha := _profile(&"alpha")
	alpha.parameters = RandomDecisionModelParameters.new()
	var beta := BotProfile.new()
	beta.profile_id = &"beta"
	beta.model_id = &"strategy_parameterized"
	beta.parameters = StrategyDecisionModelParameters.new()
	(beta.parameters as StrategyDecisionModelParameters).tight_vs_loose = 50
	(beta.parameters as StrategyDecisionModelParameters).passive_vs_aggressive = 50
	(beta.parameters as StrategyDecisionModelParameters).call_vs_raise = 50
	(beta.parameters as StrategyDecisionModelParameters).bluff_rate = 10
	var manifest := SimulationManifest.new()
	manifest.profiles = [alpha, beta]

	assert_eq(manifest.roster_provenance().profile_ids, fixture.profile_ids)
	assert_eq(manifest.roster_provenance().version, fixture.version)


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

	var report: RefCounted = REPORT_SCRIPT.from_batch(
		manifest, SimulationShard.new(), batch, "", "", _provenance()
	)
	assert_true(report.validate().is_empty())
	assert_eq(report.manifest, manifest.canonical_dictionary())
	assert_eq(report.manifest_checksum, manifest.checksum())
	assert_eq(report.roster, manifest.roster_provenance())
	assert_eq(report.tournaments.size(), 1)
	assert_eq(report.tournaments[0].plan_id, "plan")
	assert_eq(report.tournaments[0].effective_seed, 200)
	assert_eq(report.tournaments[0].seat_map.size(), 2)
	assert_eq(report.tournaments[0].selected_profile_ids, ["alpha", "beta"])
	assert_eq(report.tournaments[0].profile_results.size(), 2)
	assert_false(report.to_dictionary().has("hole_cards"))


func test_schema_four_rejects_legacy_command_and_incomplete_metric_payloads() -> void:
	var manifest := SimulationManifest.new()
	manifest.batch_id = &"report_validation"
	manifest.seed_start = 300
	manifest.profiles = [_profile(&"alpha"), _profile(&"beta")]
	manifest.regimes = [SimulationRegime.new(&"heads_up", 2, 20, 5, 10)]
	manifest.matchups = [SimulationMatchup.new(&"match", manifest.profiles)]
	manifest.evaluation_plans = [SimulationEvaluationPlan.new(&"plan", &"heads_up", [&"match"], 1)]
	var batch := (
		SimulationBatchRunner
		. new()
		. run(
			ResolvedTournamentConfig.new(
				2, 20, 5, 10, 300, &"single_table", {0: &"random", 1: &"random"}
			),
			manifest.build_plan().inputs,
		)
	)
	var valid_report: RefCounted = REPORT_SCRIPT.from_batch(
		manifest, SimulationShard.new(), batch, "", "", _provenance()
	)
	var data: Dictionary = valid_report.to_dictionary()
	data.command_version = "simulation_cli_v1"
	var parsed: RefCounted = REPORT_SCRIPT.from_dictionary(data)
	assert_has(parsed.validate(), "Unsupported simulation command version.")

	data.command_version = "simulation_cli_v6"
	data.tournaments[0].profile_results[0].erase("eligible_bluff_opportunities")
	parsed = REPORT_SCRIPT.from_dictionary(data)
	assert_has(
		parsed.validate(),
		"Simulation profile result is missing field: eligible_bluff_opportunities",
	)

	data = valid_report.to_dictionary()
	data.manifest = 1
	data.tournaments = [42]
	data.traces = [false]
	parsed = REPORT_SCRIPT.from_dictionary(data)
	assert_has(parsed.validate(), "Simulation report field has invalid type: manifest")
	assert_has(parsed.validate(), "Simulation tournament must be an object.")
	assert_has(parsed.validate(), "Simulation trace must be an object.")


func test_schema_four_rejects_wrong_nested_field_types_without_conversion_errors() -> void:
	var valid_data := _valid_report_dictionary()
	valid_data.report_schema_version = {"invalid": true}
	var parsed: RefCounted = REPORT_SCRIPT.from_dictionary(valid_data)
	assert_has(
		parsed.validate(),
		"Simulation report field has invalid type: report_schema_version",
	)

	valid_data = _valid_report_dictionary()
	valid_data.shard.index = []
	parsed = REPORT_SCRIPT.from_dictionary(valid_data)
	assert_has(parsed.validate(), "Simulation report shard field has invalid type: index")

	valid_data = _valid_report_dictionary()
	valid_data.tournaments[0].seat_map = false
	valid_data.tournaments[0].profile_results[0].eligible_bluff_opportunities = "one"
	parsed = REPORT_SCRIPT.from_dictionary(valid_data)
	assert_has(parsed.validate(), "Simulation tournament field has invalid type: seat_map")
	assert_has(
		parsed.validate(),
		"Simulation profile result field has invalid type: eligible_bluff_opportunities",
	)

	valid_data = _valid_report_dictionary()
	valid_data.roster.version = "forged"
	valid_data.tournaments[0].selected_profile_ids = ["beta", "alpha"]
	parsed = REPORT_SCRIPT.from_dictionary(valid_data)
	assert_has(
		parsed.validate(), "Simulation report roster version does not match its manifest profiles."
	)
	assert_has(
		parsed.validate(), "Simulation selected profile IDs do not match the ordered seat map."
	)


func _valid_report_dictionary() -> Dictionary:
	var manifest := SimulationManifest.new()
	manifest.batch_id = &"nested_validation"
	manifest.seed_start = 400
	manifest.profiles = [_profile(&"alpha"), _profile(&"beta")]
	manifest.regimes = [SimulationRegime.new(&"heads_up", 2, 20, 5, 10)]
	manifest.matchups = [SimulationMatchup.new(&"match", manifest.profiles)]
	manifest.evaluation_plans = [SimulationEvaluationPlan.new(&"plan", &"heads_up", [&"match"], 1)]
	var batch := (
		SimulationBatchRunner
		. new()
		. run(
			ResolvedTournamentConfig.new(
				2, 20, 5, 10, 400, &"single_table", {0: &"random", 1: &"random"}
			),
			manifest.build_plan().inputs,
		)
	)
	return (
		REPORT_SCRIPT
		. from_batch(manifest, SimulationShard.new(), batch, "", "", _provenance())
		. to_dictionary()
	)


func _provenance() -> Dictionary:
	return {
		"algorithm_versions": PROVENANCE_SCRIPT.ALGORITHM_VERSIONS.duplicate(true),
		"code_revision": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"dirty_source_fingerprint": "",
		"engine_version": "4.test",
		"source_state": "clean",
	}


func _profile(profile_id: StringName) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = profile_id
	profile.model_id = &"random"
	profile.parameters = RandomDecisionModelParameters.new()
	return profile
