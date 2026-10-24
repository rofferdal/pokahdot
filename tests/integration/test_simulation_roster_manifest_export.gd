extends "res://tests/support/poker_gut_test.gd"

const MANIFEST_SCRIPT := preload("res://scripts/simulation/simulation_manifest.gd")


func before_each() -> void:
	_remove_output()


func after_each() -> void:
	_remove_output()


func test_exported_roster_manifest_is_atomic_valid_and_immediately_validatable() -> void:
	var first_result := _run_cli(
		[
			"export-roster-manifest",
			"--output",
			_output_path(),
			"--batch-id",
			"integration_roster",
			"--seed",
			"901",
			"--tournament-count",
			"792",
		]
	)

	assert_eq(first_result.exit_code, 0, first_result.output)
	assert_true(FileAccess.file_exists(_output_path()))
	assert_false(FileAccess.file_exists("%s.tmp" % _output_path()))
	var first_document := _read_document()
	var parsed := MANIFEST_SCRIPT.parse(first_document)
	assert_true(parsed.is_ok())
	assert_eq(parsed.manifest.batch_id, &"integration_roster")
	assert_eq(parsed.manifest.seed_start, 901)
	assert_true(parsed.manifest.build_plan().is_valid())

	var validate_result := _run_cli(["validate", "--config", _output_path()])
	assert_eq(validate_result.exit_code, 0, validate_result.output)

	var refused_result := _run_cli(
		["export-roster-manifest", "--output", _output_path(), "--tournament-count", "792"]
	)
	assert_eq(refused_result.exit_code, 3, refused_result.output)
	assert_eq(_read_document(), first_document)

	var overwrite_result := _run_cli(
		[
			"export-roster-manifest",
			"--output",
			_output_path(),
			"--overwrite",
			"--batch-id",
			"replacement_roster",
			"--tournament-count",
			"792",
		]
	)
	assert_eq(overwrite_result.exit_code, 0, overwrite_result.output)
	assert_eq(MANIFEST_SCRIPT.parse(_read_document()).manifest.batch_id, &"replacement_roster")


func _run_cli(arguments: Array[String]) -> Dictionary:
	var output: Array[String] = []
	var command_arguments := PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://scripts/simulation/simulation_cli_app.gd",
			"--",
		]
	)
	command_arguments.append_array(PackedStringArray(arguments))
	var exit_code := OS.execute(OS.get_executable_path(), command_arguments, output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _read_document() -> Dictionary:
	var file := FileAccess.open(_output_path(), FileAccess.READ)
	assert_not_null(file)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(typeof(parsed) == TYPE_DICTIONARY)
	return parsed as Dictionary


func _remove_output() -> void:
	if FileAccess.file_exists(_output_path()):
		var result := DirAccess.remove_absolute(_output_path())
		assert_eq(result, OK)


func _output_path() -> String:
	return ProjectSettings.globalize_path(
		"res://tests/.simulation_roster_manifest_export_test.json"
	)
