extends "res://tests/support/poker_gut_test.gd"

const GuiPhoneSeatLayoutScript := preload("res://scripts/gui/gui_phone_seat_layout.gd")
const GuiViewportFixturesScript := preload("res://tests/support/gui_viewport_fixtures.gd")

const REPRESENTATIVE_PLAYER_COUNTS: Array[int] = [2, 4, 5, 6, 7, 9]


func test_phone_policy_keeps_six_as_default_and_four_as_guidance() -> void:
	var defaults := load("res://resources/default_tournament_config.tres") as TournamentConfig
	assert_eq(defaults.player_count, 6)
	assert_eq(GuiPhoneSeatLayoutScript.RECOMMENDED_PHONE_PLAYER_COUNT, 4)
	assert_eq(GuiPhoneSeatLayoutScript.MIN_PLAYER_COUNT, 2)
	assert_eq(GuiPhoneSeatLayoutScript.MAX_SUPPORTED_PLAYER_COUNT, 7)


func test_density_tiers_cover_every_supported_player_count() -> void:
	for player_count: int in range(2, 5):
		assert_eq(
			GuiPhoneSeatLayoutScript.density_for(player_count),
			GuiPhoneSeatLayoutScript.Density.STANDARD,
		)
	for player_count: int in range(5, 7):
		assert_eq(
			GuiPhoneSeatLayoutScript.density_for(player_count),
			GuiPhoneSeatLayoutScript.Density.COMPACT,
		)
	for player_count: int in range(7, 10):
		assert_eq(
			GuiPhoneSeatLayoutScript.density_for(player_count),
			GuiPhoneSeatLayoutScript.Density.MINIMAL,
		)


func test_phone_seats_fit_without_overlap_and_preserve_the_center() -> void:
	for fixture: Dictionary in GuiViewportFixturesScript.all():
		if (
			fixture.profile
			not in [
				GuiViewportFixturesScript.PROFILE_PHONE_PORTRAIT,
				GuiViewportFixturesScript.PROFILE_PHONE_LANDSCAPE,
			]
		):
			continue
		var usable_size := Vector2(fixture.size)
		var bounds := Rect2(Vector2.ZERO, usable_size)
		var center: Rect2 = GuiPhoneSeatLayoutScript.center_rect(usable_size)
		assert_true(bounds.encloses(center), "%s center" % fixture.key)
		for player_count: int in REPRESENTATIVE_PLAYER_COUNTS:
			var context := "%s_%d_players" % [fixture.key, player_count]
			var rects: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(
				usable_size, player_count
			)
			assert_eq(rects.size(), player_count, context)
			assert_eq(rects[0].position.y + rects[0].size.y, usable_size.y - 8.0, context)
			var placed: Array[Rect2] = []
			for seat: int in rects:
				var seat_rect: Rect2 = rects[seat]
				assert_true(bounds.encloses(seat_rect), "%s seat %d bounds" % [context, seat])
				assert_false(seat_rect.intersects(center), "%s seat %d center" % [context, seat])
				for other_rect: Rect2 in placed:
					assert_false(seat_rect.intersects(other_rect), context)
				placed.append(seat_rect)


func test_nine_seat_minimal_phone_layout_uses_all_distinct_perimeter_slots() -> void:
	for usable_size: Vector2 in [Vector2(360, 640), Vector2(844, 390)]:
		var rects: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(usable_size, 9)
		var distinct_positions: Dictionary[Vector2, bool] = {}
		for seat: int in rects:
			distinct_positions[rects[seat].position] = true
			assert_eq(rects[seat].size.y, 48.0)
		assert_eq(distinct_positions.size(), 9)


func test_supported_seven_seat_tokens_are_larger_than_the_emergency_fallback() -> void:
	for usable_size: Vector2 in [Vector2(360, 640), Vector2(844, 390)]:
		var supported: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(usable_size, 7)
		var emergency: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(usable_size, 9)
		assert_gt(supported[1].size.x, emergency[1].size.x)
		assert_gt(supported[1].size.y, emergency[1].size.y)


func test_invalid_layout_inputs_return_no_geometry() -> void:
	assert_true(GuiPhoneSeatLayoutScript.seat_rects(Vector2.ZERO, 6).is_empty())
	assert_true(GuiPhoneSeatLayoutScript.seat_rects(Vector2(390, 844), 1).is_empty())
	assert_true(GuiPhoneSeatLayoutScript.seat_rects(Vector2(390, 844), 10).is_empty())
