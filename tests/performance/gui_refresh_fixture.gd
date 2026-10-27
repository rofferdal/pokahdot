extends Node

## Finite profiling fixture shared by a real native renderer and exported Web.
## It drives actual product handlers with seeded core matches, without timers.
const ProfiledTable := preload("res://tests/performance/profiled_poker_table.gd")
const TableScene := preload("res://scenes/poker_table.tscn")
const PROFILE_SIZES: Dictionary[String, Vector2i] = {
	"phone": Vector2i(390, 844),
	"tablet": Vector2i(1024, 768),
	"desktop": Vector2i(1920, 1080),
}
const NAMES: Array[String] = [
	"Human", "Santiago", "Priyanka", "Benedikt", "Youssef", "Aleksia", "Haruto", "Chidi", "Kwame"
]


class ProfilingAgent:
	extends Agent
	var shove: bool = false

	func choose_action(view: GameView) -> PlayerAction:
		if shove and PlayerAction.Kind.ALL_IN in view.legal_actions:
			return PlayerAction.all_in_action()
		if PlayerAction.Kind.CHECK in view.legal_actions:
			return PlayerAction.check_action()
		return PlayerAction.call_action()


var _table: PokerTableController
var _match: TournamentMatch
var _options: Dictionary
var _seed_offset: int = 0
var _failures: Array[String] = []
var _streets: Dictionary[String, int] = {}
var _completed_hands: int = 0
var _sample_count: int = 120
var _size: Vector2i
var _runout: bool = false
var _profile: String
var _selected_layouts: Array[Dictionary] = []
var _avatar_checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if (
		DisplayServer.get_name() == "headless"
		or RenderingServer.get_current_rendering_method() == "dummy"
	):
		_fail("GUI profiling requires a real display and Compatibility renderer.")
		return
	_options = _read_options()
	var profile: String = _options.get("profile", "phone")
	var scenario: String = _options.get("scenario", "turns")
	if not PROFILE_SIZES.has(profile) or scenario not in ["turns", "runouts", "resize"]:
		_fail("Unsupported profiling profile/scenario.")
		return
	_sample_count = int(_options.get("samples", 120))
	if _sample_count < 20 or _sample_count > 2000:
		_fail("Profiling samples must be in 20..2000.")
		return
	_profile = profile
	_runout = scenario == "runouts"
	_size = PROFILE_SIZES[profile]
	_table = TableScene.instantiate() as PokerTableController
	_table.set_script(ProfiledTable)
	_table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_table)
	await _set_size(_size)
	_new_match(profile)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for _frame: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_phase("idle")
	var idle: Dictionary = await _sample_frames(20, false, false, profile)
	_phase("warmup")
	var warmup: Dictionary = await _sample_frames(12, true, scenario == "resize", profile)
	warmup["refresh_usec"] = (_table.get("refresh_usec") as Array[int]).duplicate()
	warmup["layout_usec"] = (_table.get("layout_usec") as Array[int]).duplicate()
	var before: Dictionary = ProfiledTable.counters()
	_table.set("refresh_usec", [] as Array[int])
	_table.set("visual_usec", [] as Array[int])
	_table.set("layout_usec", [] as Array[int])
	_table.set("counter_samples", [] as Array[Dictionary])
	_phase("active")
	var measured: Dictionary = await _sample_frames(
		_sample_count, true, scenario == "resize", profile
	)
	var after: Dictionary = ProfiledTable.counters()
	_phase("census")
	# Node-ID census is deliberately separate from all timing samples.
	_table.set("census", true)
	_table.set("recording", false)
	for _sample: int in range(5):
		if scenario == "resize":
			await _set_size(_resize_size(_sample))
		else:
			_drive_step(profile)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	_table.set("census", false)
	var result: Dictionary = {
		"schema_version": 1,
		"profile": profile,
		"scenario": scenario,
		"samples_requested": _sample_count,
		"starting_stack": 1000000,
		"initial_player_count": 7 if profile == "phone" else 9,
		"names": NAMES,
		"seed_start": 42000,
		"tournaments_constructed": _seed_offset,
		"streets_observed": _streets,
		"completed_hands_observed": _completed_hands,
		"selected_layouts": _selected_layouts,
		"avatar_presence_checks": _avatar_checks,
		"warmup": warmup,
		"idle": idle,
		"active": measured,
		"refresh_usec": _table.get("refresh_usec"),
		"widget_refresh_usec": _table.get("visual_usec"),
		"layout_usec": _table.get("layout_usec"),
		"node_census": _table.get("node_churn"),
		"counters_before": before,
		"counters_after": after,
		"counter_samples": _table.get("counter_samples"),
		"failures": _failures,
		"environment": _environment(),
		"scope":
		{
			"pacing": "Test pacing only is suppressed; product handlers run one step/sample.",
			"frame_wall":
			"Step to first post_draw plus one settle-frame interval; wall, not GPU duration.",
			"process_monitor":
			"Engine TIME_PROCESS may lag up to 1s; not independent per-frame OS CPU.",
			"node_census":
			"Before/after observed new Node IDs; excludes transient IDs and other allocations.",
			"memory": "Godot static bytes; zero=unavailable. Excludes browser/GPU memory.",
			"reset": "Tournament resets are untimed; their consecutive-frame sample is omitted.",
		},
	}
	_publish(result)


func _sample_frames(count: int, active: bool, resizing: bool, profile: String) -> Dictionary:
	var wall: Array[int] = []
	var intervals: Array[int] = []
	var settled_intervals: Array[int] = []
	var process: Array[float] = []
	var render_cpu: Array[float] = []
	var previous_start: int = 0
	for index: int in range(count):
		var reset: bool = false
		if _match.state == TournamentMatch.State.FINISHED:
			_completed_hands += 1
			_new_match(profile)
			reset = true
		if resizing:
			# The browser runner acknowledges real CSS viewport changes before
			# the table applies the corresponding logical geometry.
			await _request_window_size(_resize_size(index))
		await get_tree().process_frame
		_table.set("recording", active)
		var started: int = Time.get_ticks_usec()
		if previous_start > 0 and not reset and not resizing:
			intervals.append(started - previous_start)
		previous_start = started
		if active:
			if resizing:
				_apply_size(_resize_size(index))
			else:
				_drive_step(profile)
		await RenderingServer.frame_post_draw
		wall.append(Time.get_ticks_usec() - started)
		var first_draw: int = Time.get_ticks_usec()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		settled_intervals.append(Time.get_ticks_usec() - first_draw)
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0)
		_table.set("recording", false)
		if active:
			(_table.get("counter_samples") as Array[Dictionary]).append(ProfiledTable.counters())
		render_cpu.append(
			(
				1000.0
				* (
					RenderingServer.get_frame_setup_time_cpu()
					+ RenderingServer.viewport_get_measured_render_time_cpu(
						get_viewport().get_viewport_rid()
					)
				)
			)
		)
		if resizing:
			_selected_layouts.append(
				{
					"requested": [_resize_size(index).x, _resize_size(index).y],
					"profile": _table.get_layout_profile(),
					"generation": _table.get_layout_generation()
				}
			)
		_validate_privacy()
		_validate_avatars()
	return {
		"step_to_post_draw_usec": wall,
		"sample_start_interval_usec": intervals,
		"settle_frame_interval_usec": settled_intervals,
		"engine_process_frame_usec": process,
		"render_cpu_usec": render_cpu
	}


func _drive_step(profile: String) -> void:
	if _match.state == TournamentMatch.State.FINISHED:
		_new_match(profile)
	var view: GameView = _match.get_view_for(0)
	_streets[String(view.street)] = int(_streets.get(String(view.street), 0)) + 1
	if view.hand_complete:
		_completed_hands += 1
		_table._advance_after_hand_boundary()
	elif view.acting_seat == 0:
		if _runout and PlayerAction.Kind.ALL_IN in view.legal_actions:
			_table._on_all_in_pressed()
		else:
			_table._on_check_call_pressed()
	else:
		_table._advance_after_action_pause()


func _new_match(profile: String) -> void:
	var count: int = 7 if profile == "phone" else 9
	var agents: Dictionary[int, Agent] = {0: HumanAgent.new()}
	var roles: Dictionary[int, StringName] = {0: &"human"}
	var names: Dictionary[int, String] = {0: "Human"}
	for seat: int in range(1, count):
		var agent := ProfilingAgent.new()
		agent.shove = _runout
		agents[seat] = agent
		roles[seat] = &"scripted"
		names[seat] = NAMES[seat]
	_match = TournamentMatch.new(
		ResolvedTournamentConfig.new(
			count, 1000000, 5, 10, 42000 + _seed_offset, &"single_table", roles
		),
		agents
	)
	_seed_offset += 1
	var start: StepResult = _match.start()
	if start.status == StepResult.Status.ERROR:
		_failures.append(start.message)
	var avatars: Dictionary[int, String] = {}
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	for seat: int in range(count):
		avatars[seat] = paths[seat]
	_table.bind_match(_match, 0, avatars, names)


func _resize_size(index: int) -> Vector2i:
	var sizes: Array[Vector2i] = []
	if _profile == "phone":
		sizes.assign([Vector2i(390, 844), Vector2i(1024, 768), Vector2i(412, 915)])
	else:
		sizes.assign([Vector2i(1024, 768), Vector2i(1377, 777), Vector2i(1920, 1080)])
	return sizes[index % sizes.size()]


func _set_size(target: Vector2i) -> void:
	await _request_window_size(target)
	_apply_size(target)


func _request_window_size(target: Vector2i) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.pokahdotProfileResize = %s; void 0" % JSON.stringify([target.x, target.y])
		)
		while bool(JavaScriptBridge.eval("window.pokahdotProfileResize !== null")):
			await get_tree().process_frame
	else:
		get_window().size = target
		await get_tree().process_frame


func _apply_size(target: Vector2i) -> void:
	get_window().content_scale_size = target
	_table.size = Vector2(target)


func _validate_privacy() -> void:
	var view: GameView = _match.get_view_for(0)
	for seat: int in _table._seat_widgets:
		if seat == view.hero_seat or view.revealed_hole_cards.has(seat):
			continue
		var panel: Control = _table._seat_widgets[seat]
		if panel.find_child("ShowdownCard1", true, false) != null:
			_failures.append("Unrevealed opponent card rendered at seat %d" % seat)


func _validate_avatars() -> void:
	if GuiLayoutProfile.is_phone(_table.get_layout_profile()):
		return
	for seat: int in _table._seat_widgets:
		var avatar := _table._seat_widgets[seat].find_child("Avatar", true, false) as TextureRect
		if avatar == null or avatar.texture == null or not avatar.is_visible_in_tree():
			_failures.append("Expected a drawn avatar texture for seat %d" % seat)
		else:
			_avatar_checks += 1


func _environment() -> Dictionary:
	return {
		"engine": Engine.get_version_info().string,
		"os": OS.get_name(),
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"debug_build": OS.is_debug_build(),
		"web": OS.has_feature("web"),
		"logical_size": [_size.x, _size.y],
		"window_size": [get_window().size.x, get_window().size.y],
		"content_size": [get_window().content_scale_size.x, get_window().content_scale_size.y],
		"screen_scale": DisplayServer.screen_get_scale(),
	}


func _read_options() -> Dictionary:
	if OS.has_feature("web"):
		return JSON.parse_string(
			str(
				JavaScriptBridge.eval(
					"JSON.stringify(Object.fromEntries(new URLSearchParams(location.search)))"
				)
			)
		)
	var result: Dictionary = {}
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(0, arguments.size() - 1, 2):
		result[arguments[index].trim_prefix("--")] = arguments[index + 1]
	return result


func _phase(phase: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pokahdotProfilePhase = %s; void 0" % JSON.stringify(phase))


func _publish(result: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pokahdotProfileResult = %s; void 0" % JSON.stringify(result))
	else:
		var output: String = _options.get("output", "res://localtmp/gui-profile.json")
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			_fail("Cannot write profiling result: %s" % output)
			return
		file.store_string(JSON.stringify(result))
		file.close()
		get_tree().quit(0 if _failures.is_empty() else 1)


func _fail(message: String) -> void:
	push_error(message)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.pokahdotProfileFailure = %s; void 0" % JSON.stringify(message)
		)
	else:
		get_tree().quit(1)
