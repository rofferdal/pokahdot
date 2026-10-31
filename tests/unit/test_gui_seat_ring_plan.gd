extends GutTest

const Template := preload("res://scripts/gui/layout/gui_seat_slot_template.gd")
const Plan := preload("res://scripts/gui/layout/gui_seat_ring_plan.gd")
const CENTER := Vector2(220, 110)
const LOWER := Vector2(380, 54)


func test_authored_templates_have_explicit_capped_rows_and_bottom_center_hero() -> void:
	var populations: Dictionary[int, PackedInt32Array] = {
		2: PackedInt32Array([1, 1]),
		3: PackedInt32Array([2, 1]),
		4: PackedInt32Array([1, 2, 1]),
		5: PackedInt32Array([2, 2, 1]),
		6: PackedInt32Array([1, 2, 2, 1]),
		7: PackedInt32Array([2, 2, 2, 1]),
		8: PackedInt32Array([1, 2, 2, 2, 1]),
		9: PackedInt32Array([2, 2, 2, 2, 1])
	}
	for count: int in range(2, 10):
		var template: GuiSeatSlotTemplate = Template.load_for_count(count)
		assert_not_null(template)
		assert_eq(template.validation_error(), "")
		assert_eq(template.seat_count, count)
		assert_eq(template.slots.size(), count)
		var plan: GuiSeatRingPlan = Plan.resolve(
			_minima(count, 0), 0, template, CENTER, LOWER, Vector2.ZERO
		)
		var actual := PackedInt32Array()
		for row: PackedInt32Array in plan.rows:
			actual.append(row.size())
		assert_eq(actual, populations[count], str(count))
		assert_eq(plan.rows[-1][floori(plan.rows[-1].size() / 2.0)], 0)
	assert_null(Template.load_for_count(1))
	assert_null(Template.load_for_count(10))


func test_clockwise_seat_order_is_independent_of_dictionary_insertion_order_and_recipient() -> void:
	for count: int in range(2, 10):
		var template: GuiSeatSlotTemplate = Template.load_for_count(count)
		for hero: int in count:
			var forward: Dictionary[int, Vector2] = _minima(count, hero)
			var backward: Dictionary[int, Vector2] = {}
			for id: int in range(count - 1, -1, -1):
				backward[id] = forward[id]
			var first: GuiSeatRingPlan = Plan.resolve(
				forward, hero, template, CENTER, LOWER, Vector2.ZERO
			)
			var second: GuiSeatRingPlan = Plan.resolve(
				backward, hero, template, CENTER, LOWER, first.minimum
			)
			assert_true(first.valid)
			assert_true(second.feasible)
			assert_eq(first.minimum, second.minimum)
			assert_eq(first.visual_slots, second.visual_slots)
			assert_eq(first.rows, second.rows)
			for offset: int in count:
				assert_eq(
					second.visual_slots[(hero + offset) % count],
					posmod(floori(count / 2.0) + offset, count)
				)
			_assert_geometry(second, backward, second.minimum, 0.0, 0.0)
	var six: GuiSeatRingPlan = Plan.resolve(
		_minima(6, 0), 0, Template.load_for_count(6), CENTER, LOWER, Vector2.ZERO
	)
	assert_eq(
		six.rows,
		[
			PackedInt32Array([3]),
			PackedInt32Array([2, 4]),
			PackedInt32Array([1, 5]),
			PackedInt32Array([0])
		]
	)
	var nine: GuiSeatRingPlan = Plan.resolve(
		_minima(9, 0), 0, Template.load_for_count(9), CENTER, LOWER, Vector2.ZERO
	)
	assert_eq(
		nine.rows,
		[
			PackedInt32Array([4, 5]),
			PackedInt32Array([3, 6]),
			PackedInt32Array([2, 7]),
			PackedInt32Array([1, 8]),
			PackedInt32Array([0])
		]
	)


func test_top_pairs_use_the_outer_columns_and_keep_themed_clearance() -> void:
	for count: int in [3, 5, 7, 9]:
		for hero: int in count:
			for gap: float in [0.0, 8.0, 16.0]:
				var minima: Dictionary[int, Vector2] = _minima(count, hero)
				var template: GuiSeatSlotTemplate = Template.load_for_count(count)
				var probe: GuiSeatRingPlan = Plan.resolve(
					minima,
					hero,
					template,
					CENTER,
					LOWER,
					Vector2.ZERO,
					gap,
					Vector2(8, 8),
					36,
					4,
					72
				)
				var allocation: Vector2 = probe.minimum + Vector2(200, 100)
				var plan: GuiSeatRingPlan = Plan.resolve(
					minima, hero, template, CENTER, LOWER, allocation, gap, Vector2(8, 8), 36, 4, 72
				)
				var grown: GuiSeatRingPlan = Plan.resolve(
					minima,
					hero,
					template,
					CENTER,
					LOWER,
					allocation + Vector2(300, 0),
					gap,
					Vector2(8, 8),
					36,
					4,
					72
				)
				assert_eq(plan.rows, probe.rows)
				assert_eq(plan.visual_slots, probe.visual_slots)
				assert_eq(plan.minimum, probe.minimum)
				assert_eq(plan.rows[0].size(), 2)
				var left: Rect2 = plan.seats[plan.rows[0][0]]
				var right: Rect2 = plan.seats[plan.rows[0][1]]
				assert_gte(right.position.x - left.end.x, gap)
				assert_almost_eq(left.merge(right).get_center().x, allocation.x * 0.5, 0.001)
				assert_eq(left.position.x, 22.0)
				assert_eq(right.end.x, allocation.x - 22.0)
				for id: int in minima:
					var slot: Vector2i = template.slots[plan.visual_slots[id]]
					var expected_shift: float = slot.x * 150.0
					assert_almost_eq(
						grown.seats[id].position.x - plan.seats[id].position.x,
						expected_shift,
						0.001
					)
					assert_eq(grown.seats[id].position.y, plan.seats[id].position.y)
				_assert_geometry(plan, minima, allocation, 36, 4)
				_assert_geometry(grown, minima, allocation + Vector2(300, 0), 36, 4)


func test_apex_clearance_remains_a_minimum_when_pairs_move_to_outer_columns() -> void:
	for count: int in [3, 5, 7, 9]:
		for hero: int in count:
			for apex: float in [64.0, 96.0]:
				for gap: float in [8.0, 128.0]:
					var minima: Dictionary[int, Vector2] = _minima(count, hero)
					var template: GuiSeatSlotTemplate = Template.load_for_count(count)
					var probe: GuiSeatRingPlan = Plan.resolve(
						minima,
						hero,
						template,
						CENTER,
						LOWER,
						Vector2.ZERO,
						gap,
						Vector2(8, 8),
						36,
						4,
						72,
						apex
					)
					assert_true(probe.valid)
					assert_false(probe.feasible)
					for growth: Vector2 in [Vector2.ZERO, Vector2(250, 120)]:
						var allocation: Vector2 = probe.minimum + growth
						var plan: GuiSeatRingPlan = Plan.resolve(
							minima,
							hero,
							template,
							CENTER,
							LOWER,
							allocation,
							gap,
							Vector2(8, 8),
							36,
							4,
							72,
							apex
						)
						assert_true(plan.feasible)
						assert_eq(plan.minimum, probe.minimum)
						assert_eq(plan.rows, probe.rows)
						var left: Rect2 = plan.seats[plan.rows[0][0]]
						var right: Rect2 = plan.seats[plan.rows[0][1]]
						assert_gte(right.position.x - left.end.x, maxf(gap, apex))
						assert_gte(right.position.x - left.end.x, apex)
						assert_almost_eq(
							left.merge(right).get_center().x, allocation.x * 0.5, 0.001
						)
						_assert_geometry(plan, minima, allocation, 36, 4)
					for delta: Vector2 in [Vector2(-1, 0), Vector2(0, -1)]:
						var short: GuiSeatRingPlan = Plan.resolve(
							minima,
							hero,
							template,
							CENTER,
							LOWER,
							probe.minimum + delta,
							gap,
							Vector2(8, 8),
							36,
							4,
							72,
							apex
						)
						assert_true(short.valid)
						assert_false(short.feasible)
						assert_true(short.seats.is_empty())


func test_apex_gap_controls_three_seat_minimum_and_preserves_equal_width_mirrors() -> void:
	for apex: float in [64.0, 96.0]:
		var minima: Dictionary[int, Vector2] = {
			0: Vector2(100, 70), 1: Vector2(100, 80), 2: Vector2(100, 70)
		}
		var template: GuiSeatSlotTemplate = Template.load_for_count(3)
		var probe: GuiSeatRingPlan = Plan.resolve(
			minima,
			1,
			template,
			Vector2(60, 60),
			Vector2.ZERO,
			Vector2.ZERO,
			8,
			Vector2.ZERO,
			0,
			0,
			72,
			apex
		)
		assert_eq(probe.minimum.x, 200.0 + apex, "The apex pair determines this exact boundary")
		var plan: GuiSeatRingPlan = Plan.resolve(
			minima,
			1,
			template,
			Vector2(60, 60),
			Vector2.ZERO,
			probe.minimum,
			8,
			Vector2.ZERO,
			0,
			0,
			72,
			apex
		)
		var left: Rect2 = plan.seats[plan.rows[0][0]]
		var right: Rect2 = plan.seats[plan.rows[0][1]]
		assert_almost_eq(left.position.x, probe.minimum.x - right.end.x, 0.001)
		assert_eq(left.position.y, right.position.y)
		_assert_geometry(plan, minima, probe.minimum, 0, 0)
	var minima: Dictionary[int, Vector2] = _minima(5, 0)
	for invalid: float in [-1.0, NAN, INF, 1.0e308]:
		_assert_invalid(
			Plan.resolve(
				minima,
				0,
				Template.load_for_count(5),
				CENTER,
				LOWER,
				Vector2.ZERO,
				8,
				Vector2.ZERO,
				0,
				0,
				0,
				invalid
			)
		)


func test_hero_drop_reserves_space_without_changing_rows_or_moving_bots_at_new_minimum() -> void:
	var drop: float = 48.0
	for count: int in range(2, 10):
		for hero: int in count:
			for footer: Vector2 in [Vector2.ZERO, LOWER]:
				var minima: Dictionary[int, Vector2] = _minima(count, hero)
				var template: GuiSeatSlotTemplate = Template.load_for_count(count)
				var base: GuiSeatRingPlan = Plan.resolve(
					minima, hero, template, CENTER, footer, Vector2.ZERO, 8, Vector2.ZERO, 36, 4
				)
				var probe: GuiSeatRingPlan = Plan.resolve(
					minima,
					hero,
					template,
					CENTER,
					footer,
					Vector2.ZERO,
					8,
					Vector2.ZERO,
					36,
					4,
					drop
				)
				assert_true(probe.valid)
				assert_false(probe.feasible)
				assert_eq(probe.minimum, base.minimum + Vector2(0, drop))
				assert_eq(probe.rows, base.rows)
				assert_eq(probe.visual_slots, base.visual_slots)
				var old: GuiSeatRingPlan = Plan.resolve(
					minima, hero, template, CENTER, footer, base.minimum, 8, Vector2.ZERO, 36, 4
				)
				var moved: GuiSeatRingPlan = Plan.resolve(
					minima,
					hero,
					template,
					CENTER,
					footer,
					probe.minimum,
					8,
					Vector2.ZERO,
					36,
					4,
					drop
				)
				assert_true(moved.feasible)
				assert_eq(moved.center, old.center)
				for id: int in minima:
					assert_eq(moved.seats[id].size, old.seats[id].size)
					assert_eq(
						moved.seats[id].position,
						old.seats[id].position + Vector2(0, drop if id == hero else 0.0)
					)
				if footer != Vector2.ZERO:
					assert_eq(moved.lower.position, old.lower.position + Vector2(0, drop))
					assert_eq(moved.lower.size, old.lower.size)
				else:
					assert_eq(moved.lower, Rect2())
				_assert_geometry(moved, minima, probe.minimum, 36, 4)
				for delta: Vector2 in [Vector2(-1, 0), Vector2(0, -1)]:
					var short: GuiSeatRingPlan = Plan.resolve(
						minima,
						hero,
						template,
						CENTER,
						footer,
						probe.minimum + delta,
						8,
						Vector2.ZERO,
						36,
						4,
						drop
					)
					assert_true(short.valid)
					assert_false(short.feasible)
					assert_true(short.seats.is_empty())


func test_hero_drop_keeps_hero_and_footer_bottom_anchored_at_a_fixed_allocation() -> void:
	for count: int in range(4, 10):
		var minima: Dictionary[int, Vector2] = _minima(count, 0)
		var template: GuiSeatSlotTemplate = Template.load_for_count(count)
		var probe: GuiSeatRingPlan = Plan.resolve(
			minima, 0, template, CENTER, LOWER, Vector2.ZERO, 8, Vector2.ZERO, 36, 4, 48
		)
		var fixed: Vector2 = probe.minimum + Vector2(120, 160)
		var base: GuiSeatRingPlan = Plan.resolve(
			minima, 0, template, CENTER, LOWER, fixed, 8, Vector2.ZERO, 36, 4
		)
		var moved: GuiSeatRingPlan = Plan.resolve(
			minima, 0, template, CENTER, LOWER, fixed, 8, Vector2.ZERO, 36, 4, 48
		)
		assert_eq(moved.seats[0], base.seats[0])
		assert_eq(moved.lower, base.lower)
		for id: int in moved.rows[-1]:
			if id != 0:
				assert_eq(moved.seats[id].position, base.seats[id].position - Vector2(0, 48))
		_assert_geometry(moved, minima, fixed, 36, 4)


func test_hero_drop_validation_and_radius_dominated_minimum_are_explicit() -> void:
	var minima: Dictionary[int, Vector2] = _minima(2, 0)
	var template: GuiSeatSlotTemplate = Template.load_for_count(2)
	for invalid: float in [-1.0, NAN, INF]:
		_assert_invalid(
			Plan.resolve(
				minima, 0, template, CENTER, LOWER, Vector2.ZERO, 8, Vector2.ZERO, 0, 0, invalid
			)
		)
	var base: GuiSeatRingPlan = Plan.resolve(
		minima, 0, template, CENTER, LOWER, Vector2.ZERO, 8, Vector2.ZERO, 1000, 4
	)
	var moved: GuiSeatRingPlan = Plan.resolve(
		minima, 0, template, CENTER, LOWER, Vector2.ZERO, 8, Vector2.ZERO, 1000, 4, 48
	)
	assert_eq(moved.minimum, base.minimum + Vector2(0, 48))
	var placed: GuiSeatRingPlan = Plan.resolve(
		minima, 0, template, CENTER, LOWER, moved.minimum, 8, Vector2.ZERO, 1000, 4, 48
	)
	_assert_geometry(placed, minima, moved.minimum, 1000, 4)


func test_nonconsecutive_nonnegative_seat_ids_use_sorted_clockwise_rank() -> void:
	var minima: Dictionary[int, Vector2] = {
		100: Vector2(140, 76),
		3: Vector2(120, 78),
		105: Vector2(125, 80),
		20: Vector2(170, 90),
		7: Vector2(130, 82)
	}
	var probe: GuiSeatRingPlan = Plan.resolve(
		minima, 20, Template.load_for_count(5), CENTER, LOWER, Vector2.ZERO
	)
	var plan: GuiSeatRingPlan = Plan.resolve(
		minima, 20, Template.load_for_count(5), CENTER, LOWER, probe.minimum
	)
	assert_true(plan.feasible)
	assert_eq(
		plan.rows, [PackedInt32Array([105, 3]), PackedInt32Array([100, 7]), PackedInt32Array([20])]
	)
	assert_eq(plan.visual_slots, {3: 0, 7: 1, 20: 2, 100: 3, 105: 4})
	_assert_geometry(plan, minima, plan.minimum, 0.0, 0.0)


func test_measured_boundary_and_growth_preserve_full_footprints_reservations_and_rounded_felt(
) -> void:
	for count: int in range(2, 10):
		for hero: int in count:
			for radius: float in [0.0, 36.0, 100.0]:
				var minima: Dictionary[int, Vector2] = _minima(count, hero)
				var template: GuiSeatSlotTemplate = Template.load_for_count(count)
				var probe: GuiSeatRingPlan = Plan.resolve(
					minima, hero, template, CENTER, LOWER, Vector2.ZERO, 8, Vector2.ZERO, radius, 4
				)
				assert_true(probe.valid)
				assert_false(probe.feasible)
				assert_true(probe.seats.is_empty())
				assert_eq(probe.center, Rect2())
				assert_eq(probe.lower, Rect2())
				for delta: Vector2 in [Vector2(-1, 0), Vector2(0, -1)]:
					var small: GuiSeatRingPlan = Plan.resolve(
						minima,
						hero,
						template,
						CENTER,
						LOWER,
						probe.minimum + delta,
						8,
						Vector2.ZERO,
						radius,
						4
					)
					assert_true(small.valid)
					assert_false(small.feasible)
					assert_eq(small.error, "insufficient-space")
					assert_true(small.seats.is_empty())
					assert_eq(small.minimum, probe.minimum)
				for growth: Vector2 in [Vector2.ZERO, Vector2(1, 1), Vector2(200, 300)]:
					var allocation: Vector2 = probe.minimum + growth
					var plan: GuiSeatRingPlan = Plan.resolve(
						minima,
						hero,
						template,
						CENTER,
						LOWER,
						allocation,
						8,
						Vector2.ZERO,
						radius,
						4
					)
					assert_true(plan.valid)
					assert_true(plan.feasible)
					assert_eq(plan.minimum, probe.minimum)
					assert_eq(plan.center.size, CENTER)
					assert_eq(plan.lower.size, LOWER)
					_assert_geometry(plan, minima, allocation, radius, 4)


func test_equal_opponent_footprints_have_exact_mirrors_and_hero_is_bottom_center() -> void:
	for count: int in range(2, 10):
		var minima: Dictionary[int, Vector2] = {}
		for id: int in count:
			minima[id] = Vector2(120, 70) if id != 0 else Vector2(180, 95)
		var template: GuiSeatSlotTemplate = Template.load_for_count(count)
		var probe: GuiSeatRingPlan = Plan.resolve(
			minima, 0, template, CENTER, Vector2.ZERO, Vector2.ZERO
		)
		var available: Vector2 = probe.minimum + Vector2(180, 300)
		var plan: GuiSeatRingPlan = Plan.resolve(
			minima, 0, template, CENTER, Vector2.ZERO, available
		)
		assert_eq(plan.lower, Rect2())
		var bottom: Rect2 = plan.seats[0]
		assert_almost_eq(bottom.get_center().x, available.x * 0.5, 0.001)
		for id: int in count:
			var reflected: int = posmod(-id, count)
			var first: Rect2 = plan.seats[id]
			var second: Rect2 = plan.seats[reflected]
			assert_almost_eq(first.position.x, available.x - second.end.x, 0.001)
			assert_eq(first.position.y, second.position.y)
			assert_lte(first.end.y, bottom.end.y)
		_assert_geometry(plan, minima, available, 0.0, 0.0)


func test_optional_lower_region_and_large_content_have_truthful_minimums() -> void:
	var minima: Dictionary[int, Vector2] = _minima(9, 0)
	minima[4] = Vector2(700, 280)
	var template: GuiSeatSlotTemplate = Template.load_for_count(9)
	var no_lower: GuiSeatRingPlan = Plan.resolve(
		minima, 0, template, CENTER, Vector2.ZERO, Vector2.ZERO
	)
	var lower: GuiSeatRingPlan = Plan.resolve(minima, 0, template, CENTER, LOWER, Vector2.ZERO)
	assert_eq(lower.minimum.y - no_lower.minimum.y, LOWER.y + 8.0)
	assert_gte(no_lower.minimum.x, 1400.0 + CENTER.x + 16.0)
	var plan: GuiSeatRingPlan = Plan.resolve(minima, 0, template, CENTER, LOWER, lower.minimum)
	_assert_geometry(plan, minima, plan.minimum, 0.0, 0.0)


func test_plans_detach_identity_rows_and_rectangles_from_mutable_input_resources() -> void:
	var minima: Dictionary[int, Vector2] = _minima(5, 0)
	var template: GuiSeatSlotTemplate = Template.load_for_count(5).duplicate(true)
	var probe: GuiSeatRingPlan = Plan.resolve(minima, 0, template, CENTER, LOWER, Vector2.ZERO)
	var plan: GuiSeatRingPlan = Plan.resolve(minima, 0, template, CENTER, LOWER, probe.minimum)
	var original_rect: Rect2 = plan.seats[0]
	var original_rows: Array[PackedInt32Array] = plan.rows.duplicate()
	minima.clear()
	template.slots.clear()
	template.seat_count = 0
	assert_true(plan.valid)
	assert_true(plan.feasible)
	assert_eq(plan.seats.size(), 5)
	assert_eq(plan.seats[0], original_rect)
	assert_eq(plan.rows, original_rows)
	assert_eq(plan.visual_slots.size(), 5)


func test_invalid_schema_ids_and_metrics_fail_without_partial_geometry_or_logging() -> void:
	var minima: Dictionary[int, Vector2] = _minima(5, 0)
	var template: GuiSeatSlotTemplate = Template.load_for_count(5)
	_assert_invalid(Plan.resolve(minima, 0, null, CENTER, LOWER, Vector2.ZERO))
	_assert_invalid(Plan.resolve(minima, 100, template, CENTER, LOWER, Vector2.ZERO))
	for bad: Vector2 in [Vector2.ZERO, Vector2(-1, 1), Vector2(NAN, 1), Vector2(1, INF)]:
		_assert_invalid(Plan.resolve(minima, 0, template, bad, LOWER, Vector2.ZERO))
		var altered: Dictionary[int, Vector2] = minima.duplicate()
		altered[1] = bad
		_assert_invalid(Plan.resolve(altered, 0, template, CENTER, LOWER, Vector2.ZERO))
	for bad: Vector2 in [Vector2(0, 20), Vector2(20, 0), Vector2(-1, 1), Vector2(NAN, 1)]:
		_assert_invalid(Plan.resolve(minima, 0, template, CENTER, bad, Vector2.ZERO))
	for bad: Vector2 in [Vector2(-1, 1), Vector2(NAN, 1), Vector2(1, INF)]:
		_assert_invalid(Plan.resolve(minima, 0, template, CENTER, LOWER, bad))
		_assert_invalid(Plan.resolve(minima, 0, template, CENTER, LOWER, Vector2.ZERO, 8, bad))
	for bad: float in [-1.0, NAN, INF]:
		_assert_invalid(Plan.resolve(minima, 0, template, CENTER, LOWER, Vector2.ZERO, bad))
		_assert_invalid(
			Plan.resolve(minima, 0, template, CENTER, LOWER, Vector2.ZERO, 8, Vector2.ZERO, bad)
		)
		_assert_invalid(
			Plan.resolve(minima, 0, template, CENTER, LOWER, Vector2.ZERO, 8, Vector2.ZERO, 0, bad)
		)
	var negative: Dictionary[int, Vector2] = minima.duplicate()
	negative[-1] = negative[4]
	negative.erase(4)
	_assert_invalid(Plan.resolve(negative, 0, template, CENTER, LOWER, Vector2.ZERO))
	var unrepresentable: Dictionary[int, Vector2] = minima.duplicate()
	unrepresentable[2147483648] = unrepresentable[4]
	unrepresentable.erase(4)
	_assert_invalid(Plan.resolve(unrepresentable, 0, template, CENTER, LOWER, Vector2.ZERO))
	var malformed: GuiSeatSlotTemplate = template.duplicate(true)
	malformed.slots[0] = malformed.slots[1]
	_assert_invalid(Plan.resolve(minima, 0, malformed, CENTER, LOWER, Vector2.ZERO))
	malformed = template.duplicate(true)
	malformed.slots[0] = Vector2i(1, 0)
	_assert_invalid(Plan.resolve(minima, 0, malformed, CENTER, LOWER, Vector2.ZERO))
	malformed = template.duplicate(true)
	malformed.slots[2] = Vector2i(1, 7)
	_assert_invalid(Plan.resolve(minima, 0, malformed, CENTER, LOWER, Vector2.ZERO))
	malformed = template.duplicate(true)
	malformed.seat_count = 4
	_assert_invalid(Plan.resolve(minima, 0, malformed, CENTER, LOWER, Vector2.ZERO))
	var excessive: Dictionary[int, Vector2] = minima.duplicate()
	excessive[1] = Vector2(3.0e38, 70)
	_assert_invalid(Plan.resolve(excessive, 0, template, CENTER, LOWER, Vector2.ZERO))
	assert_push_error_count(0)


func _minima(count: int, hero: int) -> Dictionary[int, Vector2]:
	var values: Dictionary[int, Vector2] = {}
	for id: int in count:
		values[id] = Vector2(118 + (id % 3) * 16, 70 + (id % 4) * 7)
	values[hero] = Vector2(180, 95)
	return values


func _assert_invalid(plan: GuiSeatRingPlan) -> void:
	assert_false(plan.valid)
	assert_false(plan.feasible)
	assert_false(plan.error.is_empty())
	assert_eq(plan.minimum, Vector2.ZERO)
	assert_true(plan.seats.is_empty())
	assert_true(plan.rows.is_empty())
	assert_true(plan.visual_slots.is_empty())
	assert_eq(plan.center, Rect2())
	assert_eq(plan.lower, Rect2())


func _assert_geometry(
	plan: GuiSeatRingPlan,
	minima: Dictionary[int, Vector2],
	available: Vector2,
	radius: float,
	border: float
) -> void:
	assert_true(plan.feasible)
	assert_eq(plan.seats.size(), minima.size())
	var rectangles: Array[Rect2] = [plan.center]
	if plan.lower.has_area():
		rectangles.append(plan.lower)
	var seen := PackedInt32Array()
	for row: PackedInt32Array in plan.rows:
		assert_lte(row.size(), 2)
		var last_x: float = -INF
		for id: int in row:
			assert_false(id in seen)
			seen.append(id)
			var seat: Rect2 = plan.seats[id]
			assert_eq(seat.size, minima[id])
			assert_gt(seat.position.x, last_x)
			last_x = seat.position.x
			rectangles.append(seat)
	assert_eq(seen.size(), minima.size())
	for index: int in rectangles.size():
		var rect: Rect2 = rectangles[index]
		assert_true(Rect2(Vector2.ZERO, available).encloses(rect))
		for corner: Vector2 in [
			rect.position,
			rect.end,
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.end.x, rect.position.y)
		]:
			_assert_inside_round_felt(corner, available, radius, border)
		for other: int in range(index + 1, rectangles.size()):
			assert_false(
				rect.intersects(rectangles[other]), "%s overlaps %s" % [rect, rectangles[other]]
			)


func _assert_inside_round_felt(
	point: Vector2, available: Vector2, radius: float, border: float
) -> void:
	var inner_half: Vector2 = available * 0.5 - Vector2.ONE * border
	var inner_radius: float = minf(maxf(0.0, radius - border), minf(inner_half.x, inner_half.y))
	var relative: Vector2 = (point - available * 0.5).abs()
	assert_lte(relative.x, inner_half.x + 0.001)
	assert_lte(relative.y, inner_half.y + 0.001)
	var corner_offset: Vector2 = (relative - (inner_half - Vector2.ONE * inner_radius)).max(
		Vector2.ZERO
	)
	assert_lte(corner_offset.length(), inner_radius + 0.001)
