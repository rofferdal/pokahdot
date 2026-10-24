extends "res://tests/support/poker_gut_test.gd"

const MANIFEST_PATH := "res://tests/fixtures/simulation_manifest_v2.json"


func before_each() -> void:
	_remove_output()
	_write_manifest()


func after_each() -> void:
	_remove_output()
	_remove_manifest()


func test_run_prints_plan_once_and_one_dot_per_completed_tournament() -> void:
	var output: Array[String] = []
	var arguments := PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://scripts/simulation/simulation_cli_app.gd",
			"--",
			"run",
			"--config",
			_manifest_path(),
			"--output",
			_output_path(),
			"--format",
			"text",
		]
	)
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	var command_output := "\n".join(output)

	assert_eq(exit_code, 0, command_output)
	assert_true(FileAccess.file_exists(_output_path()))
	assert_eq(command_output.count("Evaluation plan: first_plan"), 1, command_output)
	assert_eq(command_output.count("Evaluation plan: second_plan"), 1, command_output)
	assert_true(
		command_output.contains(
			"Evaluation plan: first_plan\n.\nEvaluation plan: second_plan\n.\n"
		),
		command_output
	)


func test_json_run_suppresses_progress_and_emits_one_machine_document() -> void:
	var output: Array[String] = []
	var arguments := PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://scripts/simulation/simulation_cli_app.gd",
			"--",
			"run",
			"--config",
			_manifest_path(),
			"--output",
			_output_path(),
			"--format",
			"json",
		]
	)
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	var command_output := "\n".join(output)

	assert_eq(exit_code, 0, command_output)
	assert_false(command_output.contains("Evaluation plan:"), command_output)
	var completion_line := _last_json_line(command_output)
	var completion: Variant = JSON.parse_string(completion_line)
	assert_true(typeof(completion) == TYPE_DICTIONARY, command_output)
	assert_eq(int((completion as Dictionary).tournament_count), 2)


func _last_json_line(output: String) -> String:
	var lines := output.split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		if lines[index].begins_with("{"):
			return lines[index]
	return ""


func _write_manifest() -> void:
	var source := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	assert_not_null(source)
	var document: Dictionary = JSON.parse_string(source.get_as_text())
	var template: Dictionary = document.evaluation_plans[0]
	var first_plan := template.duplicate(true)
	first_plan.plan_id = "first_plan"
	first_plan.tournament_count = 1
	var second_plan := template.duplicate(true)
	second_plan.plan_id = "second_plan"
	second_plan.tournament_count = 1
	document.evaluation_plans = [first_plan, second_plan]
	var target := FileAccess.open(_manifest_path(), FileAccess.WRITE)
	assert_not_null(target)
	target.store_string(JSON.stringify(document))


func _remove_output() -> void:
	if FileAccess.file_exists(_output_path()):
		var result := DirAccess.remove_absolute(_output_path())
		assert_eq(result, OK)


func _remove_manifest() -> void:
	if FileAccess.file_exists(_manifest_path()):
		var result := DirAccess.remove_absolute(_manifest_path())
		assert_eq(result, OK)


func _output_path() -> String:
	return ProjectSettings.globalize_path("res://tests/.simulation_cli_progress_report.json")


func _manifest_path() -> String:
	return ProjectSettings.globalize_path("res://tests/.simulation_cli_progress_manifest.json")
