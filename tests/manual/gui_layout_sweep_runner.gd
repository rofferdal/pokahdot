extends SceneTree

## Headless characterization runner. Recording is explicit and never auto-accepts.
const PureSweep := preload("res://tests/support/gui_layout_sweep.gd")
const SceneSweep := preload("res://tests/support/gui_layout_scene_sweep.gd")
const Registry := preload("res://tests/support/gui_layout_sweep_registry.gd")
const REGISTRY_PATH := "res://tests/fixtures/gui_layout_sweep_known_failures.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = _options()
	if not options.error.is_empty():
		printerr(options.error)
		quit(2)
		return
	var pure: Dictionary = PureSweep.run(options.step)
	var scenes: Dictionary = await SceneSweep.run(get_root())
	var cases: Array[Dictionary] = []
	cases.assign(pure.cases)
	cases.append_array(scenes.cases)
	var source_sha: String = _source_sha()
	var observed: Dictionary = Registry.create(cases, source_sha)
	var source_checksums: Dictionary = _source_checksums()
	observed["source_files_sha256"] = source_checksums
	var failures := PackedStringArray()
	if options.record:
		if options.step != 80:
			printerr("Recording requires the canonical step-80 matrix.")
			quit(2)
			return
		if not _write(REGISTRY_PATH, observed):
			quit(2)
			return
	elif not options.diagnostic:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
		if not parsed is Dictionary:
			failures.append("registry: missing or invalid known-failure file")
		else:
			failures = Registry.compare(cases, parsed)
	var additional_samples: int = (
		_mark_diagnostic_samples(cases, scenes.cases) if options.diagnostic else 0
	)
	var report := {
		"source_sha": source_sha,
		"source_files_sha256": source_checksums,
		"step": options.step,
		"mode": "diagnostic" if options.diagnostic else "characterization",
		"acceptance": "Not established; recorded failures require review, not exemptions.",
		"pure_elapsed_ms": pure.elapsed_ms,
		"scene_elapsed_ms": scenes.elapsed_ms,
		"case_count": cases.size(),
		"failed_case_count": observed.failed_case_count,
		"additional_step20_samples": additional_samples,
		"registry_failures": Array(failures),
		"cases": cases,
	}
	if not _write(options.output, report):
		quit(2)
		return
	print(
		(
			"GUI layout sweep: %d inputs, %d observed failures; pure %d ms, scenes %d ms; %s"
			% [
				cases.size(),
				observed.failed_case_count,
				pure.elapsed_ms,
				scenes.elapsed_ms,
				options.output
			]
		)
	)
	if options.diagnostic:
		print(
			"Diagnostic step includes newly sampled inputs; it does not certify the step-80 registry."
		)
	for failure: String in failures.slice(0, 20):
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _options() -> Dictionary:
	var result := {
		"step": 80,
		"record": false,
		"diagnostic": false,
		"output": "res://localtmp/gui-layout-characterization/report.json",
		"error": "",
	}
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < arguments.size():
		var argument: String = arguments[index]
		match argument:
			"--record":
				result.record = true
			"--diagnostic":
				result.diagnostic = true
			"--step", "--output":
				index += 1
				if index >= arguments.size():
					result.error = "Missing value for %s" % argument
					break
				if argument == "--step":
					result.step = arguments[index].to_int()
				else:
					result.output = arguments[index]
			_:
				result.error = "Unknown argument: %s" % argument
		index += 1
	if result.step not in [20, 80]:
		result.error = "Choose step 80 for characterization or step 20 for diagnostics."
	if result.step == 20 and not result.diagnostic:
		result.error = "Step 20 requires --diagnostic; it is additional sampling."
	if result.record and result.diagnostic:
		result.error = "Recording and diagnostics are separate modes."
	return result


func _write(path: String, value: Dictionary) -> bool:
	var absolute: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file: FileAccess = FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write sweep evidence: %s" % absolute)
		return false
	file.store_string(JSON.stringify(value, "\t") + "\n")
	return file.get_error() == OK


func _source_sha() -> String:
	var output: Array[String] = []
	if OS.execute("git", ["rev-parse", "HEAD"], output) != 0:
		return "unavailable"
	return "".join(output).strip_edges()


func _source_checksums() -> Dictionary:
	var result: Dictionary = {}
	for directory: String in ["res://scripts/gui", "res://tests/support"]:
		var files: PackedStringArray = DirAccess.get_files_at(directory)
		files.sort()
		for file: String in files:
			if file.ends_with(".gd"):
				var path: String = directory.path_join(file)
				result[path] = FileAccess.get_sha256(path)
	for path: String in [
		"res://scenes/main.tscn",
		"res://scenes/poker_table.tscn",
		"res://project.godot",
		"res://resources/gui_theme.tres",
		"res://tests/manual/gui_layout_sweep_runner.gd",
		"res://Makefile",
	]:
		result[path] = FileAccess.get_sha256(path)
	return result


func _mark_diagnostic_samples(cases: Array[Dictionary], scenes: Array) -> int:
	var canonical: Dictionary[String, bool] = {}
	for case: Dictionary in PureSweep.run(80).cases:
		canonical[case.id] = true
	for case: Dictionary in scenes:
		canonical[case.id] = true
	var additional: int = 0
	for case: Dictionary in cases:
		var covered: bool = canonical.has(case.id)
		case["sampling"] = "canonical-step80" if covered else "additional-step20"
		if not covered:
			additional += 1
	return additional
