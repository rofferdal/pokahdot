extends GutTest

const MainScene := preload("res://scenes/main.tscn")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")


func test_reference_remains_default_and_startup_instantiates_one_table() -> void:
	var main := _main(false)
	await wait_process_frames(5)
	assert_true(main.get_table_controller() is PokerTableController)
	assert_eq(_reference_tables(main), 1)
	assert_eq(_direct_tables(main), 1)
	assert_true(main.get_layout_snapshot().ready)
	remove_child(main)
	add_child(main)
	await wait_process_frames(3)
	assert_eq(_direct_tables(main), 1, "Reentry must not instantiate another controller")


func test_opt_in_startup_adopts_one_match_and_applies_safe_origin_once() -> void:
	var main := _main(true)
	await wait_process_frames(5)
	var table: Control = main.get_table_controller()
	assert_eq(table.get_script().get_global_name(), &"GuiReplacementTableController")
	assert_eq(_reference_tables(main), 0, "Replacement must not construct hidden legacy controls")
	assert_eq(_direct_tables(main), 1)
	var safe := Rect2(23, 31, 1850, 1120)
	main.get_viewport_adapter().inject_geometry(GuiViewportGeometry.injected(main.size, safe))
	await wait_process_frames(5)
	(main.get_node("%StartButton") as Button).pressed.emit()
	var adopted: TournamentMatch = main.startup_adapter.match_instance
	assert_not_null(adopted)
	assert_true(await _settle(main))
	assert_eq(table.position, Vector2.ZERO)
	assert_eq(table.size, main.size)
	var snapshot: GuiLayoutSnapshot = main.get_layout_snapshot()
	assert_eq(snapshot.schema_version, 2)
	assert_eq(snapshot.usable_rect, safe)
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	var composition: Object = table.call("get_composition")
	main.get_viewport_adapter().inject_geometry(
		GuiViewportGeometry.injected(main.size, Rect2(41, 53, 1800, 1100))
	)
	assert_true(await _settle(main))
	assert_same(main.startup_adapter.match_instance, adopted)
	assert_same(main.get_table_controller(), table)
	assert_same(table.call("get_composition"), composition)
	assert_eq(main.get_layout_snapshot().usable_rect, Rect2(41, 53, 1800, 1100))
	assert_eq(_reference_tables(main), 0)
	assert_eq(_direct_tables(main), 1)


func _main(replacement: bool) -> StartupConfigController:
	var main := MainScene.instantiate() as StartupConfigController
	main.use_replacement_gui = replacement
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1920, 1200)
	add_child_autofree(main)
	return main


func _settle(main: StartupConfigController) -> bool:
	for frame: int in 180:
		await wait_process_frames(1)
		var snapshot: GuiLayoutSnapshot = main.get_layout_snapshot()
		if not snapshot.pending and snapshot.ready:
			return true
	return false


func _direct_tables(main: Node) -> int:
	var count: int = 0
	for child: Node in main.get_children():
		if child.has_method("bind_match") and child.has_method("get_layout_snapshot"):
			count += 1
	return count


func _reference_tables(node: Node) -> int:
	var count: int = 1 if node is PokerTableController else 0
	for child: Node in node.get_children():
		count += _reference_tables(child)
	return count
