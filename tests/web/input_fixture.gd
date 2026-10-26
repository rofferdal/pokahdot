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
var _frame: int = 0
var _match: TournamentMatch


func _ready() -> void:
	print("Web input fixture ready")
	if not OS.has_feature("web"):
		set_process(false)
		return
	_table_fixture = bool(JavaScriptBridge.eval("location.search.includes('table')"))
	print("Web input fixture instantiating production main")
	_main = MainScene.instantiate() as Control
	add_child(_main)
	_table = _main.get_node("PokerTable") as PokerTableController
	if _table_fixture:
		_main.get_node("Center").hide()
		_table.show()
		_match = TournamentMatch.new(
			ResolvedTournamentConfig.new(
				2, 1000, 5, 10, 9123, &"single_table", {0: &"human", 1: &"scripted"}
			),
			{0: HumanAgent.new(), 1: CallingAgent.new()}
		)
		_match.start()
		var timing := GuiActionTimingConfig.new()
		timing.default_pause_seconds = 60.0
		_table.set_action_timing_config(timing)
		_table.bind_match(_match, 0, {}, {0: "Human", 1: "Alex"})
		(_table.get_node("%WagerInput") as LineEdit).text = "75"
	JavaScriptBridge.eval("window.pokahdotInput = {}; void 0")


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
