extends "res://tests/support/poker_gut_test.gd"

const Fixtures := preload("res://tests/support/gui_visual_state_fixtures.gd")
const TableScene := preload("res://scenes/poker_table.tscn")


func test_binding_owns_assignment_snapshots_and_replaces_typed_seat_handles() -> void:
	var descriptor: Dictionary = Fixtures.by_id(&"human-turn-preflop", 6)
	var table := TableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(390, 844)
	add_child_autofree(table)
	var names: Dictionary[int, String] = {1: "Santiago"}
	table.bind_view(descriptor.view, {}, names)
	await _settle()
	names[1] = "Changed outside table"
	var old_seat := table._seat_widgets[1] as GuiTableSeatView
	assert_eq(old_seat.name_label.text, "Santiago")
	assert_eq(table._seat_factory.seat_title(descriptor.view.seats[1]), "Santiago")
	assert_same(old_seat.name_label, old_seat.find_child("Name", true, false))
	assert_same(old_seat.hole_cards, old_seat.find_child("HoleCards", true, false))
	assert_null(old_seat.hole_cards.find_child("ShowdownCard1", false, false))

	table.bind_view(descriptor.view, {}, {1: "Priyanka"})
	await _settle()
	assert_false(is_instance_valid(old_seat), "Rebinding releases handles with their old widget.")
	var new_seat := table._seat_widgets[1] as GuiTableSeatView
	assert_eq(new_seat.name_label.text, "Priyanka")
	assert_same(new_seat.state_badge, new_seat.badge_rows["Badge"])
	assert_same(new_seat.action_badge, new_seat.field("ActionBadge"))
	assert_eq(new_seat.hole_cards.get_child_count(), 2)


func test_action_row_handles_survive_phone_to_desktop_reparenting() -> void:
	var descriptor: Dictionary = Fixtures.by_id(&"human-turn-preflop", 4)
	var table := TableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(390, 844)
	add_child_autofree(table)
	table.bind_view(descriptor.view, {}, {})
	await _settle()
	var controls: GuiTableActionControls = table._action_controls
	var primary: HBoxContainer = controls.primary
	var wagers: HBoxContainer = controls.wagers
	for viewport: Vector2 in [Vector2(844, 390), Vector2(1920, 1080), Vector2(390, 844)]:
		table.size = viewport
		await _settle()
		assert_same(controls.primary, primary)
		assert_same(controls.wagers, wagers)
		assert_same(table._fold_button.get_parent(), primary)
		assert_same(primary.get_parent(), controls.rows)
		assert_same(wagers.get_parent(), controls.rows)
		assert_null(table._seat_widgets[1].find_child("ShowdownCard1", true, false))


func test_layout_pass_keeps_root_profile_and_independent_geometry_snapshots() -> void:
	var desktop := GuiTableLayoutPass.new()
	desktop.configure(Vector2(1369, 724), Vector2(1297, 652), GuiLayoutProfile.AUTOMATIC, 6, false)
	assert_eq(desktop.layout_profile, GuiLayoutProfile.Kind.DESKTOP)
	assert_false(desktop.phone_layout)
	assert_eq(desktop.surface_size, Vector2(1297, 652))
	var phone := GuiTableLayoutPass.new()
	phone.configure(Vector2(390, 844), Vector2(366, 820), GuiLayoutProfile.AUTOMATIC, 7, false)
	assert_true(phone.phone_layout)
	assert_eq(phone.seat_count, 7)
	assert_eq(desktop.seat_count, 6)
	assert_eq(desktop.surface_size, Vector2(1297, 652))
	var ipad := GuiTableLayoutPass.new()
	ipad.configure(Vector2(2388, 1450), Vector2(2316, 1378), GuiLayoutProfile.Kind.TABLET, 9, true)
	assert_true(ipad.tablet_layout)
	assert_false(ipad.small_desktop_layout)
	assert_false(ipad.compact_desktop)


func _settle() -> void:
	for _frame: int in range(6):
		await get_tree().process_frame
