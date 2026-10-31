class_name GuiReplacementMatrixSupport
extends RefCounted

## Shared replacement-only setup for invariant runners and rendered captures.
const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")
const Cases := preload("res://tests/support/gui_replacement_capture_cases.gd")
const Invariants := preload("res://tests/support/gui_replacement_invariant_assertions.gd")


static func mount(host: Node, case: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = case.size
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var table := TableScene.instantiate() as GuiReplacementTableController
	table.touch_entry = case.category in [&"phone", &"ipad"]
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(case.size)
	viewport.add_child(table)
	table.set_layout_mode_override(case.layout_mode_override)
	table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(case.size)))
	var fixture: Dictionary = Cases.fixture(case)
	var avatars: Dictionary[int, String] = {}
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	for seat: PlayerView in (fixture.view as GameView).seats:
		avatars[seat.seat] = paths[seat.seat]
	var bound: bool = table.bind_view(fixture.view, avatars, {})
	return {"viewport": viewport, "table": table, "fixture": fixture, "bound": bound}


static func wait_settled(tree: SceneTree, table: GuiReplacementTableController) -> bool:
	for _frame: int in 180:
		await tree.process_frame
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		if not snapshot.pending and (snapshot.ready or not snapshot.fit_guidance.is_empty()):
			return true
	return false


static func validate_case(snapshot: GuiLayoutSnapshot, case: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = Invariants.validate(snapshot)
	if case.expects_readiness and snapshot.ready != case.expected_ready:
		failures.append("readiness: expected %s" % case.expected_ready)
	if not case.expects_readiness and not snapshot.ready and snapshot.fit_guidance.is_empty():
		failures.append("readiness: neither supported layout nor fit guidance was published")
	return failures
