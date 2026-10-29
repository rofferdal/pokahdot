extends "res://tests/support/poker_gut_test.gd"

const Plan := preload("res://scripts/gui/gui_six_seat_desktop_plan.gd")
const Profile := preload("res://scripts/gui/gui_layout_profile.gd")


func test_density_selection_preserves_device_profiles_and_other_counts() -> void:
	for profile: int in [
		Profile.Kind.TABLET, Profile.Kind.PHONE_PORTRAIT, Profile.Kind.SMALL_DESKTOP
	]:
		assert_false(Plan.can_use(Vector2(1216, 664), profile, 6, false))
	for count: int in [2, 3, 4, 5, 7, 8, 9]:
		assert_false(Plan.can_use(Vector2(1216, 664), Profile.Kind.DESKTOP, count, false))
	assert_false(Plan.can_use(Vector2(1791, 862), Profile.Kind.DESKTOP, 6, false))
	assert_false(Plan.can_use(Vector2(1856, 1024), Profile.Kind.DESKTOP, 6, false))
	assert_false(Plan.can_use(Vector2(1183, 580), Profile.Kind.DESKTOP, 6, false))
	assert_true(Plan.can_use(Vector2(1216, 664), Profile.Kind.DESKTOP, 6, false))
	assert_false(Plan.can_use(Vector2(1216, 664), Profile.Kind.DESKTOP, 6, true))


func test_complete_footprints_and_controls_fit_measured_failing_surfaces() -> void:
	for surface_size: Vector2 in [
		Vector2(1216, 664),
		Vector2(1236, 704),
		Vector2(1305, 668),
		Vector2(1313, 721),
		Vector2(1376, 844)
	]:
		var plan := Plan.new()
		assert_true(
			plan.configure(
				surface_size,
				Vector2(520, 198),
				Vector2(200, 133),
				Vector2(306, 128),
				Vector2(72, 48)
			)
		)
		var footprints: Array[Rect2] = []
		for seat: int in plan.seat_rects:
			var footprint: Rect2 = plan.seat_rects[seat].merge(plan.status_rects[seat])
			assert_true(Rect2(Vector2.ZERO, surface_size).encloses(footprint))
			assert_eq(plan.status_rects[seat].size.y, 64.0)
			footprints.append(footprint)
		footprints.append_array(
			[plan.center_rect, plan.quit_rect, plan.action_rect, plan.event_rect]
		)
		for first: int in footprints.size():
			for second: int in range(first + 1, footprints.size()):
				assert_false(
					footprints[first].intersects(footprints[second]),
					"%s: %s / %s" % [surface_size, first, second]
				)


func test_fit_uses_actual_content_minima_and_rejects_impossible_geometry() -> void:
	var plan := Plan.new()
	assert_false(
		plan.configure(
			Vector2(1216, 580),
			Vector2(520, 198),
			Vector2(200, 133),
			Vector2(306, 128),
			Vector2(72, 48)
		)
	)

	assert_false(
		plan.configure(
			Vector2(1216, 664),
			Vector2(520, 198),
			Vector2(521, 133),
			Vector2(306, 128),
			Vector2(72, 48)
		)
	)
	assert_false(
		plan.configure(
			Vector2(1216, 664),
			Vector2(520, 198),
			Vector2(200, 133),
			Vector2(400, 128),
			Vector2(72, 48)
		)
	)
	assert_false(
		plan.configure(
			Vector2(1216, 664),
			Vector2(520, 198),
			Vector2(200, 133),
			Vector2(306, 128),
			Vector2(72, 48),
			Vector2(160, 200)
		)
	)


func test_corner_clearance_reserves_complete_upper_footprints_without_moving_lower_rail() -> void:
	var original := Plan.new()
	var inset := Plan.new()
	assert_true(
		original.configure(
			Vector2(1216, 664),
			Vector2(520, 198),
			Vector2(200, 133),
			Vector2(306, 128),
			Vector2(72, 48)
		)
	)
	assert_true(
		inset.configure(
			Vector2(1216, 664),
			Vector2(520, 198),
			Vector2(200, 133),
			Vector2(306, 128),
			Vector2(72, 48),
			Vector2(160, 102),
			68.0
		)
	)
	assert_eq(inset.hero_rect, original.hero_rect)
	assert_eq(inset.event_rect, original.event_rect)
	assert_eq(inset.action_rect, original.action_rect)
	for pair: Vector2i in [Vector2i(2, 1), Vector2i(4, 5)]:
		var upper: Rect2 = inset.seat_rects[pair.x].merge(inset.status_rects[pair.x])
		var lower: Rect2 = inset.seat_rects[pair.y].merge(inset.status_rects[pair.y])
		assert_gte(upper.position.y, 68.0)
		assert_false(upper.intersects(lower), "reserved showdown bands must clear lower seats")
	assert_false(
		inset.configure(
			Vector2(1216, 664),
			Vector2(520, 198),
			Vector2(200, 133),
			Vector2(306, 128),
			Vector2(72, 48),
			Vector2(160, 102),
			200.0
		),
		"impossible corner clearance must fail instead of overlapping complete footprints"
	)


func test_selected_density_configures_at_the_same_measured_contract_boundaries() -> void:
	for width: int in [1200, 1216, 1305, 1376, 1599, 1600]:
		for height: int in range(620, 681):
			for large: bool in [false, true]:
				var surface_size := Vector2(width, height)
				if not Plan.can_use(surface_size, Profile.Kind.DESKTOP, 6, large):
					continue
				var plan := Plan.new()
				assert_true(
					(
						plan
						. configure(
							surface_size,
							Vector2(minf(520.0, surface_size.x * 0.48), 226.0 if large else 198.0),
							Vector2(200.0, 150.0),
							Vector2(306.0, 150.0),
							Vector2(72.0, 48.0),
						)
					)
				)


func test_folded_and_revealed_content_share_one_reserved_lower_rail() -> void:
	var folded := Plan.new()
	var revealed := Plan.new()
	assert_true(
		folded.configure(
			Vector2(1305, 668),
			Vector2(520, 198),
			Vector2(200, 60),
			Vector2(306, 70),
			Vector2(72, 48)
		)
	)
	assert_true(
		revealed.configure(
			Vector2(1305, 668),
			Vector2(520, 198),
			Vector2(200, 133),
			Vector2(306, 150),
			Vector2(72, 48)
		)
	)
	assert_eq(folded.hero_rect, revealed.hero_rect)
	assert_eq(folded.action_rect, revealed.action_rect)
	assert_eq(folded.event_rect, revealed.event_rect)
	assert_eq(folded.status_rects, revealed.status_rects)
