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
		for player_count: int in REPRESENTATIVE_PLAYER_COUNTS:
			var context := "%s_%d_players" % [fixture.key, player_count]
			var center: Rect2 = GuiPhoneSeatLayoutScript.center_rect(usable_size, player_count)
			assert_true(bounds.encloses(center), "%s center" % context)
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


func test_six_player_portrait_uses_a_symmetric_five_opponent_arc() -> void:
	var usable_size := Vector2(296.0, 724.0)
	var rects: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(usable_size, 6)
	var linh: Rect2 = rects[1]
	var bao: Rect2 = rects[2]
	var lior: Rect2 = rects[3]
	var haruto: Rect2 = rects[4]
	var kwame: Rect2 = rects[5]
	assert_almost_eq(linh.get_center().x, bao.get_center().x, 0.001)
	assert_almost_eq(haruto.get_center().x, kwame.get_center().x, 0.001)
	assert_almost_eq(linh.get_center().y, kwame.get_center().y, 0.001)
	assert_almost_eq(bao.get_center().y, haruto.get_center().y, 0.001)
	assert_lt(bao.get_center().y, linh.get_center().y)
	assert_lt(lior.get_center().y, bao.get_center().y)
	assert_almost_eq(lior.get_center().x, usable_size.x * 0.5, 0.001)
	for mirrored_pair: Array in [[1, 5], [2, 4]]:
		assert_almost_eq(
			rects[mirrored_pair[0]].get_center().x + rects[mirrored_pair[1]].get_center().x,
			usable_size.x,
			0.001,
		)


func test_supported_portrait_counts_use_mirrored_fixed_seat_footprints() -> void:
	var usable_size := Vector2(296.0, 724.0)
	for player_count: int in [2, 4, 7]:
		var rects: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(
			usable_size, player_count
		)
		var opponent_count: int = player_count - 1
		for opponent_index: int in range(floori(float(opponent_count) / 2.0)):
			var left: Rect2 = rects[opponent_index + 1]
			var right: Rect2 = rects[player_count - 1 - opponent_index]
			assert_almost_eq(left.get_center().x + right.get_center().x, usable_size.x, 0.001)
			assert_almost_eq(left.get_center().y, right.get_center().y, 0.001)
		if opponent_count % 2 == 1:
			var center_seat: int = 1 + floori(float(opponent_count) / 2.0)
			assert_almost_eq(rects[center_seat].get_center().x, usable_size.x * 0.5, 0.001)


func test_invalid_layout_inputs_return_no_geometry() -> void:
	assert_true(GuiPhoneSeatLayoutScript.seat_rects(Vector2.ZERO, 6).is_empty())
	assert_true(GuiPhoneSeatLayoutScript.seat_rects(Vector2(390, 844), 1).is_empty())
	assert_true(GuiPhoneSeatLayoutScript.seat_rects(Vector2(390, 844), 10).is_empty())
