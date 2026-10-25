extends SceneTree
# gdlint: disable=max-returns

## Rendering-enabled CLI runner for deterministic local GUI screenshots.

const CaptureManifestScript := preload("res://tests/support/gui_visual_capture_manifest.gd")
const GuiInvariantAssertionsScript := preload("res://tests/support/gui_invariant_assertions.gd")
const GuiSceneHarnessScript := preload("res://tests/support/gui_scene_harness.gd")

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
	var display_server: String = DisplayServer.get_name()
	var rendering_method: String = RenderingServer.get_current_rendering_method()
	if display_server == "headless" or rendering_method == "dummy":
		printerr("Rendered capture requires a non-headless, non-dummy display and renderer.")
		quit(EXIT_CAPTURE)
		return

	var git_state := _read_git_state()
	if not git_state.error.is_empty():
		printerr(git_state.error)
		quit(EXIT_TREE_STATE)
		return
	if git_state.tree_state == "dirty" and not options.development:
		printerr(
			"Gate capture refused: the source tree is dirty. Use --development for non-acceptance output."
		)
		quit(EXIT_TREE_STATE)
		return

	var cases: Array[Dictionary] = (
		CaptureManifestScript.phone_cases(
			options.viewport_id, options.state_id, options.player_count
		)
		if options.full_phone
		else CaptureManifestScript.milestone_three_cases(
			options.viewport_id, options.state_id, options.player_count
		)
	)
	if cases.is_empty():
		printerr("No canonical capture cases match the selection.")
		quit(EXIT_USAGE)
		return
	var output_directory: String = options.output_directory
	if output_directory.is_empty():
		output_directory = (
			(
				"res://artifacts/gui_visual/development/%s-%s"
				% [git_state.source_sha, git_state.dirty_fingerprint]
			)
			if options.development
			else "res://artifacts/gui_visual/%s" % git_state.source_sha
		)
	var absolute_output := ProjectSettings.globalize_path(output_directory)
	var manifest_path := absolute_output.path_join("manifest.json")
	if FileAccess.file_exists(manifest_path):
		printerr("Capture refused: manifest already exists at %s" % manifest_path)
		quit(EXIT_CAPTURE)
		return
	for case: Dictionary in cases:
		var expected_path := absolute_output.path_join(
			CaptureManifestScript.capture_filename(git_state.source_sha, case)
		)
		if FileAccess.file_exists(expected_path):
			printerr("Capture refused: image already exists at %s" % expected_path)
			quit(EXIT_CAPTURE)
			return
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if mkdir_error != OK:
		printerr(
			"Could not create capture directory %s (error %d)." % [absolute_output, mkdir_error]
		)
		quit(EXIT_CAPTURE)
		return
	var staging_directory := absolute_output.path_join(".capture-staging")
	if DirAccess.dir_exists_absolute(staging_directory):
		printerr("Capture refused: staging directory already exists at %s" % staging_directory)
		quit(EXIT_CAPTURE)
		return
	if DirAccess.make_dir_absolute(staging_directory) != OK:
		printerr("Could not create capture staging directory: %s" % staging_directory)
		quit(EXIT_CAPTURE)
		return

	var manifest: Dictionary = (
		CaptureManifestScript
		. base_manifest(
			git_state.source_sha,
			git_state.tree_state,
			git_state.dirty_paths,
			Engine.get_version_info().string,
			rendering_method,
			Time.get_datetime_string_from_system(true),
			CaptureManifestScript.matrix_checksum(cases),
			options.development,
			(
				CaptureManifestScript.PHONE_SUITE_VERSION
				if options.full_phone
				else CaptureManifestScript.SUITE_VERSION
			),
		)
	)
	manifest.display_server = display_server
	manifest.rendering_driver = RenderingServer.get_current_rendering_driver_name()
	manifest.video_adapter = RenderingServer.get_video_adapter_name()
	manifest.matrix_source_sha256 = CaptureManifestScript.matrix_source_checksums()
	manifest.capture_scope = (
		"full_phone" if options.full_phone else ("full_m3" if options.full_m3 else "selection")
	)
	manifest.dirty_fingerprint = git_state.dirty_fingerprint
	for case: Dictionary in cases:
		var capture_result: Dictionary = await _capture_case(
			case, git_state.source_sha, staging_directory
		)
		if not capture_result.error.is_empty():
			printerr(capture_result.error)
			quit(EXIT_CAPTURE)
			return
		manifest.captures.append(capture_result.record)
	manifest.acceptance_eligible = (
		CaptureManifestScript.phone_acceptance_eligible(
			git_state.tree_state, options.development, options.full_phone, manifest.captures
		)
		if options.full_phone
		else CaptureManifestScript.acceptance_eligible(
			git_state.tree_state, options.development, options.full_m3, manifest.captures
		)
	)
	if (
		(options.full_m3 or options.full_phone)
		and not options.development
		and not manifest.acceptance_eligible
	):
		printerr("Gate capture failed: every canonical case must settle and pass its invariants.")
		quit(EXIT_CAPTURE)
		return
	for capture: Dictionary in manifest.captures:
		var staged_path := staging_directory.path_join(capture.filename)
		var final_path := absolute_output.path_join(capture.filename)
		var publish_error := DirAccess.rename_absolute(staged_path, final_path)
		if publish_error != OK:
			printerr("Could not publish %s (error %d)." % [capture.filename, publish_error])
			quit(EXIT_CAPTURE)
			return
	DirAccess.remove_absolute(staging_directory)

	var staged_manifest_path := "%s.tmp" % manifest_path
	var manifest_file := FileAccess.open(staged_manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		printerr("Could not open manifest for writing: %s" % manifest_path)
		quit(EXIT_CAPTURE)
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t", false) + "\n")
	manifest_file.close()
	var manifest_publish_error := DirAccess.rename_absolute(staged_manifest_path, manifest_path)
	if manifest_publish_error != OK:
		printerr("Could not publish manifest (error %d)." % manifest_publish_error)
		quit(EXIT_CAPTURE)
		return
	print("Captured %d GUI fixtures in %s" % [cases.size(), absolute_output])
	print("Manifest SHA-256: %s" % FileAccess.get_sha256(manifest_path))
	quit(0)


func _capture_case(case: Dictionary, source_sha: String, output_directory: String) -> Dictionary:
	var viewport: Dictionary = case.viewport
	var descriptor: Dictionary = case.descriptor
	var harness: Node = GuiSceneHarnessScript.new()
	get_root().add_child(harness)
	var rendered: Dictionary = harness.render(descriptor, viewport.size, viewport.profile_override)
	var settled: bool = await harness.settle_layout()
	await RenderingServer.frame_post_draw
	var image: Image = rendered.viewport.get_texture().get_image()
	var filename: String = CaptureManifestScript.capture_filename(source_sha, case)
	var image_path := output_directory.path_join(filename)
	if FileAccess.file_exists(image_path):
		harness.free()
		return {"error": "Capture refused: image already exists at %s" % image_path}
	if image == null or image.is_empty():
		harness.free()
		return {"error": "Renderer returned an empty image for %s" % filename}
	var save_error := image.save_png(image_path)
	if save_error != OK:
		harness.free()
		return {"error": "Could not save %s (error %d)." % [image_path, save_error]}
	var reloaded := Image.load_from_file(image_path)
	if reloaded == null or reloaded.is_empty():
		harness.free()
		return {"error": "Saved PNG could not be reloaded: %s" % image_path}
	if reloaded.get_size() != viewport.size:
		harness.free()
		return {
			"error":
			(
				"Saved PNG has size %s; expected %s for %s"
				% [reloaded.get_size(), viewport.size, filename]
			)
		}

	var invariant_failures: PackedStringArray = GuiInvariantAssertionsScript.validate(rendered)
	var overlay_ids: Array[String] = []
	for overlay_id: StringName in rendered.intentional_overlap_controls:
		overlay_ids.append(String(overlay_id))
	var human_seat: Variant = null
	if descriptor.view != null:
		human_seat = descriptor.view.hero_seat
	var record := {
		"capture_id": CaptureManifestScript.capture_id(case),
		"filename": filename,
		"png_sha256": FileAccess.get_sha256(image_path),
		"viewport_id": String(viewport.key),
		"logical_size": {"width": viewport.size.x, "height": viewport.size.y},
		"usable_rect":
		{
			"x": 0,
			"y": 0,
			"width": viewport.size.x,
			"height": viewport.size.y,
		},
		"orientation": String(viewport.orientation),
		"layout_profile": String(viewport.profile),
		"player_count": descriptor.player_count,
		"state_id": String(descriptor.id),
		"fixture_id": CaptureManifestScript.capture_id(case),
		"fixture_seed": descriptor.fixed_seed,
		"human_seat": human_seat,
		"intentional_overlay_exception_ids": overlay_ids,
		"invariants":
		{
			"passed": settled and invariant_failures.is_empty(),
			"layout_settled": settled,
			"failures": Array(invariant_failures),
		},
	}
	harness.free()
	await process_frame
	return {"error": "", "record": record}


func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var options := {
		"error": "",
		"help": false,
		"full_m3": false,
		"full_phone": false,
		"development": false,
		"viewport_id": &"",
		"state_id": &"",
		"player_count": -1,
		"output_directory": "",
	}
	var index: int = 0
	while index < arguments.size():
		var argument: String = arguments[index]
		match argument:
			"--help", "-h":
				options.help = true
			"--full-m3":
				options.full_m3 = true
			"--full-phone":
				options.full_phone = true
			"--development":
				options.development = true
			"--viewport", "--state", "--player-count", "--output":
				if index + 1 >= arguments.size():
					options.error = "%s requires a value." % argument
					return options
				index += 1
				var value: String = arguments[index]
				if argument == "--viewport":
					options.viewport_id = StringName(value)
				elif argument == "--state":
					options.state_id = StringName(value)
				elif argument == "--player-count":
					if not value.is_valid_int():
						options.error = "--player-count requires an integer."
						return options
					options.player_count = value.to_int()
				else:
					options.output_directory = value
			_:
				options.error = "Unknown capture argument: %s" % argument
				return options
		index += 1
	if not options.help:
		var has_selection: bool = (
			not options.viewport_id.is_empty()
			or not options.state_id.is_empty()
			or options.player_count >= 0
		)
		var full_suite_count: int = int(options.full_m3) + int(options.full_phone)
		if full_suite_count > 1:
			options.error = "--full-m3 and --full-phone are mutually exclusive."
		elif (full_suite_count == 1) == has_selection:
			options.error = "Choose one full suite or at least one selection filter."
		elif has_selection and not options.development:
			options.error = "Filtered captures require --development and are never gate evidence."
		elif not options.output_directory.is_empty() and not options.development:
			options.error = "A custom --output is allowed only with --development."
	return options


func _read_git_state() -> Dictionary:
	var sha_result := _run_git(PackedStringArray(["rev-parse", "HEAD"]))
	if sha_result.exit_code != 0:
		return {"error": "Could not resolve git HEAD: %s" % sha_result.output}
	var status_result := _run_git(
		PackedStringArray(["status", "--porcelain=v1", "--untracked-files=normal"])
	)
	if status_result.exit_code != 0:
		return {"error": "Could not inspect git tree state: %s" % status_result.output}
	var status_text: String = status_result.output.strip_edges()
	var dirty_paths := PackedStringArray()
	if not status_text.is_empty():
		dirty_paths = status_text.split("\n", false)
	var fingerprint_source: String = status_text
	if not dirty_paths.is_empty():
		var diff_result := _run_git(PackedStringArray(["diff", "--binary", "HEAD"]))
		if diff_result.exit_code != 0:
			return {"error": "Could not fingerprint tracked changes: %s" % diff_result.output}
		fingerprint_source += "\n" + diff_result.output
		var untracked_result := _run_git(
			PackedStringArray(["ls-files", "--others", "--exclude-standard"])
		)
		if untracked_result.exit_code != 0:
			return {"error": "Could not fingerprint untracked files: %s" % untracked_result.output}
		for relative_path: String in untracked_result.output.strip_edges().split("\n", false):
			fingerprint_source += (
				"\n%s:%s"
				% [
					relative_path,
					FileAccess.get_sha256(
						ProjectSettings.globalize_path("res://%s" % relative_path)
					),
				]
			)
	var dirty_fingerprint: String = (
		CaptureManifestScript.sha256_text(fingerprint_source).left(12)
		if not dirty_paths.is_empty()
		else "clean"
	)
	return {
		"error": "",
		"source_sha": sha_result.output.strip_edges(),
		"tree_state": "clean" if dirty_paths.is_empty() else "dirty",
		"dirty_paths": dirty_paths,
		"dirty_fingerprint": dirty_fingerprint,
	}


func _run_git(arguments: PackedStringArray) -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute("git", arguments, output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _print_usage() -> void:
	print(
		"GUI visual capture:\n",
		"  --full-m3 [--development] [--output PATH]\n",
		"  --full-phone [--development] [--output PATH]\n",
		"  [--viewport ID] [--state ID] [--player-count N] [--development] [--output PATH]"
	)
