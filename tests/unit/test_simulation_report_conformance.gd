extends "res://tests/support/poker_gut_test.gd"

const REPORT := preload("res://scripts/simulation/simulation_report.gd")
const CORPUS_PATH := "res://tests/fixtures/artifact_conformance_v1.json"
const OUTPUT_DIRECTORY := "res://localtmp/artifact-conformance"


func test_shared_artifact_corpus_matches_direct_validation_and_cli_inspect() -> void:
	var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CORPUS_PATH))
	assert_eq(corpus.fixture_version, 1.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	for case: Dictionary in corpus.cases:
		var data: Dictionary = _case_report(corpus, case)
		var errors: PackedStringArray = REPORT.from_dictionary(data).validate()
		assert_eq(errors.is_empty(), bool(case.valid), "%s: %s" % [case.id, errors])
		if case.valid:
			var round_trip: Dictionary = JSON.parse_string(
				REPORT.from_dictionary(data).canonical_json()
			)
			assert_eq(round_trip.manifest.seed_start, data.manifest.seed_start, case.id)
			for index: int in range(data.tournaments.size()):
				assert_eq(
					round_trip.tournaments[index].effective_seed,
					data.tournaments[index].effective_seed,
					case.id
				)
		var path: String = OUTPUT_DIRECTORY.path_join("%s.json" % case.id)
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert_not_null(file)
		file.store_string(JSON.stringify(data, "", true, true))
		file.close()
		var output: Array[String] = []
		var exit_code: int = (
			OS
			. execute(
				OS.get_executable_path(),
				PackedStringArray(
					[
						"--headless",
						"--path",
						ProjectSettings.globalize_path("res://"),
						"--script",
						"res://scripts/simulation/simulation_cli_app.gd",
						"--",
						"inspect",
						"--report",
						ProjectSettings.globalize_path(path),
						"--format",
						"json",
					]
				),
				output,
				true
			)
		)
		assert_eq(exit_code, 0 if case.valid else 3, "%s inspect: %s" % [case.id, output])


func test_partial_failed_report_remains_inspectable_without_completed_evidence() -> void:
	var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CORPUS_PATH))
	var data: Dictionary = corpus.base_report.duplicate(true)
	data.tournaments.resize(1)
	var tournament: Dictionary = data.tournaments[0]
	tournament.termination_reason = ""
	tournament.winner_profile_id = ""
	tournament.profile_results = []
	tournament.tournament_hand_count = 0
	tournament.diagnostics = [{"stage": 2, "seat": -1, "message": "Stopped safely in execution."}]
	assert_eq(REPORT.from_dictionary(data).validate(), PackedStringArray())
	tournament.termination_reason = "invented_reason"
	assert_false(REPORT.from_dictionary(data).validate().is_empty())


func test_manifest_validation_does_not_expand_a_large_declared_plan() -> void:
	var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CORPUS_PATH))
	var data: Dictionary = corpus.base_report.duplicate(true)
	data.manifest.evaluation_plans[0].tournament_count = 1000000000
	var parsed := SimulationManifest.parse(data.manifest)
	assert_true(parsed.is_ok())
	data.manifest_checksum = parsed.manifest.checksum()
	var errors: PackedStringArray = REPORT.from_dictionary(data).validate()
	assert_has(errors, "Completed simulation report does not cover its complete planned shard.")


func _case_report(corpus: Dictionary, case: Dictionary) -> Dictionary:
	var data: Dictionary = corpus.base_report.duplicate(true)
	for patch: Dictionary in case.patches:
		var target: Variant = data
		for index: int in range(patch.path.size() - 1):
			var key: Variant = patch.path[index]
			if typeof(key) == TYPE_FLOAT:
				key = int(key)
			target = target[key]
		var leaf: Variant = patch.path[-1]
		if typeof(leaf) == TYPE_FLOAT:
			leaf = int(leaf)
		target[leaf] = patch.value
	return data
