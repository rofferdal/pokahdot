extends Node

## Export-only observer. It mounts production controls and exposes read-only
## state; browser input must travel through the exported canvas and engine.

const MainScene := preload("res://scenes/main.tscn")
const Setup := preload("res://tests/web/reference_fixture_setup.gd")
const Json := preload("res://tests/web/layout_snapshot_json.gd")


class CallingAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		if PlayerAction.Kind.CHECK in view.legal_actions:
			return PlayerAction.check_action()
		return PlayerAction.call_action()


var _main: StartupConfigController
var _table: PokerTableController
var _table_fixture: bool = false
var _showdown_fixture: bool = false
var _frame: int = 0
var _match: TournamentMatch


func _ready() -> void:
	print("Web input fixture ready")
	if not OS.has_feature("web"):
		set_process(false)
		return
	_table_fixture = bool(JavaScriptBridge.eval("location.search.includes('table')"))
	_showdown_fixture = bool(JavaScriptBridge.eval("location.search.includes('showdown')"))
	print("Web input fixture instantiating production main")
	_main = MainScene.instantiate() as StartupConfigController
	add_child(_main)
	_table = Setup.table(_main, _table_fixture)
	if _table_fixture:
		var count: int = 6 if _showdown_fixture else 2
		var roles: Dictionary[int, StringName] = {0: &"human"}
		var agents: Dictionary[int, Agent] = {0: HumanAgent.new()}
		var names: Dictionary[int, String] = {0: "Human"}
		for seat: int in range(1, count):
			roles[seat] = &"scripted"
			agents[seat] = CallingAgent.new()
			names[seat] = "Alex%d" % seat
		_match = TournamentMatch.new(
			ResolvedTournamentConfig.new(
				count, 1000, 5, 10, 2 if _showdown_fixture else 9123, &"single_table", roles
			),
			agents
		)
		_match.start()
		if _showdown_fixture:
			_prepare_showdown()
		var timing := GuiActionTimingConfig.new()
		timing.default_pause_seconds = 60.0
		timing.showdown_pause_seconds = 60.0
		_table.set_action_timing_config(timing)
		_table.bind_match(_match, 0, {}, names)
		Setup.set_wager_input(_table, "75")
		if _showdown_fixture:
			Setup.show_completed_hand(_table)
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
	var input_role: StringName = (
		&"action/wager_input" if _table_fixture else &"startup/starting_stack"
	)
	var input: GuiLayoutElement = layout.elements[input_role]
	var keypad: GuiOverlaySnapshot = _overlay(layout, &"keypad")
	var menu: GuiOverlaySnapshot = _overlay(layout, &"menu")
	var quit: GuiOverlaySnapshot = _overlay(layout, &"quit")
	var summary: GuiOverlaySnapshot = _overlay(layout, &"summary")
	var controls: Dictionary = {"input": Json.element(input)}
	if _table_fixture:
		controls["PhoneMoreButton"] = Json.element(layout.elements[&"more"])
		controls["FoldButton"] = Json.element(layout.elements[&"action/fold"])
		controls["PhoneMenuCloseButton"] = _overlay_control(menu, &"close")
		controls["PhoneMenuQuitButton"] = _overlay_control(menu, &"quit")
		controls["PhoneQuitContinueButton"] = _overlay_control(quit, &"continue")
		controls["PhoneShowdownCloseButton"] = _overlay_control(summary, &"close")
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
		snapshot["history_count"] = view.action_history.size()
		snapshot["hand_complete"] = view.hand_complete
		snapshot["hand_number"] = view.hand_number
		snapshot["result_text"] = layout.elements[&"action/status"].text
		snapshot["result_visible"] = layout.elements[&"action/status"].visible
		snapshot["result_button"] = layout.elements[&"more"].text
		snapshot["summary_open"] = summary.element.visible
		snapshot["summary_text"] = _overlay_element(summary, &"text").text
		var winner_names: Array[String] = []
		for award: PotAward in view.pot_awards:
			for seat: int in award.winner_seats:
				winner_names.append(layout.seats[seat].fields[&"name"].text)
		snapshot["winner_names"] = winner_names
		snapshot["menu"] = menu.element.visible
		snapshot["quit_confirmation"] = quit.element.visible
		snapshot["modal_focus"] = _has_focus(menu) or _has_focus(quit)
		snapshot["more_focus"] = layout.elements[&"more"].focused
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


func _has_focus(overlay: GuiOverlaySnapshot) -> bool:
	if not overlay.element.visible:
		return false
	for element: GuiLayoutElement in overlay.measured:
		if element.focused:
			return true
	return false
