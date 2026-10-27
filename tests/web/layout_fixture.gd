extends Node

## Export-only read-only observer of production layout and font measurements.

const MainScene := preload("res://scenes/main.tscn")
const Fixture := preload("res://tests/support/gui_browser_capture_fixture.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")

var _main: Control
var _table: PokerTableController
var _descriptor: Dictionary
var _frame: int = 0


func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	_descriptor = Fixture.descriptor()
	_main = MainScene.instantiate() as Control
	add_child(_main)
	_main.get_node("Center").hide()
	_table = _main.get_node("PokerTable") as PokerTableController
	_table.show()
	_table.bind_view(_descriptor.view, _descriptor.avatars, _descriptor.names)
	_table._render_events(_descriptor.events)


func _process(_delta: float) -> void:
	_frame += 1
	var surface := _table.get_node("TableMargin/Felt/TableSurface") as Control
	var regions: Dictionary = {}
	for key: StringName in _table.get_resolved_region_rects():
		regions[key] = _rect(_table.get_resolved_region_rects()[key])
	var labels: Array[Dictionary] = []
	for node: Node in _table.find_children("*", "Label", true, false):
		var label := node as Label
		if not label.is_visible_in_tree():
			continue
		labels.append(
			{
				"path": String(_table.get_path_to(label)),
				"text": label.text,
				"rect_global": _rect(label.get_global_rect()),
				"font_size": label.get_theme_font_size("font_size"),
				"clip_text": label.clip_text,
				"overrun": label.text_overrun_behavior,
				"max_lines": label.max_lines_visible
			}
		)
	var seats: Array[Dictionary] = []
	for player: PlayerView in _descriptor.view.seats:
		seats.append(
			{
				"seat": player.seat,
				"name": _descriptor.names[player.seat],
				"stack": player.stack,
				"wager": player.bet_this_round,
				"folded": player.folded,
				"rect": regions["seat_%d" % player.seat],
				"status_rect": regions["status_%d" % player.seat]
			}
		)
	var rendered: Dictionary = {
		"descriptor": _descriptor,
		"table": _table,
		"root": _main,
		"overlay": null,
		"intentional_overlap_controls": [],
		"layout_profile": _table.get_layout_profile()
	}
	var snapshot: Dictionary = {
		"frame": _frame,
		"button_seat": _descriptor.view.button_seat,
		"small_blind_seat": _descriptor.view.small_blind_seat,
		"big_blind_seat": _descriptor.view.big_blind_seat,
		"layout_generation": _table.get_layout_generation(),
		"pending": _table.is_layout_pending(),
		"profile": _table.get_layout_profile(),
		"root_rect_global": _rect(_main.get_global_rect()),
		"table_rect_global": _rect(_table.get_global_rect()),
		"surface_rect_global": _rect(surface.get_global_rect()),
		"regions_surface_local": regions,
		"seats": seats,
		"labels": labels,
		"invariant_failures": Invariants.validate(rendered)
	}
	JavaScriptBridge.eval("window.pokahdotLayout = " + JSON.stringify(snapshot) + "; void 0")


func _rect(value: Rect2) -> Array[float]:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
