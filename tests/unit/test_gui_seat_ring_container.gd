extends GutTest

const RingScene := preload("res://scenes/gui/layouts/SeatRingContainer.tscn")
const SeatScene := preload("res://scenes/gui/components/SeatPanel.tscn")
const HeroScene := preload("res://scenes/gui/components/HeroPanel.tscn")
const BoardScene := preload("res://scenes/gui/components/CenterBoard.tscn")
const ActionScene := preload("res://scenes/gui/components/ActionBar.tscn")
const Palette := preload("res://resources/gui_theme.tres")
var _root: Control


func before_each() -> void:
	_root = Control.new()
	_root.theme = Palette
	_root.size = Vector2(4000, 4000)
	add_child_autofree(_root)


func test_native_container_places_all_recipients_and_reordered_children_at_measured_minimum(
) -> void:
	for count: int in range(2, 10):
		for hero: int in count:
			var ring: GuiSeatRingContainer = RingScene.instantiate()
			_root.add_child(ring)
			ring.position = Vector2(23, 31)
			var seats: Dictionary[int, Control] = _dummy_seats(ring, count)
			var center: Control = _region(ring, Vector2(200, 90))
			var lower: Control = _region(ring, Vector2(280, 60))
			assert_true(ring.bind(seats, hero, center, lower))
			ring.size = ring.get_combined_minimum_size()
			await wait_process_frames(3)
			var plan: GuiSeatRingPlan = ring.get_layout_plan()
			assert_true(plan.valid)
			assert_true(plan.feasible, plan.error)
			assert_eq(plan.minimum, ring.size)
			_assert_actual(ring, seats, center, lower, plan)
			var first: Dictionary[int, Rect2] = plan.seats.duplicate()
			ring.move_child(seats[hero], 0)
			ring.queue_sort()
			await wait_process_frames(2)
			assert_eq(ring.get_layout_plan().seats, first)
			ring.free()


func test_short_allocation_shows_guidance_then_restores_exact_controls_and_copy() -> void:
	var ring: GuiSeatRingContainer = RingScene.instantiate()
	_root.add_child(ring)
	var seats: Dictionary[int, Control] = _dummy_seats(ring, 9)
	var center: Control = _region(ring, Vector2(250, 120))
	var lower: Control = _region(ring, Vector2(300, 60))
	assert_true(ring.bind(seats, 7, center, lower))
	ring.size = ring.get_combined_minimum_size()
	await wait_process_frames(4)
	var minimum: Vector2 = ring.get_combined_minimum_size()
	assert_true(ring.set_allocation_limit(Vector2(220, 180)))
	await wait_process_frames(4)
	var failed: GuiSeatRingPlan = ring.get_layout_plan()
	assert_true(failed.valid)
	assert_false(failed.feasible)
	assert_true(failed.seats.is_empty())
	assert_true((ring.get_node("Guidance") as Control).is_visible_in_tree())
	for seat: Control in seats.values():
		assert_false(seat.is_visible_in_tree())
	assert_false(center.visible)
	assert_false(lower.visible)
	assert_eq(ring.get_combined_minimum_size(), minimum)
	assert_true(ring.set_allocation_limit(Vector2.ZERO))
	await wait_process_frames(4)
	_assert_actual(ring, seats, center, lower, ring.get_layout_plan())
	assert_false((ring.get_node("Guidance") as Control).visible)
	for id: int in seats:
		assert_eq((seats[id] as Label).text, "Seat %d" % id)
	var detached: GuiSeatRingPlan = ring.get_layout_plan()
	detached.seats.clear()
	assert_eq(ring.get_layout_plan().seats.size(), 9)


func test_child_minimum_theme_and_rebinding_recover_without_stale_nodes() -> void:
	var ring: GuiSeatRingContainer = RingScene.instantiate()
	_root.add_child(ring)
	var seats: Dictionary[int, Control] = _dummy_seats(ring, 4)
	var center: Control = _region(ring, Vector2(200, 90))
	assert_true(ring.bind(seats, 2, center))
	ring.size = Vector2(1800, 1300)
	await wait_process_frames(4)
	var minimum: Vector2 = ring.get_combined_minimum_size()
	var old_size: Vector2 = seats[1].custom_minimum_size
	seats[1].custom_minimum_size += Vector2(100, 80)
	await wait_process_frames(4)
	assert_gt(ring.get_combined_minimum_size().x, minimum.x)
	seats[1].custom_minimum_size = old_size
	await wait_process_frames(4)
	assert_eq(ring.get_combined_minimum_size(), minimum)
	ring.theme = GuiTypography.Compact
	await wait_process_frames(4)
	var compact: Vector2 = ring.get_combined_minimum_size()
	assert_lt(compact.x, minimum.x)
	ring.theme = Palette
	await wait_process_frames(4)
	assert_eq(ring.get_combined_minimum_size(), minimum)
	var new_seats: Dictionary[int, Control] = _dummy_seats(ring, 6)
	assert_true(ring.bind(new_seats, 5, center))
	await wait_process_frames(4)
	assert_eq(ring.get_layout_plan().seats.size(), 6)
	for seat: Control in seats.values():
		assert_false(seat.visible)
	_assert_actual(ring, new_seats, center, null, ring.get_layout_plan())


func test_invalid_binding_and_freed_children_fail_closed_without_partial_geometry() -> void:
	var ring: GuiSeatRingContainer = RingScene.instantiate()
	_root.add_child(ring)
	var seats: Dictionary[int, Control] = _dummy_seats(ring, 3)
	var center: Control = _region(ring, Vector2(200, 90))
	assert_true(ring.bind(seats, 0, center))
	ring.size = Vector2(1200, 900)
	await wait_process_frames(4)
	assert_false(ring.bind(seats, 0, seats[1]))
	assert_push_error_count(1)
	await wait_process_frames(4)
	assert_false(ring.get_layout_plan().valid)
	assert_true(ring.get_layout_plan().seats.is_empty())
	assert_true(ring.bind(seats, 0, center))
	seats[2].free()
	ring.queue_sort()
	await wait_process_frames(4)
	assert_false(ring.get_layout_plan().valid)
	assert_true((ring.get_node("Guidance") as Control).visible)
	assert_false(ring.set_allocation_limit(Vector2(NAN, 200)))
	assert_push_error_count(2)


func test_a_reparented_bound_child_is_not_laid_out_by_its_previous_owner() -> void:
	var ring: GuiSeatRingContainer = RingScene.instantiate()
	_root.add_child(ring)
	var seats: Dictionary[int, Control] = _dummy_seats(ring, 3)
	var center: Control = _region(ring, Vector2(200, 90))
	assert_true(ring.bind(seats, 0, center))
	ring.size = Vector2(1200, 900)
	await wait_process_frames(3)
	seats[1].reparent(_root)
	seats[1].position = Vector2(17, 19)
	ring.queue_sort()
	await wait_process_frames(3)
	assert_false(ring.get_layout_plan().valid)
	assert_eq(seats[1].position, Vector2(17, 19))
	assert_true((ring.get_node("Guidance") as Control).visible)
	assert_false(seats[0].visible)
	assert_false(seats[2].visible)
	var replacement: Dictionary[int, Control] = _dummy_seats(ring, 2)
	assert_true(ring.bind(replacement, 0, center))
	await wait_process_frames(3)
	assert_true(seats[1].visible, "A reparented node belongs to its new owner")


func test_complete_seat_and_board_components_fit_and_survive_removal_reentry() -> void:
	for density: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		var ring: GuiSeatRingContainer = RingScene.instantiate()
		ring.theme = density
		var seats: Dictionary[int, Control] = {}
		for id: int in range(8, -1, -1):
			var seat: GuiSeatPanel = (HeroScene if id == 4 else SeatScene).instantiate()
			ring.add_child(seat)
			var seat_model: SeatViewModel = _seat_model(id)
			if id != 4:
				seat_model.stack_text = "9000000 chips"
				seat_model.stack_value_text = "9000000"
			seat.render(seat_model)
			seats[id] = seat
		var board: GuiCenterBoard = BoardScene.instantiate()
		ring.add_child(board)
		var model := CenterViewModel.new()
		model.valid = true
		model.phone_pot_text = "Pot 9000000"
		model.pot_text = "Pot 9000000"
		model.board = CardRowViewModel.new()
		for rank: int in [10, 11, 12, 13, 14]:
			model.board.cards.append(CardViewModel.face(CardData.new(rank, CardData.Suit.SPADES)))
		board.render(model)
		var lower: Control = _region(ring, Vector2(500, 64))
		assert_true(ring.bind(seats, 4, board, lower))
		_root.add_child(ring)
		await wait_process_frames(8)
		ring.size = ring.get_combined_minimum_size()
		await wait_process_frames(8)
		_assert_actual(ring, seats, board, lower, ring.get_layout_plan())
		var top: PackedInt32Array = ring.get_layout_plan().rows[0]
		var left: Control = seats[top[0]]
		var right: Control = seats[top[1]]
		var avatar_width: float = left.get_theme_constant("avatar_size", &"SeatPanel")
		assert_gte(right.position.x - left.get_rect().end.x, avatar_width)
		_root.remove_child(ring)
		_root.add_child(ring)
		await wait_process_frames(4)
		_assert_actual(ring, seats, board, lower, ring.get_layout_plan())
		for id: int in seats:
			var snapshot: GuiSeatSnapshot = (seats[id] as GuiSeatPanel).get_seat_snapshot(_root)
			assert_true(snapshot.footprint.encloses(snapshot.status.rect))
			assert_eq(snapshot.seat_id, id)
			assert_eq(snapshot.fields[&"name"].text, "You" if id == 4 else "Emiliano")
			if id != 4:
				assert_eq(snapshot.fields[&"stack"].text, "9000000")
			var style: StyleBox = (seats[id].get_node("Panel") as Control).get_theme_stylebox(
				"panel"
			)
			var pair: Rect2 = snapshot.fields[&"cards"].rect
			var avatar: Rect2 = snapshot.fields[&"avatar"].rect
			assert_almost_eq(
				pair.end.x, snapshot.panel.rect.end.x - style.get_margin(SIDE_RIGHT), 0.5
			)
			assert_almost_eq(
				pair.end.y, snapshot.panel.rect.end.y - style.get_margin(SIDE_BOTTOM), 0.5
			)
			assert_almost_eq(
				avatar.position.x, snapshot.panel.rect.position.x + style.get_margin(SIDE_LEFT), 0.5
			)
			assert_almost_eq(
				avatar.position.y, snapshot.panel.rect.position.y + style.get_margin(SIDE_TOP), 0.5
			)
		ring.free()


func test_lower_actions_follow_the_dropped_human_seat_at_multiple_allocations() -> void:
	var ring: GuiSeatRingContainer = RingScene.instantiate()
	_root.add_child(ring)
	ring.position = Vector2(23, 31)
	var seats: Dictionary[int, Control] = {}
	for id: int in 6:
		var seat: GuiSeatPanel = (HeroScene if id == 4 else SeatScene).instantiate()
		ring.add_child(seat)
		seat.render(_seat_model(id))
		seats[id] = seat
	var center: Control = _region(ring, Vector2(240, 120))
	var actions: GuiActionBar = ActionScene.instantiate()
	actions.custom_minimum_size.x = 600.0
	ring.add_child(actions)
	var model := ActionBarViewModel.new()
	model.valid = true
	model.status_text = (
		"Your turn — Flop. Choose an action after reviewing "
		+ "the community cards and the amount required to call."
	)
	for role: String in ["fold", "check_call", "minimum", "pot", "wager", "all_in"]:
		model.set(role + "_visible", true)
		model.set(role + "_enabled", true)
	model.check_call_text = "Call 9000000"
	model.minimum_text = "Min Raise 9000000"
	model.pot_text = "Pot 9000000"
	model.wager_text = "Raise"
	model.all_in_text = "All In"
	actions.render(model)
	assert_true(ring.set_allocation_limit(Vector2(220, 180)))
	assert_true(ring.bind(seats, 4, center, actions))
	await wait_process_frames(12)
	var minimum: Vector2 = ring.get_combined_minimum_size()
	assert_false(ring.get_layout_plan().feasible)
	assert_true(ring.set_allocation_limit(Vector2.ZERO))
	await wait_process_frames(12)
	assert_eq(
		ring.get_combined_minimum_size(),
		minimum,
		"Measure aligned status before first feasible layout"
	)
	for allocation: Vector2 in [minimum, minimum + Vector2(300, 120), minimum]:
		ring.size = allocation
		await wait_process_frames(10)
		var plan: GuiSeatRingPlan = ring.get_layout_plan()
		_assert_actual(ring, seats, center, actions, plan)
		assert_almost_eq(
			actions.get_control(&"status").global_position.x, seats[4].global_position.x, 0.5
		)
		assert_almost_eq(
			actions.get_global_rect().get_center().x, seats[4].get_global_rect().get_center().x, 0.1
		)
		for id: int in plan.rows[-1]:
			if id != 4:
				assert_almost_eq(plan.seats[4].end.y - plan.seats[id].end.y, 72.0, 0.1)
		assert_gte(actions.global_position.y, seats[4].get_global_rect().end.y)


func _dummy_seats(ring: Control, count: int) -> Dictionary[int, Control]:
	var result: Dictionary[int, Control] = {}
	for id: int in range(count - 1, -1, -1):
		var seat := Label.new()
		seat.text = "Seat %d" % id
		seat.custom_minimum_size = Vector2(110 + id * 2, 64 + id * 2)
		ring.add_child(seat)
		result[id] = seat
	return result


func _region(ring: Control, minimum: Vector2) -> Control:
	var control := Control.new()
	control.custom_minimum_size = minimum
	ring.add_child(control)
	return control


func _assert_actual(
	ring: GuiSeatRingContainer,
	seats: Dictionary[int, Control],
	center: Control,
	lower: Control,
	plan: GuiSeatRingPlan
) -> void:
	assert_true(plan.feasible, plan.error)
	var rects: Array[Rect2] = []
	for id: int in seats:
		assert_true(seats[id].visible)
		assert_eq(Rect2(seats[id].position, seats[id].size), plan.seats[id])
		assert_gte(seats[id].size.x, seats[id].get_combined_minimum_size().x)
		assert_gte(seats[id].size.y, seats[id].get_combined_minimum_size().y)
		rects.append(plan.seats[id])
	assert_eq(Rect2(center.position, center.size), plan.center)
	rects.append(plan.center)
	if lower != null:
		assert_eq(Rect2(lower.position, lower.size), plan.lower)
		rects.append(plan.lower)
	for row: PackedInt32Array in plan.rows:
		assert_lte(row.size(), 3)
	for first: int in rects.size():
		assert_true(Rect2(Vector2.ZERO, ring.size).encloses(rects[first]))
		for second: int in range(first + 1, rects.size()):
			assert_false(rects[first].intersects(rects[second]))


func _seat_model(id: int) -> SeatViewModel:
	var model := SeatViewModel.new()
	model.valid = true
	model.seat = id
	model.is_hero = id == 4
	model.display_name = "You" if model.is_hero else "Emiliano"
	model.stack_text = "9000000"
	model.wager_text = "Bet 1000000"
	model.cards = CardRowViewModel.new()
	model.cards.cards = [CardViewModel.back(), CardViewModel.back()]
	model.status_text = "Raise to 1000000"
	return model
