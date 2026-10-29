extends Node

## Export-only read-only observer of the production semantic snapshot API.

const MainScene := preload("res://scenes/main.tscn")
const Fixture := preload("res://tests/support/gui_browser_capture_fixture.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const Json := preload("res://tests/web/layout_snapshot_json.gd")
const Setup := preload("res://tests/web/reference_fixture_setup.gd")
const GeometrySetup := preload("res://tests/web/viewport_geometry_fixture_setup.gd")

var _main: StartupConfigController
var _table: PokerTableController
var _descriptor: Dictionary
var _frame: int = 0
var _expected_overlays: Array[StringName] = []


func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	_descriptor = Fixture.descriptor()
	_main = MainScene.instantiate() as StartupConfigController
	add_child(_main)
	GeometrySetup.apply(_main)
	_expected_overlays = GeometrySetup.expected_overlays()
	_table = Setup.table(_main, true)
	_table.bind_view(_descriptor.view, _descriptor.avatars, _descriptor.names)
	Setup.bind_events(_table, _descriptor.events)
	await GeometrySetup.open_initial_overlay(_table)


func _process(_delta: float) -> void:
	_frame += 1
	var layout: GuiLayoutSnapshot = _table.get_layout_snapshot()
	var snapshot: Dictionary = Json.encode(layout)
	snapshot["frame"] = _frame
	snapshot["button_seat"] = _descriptor.view.button_seat
	snapshot["small_blind_seat"] = _descriptor.view.small_blind_seat
	snapshot["big_blind_seat"] = _descriptor.view.big_blind_seat
	for seat: Dictionary in snapshot.seats:
		var seat_id: int = seat.seat
		seat["name"] = _descriptor.names[seat_id]
		for player: PlayerView in _descriptor.view.seats:
			if player.seat == seat_id:
				seat["stack"] = player.stack
				seat["wager"] = player.bet_this_round
				seat["folded"] = player.folded
	snapshot["invariant_failures"] = Invariants.validate_snapshot(layout, _expected_overlays)
	snapshot["geometry"] = _geometry(layout)
	JavaScriptBridge.eval("window.pokahdotLayout = " + JSON.stringify(snapshot) + "; void 0")


## Real Window/output measurements; no geometry or input state is changed.
func _geometry(layout: GuiLayoutSnapshot) -> Dictionary:
	var window: Window = get_window()
	var final: Transform2D = window.get_final_transform()
	var elements: Array[Dictionary] = []
	var overlays: Array[Dictionary] = []
	for value: GuiLayoutElement in layout.elements.values():
		if not value.visible or not (value.interactive or value.font_size > 0):
			continue
		var measured: Dictionary = Json.element(value)
		measured["text_kind"] = String(value.text_kind)
		measured["interactive"] = value.interactive
		measured["target_output_size"] = [
			(final * value.rect).size.x,
			(final * value.rect).size.y,
		]
		elements.append(measured)
	for seat: GuiSeatSnapshot in layout.seats.values():
		for value: GuiLayoutElement in seat.fields.values():
			if not value.visible or value.font_size <= 0:
				continue
			var measured: Dictionary = Json.element(value)
			measured["text_kind"] = String(value.text_kind)
			measured["interactive"] = value.interactive
			measured["target_output_size"] = [
				(final * value.rect).size.x,
				(final * value.rect).size.y,
			]
			elements.append(measured)
	for overlay: GuiOverlaySnapshot in layout.overlays:
		if not overlay.element.visible:
			continue
		overlays.append({"kind": String(overlay.kind), "rect": Json.rect(overlay.element.rect)})
		for value: GuiLayoutElement in overlay.measured:
			if not value.visible or not (value.interactive or value.font_size > 0):
				continue
			var measured: Dictionary = Json.element(value)
			measured["text_kind"] = String(value.text_kind)
			measured["interactive"] = value.interactive
			measured["target_output_size"] = [
				(final * value.rect).size.x,
				(final * value.rect).size.y,
			]
			elements.append(measured)
	var backing: Vector2i = DisplayServer.window_get_size(window.get_window_id())
	return {
		"window":
		{
			"size": [window.size.x, window.size.y],
			"display_server_size": [backing.x, backing.y],
			"screen_scale": DisplayServer.screen_get_scale(window.current_screen),
			"dpi": DisplayServer.screen_get_dpi(window.current_screen),
			"content_scale_size": [window.content_scale_size.x, window.content_scale_size.y],
			"content_scale_mode": window.content_scale_mode,
			"content_scale_aspect": window.content_scale_aspect,
			"content_scale_factor": window.content_scale_factor,
			"viewport_visible_rect": Json.rect(window.get_visible_rect()),
			"final_transform":
			[final.x.x, final.x.y, final.y.x, final.y.y, final.origin.x, final.origin.y],
		},
		"control":
		{
			"size": [_table.size.x, _table.size.y],
			"main_size": [_main.size.x, _main.size.y],
			"profile": layout.profile,
			"root_rect": Json.rect(layout.root_rect)
		},
		"elements": elements,
		"overlays": overlays,
	}
