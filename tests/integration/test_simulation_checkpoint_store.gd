extends "res://tests/support/poker_gut_test.gd"

const FIXTURE := "res://tests/fixtures/simulation_manifest_v2.json"
var _directory: String
var _manifest: SimulationManifest


func before_each() -> void:
	_directory = ProjectSettings.globalize_path(
		"res://localtmp/checkpoint-store-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	_manifest = (
		SimulationManifest.parse(JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))).manifest
	)


func test_checkpoint_owns_snapshots_and_refuses_duplicate_publication() -> void:
	var store := _fresh()
	var outcome := _outcome()
	assert_true(store.save_outcome(outcome), store.error_message)
	var path := _directory.path_join("0.json")
	var original := FileAccess.get_file_as_string(path)
	assert_false(store.save_outcome(outcome))
	assert_eq(FileAccess.get_file_as_string(path), original)
	var record := store.load_record(0)
	assert_false(record.is_empty(), store.error_message)
	record.tournament.plan_id = "changed caller copy"
	record.traces.clear()
	assert_eq(store.load_record(0).tournament.plan_id, "fixture_plan")
	var resumed := SimulationCheckpointStore.new()
	assert_true(
		resumed.initialize(
			_directory,
			_manifest,
			SimulationShard.new(),
			_provenance(),
			SimulationTraceConfig.new(),
			true
		)
	)
	assert_eq(resumed.started_at, store.started_at)
	assert_eq(resumed.load_record(0).tournament_json, store.load_record(0).tournament_json)


func test_resume_rejects_each_executable_provenance_difference() -> void:
	_fresh()
	for field: String in [
		"code_revision",
		"dirty_source_fingerprint",
		"engine_version",
		"source_state",
		"algorithm_versions"
	]:
		var changed := _provenance()
		if field == "algorithm_versions":
			changed.algorithm_versions.simulation_runner = "changed"
		else:
			changed[field] = "changed"
		var resumed := SimulationCheckpointStore.new()
		assert_false(
			resumed.initialize(
				_directory,
				_manifest,
				SimulationShard.new(),
				changed,
				SimulationTraceConfig.new(),
				true
			),
			field
		)


func test_invalid_record_json_and_checksum_fail_without_engine_errors() -> void:
	var store := _fresh()
	assert_true(store.save_outcome(_outcome()))
	var path := _directory.path_join("0.json")
	var original := FileAccess.get_file_as_string(path)
	_write(path, "{truncated")
	assert_true(store.load_record(0).is_empty())
	assert_true(store.error_message.contains("JSON object"))
	var record: Dictionary = JSON.parse_string(original)
	record.tournament_json = "{}"
	_write(path, JSON.stringify(record))
	assert_true(store.load_record(0).is_empty())
	assert_true(store.error_message.contains("checksum"))


func test_recomputed_checksum_does_not_bypass_plan_or_trace_validation() -> void:
	var store := _fresh()
	assert_true(store.save_outcome(_outcome()))
	var path := _directory.path_join("0.json")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var record := original.duplicate(true)
	var tournament: Dictionary = JSON.parse_string(record.tournament_json)
	tournament.effective_seed += 1
	record.tournament_json = JSON.stringify(tournament, "", true, true)
	_write_record(path, record)
	assert_true(store.load_record(0).is_empty())
	assert_true(store.error_message.contains("does not match its plan"))
	record = original.duplicate(true)
	record.traces_json = JSON.stringify([{"tournament_index": 0, "hole_cards": ["AS", "KS"]}])
	_write_record(path, record)
	assert_true(store.load_record(0).is_empty())
	assert_true(store.error_message.contains("disabled"))
	record = original.duplicate(true)
	record.tournament_json = "{invalid"
	_write_record(path, record)
	assert_true(store.load_record(0).is_empty())
	assert_true(store.error_message.contains("invalid JSON"))


func test_streamed_report_is_canonical_and_preserves_tournament_digests() -> void:
	var store := _fresh()
	var batch: SimulationBatchResult = SimulationBatchRunner.new().run(
		_manifest.regimes[0].resolve(_manifest.seed_start).get_config(),
		_manifest.build_plan().inputs
	)
	for outcome: SimulationTournamentOutcome in batch.outcomes:
		assert_true(store.save_outcome(outcome))
	# Valid JSON whitespace must not turn an empty trace array into a nested array.
	var checkpoint_path := _directory.path_join("0.json")
	var checkpoint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
	checkpoint.traces_json = " [ ] "
	_write_record(checkpoint_path, checkpoint)
	var path := _directory.path_join("report.json")
	var writer := SimulationStreamReportWriter.new()
	var result := writer.write(
		path, store, _manifest, SimulationShard.new(), batch.aggregates, false
	)
	assert_true(result.success, writer.error_message)
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var report := SimulationReport.from_dictionary(parsed)
	assert_eq(report.validate(), PackedStringArray())
	var expected_report := SimulationReport.from_batch(
		_manifest,
		SimulationShard.new(),
		batch,
		parsed.started_at,
		parsed.finished_at,
		_provenance()
	)
	assert_eq(result.report_checksum, expected_report.checksum())
	assert_eq(result.report_checksum, FileAccess.get_sha256(path))
	for index: int in range(batch.outcomes.size()):
		assert_eq(
			SimulationReport.tournament_digest(parsed.tournaments[index]),
			SimulationReport.tournament_digest(
				SimulationReport._tournament_dictionary(batch.outcomes[index])
			)
		)
	var existing := FileAccess.get_file_as_string(path)
	assert_false(writer.write(path, store, _manifest, SimulationShard.new(), {}, false).success)
	assert_eq(FileAccess.get_file_as_string(path), existing)


func test_streamed_trace_arrays_handle_empty_then_padded_nonempty_records() -> void:
	var trace_config := SimulationTraceConfig.new(SimulationTraceConfig.Mode.SAMPLED, 4)
	var store := SimulationCheckpointStore.new()
	assert_true(
		store.initialize(
			_directory, _manifest, SimulationShard.new(), _provenance(), trace_config, false
		)
	)
	var expected_traces: Array = []
	for index: int in range(2):
		var outcome := (
			SimulationBatchRunner
			. new()
			. run_one(
				_manifest.regimes[0].resolve(_manifest.seed_start).get_config(),
				_manifest.input_at(index),
				256,
				trace_config,
			)
		)
		assert_true(store.save_outcome(outcome))
		var path := _directory.path_join("%d.json" % index)
		var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		if index == 0:
			record.traces_json = " \n [ ] \n "
		else:
			expected_traces = JSON.parse_string(record.traces_json)
			assert_false(expected_traces.is_empty())
			record.traces_json = " \n " + String(record.traces_json) + " \n "
		_write_record(path, record)
	var path := _directory.path_join("trace-report.json")
	var writer := SimulationStreamReportWriter.new()
	assert_true(
		writer.write(path, store, _manifest, SimulationShard.new(), {}, false).success,
		writer.error_message
	)
	var parser := JSON.new()
	assert_eq(parser.parse(FileAccess.get_file_as_string(path)), OK)
	assert_eq(parser.data.traces, expected_traces)


func _fresh() -> SimulationCheckpointStore:
	var store := SimulationCheckpointStore.new()
	assert_true(
		store.initialize(
			_directory,
			_manifest,
			SimulationShard.new(),
			_provenance(),
			SimulationTraceConfig.new(),
			false
		),
		store.error_message
	)
	return store


func _outcome() -> SimulationTournamentOutcome:
	return SimulationBatchRunner.new().run_one(
		_manifest.regimes[0].resolve(_manifest.seed_start).get_config(), _manifest.input_at(0)
	)


func _provenance() -> Dictionary:
	return {
		"code_revision": "1".repeat(40),
		"source_state": "clean",
		"dirty_source_fingerprint": "",
		"engine_version": "test-engine",
		"algorithm_versions": SimulationProvenance.ALGORITHM_VERSIONS.duplicate(true),
	}


func _write_record(path: String, record: Dictionary) -> void:
	record.erase("checksum")
	record.checkpoint_schema_version = SimulationCheckpointStore.SCHEMA_VERSION
	record["checksum"] = JSON.stringify(record, "", true).sha256_text()
	_write(path, JSON.stringify(record, "", true, true))


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
