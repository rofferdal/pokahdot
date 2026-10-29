extends Node

## Real root-Window measurement. Policies below are explicit runtime experiments;
## this development fixture never changes the product project or GUI adapter.
const MainScene := preload("res://scenes/main.tscn")
const SafeFixture := preload("res://tests/support/gui_browser_capture_fixture.gd")
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const POLICIES: Array[String] = [
	"project_baseline",
	"window_size",
	"window_size_divided_by_screen_scale",
]

var _main: StartupConfigController
var _table: PokerTableController
var _startup: Control
var _output: String = "res://localtmp/restructure_rg10/native"
var _bounds_helper: String = ""
var _images: bool = true
var _app_adapter: bool = false
var _baseline_size := Vector2i.ZERO
var _source_sha: String = "unavailable"
var _screen: int = 0
var _measurements: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		push_error("Native geometry evidence requires a real native root Window.")
		get_tree().quit(2)
		return
	_options()
	var git_output: Array[String] = []
	if OS.execute("git", ["rev-parse", "HEAD"], git_output) == 0:
		_source_sha = "".join(git_output).strip_edges()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	var window: Window = get_window()
	window.title = "Pokahdot Geometry Probe"
	window.always_on_top = true
	window.grab_focus()
	_baseline_size = window.content_scale_size
	_screen = window.current_screen
	var descriptor: Dictionary = SafeFixture.descriptor()
	var policies: Array[String] = []
	if _app_adapter:
		policies.append("app_adapter")
	else:
		policies.assign(POLICIES)
	for policy: String in policies:
		for requested: Vector2i in SIZES:
			if is_instance_valid(_main):
				_main.free()
			window.current_screen = _screen
			window.size = requested
			await _frames(4)
			_apply_policy(window, policy)
			await _frames(4)
			_main = MainScene.instantiate() as StartupConfigController
			add_child(_main)
			if not _app_adapter:
				_main.get_viewport_adapter().inject_geometry(
					GuiViewportGeometry.injected(window.get_visible_rect().size)
				)
			_table = _main.get_node("PokerTable") as PokerTableController
			_startup = _main.get_node("Center") as Control
			_table.bind_view(descriptor.view, descriptor.avatars, descriptor.names)
			for phase: String in ["startup", "table"]:
				_startup.visible = phase == "startup"
				_table.visible = phase == "table"
				var settled: bool = await _settle()
				var snapshot: GuiLayoutSnapshot = _main.get_layout_snapshot()
				var record: Dictionary = _record(window, policy, requested, phase, snapshot)
				record["settled"] = settled
				_measurements.append(record)
				_save()
				if _images:
					await RenderingServer.frame_post_draw
					var image: Image = window.get_texture().get_image()
					var filename: String = (
						"%s-%dx%d-%s.png" % [policy, requested.x, requested.y, phase]
					)
					var error: Error = image.save_png(
						ProjectSettings.globalize_path(_output.path_join(filename))
					)
					record["rendered_image_size"] = [image.get_width(), image.get_height()]
					record["screenshot"] = filename
					record["screenshot_error"] = error
				_save()
				print("Native geometry measured: %s %s %s" % [policy, requested, phase])
	get_tree().quit()


func _apply_policy(window: Window, policy: String) -> void:
	match policy:
		"project_baseline":
			window.content_scale_size = _baseline_size
		"window_size":
			window.content_scale_size = window.size
		"window_size_divided_by_screen_scale":
			var scale: float = maxf(1.0, DisplayServer.screen_get_scale(window.current_screen))
			window.content_scale_size = Vector2i((Vector2(window.size) / scale).round())


func _record(
	window: Window, policy: String, requested: Vector2i, phase: String, snapshot: GuiLayoutSnapshot
) -> Dictionary:
	var elements: Array[Dictionary] = []
	for value: GuiLayoutElement in snapshot.elements.values():
		_elements_append(elements, value, window)
	for seat: GuiSeatSnapshot in snapshot.seats.values():
		for value: GuiLayoutElement in seat.fields.values():
			_elements_append(elements, value, window)
	for value: GuiLayoutElement in snapshot.measured:
		_elements_append(elements, value, window)
	var scale: float = DisplayServer.screen_get_scale(window.current_screen)
	var active: Control = _main if phase == "startup" else _table
	return {
		"policy": policy,
		"phase": phase,
		"requested_window_size": _vector(requested),
		"window":
		{
			"visible": window.visible,
			"focused": window.has_focus(),
			"current_screen": window.current_screen,
			"size": _vector(window.size),
			"display_server_size": _vector(DisplayServer.window_get_size()),
			"decorated_size": _vector(DisplayServer.window_get_size_with_decorations()),
			"screen_scale": scale,
			"screen_scale_from_main_window": DisplayServer.screen_get_scale(),
			"dpi": DisplayServer.screen_get_dpi(window.current_screen),
			"screen_size": _vector(DisplayServer.screen_get_size(window.current_screen)),
			"content_scale_size": _vector(window.content_scale_size),
			"content_scale_mode": window.content_scale_mode,
			"content_scale_aspect": window.content_scale_aspect,
			"content_scale_factor": window.content_scale_factor,
			"viewport_visible_rect": _rect(window.get_visible_rect()),
			"final_transform": _transform(window.get_final_transform()),
		},
		"control":
		{
			"size": _vector(active.size),
			"main_size": _vector(_main.size),
			"table_size": _vector(_table.size),
			"profile": snapshot.profile,
			"root_rect": _rect(snapshot.root_rect),
			"usable_rect": _rect(snapshot.usable_rect),
		},
		"elements": elements,
		"summary": _summary(elements),
		"own_os_windows": _own_os_windows(),
		"coordinate_note":
		(
			"API client pixels and viewport logical units; "
			+ "OS frame bounds are independently observed when available."
		),
	}


func _elements_append(elements: Array[Dictionary], value: GuiLayoutElement, window: Window) -> void:
	if not value.visible or (value.font_size == 0 and not value.interactive):
		return
	var text_present: bool = value.required_size.x > 0.0 and value.text_kind != &"none"
	if not text_present and not value.interactive:
		return
	var output_rect: Rect2 = window.get_final_transform() * value.rect
	var scale: float = maxf(1.0, DisplayServer.screen_get_scale(window.current_screen))
	(
		elements
		. append(
			{
				"role": String(value.role),
				"text_present": text_present,
				"text_kind": String(value.text_kind),
				"font_size": value.font_size,
				"effective_font_size": value.effective_font_size,
				"output_font_size": value.output_font_size,
				"output_font_size_divided_by_screen_scale": value.output_font_size / scale,
				"rect": _rect(value.rect),
				"allocated_size": _vector(value.allocated_size),
				"target_output_size": _vector(output_rect.size),
				"target_output_size_divided_by_screen_scale": _vector(output_rect.size / scale),
				"visible": value.visible,
				"interactive": value.interactive,
			}
		)
	)


func _summary(elements: Array[Dictionary]) -> Dictionary:
	var minimum_font: float = INF
	var minimum_target := Vector2(INF, INF)
	var small_fonts: Array[String] = []
	var small_targets: Array[String] = []
	for value: Dictionary in elements:
		if value.text_present and value.font_size > 0:
			minimum_font = minf(minimum_font, value.output_font_size)
			if value.output_font_size < 20.0:
				small_fonts.append(value.role)
		if value.interactive:
			var target := Vector2(value.target_output_size[0], value.target_output_size[1])
			minimum_target = minimum_target.min(target)
			if target.x < 48.0 or target.y < 48.0:
				small_targets.append(value.role)
	return {
		"minimum_player_text_output_font_size": minimum_font if is_finite(minimum_font) else 0.0,
		"minimum_target_output_size": _vector(minimum_target),
		"text_below_20_output_pixels": small_fonts,
		"targets_below_48_output_pixels": small_targets,
	}


func _settle() -> bool:
	var previous: String = ""
	var stable: int = 0
	for _frame: int in range(48):
		await get_tree().process_frame
		var snapshot: GuiLayoutSnapshot = _main.get_layout_snapshot()
		var signature: String = snapshot.geometry_signature()
		stable = (
			stable + 1 if snapshot.ready and not snapshot.pending and signature == previous else 0
		)
		previous = signature
		if stable >= 3:
			return true
	return false


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _own_os_windows() -> Array:
	if _bounds_helper.is_empty():
		return []
	var output: Array[String] = []
	if OS.execute(_bounds_helper, [str(OS.get_process_id())], output, true) != 0:
		return []
	var parsed: Variant = JSON.parse_string("".join(output))
	return parsed if parsed is Array else []


func _save() -> void:
	var sources: Dictionary = {}
	for directory: String in ["res://scripts/gui", "res://scripts/gui/platform"]:
		for filename: String in DirAccess.get_files_at(directory):
			if filename.ends_with(".gd"):
				var path: String = directory.path_join(filename)
				sources[path] = FileAccess.get_sha256(path)
	for path: String in [
		"res://project.godot",
		"res://tests/performance/gui_geometry_fixture.gd",
		"res://scenes/main.tscn",
		"res://scenes/poker_table.tscn",
		"res://resources/gui_theme.tres",
	]:
		sources[path] = FileAccess.get_sha256(path)
	var report: Dictionary = {
		"schema_version": 1,
		"source_sha": _source_sha,
		"platform": "native",
		"engine": Engine.get_version_info().string,
		"pid": OS.get_process_id(),
		"os": OS.get_name(),
		"display_server": DisplayServer.get_name(),
		"screens": _screens(),
		"source_files_sha256": sources,
		"baseline_content_scale_size": _vector(_baseline_size),
		"acceptance":
		"Runtime measurement experiments only; no product policy or device acceptance established.",
		"measurements": _measurements,
	}
	var file: FileAccess = FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot save native geometry evidence under %s." % _output)
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")


func _screens() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(DisplayServer.get_screen_count()):
		(
			result
			. append(
				{
					"index": index,
					"scale": DisplayServer.screen_get_scale(index),
					"dpi": DisplayServer.screen_get_dpi(index),
					"size": _vector(DisplayServer.screen_get_size(index)),
					"position": _vector(DisplayServer.screen_get_position(index)),
				}
			)
		)
	return result


func _options() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index] == "--output" and index + 1 < args.size():
			_output = args[index + 1]
		elif args[index] == "--bounds-helper" and index + 1 < args.size():
			_bounds_helper = args[index + 1]
		elif args[index] == "--no-images":
			_images = false
		elif args[index] == "--app-adapter":
			_app_adapter = true


func _vector(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _rect(value: Rect2) -> Array[float]:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _transform(value: Transform2D) -> Array[float]:
	return [value.x.x, value.x.y, value.y.x, value.y.y, value.origin.x, value.origin.y]
