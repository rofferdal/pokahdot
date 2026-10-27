extends "res://tests/support/poker_gut_test.gd"

const FIXTURE := "res://tests/fixtures/simulation_manifest_v2.json"
var _work: String


func before_each() -> void:
	_work = ProjectSettings.globalize_path(
		"res://localtmp/checkpoint-cli-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	assert_eq(DirAccess.make_dir_recursive_absolute(_work), OK)


func test_killed_cli_resumes_without_rewriting_completed_records() -> void:
	var manifest_path := _write_manifest(120)
	var checkpoint := _work.path_join("interrupted")
	var resumed_path := _work.path_join("resumed.json")
	var arguments := _arguments(manifest_path, resumed_path, checkpoint)
	var pid := OS.create_process(OS.get_executable_path(), arguments)
	assert_gt(pid, 0)
	if pid <= 0:
		return
	var deadline := Time.get_ticks_msec() + 15000
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		if _checkpoint_files(checkpoint).size() >= 4:
			break
		await get_tree().process_frame
	if OS.is_process_running(pid):
		assert_eq(OS.kill(pid), OK)
	for _frame: int in range(4):
		await get_tree().process_frame
	var retained := _checkpoint_files(checkpoint)
	assert_gte(
		retained.size(), 4, "The process must persist completed records before interruption."
	)
	assert_lt(retained.size(), 121, "The process must be interrupted before batch completion.")
	assert_false(
		FileAccess.file_exists(resumed_path), "Partial results must not publish a final report."
	)
	if retained.size() < 4 or retained.size() >= 121:
		return
	var original_contents: Dictionary[String, String] = {}
	var original_times: Dictionary[String, int] = {}
	for filename: String in retained:
		var path := checkpoint.path_join(filename)
		original_contents[filename] = FileAccess.get_file_as_string(path)
		original_times[filename] = FileAccess.get_modified_time(path)
	# File modification times have whole-second resolution on supported systems.
	await get_tree().create_timer(1.1).timeout
	var torn := FileAccess.open(
		checkpoint.path_join("ignored.json.tmp.interrupted"), FileAccess.WRITE
	)
	torn.store_string("{torn temporary sibling")
	torn.close()
	arguments.append("--resume")
	var resumed := _execute(arguments)
	assert_eq(resumed.status, 0, resumed.output)
	if resumed.status != 0:
		return
	for filename: String in original_contents:
		var path := checkpoint.path_join(filename)
		assert_eq(FileAccess.get_file_as_string(path), original_contents[filename])
		assert_eq(
			FileAccess.get_modified_time(path), original_times[filename], "Reuse %s" % filename
		)
	var control_path := _work.path_join("control.json")
	var control := _execute(_arguments(manifest_path, control_path, _work.path_join("control")))
	assert_eq(control.status, 0, control.output)
	if control.status != 0:
		return
	var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resumed_path))
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(control_path))
	assert_eq(actual.tournaments.size(), 120)
	for index: int in range(120):
		assert_eq(
			SimulationReport.tournament_digest(actual.tournaments[index]),
			SimulationReport.tournament_digest(expected.tournaments[index]),
			"Tournament %d" % index
		)
	assert_eq(actual.traces, expected.traces)
	assert_eq(actual.aggregates, expected.aggregates)
	assert_eq(_completion(resumed.output).report_checksum, FileAccess.get_sha256(resumed_path))
	assert_eq(SimulationReport.from_dictionary(actual).validate(), PackedStringArray())


func test_resume_rejects_manifest_shard_trace_and_corrupted_checkpoint() -> void:
	var manifest_path := _write_manifest(2)
	var checkpoint := _work.path_join("checkpoint")
	var first := _execute(_arguments(manifest_path, _work.path_join("first.json"), checkpoint))
	assert_eq(first.status, 0, first.output)
	if first.status != 0:
		return
	var base := _arguments(manifest_path, _work.path_join("rejected.json"), checkpoint)
	base.append("--resume")
	var fresh := _execute(_arguments(manifest_path, _work.path_join("fresh.json"), checkpoint))
	assert_ne(fresh.status, 0, "An existing checkpoint requires explicit resume.")
	var wrong_shard := base.duplicate()
	wrong_shard.append_array(["--shard", "0/2"])
	assert_ne(_execute(wrong_shard).status, 0)
	var wrong_trace := base.duplicate()
	wrong_trace[wrong_trace.find("sampled")] = "none"
	assert_ne(_execute(wrong_trace).status, 0)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	data.seed_start += 100
	_write_json(manifest_path, data)
	assert_ne(_execute(base).status, 0)
	data.seed_start -= 100
	_write_json(manifest_path, data)
	var files := _checkpoint_files(checkpoint)
	assert_false(files.is_empty())
	if not files.is_empty():
		var file := FileAccess.open(checkpoint.path_join(files[0]), FileAccess.WRITE)
		file.store_string("{truncated")
		file.close()
		assert_ne(_execute(base).status, 0, "Corrupted records must not silently rerun or publish.")
	assert_false(FileAccess.file_exists(_work.path_join("rejected.json")))


func _checkpoint_files(directory: String) -> PackedStringArray:
	var result := PackedStringArray()
	if not DirAccess.dir_exists_absolute(directory):
		return result
	for filename: String in DirAccess.get_files_at(directory):
		if filename.ends_with(".json"):
			result.append(filename)
	result.sort()
	return result


func _write_manifest(count: int) -> String:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	data.evaluation_plans[0].tournament_count = count
	var path := _work.path_join("manifest.json")
	_write_json(path, data)
	return path


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", true, true))
	file.close()


func _arguments(
	manifest_path: String, report_path: String, checkpoint: String
) -> PackedStringArray:
	return PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://scripts/simulation/simulation_cli_app.gd",
			"--",
			"run",
			"--config",
			manifest_path,
			"--output",
			report_path,
			"--checkpoint",
			checkpoint,
			"--trace",
			"sampled",
			"--trace-sample",
			"4",
			"--format",
			"json"
		]
	)


func _execute(arguments: PackedStringArray) -> Dictionary:
	var output: Array[String] = []
	var status := OS.execute(OS.get_executable_path(), arguments, output, true)
	return {"status": status, "output": "\n".join(output)}


func _completion(output: String) -> Dictionary:
	var lines := output.split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		if lines[index].begins_with("{"):
			var parsed: Variant = JSON.parse_string(lines[index])
			if parsed is Dictionary:
				return parsed
	return {}
