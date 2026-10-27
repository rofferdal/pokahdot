extends Node

## Export-only observer. It mounts production controls and exposes read-only
## state; browser input must travel through the exported canvas and engine.

const MainScene := preload("res://scenes/main.tscn")


class CallingAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		if PlayerAction.Kind.CHECK in view.legal_actions:
			return PlayerAction.check_action()
		return PlayerAction.call_action()


var _main: Control
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
	_main = MainScene.instantiate() as Control
	add_child(_main)
	_table = _main.get_node("PokerTable") as PokerTableController
	if _table_fixture:
		_main.get_node("Center").hide()
		_table.show()
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
		(_table.get_node("%WagerInput") as LineEdit).text = "75"
		if _showdown_fixture:
			_table._advance_after_action_pause()
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
	var controls: Dictionary = {}
	var input: LineEdit = (
		(
			_table.get_node("%WagerInput")
			if _table_fixture
			else _main.get_node("%StartingStackInput")
		)
		as LineEdit
	)
	controls.input = _control_state(input)
	if _table_fixture:
		for key: String in [
			"PhoneMoreButton",
			"PhoneMenuCloseButton",
			"PhoneMenuQuitButton",
			"PhoneQuitContinueButton",
			"FoldButton",
			"PhoneShowdownCloseButton"
		]:
			controls[key] = _control_state(_table.get_node("%" + key))
	controls.open = (
		_control_state(_table.get_node("%WagerButton")) if _table_fixture else controls.input
	)
	var popup: Window = (
		(
			_table.get_node("WagerKeypad")
			if _table_fixture
			else _main.get_node("StartupNumberKeypad")
		)
		as Window
	)
	if popup.visible:
		for key: String in ["KeyClear", "Key2", "Key5"]:
			controls[key] = _control_state(popup.get_node("Content/Keys/" + key))
		for key: String in ["Done", "Cancel", "Value"]:
			controls[key] = _control_state(popup.get_node("Content/" + key))
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var snapshot := {
		"frame": _frame,
		"fixture": "table" if _table_fixture else "startup",
		"viewport": [viewport_size.x, viewport_size.y],
		"controls": controls,
		"popup": popup.visible,
		"input": input.text,
		"focus": input.has_focus(),
		"draft": (popup.get_node("Content/Value") as Label).text,
	}
	if _match != null:
		var view: GameView = _match.get_view_for(0)
		snapshot["hero_wager"] = view.seats[0].bet_this_round
		snapshot["history_count"] = view.action_history.size()
		snapshot["hand_complete"] = view.hand_complete
		snapshot["hand_number"] = view.hand_number
		snapshot["result_text"] = _table._action_status.text
		snapshot["result_visible"] = _table._action_status.is_visible_in_tree()
		snapshot["result_button"] = _table._phone_more_button.text
		snapshot["summary_open"] = _table._phone_showdown_overlay.visible
		snapshot["summary_text"] = _table._phone_showdown_summary.text
		var winner_names: Array[String] = []
		for award: PotAward in view.pot_awards:
			for seat: int in award.winner_seats:
				winner_names.append(_table._display_name_for_seat(seat))
		snapshot["winner_names"] = winner_names
		snapshot["menu"] = _table._phone_overflow_menu.visible
		snapshot["quit_confirmation"] = _table._phone_quit_confirmation.visible
		var focus: Control = _table.get_viewport().gui_get_focus_owner()
		snapshot["modal_focus"] = (
			focus != null
			and (
				_table._phone_overflow_menu.is_ancestor_of(focus)
				or _table._phone_quit_confirmation.is_ancestor_of(focus)
			)
		)
		snapshot["more_focus"] = _table._phone_more_button.has_focus()
	JavaScriptBridge.eval("window.pokahdotInput = " + JSON.stringify(snapshot) + "; void 0")


func _control_state(control: Control) -> Dictionary:
	var rect: Rect2 = control.get_global_rect()
	var window: Window = control.get_window()
	if window != get_window():
		rect.position += Vector2(window.position)
	return {
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"visible": control.is_visible_in_tree(),
	}
