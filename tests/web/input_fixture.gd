extends Node

## Export-only observer. It mounts production controls and exposes read-only
## state; browser input must travel through the exported canvas and engine.

const MainScene := preload("res://scenes/main.tscn")
const Measure := preload("res://scripts/gui/gui_snapshot_measurement.gd")
const Json := preload("res://tests/web/layout_snapshot_json.gd")


class CallingAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		if PlayerAction.Kind.CHECK in view.legal_actions:
			return PlayerAction.check_action()
		return PlayerAction.call_action()


var _main: StartupConfigController
var _table: GuiReplacementTableController
var _table_fixture: bool = false
var _showdown_fixture: bool = false
var _showdown_advance_pending: bool = false
var _fullscreen_fixture: bool = false
var _preset_fixture: bool = false
var _live_fixture: bool = false
var _warning_frames: int = 0
var _bot_frames: int = 0
var _frame: int = 0
var _match: TournamentMatch


func _ready() -> void:
	print("Web input fixture ready")
	if not OS.has_feature("web"):
		set_process(false)
		return
	_fullscreen_fixture = bool(JavaScriptBridge.eval("location.search.includes('fullscreen')"))
	_preset_fixture = bool(JavaScriptBridge.eval("location.search.includes('presets')"))
	_live_fixture = bool(JavaScriptBridge.eval("location.search.includes('phone-live')"))
	_table_fixture = bool(JavaScriptBridge.eval("location.search.includes('table')"))
	_showdown_fixture = bool(JavaScriptBridge.eval("location.search.includes('showdown')"))
	print("Web input fixture instantiating production main")
	_main = MainScene.instantiate() as StartupConfigController
	add_child(_main)
	_table = _main.get_table_controller() as GuiReplacementTableController
	if _table_fixture:
		(_main.get_node("Center") as Control).hide()
		_table.show()
	if _table_fixture:
		var count: int = 6 if _preset_fixture or _live_fixture else 2
		var roles: Dictionary[int, StringName] = {0: &"human"}
		var agents: Dictionary[int, Agent] = {0: HumanAgent.new()}
		var names: Dictionary[int, String] = {0: "Human"}
		for seat: int in range(1, count):
			roles[seat] = &"scripted"
			agents[seat] = CallingAgent.new()
			names[seat] = "Emiliano" if _live_fixture else "Alex%d" % seat
		_match = TournamentMatch.new(
			ResolvedTournamentConfig.new(
				count, 1000, 5, 10, 2 if _showdown_fixture else 9123, &"single_table", roles
			),
			agents
		)
		_match.start(1 if _live_fixture else 32)
		if _preset_fixture:
			for step: int in count:
				if _match.get_view_for(0).acting_seat == 0:
					break
				_match.advance_one_action()
		if _showdown_fixture:
			_prepare_showdown()
		var timing := GuiActionTimingConfig.new()
		timing.default_pause_seconds = 0.25 if _live_fixture else 60.0
		timing.showdown_pause_seconds = 0.25 if _live_fixture else 60.0
		_table.set_action_timing_config(timing)
		var avatars: Dictionary[int, String] = {}
		if _preset_fixture:
			var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
			for seat: int in count:
				avatars[seat] = paths[seat]
		if _live_fixture:
			for frame: int in 120:
				await get_tree().process_frame
				var geometry: GuiViewportGeometry = _main.get_viewport_adapter().get_geometry()
				if geometry.valid:
					_main.get_viewport_adapter().inject_geometry(
						GuiViewportGeometry.injected(
							geometry.full_rect.size,
							Rect2(0, 36, geometry.logical_size.x, geometry.logical_size.y - 36)
						)
					)
					break
		_table.bind_match(_match, 0, avatars, names)
		_table.set_wager_draft("75")
		if _showdown_fixture:
			_showdown_advance_pending = true
	JavaScriptBridge.eval("window.pokahdotInput = {}; void 0")


func _prepare_showdown() -> void:
	for transition: int in range(300):
		var view: GameView = _match.get_view_for(0)
		if view.street == &"river" and view.acting_seat == Table.NO_SEAT:
			return
		if view.acting_seat == 0:
			var action: PlayerAction = (
				PlayerAction.check_action()
				if PlayerAction.Kind.CHECK in view.legal_actions
				else PlayerAction.call_action()
			)
			_match.submit_human_action_without_advance(action)
		else:
			_match.advance_one_action()
	push_error("Exported showdown fixture did not reach settlement.")


func _process(_delta: float) -> void:
	_frame += 1
	var layout: GuiLayoutSnapshot = _main.get_layout_snapshot()
	if _live_fixture:
		_publish_live_phone(layout)
		return
	if _fullscreen_fixture:
		_publish_fullscreen(layout)
		return
	var input_role: StringName = &"action/total" if _table_fixture else &"startup/starting_stack"
	if _table_fixture and (not layout.ready or layout.pending):
		return
	if _showdown_advance_pending:
		_showdown_advance_pending = false
		_table.advance_one_action()
		return
	var input: GuiLayoutElement = layout.elements[input_role]
	var keypad: GuiOverlaySnapshot = _overlay(layout, &"keypad")
	var menu: GuiOverlaySnapshot = _overlay(layout, &"menu")
	var quit: GuiOverlaySnapshot = _overlay(layout, &"quit")
	var summary: GuiOverlaySnapshot = _overlay(layout, &"summary")
	var controls: Dictionary = {"input": Json.element(input)}
	if _table_fixture:
		controls["PhoneMoreButton"] = Json.element(layout.elements[&"action/more"])
		controls["FoldButton"] = Json.element(layout.elements[&"action/fold"])
		controls["MinimumButton"] = Json.element(layout.elements[&"action/minimum"])
		controls["PotButton"] = Json.element(layout.elements[&"action/pot"])
		controls["PhoneMenuCloseButton"] = _overlay_host_control(&"menu_close")
		controls["PhoneMenuQuitButton"] = _overlay_host_control(&"menu_quit")
		controls["PhoneQuitContinueButton"] = _overlay_host_control(&"quit_keep")
		controls["PhoneShowdownCloseButton"] = _overlay_host_control(&"summary_close")
		controls["PhoneMenuSummaryButton"] = _overlay_host_control(&"menu_summary")
	controls["open"] = (
		Json.element(layout.elements[&"action/wager"]) if _table_fixture else controls.input
	)
	if keypad.element.visible:
		var keys: Dictionary[String, StringName] = {
			"KeyClear": &"clear",
			"Key2": &"key/2",
			"Key5": &"key/5",
			"Done": &"done",
			"Cancel": &"cancel",
			"Value": &"value",
		}
		for key: String in keys:
			controls[key] = _overlay_control(keypad, keys[key])
	var viewport_size: Vector2 = layout.viewport_rect.size
	var keypad_has_quit: bool = false
	for element: GuiLayoutElement in keypad.measured:
		if element.visible and element.text_kind == &"button" and element.text == "Quit":
			keypad_has_quit = true
	var snapshot := {
		"frame": _frame,
		"fixture": "table" if _table_fixture else "startup",
		"viewport": [viewport_size.x, viewport_size.y],
		"controls": controls,
		"popup": keypad.element.visible,
		"keypad_has_quit": keypad_has_quit,
		"input": input.value_text,
		"focus": input.focused,
		"draft": _overlay_element(keypad, &"value").text,
	}
	if _match != null:
		var view: GameView = _match.get_view_for(0)
		snapshot["hero_wager"] = view.seats[0].bet_this_round
		var model: TableViewModel = _table.get_table_view_model()
		snapshot["minimum_total"] = model.actions.minimum_total
		snapshot["pot_total"] = model.actions.pot_total
		snapshot["raw_draft"] = _table.get_wager_draft()
		snapshot["layout_mode"] = layout.layout_mode
		snapshot["avatar_count"] = 0
		for seat: GuiSeatSnapshot in layout.seats.values():
			var avatar: GuiLayoutElement = seat.fields.get(&"avatar")
			if avatar != null and avatar.visible and avatar.texture_present:
				snapshot["avatar_count"] += 1
		snapshot["history_count"] = view.action_history.size()
		snapshot["hand_complete"] = view.hand_complete
		snapshot["hand_number"] = view.hand_number
		snapshot["result_text"] = layout.elements[&"action/status"].text
		snapshot["result_visible"] = layout.elements[&"action/status"].visible
		snapshot["result_button"] = layout.elements[&"action/more"].text
		snapshot["summary_open"] = summary.element.visible
		snapshot["summary_text"] = (
			(_table.get_overlay_host().get_control(&"summary_body") as RichTextLabel)
			. get_parsed_text()
		)
		var winner_names: Array[String] = []
		for award: PotAward in view.pot_awards:
			for seat: int in award.winner_seats:
				winner_names.append(layout.seats[seat].fields[&"name"].text)
		snapshot["winner_names"] = winner_names
		snapshot["menu"] = menu.element.visible
		snapshot["quit_confirmation"] = quit.element.visible
		snapshot["modal_focus"] = _has_focus(menu) or _has_focus(quit)
		snapshot["more_focus"] = layout.elements[&"action/more"].focused
	JavaScriptBridge.eval("window.pokahdotInput = " + JSON.stringify(snapshot) + "; void 0")


func _overlay(layout: GuiLayoutSnapshot, kind: StringName) -> GuiOverlaySnapshot:
	var fallback := GuiOverlaySnapshot.new()
	fallback.element = GuiLayoutElement.new()
	for overlay: GuiOverlaySnapshot in layout.overlays:
		if overlay.kind == kind:
			fallback = overlay
			if overlay.element.visible:
				return overlay
	return fallback


func _overlay_element(overlay: GuiOverlaySnapshot, role: StringName) -> GuiLayoutElement:
	return overlay.elements.get(role, GuiLayoutElement.new())


func _overlay_control(overlay: GuiOverlaySnapshot, role: StringName) -> Dictionary:
	return Json.element(_overlay_element(overlay, role))


func _overlay_host_control(role: StringName) -> Dictionary:
	return Json.element(Measure.element(_table.get_overlay_host().get_control(role), _table, role))


func _has_focus(overlay: GuiOverlaySnapshot) -> bool:
	if not overlay.element.visible:
		return false
	for element: GuiLayoutElement in overlay.measured:
		if element.focused:
			return true
	return false


func _publish_live_phone(layout: GuiLayoutSnapshot) -> void:
	var warning := _table.get_node("CompositionHost/LayoutSlot/SpaceGuidance") as Control
	if warning.is_visible_in_tree() or layout.fit_guidance.begins_with("More space"):
		_warning_frames += 1
	var view: GameView = _match.get_view_for(0)
	if layout.ready and view.acting_seat != 0 and not view.hand_complete:
		_bot_frames += 1
	var controls: Dictionary = {}
	if layout.elements.has(&"action/check_call"):
		controls["check_call"] = Json.element(layout.elements[&"action/check_call"])
	var state: Dictionary = {
		"frame": _frame,
		"ready": layout.ready,
		"pending": layout.pending,
		"viewport": [layout.viewport_rect.size.x, layout.viewport_rect.size.y],
		"controls": controls,
		"human_turn": view.acting_seat == 0,
		"hand": view.hand_number,
		"history": view.action_history.size(),
		"warning_frames": _warning_frames,
		"bot_frames": _bot_frames,
	}
	JavaScriptBridge.eval("window.pokahdotLive = " + JSON.stringify(state) + "; void 0")


func _publish_fullscreen(layout: GuiLayoutSnapshot) -> void:
	var playing: bool = _table.is_visible_in_tree()
	var controls: Dictionary = {}
	if playing:
		if layout.elements.has(&"action/more"):
			controls["more"] = Json.element(layout.elements[&"action/more"])
		for role: StringName in [&"menu_fullscreen", &"menu_close"]:
			controls[role] = _overlay_host_control(role)
	else:
		controls["start"] = Json.element(layout.elements[&"startup/start"])
	var state: Dictionary = {
		"frame": _frame,
		"playing": playing,
		"ready": layout.ready,
		"pending": layout.pending,
		"viewport": [layout.viewport_rect.size.x, layout.viewport_rect.size.y],
		"controls": controls,
		"draft": _table.get_wager_draft(),
	}
	if playing:
		var view: GameView = _main.startup_adapter.match_instance.get_view_for(0)
		state["hand"] = view.hand_number
		state["human_turn"] = view.acting_seat == 0
		state["history"] = view.action_history.size()
	JavaScriptBridge.eval("window.pokahdotFullscreen = " + JSON.stringify(state) + "; void 0")
