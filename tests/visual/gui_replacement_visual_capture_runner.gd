extends SceneTree
# gdlint: disable=max-returns

## Release-safe replacement capture. The caller must provide a new localtmp path.
const Manifest := preload("res://tests/support/gui_replacement_visual_capture_manifest.gd")
const Matrix := preload("res://tests/support/gui_replacement_matrix_support.gd")

const EXIT_USAGE: int = 2
const EXIT_TREE_STATE: int = 3
const EXIT_CAPTURE: int = 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_arguments(OS.get_cmdline_user_args())
	if not options.error.is_empty():
		printerr(options.error)
		_print_usage()
		quit(EXIT_USAGE)
		return
	if options.help:
		_print_usage()
		quit(0)
		return
	var cases: Array[Dictionary] = Manifest.cases(options.category)
	if not options.case_id.is_empty():
		if not options.development:
			printerr(
				"A selected capture case requires --development and cannot be acceptance evidence."
			)
			quit(EXIT_USAGE)
			return
		var selected: Array[Dictionary] = []
		for case: Dictionary in cases:
			if case.case_id == options.case_id:
				selected.append(case)
		cases = selected
	if cases.is_empty():
		printerr("No replacement capture cases match %s." % options.category)
		quit(EXIT_USAGE)
		return
	var output_path: String = options.output
	if not Manifest.is_safe_output_path(output_path):
		printerr("Capture output must be a new path beneath localtmp/.")
		quit(EXIT_USAGE)
		return
	var output_absolute := ProjectSettings.globalize_path("res://" + output_path)
	if DirAccess.dir_exists_absolute(output_absolute) or FileAccess.file_exists(output_absolute):
		printerr("Capture output already exists; choose a new localtmp path: %s" % output_path)
		quit(EXIT_CAPTURE)
		return
	var source_state := _read_source_state()
	if not source_state.error.is_empty():
		printerr(source_state.error)
		quit(EXIT_TREE_STATE)
		return
	if source_state.tree_state != "clean" and not options.development:
		printerr("Release capture refused for a dirty tree; use --development for local review.")
		quit(EXIT_TREE_STATE)
		return
	if (
		DisplayServer.get_name() == "headless"
		or RenderingServer.get_current_rendering_method() == "dummy"
	):
		printerr("Replacement capture requires a rendered display and renderer.")
		quit(EXIT_CAPTURE)
		return
	var parent_error := DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	if parent_error != OK:
		printerr("Could not create localtmp parent (error %d)." % parent_error)
		quit(EXIT_CAPTURE)
		return
	var directory_error := DirAccess.make_dir_absolute(output_absolute)
	if directory_error != OK:
		printerr("Could not create requested output directory (error %d)." % directory_error)
		quit(EXIT_CAPTURE)
		return
	var staging := output_absolute.path_join(".capture-stage")
	if DirAccess.make_dir_absolute(staging) != OK:
		printerr("Could not create capture staging directory.")
		DirAccess.remove_absolute(output_absolute)
		quit(EXIT_CAPTURE)
		return
	var manifest := Manifest.new_manifest(
		options.category,
		source_state.source_sha,
		source_state.tree_state,
		source_state.dirty_paths,
		Engine.get_version_info().string,
		RenderingServer.get_current_rendering_method(),
		Time.get_datetime_string_from_system(true),
		Manifest.matrix_checksum(cases),
		options.development
	)
	manifest.selection_filter = options.case_id
	manifest.display_server = DisplayServer.get_name()
	manifest.rendering_driver = RenderingServer.get_current_rendering_driver_name()
	manifest.video_adapter = RenderingServer.get_video_adapter_name()
	manifest.case_count = cases.size()
	var failed: bool = false
	var staged_files: PackedStringArray = []
	for case: Dictionary in cases:
		var result: Dictionary = await _capture(case, source_state.source_sha, staging)
		if not result.error.is_empty():
			printerr(result.error)
			failed = true
			break
		manifest.captures.append(result.record)
		staged_files.append(result.record.filename)
	if failed or (not options.development and not _all_cases_passed(manifest.captures)):
		if not failed:
			printerr("A replacement capture did not settle or pass schema-2 invariants.")
		_cleanup_staging(staging, staged_files)
		DirAccess.remove_absolute(output_absolute)
		quit(EXIT_CAPTURE)
		return
	manifest.acceptance_eligible = (
		source_state.tree_state == "clean"
		and not options.development
		and options.case_id.is_empty()
		and _all_cases_passed(manifest.captures)
	)
	var manifest_file := FileAccess.open(staging.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file == null:
		printerr("Could not write replacement capture manifest.")
		_cleanup_staging(staging, staged_files)
		DirAccess.remove_absolute(output_absolute)
		quit(EXIT_CAPTURE)
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t", false) + "\n")
	manifest_file.close()
	var publish_error := DirAccess.rename_absolute(staging, output_absolute.path_join("captures"))
	if publish_error != OK:
		printerr("Could not publish replacement captures (error %d)." % publish_error)
		_cleanup_staging(staging, staged_files)
		DirAccess.remove_absolute(output_absolute)
		quit(EXIT_CAPTURE)
		return
	print("Captured %d replacement cases in %s/captures" % [cases.size(), output_path])
	quit(0)


func _capture(case: Dictionary, source_sha: String, staging: String) -> Dictionary:
	var mounted := Matrix.mount(root, case)
	if not mounted.bound:
		mounted.viewport.queue_free()
		return {"error": "%s: replacement rejected fixture" % case.case_id}
	var table: GuiReplacementTableController = mounted.table
	var settled: bool = await Matrix.wait_settled(self, table)
	await RenderingServer.frame_post_draw
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	var failures: PackedStringArray = Matrix.validate_case(snapshot, case)
	if not settled:
		failures.append("layout did not settle")
	var image: Image = mounted.viewport.get_texture().get_image()
	var filename: String = Manifest.filename(source_sha, case)
	if image == null or image.is_empty() or image.get_size() != case.size:
		mounted.viewport.queue_free()
		return {"error": "%s: rendered image is empty or has the wrong size" % case.case_id}
	var image_path := staging.path_join(filename)
	if FileAccess.file_exists(image_path):
		mounted.viewport.queue_free()
		return {"error": "%s: duplicate capture identity" % case.case_id}
	var save_error: Error = image.save_png(image_path)
	if save_error != OK:
		mounted.viewport.queue_free()
		return {"error": "%s: PNG save failed (%d)" % [case.case_id, save_error]}
	var record := {
		"case_id": case.case_id,
		"category": String(case.category),
		"filename": filename,
		"png_sha256": FileAccess.get_sha256(image_path),
		"logical_size": {"width": case.size.x, "height": case.size.y},
		"player_count": case.player_count,
		"state_id": String(case.state_id),
		"layout_mode": snapshot.layout_mode,
		"ready": snapshot.ready,
		"fit_guidance": snapshot.fit_guidance,
		"invariants": {"passed": settled and failures.is_empty(), "failures": Array(failures)},
	}
	mounted.viewport.queue_free()
	await process_frame
	return {"error": "", "record": record}


func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var result := {
		"error": "",
		"help": false,
		"category": &"",
		"case_id": "",
		"output": "",
		"development": false,
	}
	var index: int = 0
	while index < arguments.size():
		var argument: String = arguments[index]
		match argument:
			"--help", "-h":
				result.help = true
			"--development":
				result.development = true
			"--suite", "--case-id", "--output":
				if index + 1 >= arguments.size():
					result.error = "%s requires a value." % argument
					return result
				index += 1
				if argument == "--suite":
					result.category = StringName(arguments[index])
				elif argument == "--case-id":
					result.case_id = arguments[index]
				else:
					result.output = arguments[index]
			_:
				result.error = "Unknown argument: %s" % argument
				return result
		index += 1
	if result.help:
		return result
	if result.category not in [&"m3", &"phone", &"ipad", &"desktop"]:
		result.error = "--suite must be m3, phone, ipad, or desktop."
	elif result.output.is_empty():
		result.error = "--output localtmp/PATH is required."
	return result


func _read_source_state() -> Dictionary:
	var sha := _git(["rev-parse", "HEAD"])
	if sha.code != 0:
		return {"error": "Could not resolve source revision: %s" % sha.output}
	var status := _git(["status", "--porcelain=v1", "--untracked-files=normal"])
	if status.code != 0:
		return {"error": "Could not inspect source tree: %s" % status.output}
	var dirty_paths := PackedStringArray(status.output.strip_edges().split("\n", false))
	if dirty_paths == PackedStringArray([""]):
		dirty_paths = PackedStringArray()
	return {
		"error": "",
		"source_sha": sha.output.strip_edges(),
		"tree_state": "clean" if dirty_paths.is_empty() else "dirty",
		"dirty_paths": dirty_paths,
	}


func _git(arguments: Array[String]) -> Dictionary:
	var output: Array[String] = []
	var code: int = OS.execute("git", PackedStringArray(arguments), output, true)
	return {"code": code, "output": "\n".join(output)}


func _all_cases_passed(captures: Array) -> bool:
	for capture: Dictionary in captures:
		if not capture.invariants.passed:
			return false
	return true


func _cleanup_staging(directory: String, files: PackedStringArray) -> void:
	for filename: String in files:
		DirAccess.remove_absolute(directory.path_join(filename))
	var access := DirAccess.open(directory)
	if access != null:
		access.list_dir_begin()
		var filename := access.get_next()
		while not filename.is_empty():
			if not access.current_is_dir():
				DirAccess.remove_absolute(directory.path_join(filename))
			filename = access.get_next()
		access.list_dir_end()
	var manifest_path := directory.path_join("manifest.json")
	if FileAccess.file_exists(manifest_path):
		DirAccess.remove_absolute(manifest_path)
	DirAccess.remove_absolute(directory)


func _print_usage() -> void:
	print(
		"Replacement visual capture:\n",
		"  --suite m3|phone|ipad|desktop --output localtmp/NEW-DIRECTORY [--development]\n",
		"  Optional: --case-id CASE (development captures only)\n",
		"The destination must not already exist."
	)
