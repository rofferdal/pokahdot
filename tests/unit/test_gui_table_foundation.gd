extends "res://tests/support/poker_gut_test.gd"

const AvatarAssignmentServiceScript := preload("res://scripts/gui/avatar_assignment_service.gd")
const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const MainScene := preload("res://scenes/main.tscn")
const PokerTableScene := preload("res://scenes/poker_table.tscn")


func test_game_window_starts_at_full_hd_size() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080)


func test_startup_and_table_fonts_are_scaled_by_one_point_eight() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	assert_eq(main.theme.default_font_size, 29)
	assert_eq(main.get_node("Center/Panel/Margin/Form/Title").get_theme_font_size("font_size"), 50)
	assert_eq(
		main.get_node("Center/Panel/Margin/Form/Description").get_theme_font_size("font_size"), 29
	)
	assert_eq(
		main.get_node("Center/Panel/Margin/Form/PlayerCountInput").get_theme_font_size("font_size"),
		29
	)
	assert_eq(
		main.get_node("Center/Panel/Margin/Form/StartButton").get_theme_font_size("font_size"), 29
	)

	var table = main.get_node("PokerTable")
	table.bind_view(_table_view(2), _avatar_assignments(2))
	assert_eq(table.theme.default_font_size, 29)
	assert_eq(table.find_child("BoardLabel", true, false).get_theme_font_size("font_size"), 29)
	assert_eq(table.find_child("PotLabel", true, false).get_theme_font_size("font_size"), 29)
	assert_eq(table.find_child("WagerLabel", true, false).get_theme_font_size("font_size"), 29)
	assert_eq(table.find_child("CardSlot1", true, false).get_theme_font_size("font_size"), 29)
	assert_eq(table.find_child("Name", true, false).get_theme_font_size("font_size"), 23)


func test_default_avatar_catalog_has_sixteen_distinct_loadable_pixel_portraits() -> void:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var distinct_paths: Dictionary = {}

	assert_eq(paths.size(), 16)
	for avatar_path: String in paths:
		distinct_paths[avatar_path] = true
		var avatar_texture := load(avatar_path) as Texture2D
		assert_not_null(avatar_texture, avatar_path)
		assert_eq(avatar_texture.get_width(), 64, avatar_path)
		assert_eq(avatar_texture.get_height(), 64, avatar_path)
	assert_eq(distinct_paths.size(), 16)


func test_avatar_assignment_is_seeded_and_unique() -> void:
	var catalog := GuiAvatarCatalogScript.new(PackedStringArray(["a", "b", "c", "d"]))
	var service = AvatarAssignmentServiceScript.new(catalog)

	var first = service.assign_for_tournament(4, 7331)
	var second = service.assign_for_tournament(4, 7331)

	assert_true(first.is_ok())
	assert_eq(first.assignments, second.assignments)
	assert_eq(first.assignments.values().size(), 4)
	var distinct_assignments: Dictionary = {}
	for avatar_path: String in first.assignments.values():
		distinct_assignments[avatar_path] = true
	assert_eq(distinct_assignments.size(), 4)


func test_avatar_assignment_rejects_an_insufficient_catalog() -> void:
	var catalog := GuiAvatarCatalogScript.new(PackedStringArray(["a", "b"]))
	var result = AvatarAssignmentServiceScript.new(catalog).assign_for_tournament(3, 1)

	assert_false(result.is_ok())
	assert_eq(result.assignments, {})
	assert_eq(
		result.error_message, "Avatar catalog has 2 assets but 3 seats require distinct avatars."
	)


func test_hidden_table_lays_out_seats_after_showing_at_desktop_and_mobile_sizes() -> void:
	var cases: Array[Dictionary] = [
		{"player_count": 6, "size": Vector2(1140, 632)},
		{"player_count": 9, "size": Vector2(1140, 632)},
		{"player_count": 6, "size": Vector2(390, 780)},
		{"player_count": 9, "size": Vector2(390, 780)},
	]
	for test_case: Dictionary in cases:
		var player_count: int = test_case["player_count"]
		var viewport_size: Vector2 = test_case["size"]
		var table = PokerTableScene.instantiate()
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = viewport_size
		table.bind_view(_table_view(player_count), _avatar_assignments(player_count))

		table.show()
		await get_tree().process_frame
		await get_tree().process_frame

		var seat_rects: Dictionary[int, Rect2] = table.get_seat_rects()
		var surface_rect := Rect2(Vector2.ZERO, table.get_surface_size())
		var distinct_positions: Dictionary[Vector2, bool] = {}
		var placed_rects: Array[Rect2] = []
		assert_eq(seat_rects.size(), player_count)
		for seat: int in seat_rects:
			var seat_rect: Rect2 = seat_rects[seat]
			var context := "seat %d at %d players in %s" % [seat, player_count, viewport_size]
			distinct_positions[seat_rect.position] = true
			assert_true(surface_rect.encloses(seat_rect), context)
			for placed_rect: Rect2 in placed_rects:
				assert_false(
					seat_rect.intersects(placed_rect),
					"%s: %s intersects %s" % [context, seat_rect, placed_rect]
				)
			placed_rects.append(seat_rect)
			var seat_node: Control = table.get_node(
				"TableMargin/Felt/TableSurface/Seats/Seat%d" % seat
			)
			var avatar := seat_node.find_child("Avatar", true, false) as TextureRect
			assert_true(seat_node.is_visible_in_tree(), context)
			assert_not_null(avatar.texture, context)
		assert_eq(distinct_positions.size(), player_count)


func test_table_scene_binds_board_wager_and_pot_zones() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := GameView.new()
	view._community_cards = [
		CardData.new(14, CardData.Suit.CLUBS),
		CardData.new(13, CardData.Suit.DIAMONDS),
		CardData.new(12, CardData.Suit.HEARTS),
	]
	view.pot_amount = 55
	view._seats = [_player_view(0, 5), _player_view(1, 10)]

	var avatar_paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var avatar_assignments: Dictionary[int, String] = {0: avatar_paths[0], 1: avatar_paths[1]}
	table.bind_view(view, avatar_assignments)

	assert_eq(table.board_card_count, 3)
	assert_eq(table.wager_amounts, {0: 5, 1: 10})
	assert_eq(table.displayed_pot_amount, 55)
	assert_eq(table.get_card_slot_count(), 5)
	assert_eq(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/CenterZone/BoardZone/BoardContent/BoardLabel")
			. text
		),
		"Community cards"
	)
	assert_eq(
		table.get_node("TableMargin/Felt/TableSurface/CenterZone/WagerZone/WagerLabel").text,
		"Wagers  •  2 active"
	)
	assert_eq(
		table.get_node("TableMargin/Felt/TableSurface/CenterZone/PotZone/PotLabel").text,
		"POT  •  55"
	)
	var name_label := table.find_child("Name", true, false) as Label
	assert_not_null(name_label)
	assert_eq(name_label.autowrap_mode, TextServer.AUTOWRAP_OFF)
	assert_true(name_label.clip_text)
	var avatar := table.find_child("Avatar", true, false) as TextureRect
	assert_not_null(avatar)
	assert_not_null(avatar.texture)
	assert_eq(avatar.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func _player_view(seat: int, wager: int) -> PlayerView:
	var player := Player.new(&"test_%d" % seat, "Test %d" % seat, seat, 100, HumanAgent.new())
	player.bet_this_round = wager
	return PlayerView.new(player)


func _table_view(player_count: int) -> GameView:
	var view := GameView.new()
	for seat: int in range(player_count):
		view._seats.append(_player_view(seat, 0))
	return view


func _avatar_assignments(player_count: int) -> Dictionary[int, String]:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = paths[seat]
	return assignments
