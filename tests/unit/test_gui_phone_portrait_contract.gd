extends "res://tests/support/poker_gut_test.gd"

const Driver := preload("res://tests/support/gui_reference_fixture_driver.gd")
const Harness := preload("res://tests/support/gui_scene_harness.gd")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const Phone := preload("res://tests/support/gui_phone_matrix_contract.gd")


func test_supported_portrait_counts_preserve_semantic_content_and_order_across_resize() -> void:
	for count: int in range(2, 8):
		for showdown: bool in [false, true]:
			var view: GameView = (
				States._showdown_view(count)
				if showdown
				else States._human_turn_view(count, &"preflop")
			)
			var descriptor: Dictionary = States._table_descriptor(
				&"showdown-long" if showdown else &"human-turn-preflop", view
			)
			var signature: String = Phone.view_signature(view)
			var harness: Node = Harness.new()
			add_child_autofree(harness)
			var rendered: Dictionary = harness.render(descriptor, Vector2i(360, 640))
			for extent: Vector2i in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(360, 640)]:
				harness.resize_viewport(extent)
				assert_true(await harness.settle_layout())
				var context: String = "%s p%d showdown=%s" % [extent, count, showdown]
				var failures: PackedStringArray = Invariants.validate(rendered)
				Phone.validate(rendered, context, failures)
				assert_eq(failures, PackedStringArray(), context)
				assert_eq(
					Phone.view_signature(view), signature, "Rendering cannot mutate GameView."
				)


func test_portrait_contract_rejects_external_status_footprint_overlap_and_escape() -> void:
	var snapshot: GuiLayoutSnapshot = _snapshot()
	var failures := PackedStringArray()
	Driver.validate_phone_geometry(snapshot, "baseline", failures)
	assert_eq(failures, PackedStringArray())
	snapshot.seats[1].footprint.size.y = 740
	Driver.validate_phone_geometry(snapshot, "broken status band", failures)
	assert_true(_contains(failures, "portrait-footprint:"))
	snapshot = _snapshot()
	var action := GuiLayoutElement.new()
	action.role = &"seat/1/action"
	action.visible = true
	action.rect = Rect2(10, 190, 180, 30)
	snapshot.seats[1].fields[&"action"] = action
	failures.clear()
	Driver.validate_phone_geometry(snapshot, "omitted action band", failures)
	assert_true(_contains(failures, "omits visible seat/1/action"))


func test_two_seat_row_cap_counts_complete_footprints_despite_small_vertical_stagger() -> void:
	var snapshot: GuiLayoutSnapshot = _snapshot()
	for seat_id: int in range(1, 5):
		snapshot.seats[seat_id].panel.rect = Rect2(10 + (seat_id - 1) * 90, seat_id, 80, 60)
		snapshot.seats[seat_id].footprint = snapshot.seats[seat_id].panel.rect
	var failures := PackedStringArray()
	Driver.validate_phone_geometry(snapshot, "four seats", failures)
	assert_true(_contains(failures, "portrait-row-cap:"))


func test_portrait_order_rejects_swapped_rendered_seats_without_changing_source_identity() -> void:
	var snapshot: GuiLayoutSnapshot = _snapshot()
	var first: Rect2 = snapshot.seats[1].panel.rect
	snapshot.seats[1].panel.rect = snapshot.seats[3].panel.rect
	snapshot.seats[3].panel.rect = first
	for seat_id: int in [1, 3]:
		snapshot.seats[seat_id].footprint = snapshot.seats[seat_id].panel.rect
	var failures := PackedStringArray()
	Driver.validate_phone_geometry(snapshot, "swapped seats", failures)
	assert_true(_contains(failures, "portrait-order:"))


func test_portrait_status_copy_cannot_grow_to_three_lines_or_hide_its_third_line() -> void:
	var snapshot: GuiLayoutSnapshot = _snapshot()
	var status := GuiLayoutElement.new()
	status.role = &"status/1"
	status.visible = true
	status.rect = Rect2(10, 194, 180, 84)
	status.text = "Four of a\nkind\nQueens"
	status.line_count = 3
	status.max_lines = 2
	snapshot.seats[1].status = status
	snapshot.seats[1].footprint = snapshot.seats[1].panel.rect.merge(status.rect)
	var failures := PackedStringArray()
	Driver.validate_phone_geometry(snapshot, "three lines", failures)
	assert_true(_contains(failures, "portrait-status-lines:"))


func test_single_opponent_is_centered_and_same_width_as_paired_opponents() -> void:
	for extent: Vector2i in [Vector2i(360, 640), Vector2i(390, 844)]:
		var widths: Array[float] = []
		for count: int in [2, 3]:
			var descriptor: Dictionary = States._table_descriptor(
				&"human-turn-preflop", States._human_turn_view(count, &"preflop")
			)
			var harness: Node = Harness.new()
			add_child_autofree(harness)
			var rendered: Dictionary = harness.render(descriptor, extent)
			assert_true(await harness.settle_layout())
			var snapshot: GuiLayoutSnapshot = rendered.root.get_layout_snapshot()
			var failures := PackedStringArray()
			Driver.validate_phone_geometry(snapshot, "one bot versus pairs", failures)
			assert_eq(failures, PackedStringArray())
			widths.append(snapshot.seats[1].panel.rect.size.x)
			if count == 2:
				assert_almost_eq(
					snapshot.seats[1].panel.rect.get_center().x,
					snapshot.surface_rect.get_center().x,
					0.01
				)
		assert_almost_eq(widths[0], widths[1], 0.01)


func test_odd_apex_rejects_full_width_and_off_center_top_seat() -> void:
	var snapshot := GuiLayoutSnapshot.new()
	snapshot.surface_size = Vector2(400, 800)
	snapshot.surface_rect = Rect2(Vector2.ZERO, snapshot.surface_size)
	for seat_id: int in range(2):
		var seat := GuiSeatSnapshot.new()
		seat.seat_id = seat_id
		seat.visual_slot = seat_id
		seat.hero = seat_id == 0
		seat.panel = GuiLayoutElement.new()
		seat.panel.visible = seat_id == 1
		seat.panel.rect = Rect2(0, 10, 400, 80)
		seat.footprint = seat.panel.rect
		snapshot.seats[seat_id] = seat
	var failures := PackedStringArray()
	Driver.validate_phone_geometry(snapshot, "full width apex", failures)
	assert_true(_contains(failures, "portrait-apex:"))
	snapshot.seats[1].panel.rect = Rect2(10, 10, 180, 80)
	snapshot.seats[1].footprint = snapshot.seats[1].panel.rect
	failures.clear()
	Driver.validate_phone_geometry(snapshot, "off center apex", failures)
	assert_true(_contains(failures, "top seat is not centered"))


func _snapshot() -> GuiLayoutSnapshot:
	var snapshot := GuiLayoutSnapshot.new()
	snapshot.surface_size = Vector2(400, 800)
	snapshot.surface_rect = Rect2(Vector2.ZERO, snapshot.surface_size)
	for role: StringName in [&"center", &"action"]:
		var element := GuiLayoutElement.new()
		element.rect = Rect2(10, 500 if role == &"center" else 650, 380, 100)
		snapshot.elements[role] = element
	var positions: Array[Vector2] = [
		Vector2(10, 110), Vector2(10, 10), Vector2(210, 10), Vector2(210, 110)
	]
	for seat_id: int in range(5):
		var seat := GuiSeatSnapshot.new()
		seat.seat_id = seat_id
		seat.visual_slot = seat_id
		seat.hero = seat_id == 0
		seat.panel = GuiLayoutElement.new()
		seat.panel.visible = seat_id > 0
		if seat_id > 0:
			seat.panel.rect = Rect2(positions[seat_id - 1], Vector2(180, 80))
			seat.footprint = seat.panel.rect
		snapshot.seats[seat_id] = seat
	return snapshot


func _contains(failures: PackedStringArray, category: String) -> bool:
	for failure: String in failures:
		if category in failure:
			return true
	return false
