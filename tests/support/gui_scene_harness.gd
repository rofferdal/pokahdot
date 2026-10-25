class_name GuiSceneHarness
extends Node

## Mounts one deterministic visual-state descriptor in an isolated viewport.

const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const MainScene := preload("res://scenes/main.tscn")
const PokerTableScene := preload("res://scenes/poker_table.tscn")

var _viewport: SubViewport
var _rendered: Dictionary = {}


func render(descriptor: Dictionary, viewport_size: Vector2i) -> Dictionary:
	assert(_viewport == null, "A GUI scene harness renders one fixture.")
	_viewport = SubViewport.new()
	_viewport.name = "FixtureViewport"
	_viewport.size = viewport_size
	_viewport.disable_3d = true
	_viewport.gui_embed_subwindows = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	if (
		descriptor.kind
		in [
			GuiVisualStateFixturesScript.KIND_STARTUP,
			GuiVisualStateFixturesScript.KIND_UI_ONLY,
		]
	):
		_rendered = _render_startup_state(descriptor, viewport_size)
	else:
		_rendered = _render_table_state(descriptor, viewport_size)
	return _rendered


func resize_viewport(viewport_size: Vector2i) -> void:
	assert(not _rendered.is_empty(), "Render a GUI fixture before resizing it.")
	_viewport.size = viewport_size
	var root: Control = _rendered.root
	root.size = Vector2(viewport_size)
	if _rendered.table == null:
		root.call("_refresh_startup_layout")


func rerender(descriptor: Dictionary) -> Dictionary:
	assert(_rendered.table != null, "Only a rendered table can bind a new visual state.")
	assert(descriptor.view != null, "A table rerender requires a GameView snapshot.")
	var table: PokerTableController = _rendered.table
	_close_overlay(_rendered.overlay)
	(
		table
		. bind_view(
			descriptor.view,
			_avatar_assignments(descriptor.player_count),
			_name_assignments(descriptor.player_count),
		)
	)
	table._render_events(descriptor.events)
	if descriptor.id == &"wager-entry":
		(table.get_node("%WagerInput") as LineEdit).text = descriptor.ui.wager_input_text
	var overlay: Node = null
	if descriptor.id == &"quit-confirmation":
		overlay = table.get_node("%QuitConfirmation")
		(overlay as ConfirmationDialog).popup_centered()
	_rendered = _result(descriptor, table, table, overlay)
	return _rendered


func settle_layout(max_frames: int = 16) -> bool:
	assert(not _rendered.is_empty(), "Render a GUI fixture before settling it.")
	var previous_signature: String = ""
	var stable_frames: int = 0
	for _frame: int in range(max_frames):
		await get_tree().process_frame
		var signature := _geometry_signature()
		var table: PokerTableController = _rendered.table
		var pending: bool = table != null and table.is_layout_pending()
		if not pending and signature == previous_signature:
			stable_frames += 1
		else:
			stable_frames = 0
		previous_signature = signature
		if stable_frames >= 2:
			return true
	return false


func _render_startup_state(descriptor: Dictionary, viewport_size: Vector2i) -> Dictionary:
	var main := MainScene.instantiate() as Control
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(viewport_size)
	_viewport.add_child(main)
	main._refresh_startup_layout()
	var overlay: Node = null
	if descriptor.id == &"keypad-open":
		main.show_numeric_keypad(main.get_node("%PlayerCountInput") as LineEdit)
		overlay = main.get_node("StartupNumberKeypad")
	return _result(descriptor, main, null, overlay)


func _render_table_state(descriptor: Dictionary, viewport_size: Vector2i) -> Dictionary:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(viewport_size)
	_viewport.add_child(table)
	(
		table
		. bind_view(
			descriptor.view,
			_avatar_assignments(descriptor.player_count),
			_name_assignments(descriptor.player_count),
		)
	)
	if not descriptor.events.is_empty():
		table._render_events(descriptor.events)
	if descriptor.id == &"wager-entry":
		(table.get_node("%WagerInput") as LineEdit).text = descriptor.ui.wager_input_text
	var overlay: Node = null
	if descriptor.id == &"quit-confirmation":
		overlay = table.get_node("%QuitConfirmation")
		(overlay as ConfirmationDialog).popup_centered()
	return _result(descriptor, table, table, overlay)


func _result(
	descriptor: Dictionary, root: Control, table: PokerTableController, overlay: Node
) -> Dictionary:
	return {
		"descriptor": descriptor,
		"viewport": _viewport,
		"root": root,
		"table": table,
		"overlay": overlay,
		"intentional_overlap_controls": descriptor.ui.get("intentional_overlap_controls", []),
	}


func _avatar_assignments(player_count: int) -> Dictionary[int, String]:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = paths[seat]
	return assignments


func _name_assignments(player_count: int) -> Dictionary[int, String]:
	var names: Array[String] = [
		"Human",
		"Youssef",
		"Leilani",
		"Aleksiej",
		"Santiago",
		"Priyanka",
		"Kwame",
		"Saoirse",
		"Natsuki"
	]
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = names[seat]
	return assignments


func _geometry_signature() -> String:
	var root: Control = _rendered.root
	var parts := PackedStringArray([str(root.size)])
	for node: Node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		parts.append("%s:%s" % [root.get_path_to(control), control.get_global_rect()])
	return "|".join(parts)


func _close_overlay(overlay: Node) -> void:
	if overlay != null and overlay.has_method("hide"):
		overlay.call("hide")
