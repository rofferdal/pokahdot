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


func test_desktop_seats_are_equally_wide_for_every_supported_player_count() -> void:
	for player_count: int in range(2, 10):
		var table = PokerTableScene.instantiate()
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = Vector2(1920, 1080)
		table.bind_view(_hero_table_view(player_count), _avatar_assignments(player_count))

		table.show()
		await get_tree().process_frame
		await get_tree().process_frame

		for seat: int in range(player_count):
			var panel: PanelContainer = table.get_node(
				"TableMargin/Felt/TableSurface/Seats/Seat%d" % seat
			)
			assert_almost_eq(
				panel.size.x,
				280.0,
				0.001,
				(
					"seat %d at %d players should use the shared wide desktop panel"
					% [seat, player_count]
				)
			)
			if seat != 0:
				var name_label: Label = panel.find_child("Name", true, false)
				assert_gte(
					name_label.size.x,
					100.0,
					(
						"seat %d at %d players should retain a readable name area"
						% [seat, player_count]
					)
				)


func test_three_to_seven_player_tables_mirror_seat_positions_left_to_right() -> void:
	for player_count: int in range(3, 8):
		var table = PokerTableScene.instantiate()
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = Vector2(1920, 1080)
		table.bind_view(_hero_table_view(player_count), _avatar_assignments(player_count))

		table.show()
		await get_tree().process_frame
		await get_tree().process_frame

		var seat_rects: Dictionary[int, Rect2] = table.get_seat_rects()
		var surface_width: float = table.get_surface_size().x
		for seat: int in range(1, (player_count + 1) / 2):
			var mirrored_seat: int = player_count - seat
			var seat_center: Vector2 = seat_rects[seat].get_center()
			var mirrored_center: Vector2 = seat_rects[mirrored_seat].get_center()
			var context := "%d-player seats %d and %d" % [player_count, seat, mirrored_seat]
			assert_almost_eq(seat_center.x + mirrored_center.x, surface_width, 0.01, context)
			assert_almost_eq(seat_center.y, mirrored_center.y, 0.01, context)


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
	assert_string_contains(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/CenterZone/BoardZone/BoardContent/BoardLabel")
			. text
		),
		"Community cards"
	)
	assert_string_contains(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/CenterZone/BoardZone/BoardContent/BoardLabel")
			. text
		),
		"A♣"
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


func test_table_renders_only_recipient_cards_and_live_position_state() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := GameView.new()
	view.hero_seat = 0
	view.button_seat = 0
	view.small_blind_seat = 1
	view.big_blind_seat = 2
	view.acting_seat = 2
	view._community_cards = [
		CardData.new(14, CardData.Suit.CLUBS), CardData.new(10, CardData.Suit.HEARTS)
	]
	view._hero_hole_cards = [
		CardData.new(13, CardData.Suit.DIAMONDS), CardData.new(2, CardData.Suit.SPADES)
	]
	view.pot_amount = 35
	view._pots = [PotLayer.new(35, 20, [0, 1, 2], [0, 1, 2])]
	var hero := Player.new(&"hero", "Hero", 0, 95, HumanAgent.new())
	hero.bet_this_round = 5
	var opponent := Player.new(
		&"bot", "Opponent", 1, 90, RandomAgent.new(RandomNumberGenerator.new())
	)
	opponent.bet_this_round = 10
	var eliminated := Player.new(&"out", "Out", 2, 0, RandomAgent.new(RandomNumberGenerator.new()))
	eliminated.busted = true
	view._seats = [PlayerView.new(hero), PlayerView.new(opponent), PlayerView.new(eliminated)]

	table.bind_view(view, _avatar_assignments(3))

	var seat_prefix: String = "TableMargin/Felt/TableSurface/Seats/Seat%d/Content/"
	assert_string_contains(table.find_child("BoardLabel", true, false).text, "A♣")
	assert_string_contains(table.get_node(seat_prefix % 0 + "Header/Marker").text, "D")
	assert_string_contains(table.get_node(seat_prefix % 1 + "Header/Marker").text, "SB")
	assert_string_contains(table.get_node(seat_prefix % 2 + "Header/Marker").text, "BB ACT")
	assert_string_contains(table.get_node(seat_prefix % 0 + "State").text, "95 chips")
	assert_eq(table.get_node(seat_prefix % 0 + "HeroCards/HeroCard1").text, "K♦")
	assert_not_null(table.get_node(seat_prefix % 1 + "Footer/HoleCards/CardBack1"))
	assert_string_contains(table.get_node(seat_prefix % 2 + "Header/Name").text, "Out")

	view._community_cards.append(CardData.new(2, CardData.Suit.DIAMONDS))
	view.pot_amount = 65
	view._pots = [
		PotLayer.new(40, 15, [0, 1, 2], [0, 1, 2]),
		PotLayer.new(25, 25, [0, 1], [0, 1]),
	]
	table.bind_view(view, _avatar_assignments(3))

	assert_string_contains(table.find_child("BoardLabel", true, false).text, "2♦")
	assert_eq(table.find_child("PotLabel", true, false).text, "POT  •  65  •  2 layers")


func test_table_refreshes_from_a_recipient_safe_match_view() -> void:
	var adapter = GuiStartupConfigAdapter.new()
	assert_true(adapter.try_start())
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(adapter.match_instance, 0, _avatar_assignments(6))

	assert_eq(table.displayed_hero_cards.size(), 2)
	assert_not_null(
		table.get_node(
			"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Footer/HoleCards/CardBack1"
		)
	)
	table.refresh_from_match()
	assert_eq(table.board_card_count, 0)


func test_gui_startup_displays_the_initial_read_only_table() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)

	main.get_node("Center/Panel/Margin/Form/StartButton").emit_signal("pressed")

	var table = main.get_node("PokerTable")
	assert_true(table.visible)
	assert_false(main.get_node("Center").visible)
	assert_eq(table.displayed_hero_cards.size(), 2)
	assert_eq(table.board_card_count, 0)


func test_human_seat_is_bottom_anchored_with_card_faces_and_full_name() -> void:
	var cases: Array[Dictionary] = [
		{"player_count": 6, "size": Vector2(1140, 632)},
		{"player_count": 9, "size": Vector2(390, 780)},
	]
	for test_case: Dictionary in cases:
		var player_count: int = test_case["player_count"]
		var table = PokerTableScene.instantiate()
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = test_case["size"]
		table.bind_view(_hero_table_view(player_count), _avatar_assignments(player_count))
		table.show()
		await get_tree().process_frame
		await get_tree().process_frame

		var hero_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0")
		var hero_name: Label = hero_panel.find_child("Name", true, false)
		var hero_card: Label = hero_panel.find_child("HeroCard1", true, false)
		assert_gt(hero_panel.get_rect().get_center().y, table.get_surface_size().y * 0.75)
		assert_eq(hero_name.text, "Player 1 (you)")
		assert_eq(hero_card.text, "A♥")
		assert_not_null(hero_card.get_theme_stylebox("normal"))
		for seat: int in range(1, player_count):
			var name_label: Label = table.get_node(
				"TableMargin/Felt/TableSurface/Seats/Seat%d/Content/Header/Name" % seat
			)
			assert_eq(name_label.text, "Player %d" % (seat + 1))


func test_live_seat_panels_show_stacks_positions_and_hidden_opponent_cards() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _hero_table_view(3)
	view.button_seat = 1
	view.small_blind_seat = 2
	view.big_blind_seat = 0
	view.acting_seat = 2
	view._seats = [
		_player_snapshot(0, "Player 1", 975, HumanAgent.new()),
		_player_snapshot(1, "Player 2", 990, RandomAgent.new(RandomNumberGenerator.new())),
		_player_snapshot(2, "Player 3", 995, RandomAgent.new(RandomNumberGenerator.new())),
	]
	table.bind_view(view, _avatar_assignments(3))

	var seat_prefix: String = "TableMargin/Felt/TableSurface/Seats/Seat%d/Content/"
	assert_string_contains(table.get_node(seat_prefix % 1 + "Header/Marker").text, "D")
	assert_string_contains(table.get_node(seat_prefix % 2 + "Header/Marker").text, "SB")
	assert_string_contains(table.get_node(seat_prefix % 2 + "Header/Marker").text, "ACT")
	assert_string_contains(table.get_node(seat_prefix % 0 + "Header/Marker").text, "BB")
	assert_string_contains(table.get_node(seat_prefix % 1 + "Footer/Detail").text, "990 chips")
	var chip_detail: Label = table.get_node(seat_prefix % 1 + "Footer/Detail")
	var avatar: TextureRect = table.get_node(seat_prefix % 1 + "Header/Avatar")
	var card_back: Label = table.get_node(seat_prefix % 2 + "Footer/HoleCards/CardBack1")
	assert_eq(chip_detail.get_theme_font_size("font_size"), 22)
	assert_eq(avatar.custom_minimum_size, Vector2(56, 56))
	assert_eq(card_back.custom_minimum_size, Vector2(30, 38))
	assert_not_null(card_back)
	assert_not_null(table.get_node(seat_prefix % 2 + "Footer/HoleCards/CardBack2"))


func test_revealed_bot_cards_match_hidden_card_back_dimensions() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var hidden_view := _hero_table_view(2)
	table.bind_view(hidden_view, _avatar_assignments(2))
	var seat_prefix: String = "TableMargin/Felt/TableSurface/Seats/Seat%d/Content/"
	var hidden_card: Label = table.get_node(seat_prefix % 1 + "Footer/HoleCards/CardBack1")

	var showdown_table = PokerTableScene.instantiate()
	add_child_autofree(showdown_table)
	var showdown_view := _hero_table_view(2)
	showdown_view._revealed_hole_cards[1] = [
		CardData.new(14, CardData.Suit.SPADES), CardData.new(13, CardData.Suit.HEARTS)
	]
	showdown_table.bind_view(showdown_view, _avatar_assignments(2))
	var revealed_card: Label = showdown_table.get_node(
		seat_prefix % 1 + "Footer/HoleCards/ShowdownCard1"
	)

	assert_eq(revealed_card.text, "A♠")
	assert_eq(revealed_card.custom_minimum_size, hidden_card.custom_minimum_size)


func _player_view(seat: int, wager: int) -> PlayerView:
	var player := Player.new(&"test_%d" % seat, "Test %d" % seat, seat, 100, HumanAgent.new())
	player.bet_this_round = wager
	return PlayerView.new(player)


func _table_view(player_count: int) -> GameView:
	var view := GameView.new()
	for seat: int in range(player_count):
		view._seats.append(_player_view(seat, 0))
	return view


func _hero_table_view(player_count: int) -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	view._hero_hole_cards = [
		CardData.new(14, CardData.Suit.HEARTS), CardData.new(10, CardData.Suit.CLUBS)
	]
	for seat: int in range(player_count):
		var agent: Agent = (
			HumanAgent.new() if seat == 0 else RandomAgent.new(RandomNumberGenerator.new())
		)
		var player := Player.new(&"display_%d" % seat, "Player %d" % (seat + 1), seat, 100, agent)
		view._seats.append(PlayerView.new(player))
	return view


func _player_snapshot(seat: int, display_name: String, stack: int, agent: Agent) -> PlayerView:
	return PlayerView.new(Player.new(&"snapshot_%d" % seat, display_name, seat, stack, agent))


func _avatar_assignments(player_count: int) -> Dictionary[int, String]:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = paths[seat]
	return assignments
