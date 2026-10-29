extends GutTest

const MODE := GuiSizeClass.LayoutMode


func test_seven_player_phone_envelopes_before_nine_player_wide() -> void:
	for mode: int in [MODE.PHONE, MODE.PHONE_LANDSCAPE, MODE.WIDE_COMPACT, MODE.WIDE]:
		var count: int = 7 if mode in [MODE.PHONE, MODE.PHONE_LANDSCAPE] else 9
		var candidate: GuiFitCandidate = _candidate(mode, count)
		assert_true(candidate.valid)
		assert_eq(candidate.evidence, &"primitive_fixture")
		var exact: GuiFitPolicy = _resolve(candidate.minimum, count, [candidate], mode)
		assert_eq(exact.status, GuiFitPolicy.Status.FIT, str(candidate.minimum))
		for delta: Vector2 in [Vector2(-1, 0), Vector2(0, -1)]:
			assert_eq(
				_resolve(candidate.minimum + delta, count, [candidate], mode).status,
				GuiFitPolicy.Status.TOO_SMALL
			)


func test_width_and_height_classes_at_every_boundary_plus_minus_one() -> void:
	for boundary: float in [600.0, 1100.0]:
		for delta: float in [-1.0, 0.0, 1.0]:
			var value: GuiSizeClass = GuiSizeClass.classify(Vector2(boundary + delta, 900))
			var expected: int = 0 if boundary + delta < 600 else 1 if boundary + delta < 1100 else 2
			assert_eq(int(value.width_class), expected)
	for boundary: float in [600.0, 760.0]:
		for delta: float in [-1.0, 0.0, 1.0]:
			var value: GuiSizeClass = GuiSizeClass.classify(Vector2(1280, boundary + delta))
			var expected: int = 0 if boundary + delta < 600 else 1 if boundary + delta < 760 else 2
			assert_eq(int(value.height_class), expected)
	assert_eq(GuiSizeClass.classify(Vector2(650, 900)).mode, MODE.WIDE_COMPACT)
	assert_eq(GuiSizeClass.classify(Vector2(390, 844)).mode, MODE.PHONE)
	assert_eq(GuiSizeClass.classify(Vector2(844, 390)).mode, MODE.PHONE_LANDSCAPE)
	assert_eq(GuiSizeClass.classify(Vector2(600, 600)).mode, MODE.WIDE_COMPACT)
	assert_eq(GuiSizeClass.classify(Vector2(1100, 760)).mode, MODE.WIDE)
	for width: int in range(1, 1601, 79):
		for height: int in range(1, 1201, 59):
			var value: GuiSizeClass = GuiSizeClass.classify(Vector2(width, height))
			assert_true(value.ready)
			assert_between(int(value.mode), int(MODE.PHONE), int(MODE.WIDE))


func test_constrained_landscape_can_use_a_smaller_measured_content_plan() -> void:
	var metrics: GuiFitMetrics = _metrics()
	metrics.opponent.y = 84
	var candidate: GuiFitCandidate = GuiFitCandidate.measure(
		MODE.PHONE_LANDSCAPE, metrics, _ids(7), 0
	)
	assert_eq(candidate.minimum, Vector2(608, 348))
	assert_eq(_resolve(Vector2(844, 390), 7, [candidate]).status, GuiFitPolicy.Status.FIT)
	assert_eq(_resolve(Vector2(608, 347), 7, [candidate]).status, GuiFitPolicy.Status.TOO_SMALL)
	for row: PackedInt32Array in candidate.seats.rows:
		assert_lte(row.size(), 2, "reserve the third seat in any band for the hero rail")


func test_preference_cannot_discard_a_fitting_lower_density_plan() -> void:
	var compact: GuiFitCandidate = _candidate(MODE.PHONE, 7)
	var regular: GuiFitCandidate = _candidate(MODE.WIDE, 7)
	regular.minimum = Vector2(1400, 1000)
	var at_medium: GuiFitPolicy = _resolve(Vector2(650, 900), 7, [regular, compact])
	assert_eq(at_medium.status, GuiFitPolicy.Status.FIT)
	assert_same(at_medium.selected, compact)
	assert_eq(at_medium.size_class.mode, MODE.WIDE_COMPACT)
	var at_wide: GuiFitPolicy = _resolve(Vector2(1600, 1000), 7, [compact, regular])
	assert_eq(at_wide.status, GuiFitPolicy.Status.FIT)
	assert_same(at_wide.selected, regular)


func test_invalid_geometry_cannot_be_forced_ready() -> void:
	for size: Vector2 in [
		Vector2.ZERO, Vector2(-1, 10), Vector2(10, 0), Vector2(NAN, 10), Vector2(10, INF)
	]:
		for override: int in [GuiSizeClass.AUTOMATIC, MODE.PHONE, MODE.WIDE]:
			var value: GuiSizeClass = GuiSizeClass.classify(size, override)
			assert_false(value.ready)
			assert_eq(value.mode, MODE.NOT_READY)
	assert_eq(GuiFitPolicy.resolve(null, _ids(7), 0, []).status, GuiFitPolicy.Status.NOT_READY)
	assert_eq(_resolve(Vector2.ZERO, 7, []).status, GuiFitPolicy.Status.NOT_READY)


func test_fixture_override_changes_preference_only() -> void:
	for mode: int in [MODE.PHONE, MODE.PHONE_LANDSCAPE, MODE.WIDE_COMPACT, MODE.WIDE]:
		var value: GuiSizeClass = GuiSizeClass.classify(Vector2(1280, 900), mode)
		assert_eq(int(value.mode), mode)
		assert_eq(value.width_class, GuiSizeClass.Width.EXPANDED)
	for invalid: int in [-10, MODE.NOT_READY, 99]:
		assert_eq(GuiSizeClass.classify(Vector2(650, 900), invalid).mode, MODE.WIDE_COMPACT)
	var huge: GuiFitCandidate = _candidate(MODE.PHONE, 7)
	huge.minimum = Vector2(5000, 5000)
	assert_eq(
		_resolve(Vector2(390, 844), 7, [huge], MODE.PHONE).status, GuiFitPolicy.Status.TOO_SMALL
	)


func test_rows_have_real_capacity_and_clockwise_identity_for_every_recipient() -> void:
	for count: int in range(2, 10):
		var ids: PackedInt32Array = _ids(count)
		for recipient: int in ids:
			for portrait: bool in [false, true]:
				var plan: GuiSeatRows = GuiSeatRows.compose(ids, recipient, portrait)
				assert_true(plan.valid)
				var observed := PackedInt32Array()
				for row: PackedInt32Array in plan.rows:
					assert_lte(row.size(), 2 if portrait else 3)
					for id: int in row:
						assert_false(observed.has(id))
						observed.append(id)
				assert_eq(observed.size(), count)
				assert_eq(plan.rows[-1], PackedInt32Array([recipient]))
				if portrait and (count - 1) % 2 == 1:
					assert_eq(plan.rows[0].size(), 1, "one centered apex slot")
				var traversal := PackedInt32Array()
				for index: int in range(plan.rows.size() - 2, 0, -1):
					traversal.append(plan.rows[index][0])
				traversal.append_array(plan.rows[0])
				for index: int in range(1, plan.rows.size() - 1):
					traversal.append(plan.rows[index][1])
				traversal.append(recipient)
				assert_eq(traversal, plan.clockwise_ids)
				for offset: int in count:
					assert_eq(traversal[offset], ids[(ids.find(recipient) + offset + 1) % count])


func test_invalid_ids_and_stale_candidate_cannot_publish_fit() -> void:
	for ids: PackedInt32Array in [
		PackedInt32Array(),
		PackedInt32Array([0]),
		PackedInt32Array([0, 0]),
		PackedInt32Array([-1, 0])
	]:
		assert_false(GuiSeatRows.compose(ids, 0, false).valid)
	assert_false(GuiSeatRows.compose(_ids(7), 99, false).valid)
	var geometry: GuiViewportGeometry = GuiViewportGeometry.injected(Vector2(1280, 900))
	assert_eq(
		GuiFitPolicy.resolve(geometry, _ids(7), 99, []).status, GuiFitPolicy.Status.INVALID_INPUT
	)
	assert_eq(
		GuiFitPolicy.resolve(geometry, _ids(7), 0, [_candidate(MODE.WIDE, 6)]).status,
		GuiFitPolicy.Status.NEEDS_MEASUREMENTS
	)


func test_phone_capacity_is_guidance_and_preserves_all_input_ids() -> void:
	for size: Vector2 in [Vector2(390, 844), Vector2(844, 390)]:
		for count: int in [8, 9]:
			var ids: PackedInt32Array = _ids(count)
			var before: PackedInt32Array = ids.duplicate()
			var result: GuiFitPolicy = GuiFitPolicy.resolve(
				GuiViewportGeometry.injected(size), ids, 0, [_candidate(MODE.WIDE, count)]
			)
			assert_eq(result.status, GuiFitPolicy.Status.PHONE_CAPACITY)
			assert_false(result.guidance.is_empty())
			assert_eq(ids, before)
			assert_null(result.selected)
			assert_false(_candidate(MODE.PHONE, count).valid)


func test_usable_extent_not_full_window_or_safe_origin_selects_class_and_fit() -> void:
	var geometry: GuiViewportGeometry = GuiViewportGeometry.injected(
		Vector2(1400, 1000), Rect2(20, 30, 390, 844)
	)
	var candidate: GuiFitCandidate = _candidate(MODE.PHONE, 7)
	var result: GuiFitPolicy = GuiFitPolicy.resolve(geometry, _ids(7), 0, [candidate])
	assert_eq(result.size_class.mode, MODE.PHONE)
	assert_eq(result.size_class.usable_size, Vector2(390, 844))
	assert_eq(geometry.usable_rect.position, Vector2(20, 30))
	assert_eq(result.status, GuiFitPolicy.Status.FIT)


func test_fitting_candidate_survives_each_axis_growth_and_preference_changes() -> void:
	for mode: int in [MODE.PHONE, MODE.PHONE_LANDSCAPE, MODE.WIDE_COMPACT]:
		var candidate: GuiFitCandidate = _candidate(mode, 7)
		var origin: Vector2 = candidate.minimum.ceil()
		if mode == MODE.PHONE:
			origin.y = maxf(origin.y, 1200)
		elif mode == MODE.PHONE_LANDSCAPE:
			origin.x = maxf(origin.x, 1800)
		for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
			for growth: int in range(0, 801, 20):
				var size: Vector2 = origin + axis * growth
				if (size.x > size.y) != (origin.x > origin.y):
					continue
				assert_eq(_resolve(size, 7, [candidate]).status, GuiFitPolicy.Status.FIT, str(size))


func test_missing_and_invalid_metrics_are_distinct_from_too_small() -> void:
	assert_eq(_resolve(Vector2(390, 844), 7, []).status, GuiFitPolicy.Status.NEEDS_MEASUREMENTS)
	var metrics := GuiFitMetrics.new()
	assert_false(metrics.valid())
	assert_false(GuiFitCandidate.measure(MODE.PHONE, metrics, _ids(7), 0).valid)
	for invalid: Vector2 in [Vector2.ZERO, Vector2(-1, 48), Vector2(NAN, 48), Vector2(48, INF)]:
		metrics = _metrics()
		metrics.actions = invalid
		assert_false(metrics.valid())
	var small: GuiFitCandidate = _candidate(MODE.PHONE, 2)
	var large: GuiFitCandidate = _candidate(MODE.PHONE, 7)
	assert_gt(large.minimum.y, small.minimum.y)
	metrics = _metrics()
	metrics.opponent.y += 20
	assert_gt(GuiFitCandidate.measure(MODE.PHONE, metrics, _ids(7), 0).minimum.y, large.minimum.y)


func _metrics() -> GuiFitMetrics:
	var metrics := GuiFitMetrics.new()
	metrics.opponent = Vector2(160, 108)
	metrics.board = Vector2(280, 84)
	metrics.hero = Vector2(180, 96)
	metrics.actions = Vector2(280, 104)
	metrics.event_log = Vector2(220, 104)
	metrics.gap = 4
	metrics.evidence = &"primitive_fixture"
	return metrics


func _candidate(mode: int, count: int) -> GuiFitCandidate:
	return GuiFitCandidate.measure(mode, _metrics(), _ids(count), 0)


func _ids(count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index: int in count:
		result.append(10 + index * 2 if index > 0 else 0)
	return result


func _resolve(
	size: Vector2,
	count: int,
	candidates: Array[GuiFitCandidate],
	override: int = GuiSizeClass.AUTOMATIC
) -> GuiFitPolicy:
	return GuiFitPolicy.resolve(
		GuiViewportGeometry.injected(size), _ids(count), 0, candidates, override
	)
