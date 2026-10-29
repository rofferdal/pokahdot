extends GutTest

const Portrait := preload("res://scenes/gui/layouts/PhoneTableLayout.tscn")
const Landscape := preload("res://scenes/gui/layouts/PhoneLandscapeLayout.tscn")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const Palette := preload("res://resources/gui_theme.tres")


func test_symmetric_plans_cover_every_recipient_at_exact_minimum_and_recover_after_growth() -> void:
	for count: int in range(2, 8):
		for hero: int in count:
			for actions: Vector2 in [Vector2(225, 132), Vector2(360, 280)]:
				var ids := PackedInt32Array()
				var minima: Dictionary[int, Vector2] = {}
				for id: int in count:
					ids.append(id)
					minima[id] = Vector2(159 + id % 3 * 5, 155 + id % 2 * 7)
				var unallocated: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan.resolve(
					ids, hero, minima, Vector2(236, 215), actions, Vector2.ZERO
				)
				assert_true(unallocated.valid)
				assert_false(unallocated.feasible)
				for allocation: Vector2 in [
					unallocated.minimum, unallocated.minimum * 2.0, unallocated.minimum
				]:
					var plan: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan.resolve(
						ids, hero, minima, Vector2(236, 215), actions, allocation
					)
					assert_true(plan.feasible)
					assert_eq(plan.minimum, unallocated.minimum)
					_assert_plan(plan, hero, allocation)
				for missing: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
					var failed: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan.resolve(
						ids, hero, minima, Vector2(236, 215), actions, unallocated.minimum - missing
					)
					assert_true(failed.valid)
					assert_false(failed.feasible)
					assert_true(failed.seats.is_empty())
					assert_eq(failed.center, Rect2())
					assert_eq(failed.actions, Rect2())


func test_three_seats_fit_short_landscape_with_board_between_top_corners() -> void:
	var minima: Dictionary[int, Vector2] = {
		0: Vector2(159, 155), 1: Vector2(159, 155), 2: Vector2(159, 155)
	}
	var plan: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan.resolve(
		PackedInt32Array([0, 1, 2]),
		0,
		minima,
		Vector2(236, 215),
		Vector2(225, 132),
		Vector2(844, 390)
	)
	assert_true(plan.feasible)
	assert_eq(plan.minimum, Vector2(694, 374))
	assert_eq(plan.seats[1].position, Vector2.ZERO)
	assert_eq(plan.seats[2].end.x, 844.0)
	assert_eq(plan.seats[1].position.y, plan.seats[2].position.y)
	_assert_plan(plan, 0, Vector2(844, 390))
	minima.erase(2)
	var apex: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan.resolve(
		PackedInt32Array([0, 1]), 0, minima, Vector2(236, 215), Vector2(225, 132), Vector2(844, 390)
	)
	assert_true(apex.valid)
	assert_false(apex.feasible)
	assert_eq(apex.minimum, Vector2(694, 533))


func test_native_landscape_centers_board_and_hero_and_keeps_all_regions_disjoint() -> void:
	var root := Control.new()
	root.size = Vector2(3000, 2500)
	root.theme = Palette
	add_child_autofree(root)
	var layout: GuiPhoneTableLayout = Landscape.instantiate()
	layout.theme = GuiTypography.Compact
	root.add_child(layout)
	layout.size = Vector2(844, 390)
	layout.set_allocation_limit(Vector2(844, 390))
	assert_true(layout.render(_model(3)))
	await wait_process_frames(14)
	var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(root)
	assert_true(snapshot.ready)
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	var container := layout.get_control(&"landscape") as GuiPhoneLandscapeContainer
	var plan: GuiPhoneLandscapePlan = container.get_layout_plan()
	_assert_plan(plan, 0, Vector2(844, 390))
	assert_almost_eq(snapshot.seats[0].footprint.get_center().x, 422.0, 0.5)
	assert_almost_eq(snapshot.elements[&"center"].rect.get_center().x, 422.0, 0.5)
	assert_eq(snapshot.seats[1].footprint.position.x, 0.0)
	assert_eq(snapshot.seats[2].footprint.end.x, 844.0)
	assert_almost_eq(
		snapshot.seats[0].footprint.size.x - snapshot.seats[1].footprint.size.x, 8.0, 0.5
	)


func test_portrait_hero_is_centered_and_only_two_gaps_wider_than_allocated_bot_cells() -> void:
	var root := Control.new()
	root.size = Vector2(1600, 1500)
	root.theme = Palette
	add_child_autofree(root)
	var layout: GuiPhoneTableLayout = Portrait.instantiate()
	layout.theme = GuiTypography.Compact
	root.add_child(layout)
	layout.size = Vector2(480, 1000)
	layout.set_allocation_limit(Vector2(480, 1000))
	var model: TableViewModel = _model(4)
	for seat: SeatViewModel in model.seats:
		seat.stack_value_text = "9000000"
		seat.wager_text = "Bet 1000000"
	assert_true(layout.render(model))
	await wait_process_frames(14)
	var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(root)
	assert_true(snapshot.ready)
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	var hero: GuiSeatSnapshot = snapshot.seats[0]
	assert_almost_eq(hero.footprint.get_center().x, 240.0, 0.5)
	assert_almost_eq(hero.footprint.size.x - snapshot.seats[1].footprint.size.x, 8.0, 0.5)
	assert_lt(hero.footprint.size.x, 300.0)
	assert_almost_eq(
		snapshot.elements[&"action/status"].rect.position.x, hero.panel.rect.position.x, 1.0
	)


func test_one_column_portrait_recovers_at_minimum_and_never_overflows_reserved_hero_width() -> void:
	var root := Control.new()
	root.size = Vector2(3000, 2500)
	root.theme = Palette
	add_child_autofree(root)
	var layout: GuiPhoneTableLayout = Portrait.instantiate()
	layout.theme = GuiTypography.Compact
	root.add_child(layout)
	layout.size = Vector2(300, 1400)
	layout.set_allocation_limit(Vector2(300, 1400))
	assert_true(layout.render(_model(3)))
	await wait_process_frames(14)
	var minimum: Vector2 = layout.get_combined_minimum_size()
	for allocation: Vector2 in [minimum, Vector2(1000, 1600), Vector2(300, 1400), minimum]:
		layout.size = allocation
		layout.set_allocation_limit(allocation)
		await wait_process_frames(14)
		var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(root)
		assert_true(snapshot.ready)
		assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
		assert_almost_eq(snapshot.seats[0].footprint.get_center().x, allocation.x * 0.5, 0.5)
		assert_almost_eq(
			snapshot.seats[0].footprint.size.x - snapshot.seats[1].footprint.size.x, 8.0, 0.5
		)
		if allocation.x <= 300:
			assert_eq(layout.get_combined_minimum_size(), minimum)

	var wide_seats: Dictionary[int, Vector2] = {
		0: Vector2(159, 155), 1: Vector2(500, 155), 2: Vector2(500, 155)
	}
	var narrow: GuiPhoneTablePlan = GuiPhoneTablePlan.resolve(
		PackedInt32Array([0, 1, 2]),
		0,
		wide_seats,
		Vector2(236, 215),
		Vector2(225, 132),
		false,
		Vector2(508, 1400)
	)
	assert_true(narrow.feasible)
	assert_eq(narrow.columns, 1)
	assert_eq(narrow.minimum.x, 508.0)


func test_landscape_three_seats_fit_representative_safe_area_without_reducing_copy() -> void:
	var root := Control.new()
	root.size = Vector2(3000, 2500)
	root.theme = Palette
	add_child_autofree(root)
	var layout: GuiPhoneTableLayout = Landscape.instantiate()
	layout.theme = GuiTypography.Compact
	root.add_child(layout)
	layout.size = Vector2(756, 369)
	layout.set_allocation_limit(Vector2(756, 369))
	assert_true(layout.render(_model(3)))
	await wait_process_frames(14)
	var minimum: Vector2 = layout.get_combined_minimum_size()
	assert_eq(minimum, Vector2(694, 368))
	for allocation: Vector2 in [Vector2(756, 369), minimum, minimum - Vector2(0, 1), minimum]:
		layout.size = allocation
		layout.set_allocation_limit(allocation)
		await wait_process_frames(14)
		var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(root)
		assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
		assert_eq(snapshot.ready, allocation.y >= minimum.y)
		if snapshot.ready:
			_assert_plan(
				(layout.get_control(&"landscape") as GuiPhoneLandscapeContainer).get_layout_plan(),
				0,
				allocation
			)


func test_landscape_binding_fails_closed_when_region_parent_changes_before_native_sort() -> void:
	var root := Control.new()
	root.theme = Palette
	add_child_autofree(root)
	for role: StringName in [&"center", &"actions"]:
		var layout: GuiPhoneTableLayout = Landscape.instantiate()
		root.add_child(layout)
		layout.size = Vector2(2000, 1400)
		assert_true(layout.render(_model(3)))
		await wait_process_frames(14)
		var container := layout.get_control(&"landscape") as GuiPhoneLandscapeContainer
		assert_true(container.get_layout_plan().valid)
		var control: Control = layout.get_control(role)
		control.reparent(root, false)
		container.queue_sort()
		assert_false(container.get_layout_plan().valid)
		await wait_process_frames(2)
		assert_false(container.get_layout_plan().feasible)
		layout.free()
		control.free()


func test_invalid_inputs_publish_no_partial_landscape_geometry() -> void:
	var ids := PackedInt32Array([0, 1])
	var minima: Dictionary[int, Vector2] = {0: Vector2(159, 155), 1: Vector2(159, 155)}
	for invalid: Vector2 in [Vector2.ZERO, Vector2(-1, 1), Vector2(NAN, 1), Vector2(1, INF)]:
		var plan: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan.resolve(
			ids, 0, minima, invalid, Vector2(225, 132), Vector2(844, 390)
		)
		assert_false(plan.valid)
		assert_true(plan.seats.is_empty())
	for invalid: float in [-1.0, NAN, INF]:
		assert_false(
			(
				GuiPhoneLandscapePlan
				. resolve(
					ids, 0, minima, Vector2(236, 215), Vector2(225, 132), Vector2(844, 390), invalid
				)
				. valid
			)
		)


func _assert_plan(plan: GuiPhoneLandscapePlan, hero: int, available: Vector2) -> void:
	assert_true(plan.valid)
	assert_true(plan.feasible)
	var hero_rect: Rect2 = plan.seats[hero]
	assert_almost_eq(hero_rect.get_center().x, available.x * 0.5, 0.001)
	assert_eq(hero_rect.end.y, available.y)
	assert_almost_eq(plan.center.get_center().x, available.x * 0.5, 0.001)
	assert_eq(plan.center.end.y + 4.0, hero_rect.position.y)
	assert_gte(plan.actions.position.x, maxf(plan.center.end.x, hero_rect.end.x) + 4.0)
	assert_eq(plan.actions.end.y, available.y)
	var rectangles: Array[Rect2] = [plan.center, plan.actions]
	for id: int in plan.seats:
		rectangles.append(plan.seats[id])
	for index: int in rectangles.size():
		assert_true(Rect2(Vector2.ZERO, available).encloses(rectangles[index]))
		for other: int in range(index + 1, rectangles.size()):
			assert_false(rectangles[index].intersects(rectangles[other]))
	for row: PackedInt32Array in plan.rows:
		if row.has(hero):
			continue
		if row.size() == 1:
			assert_almost_eq(plan.seats[row[0]].get_center().x, available.x * 0.5, 0.001)
		else:
			var first: Rect2 = plan.seats[row[0]]
			var second: Rect2 = plan.seats[row[1]]
			assert_eq(first.size, second.size)
			assert_eq(first.position.y, second.position.y)
			assert_eq(first.position.x, 0.0)
			assert_eq(second.end.x, available.x)


func _model(count: int) -> TableViewModel:
	var fixture: Dictionary = GuiVisualStateFixtures.by_id(&"human-turn-flop", 9)
	var names: Dictionary[int, String] = {0: "You", 1: "Emiliano", 2: "Leilani", 3: "Matteo"}
	var latest: Dictionary[int, PublicActionRecord] = {}
	for action: PublicActionRecord in (fixture.view as GameView).action_history:
		latest[action.seat] = action
	var model: TableViewModel = TableViewModel.build(
		fixture.view, names, {}, latest, {}, [], GuiFitCandidate.Density.COMPACT
	)
	model.seats.resize(count)
	return model
