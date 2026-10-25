# gdlint: disable=max-public-methods
extends "res://tests/support/poker_gut_test.gd"

const AvatarAssignmentServiceScript := preload("res://scripts/gui/avatar_assignment_service.gd")
const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const MainScene := preload("res://scenes/main.tscn")
const PokerTableScene := preload("res://scenes/poker_table.tscn")


func test_game_window_starts_at_full_hd_size() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080)


func test_startup_and_table_fonts_are_scaled_by_one_point_eight() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	assert_eq(main.theme.default_font_size, 29)
	assert_eq(main.get_node("%Title").get_theme_font_size("font_size"), 50)
	assert_eq(main.get_node("%Description").get_theme_font_size("font_size"), 29)
	assert_eq(main.get_node("%PlayerCountInput").get_theme_font_size("font_size"), 29)
	assert_eq(main.get_node("%StartButton").get_theme_font_size("font_size"), 29)

	var table = main.get_node("PokerTable")
	table.bind_view(_table_view(2), _avatar_assignments(2))
	assert_eq(table.theme.default_font_size, 29)
	assert_eq(table.find_child("BoardLabel", true, false).get_theme_font_size("font_size"), 29)
	assert_eq(table.find_child("PotLabel", true, false).get_theme_font_size("font_size"), 29)
	assert_eq(table.find_child("WagerLabel", true, false).get_theme_font_size("font_size"), 29)
	assert_eq(
		table.get_node("%CardSlots/CardSlot1/Content/Rank").get_theme_font_size("font_size"), 32
	)
	assert_eq(table.find_child("Name", true, false).get_theme_font_size("font_size"), 46)


func test_startup_form_uses_readable_portrait_mobile_layout_and_resets_after_rotation() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1920, 3840)
	main._refresh_startup_layout()

	var panel: PanelContainer = main.get_node("Center/Panel")
	assert_true(is_equal_approx(panel.custom_minimum_size.x, 1612.8))
	assert_eq(main.get_node("%Title").get_theme_font_size("font_size"), 128)
	assert_eq(main.get_node("%StartButton").get_theme_font_size("font_size"), 64)
	assert_eq(main.get_node("%Fields").columns, 1)

	main.size = Vector2(1920, 1080)
	main._refresh_startup_layout()

	assert_true(is_equal_approx(panel.custom_minimum_size.x, 883.2))
	assert_eq(main.get_node("%Title").get_theme_font_size("font_size"), 64)
	assert_eq(main.get_node("%StartButton").get_theme_font_size("font_size"), 32)
	assert_eq(main.get_node("%Fields").columns, 2)
	for input_path: NodePath in [
		^"%PlayerCountInput",
		^"%StartingStackInput",
		^"%SmallBlindInput",
		^"%BigBlindInput",
		^"%StartButton",
	]:
		assert_gte(main.get_node(input_path).custom_minimum_size.y, 48.0, str(input_path))

	main.size = Vector2(950, 532)
	main._refresh_startup_layout()
	assert_true(is_equal_approx(panel.custom_minimum_size.x, 798.0))
	assert_eq(main.get_node("%Title").get_theme_font_size("font_size"), 40)
	assert_eq(main.get_node("%StartButton").get_theme_font_size("font_size"), 20)
	assert_eq(main.get_node("%Form").get_theme_constant("separation"), 8)
	assert_eq(main.get_node("%Fields").columns, 2)

	main.size = Vector2(768, 1024)
	main._refresh_startup_layout()
	assert_true(is_equal_approx(panel.custom_minimum_size.x, 645.12))
	assert_eq(main.get_node("%Title").get_theme_font_size("font_size"), 40)
	assert_eq(main.get_node("%Fields").columns, 1)
	assert_false(main.get_node("%FormStatus").visible)


func test_phone_explains_its_limit_without_changing_the_six_player_default() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var player_count_input := main.get_node("%PlayerCountInput") as LineEdit
	var guidance := main.get_node("%PhonePlayerCountGuidance") as Label

	main.size = Vector2(390, 844)
	main._refresh_startup_layout()
	assert_true(guidance.visible)
	assert_eq(guidance.text, "Phone supports 2–7 players; 4 recommended. Default: 6.")
	assert_eq(main.get_node("%PlayerCountLabel").text, "Players (2–7)")
	assert_same(guidance.get_parent(), main.get_node("%Form"))
	assert_eq(player_count_input.text, "6")

	main.size = Vector2(1920, 1080)
	main._refresh_startup_layout()
	assert_false(guidance.visible)
	assert_eq(guidance.get_parent().name, &"PlayerCountField")
	assert_eq(player_count_input.text, "6")
	assert_eq(main.get_node("%PlayerCountLabel").text, "Participants (2–9)")


func test_phone_rejects_eight_players_without_clamping_the_entered_value() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var input := main.get_node("%PlayerCountInput") as LineEdit
	var error := main.get_node("%PlayerCountError") as Label

	main.size = Vector2(390, 844)
	main._refresh_startup_layout()
	input.text = "8"
	main._on_start_pressed()
	assert_eq(input.text, "8")
	assert_eq(
		error.text,
		"Phone layouts support 2–7 players. Enlarge the window to start with 8 or 9.",
	)
	assert_true(main.get_node("Center").visible)

	main.size = Vector2(1920, 1080)
	main._refresh_startup_layout()
	assert_eq(input.text, "8")
	assert_eq(main.get_node("%PlayerCountLabel").text, "Participants (2–9)")


func test_startup_numeric_inputs_use_the_same_in_canvas_number_keypad_as_the_table() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)

	for input_path: NodePath in [
		^"%PlayerCountInput",
		^"%StartingStackInput",
		^"%SmallBlindInput",
		^"%BigBlindInput",
	]:
		var input := main.get_node(input_path) as LineEdit
		assert_false(input.virtual_keyboard_enabled, str(input_path))
		assert_false(input.virtual_keyboard_show_on_focus, str(input_path))
		assert_eq(input.virtual_keyboard_type, LineEdit.KEYBOARD_TYPE_NUMBER, str(input_path))

	var player_count_input := main.get_node("%PlayerCountInput") as LineEdit
	main.show_numeric_keypad(player_count_input)
	var keypad := main.get_node("StartupNumberKeypad") as WagerKeypad
	assert_true(keypad.visible)
	assert_eq(keypad.get_node("Content/Title").text, "Enter number")
	assert_false(keypad.get_node("Content/Range").visible)
	keypad.get_node("Content/Keys/Key2").emit_signal("pressed")
	assert_eq(player_count_input.text, "6")
	assert_eq(keypad.get_node("Content/Value").text, "62")
	keypad.get_node("Content/Done").emit_signal("pressed")
	assert_eq(player_count_input.text, "62")


func test_startup_numeric_input_dispatch_depends_on_touch_not_layout_profile() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	var input := main.get_node("%PlayerCountInput") as LineEdit
	var keypad := main.get_node("StartupNumberKeypad") as WagerKeypad
	var profiles: Array[int] = [
		GuiLayoutProfileScript.Kind.PHONE_PORTRAIT,
		GuiLayoutProfileScript.Kind.TABLET,
		GuiLayoutProfileScript.Kind.SMALL_DESKTOP,
		GuiLayoutProfileScript.Kind.DESKTOP,
	]

	for profile: int in profiles:
		main.set_layout_profile_override(profile)
		input.gui_input.emit(_left_mouse_press())
		assert_false(keypad.visible, "mouse profile %d" % profile)
		input.gui_input.emit(_touch_press())
		assert_true(keypad.visible, "touch profile %d" % profile)
		keypad.cancel()


func test_startup_touch_to_keyboard_transition_cancels_only_the_draft() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	var input := main.get_node("%PlayerCountInput") as LineEdit
	var keypad := main.get_node("StartupNumberKeypad") as WagerKeypad
	main.set_layout_profile_override(GuiLayoutProfileScript.Kind.DESKTOP)

	input.gui_input.emit(_touch_press())
	keypad.get_node("Content/Keys/Key2").emit_signal("pressed")
	assert_eq(input.text, "6")
	assert_eq(keypad.get_node("Content/Value").text, "62")

	input.gui_input.emit(_left_mouse_press())
	assert_false(keypad.visible)
	assert_eq(input.text, "6")
	# Godot owns physical-keyboard editing once pointer focus is allowed through.
	input.text = "10"
	input.text_submitted.emit(input.text)
	assert_eq(
		(main.get_node("%PlayerCountError") as Label).text,
		"Player count must be between 2 and 9.",
	)
	input.text = "6"


func test_return_to_startup_reveals_the_completion_status() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main._return_to_startup("Tournament complete.")

	var form_status := main.get_node("%FormStatus") as Label
	assert_true(main.get_node("Center").visible)
	assert_eq(form_status.text, "Tournament complete.")
	assert_true(form_status.visible)


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

	var first = service.assign_for_tournament(4, _avatar_rng(7331))
	var second = service.assign_for_tournament(4, _avatar_rng(7331))

	assert_true(first.is_ok())
	assert_eq(first.assignments, second.assignments)
	assert_eq(first.assignments.values().size(), 4)
	var distinct_assignments: Dictionary = {}
	for avatar_path: String in first.assignments.values():
		distinct_assignments[avatar_path] = true
	assert_eq(distinct_assignments.size(), 4)


func test_avatar_assignment_rejects_an_insufficient_catalog() -> void:
	var catalog := GuiAvatarCatalogScript.new(PackedStringArray(["a", "b"]))
	var result = AvatarAssignmentServiceScript.new(catalog).assign_for_tournament(3, _avatar_rng(1))

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
		var surface_rect := Rect2(Vector2.ZERO, _surface_size(table))
		var distinct_positions: Dictionary[Vector2, bool] = {}
		var placed_rects: Array[Rect2] = []
		assert_eq(seat_rects.size(), player_count)
		for seat: int in seat_rects:
			var seat_rect: Rect2 = seat_rects[seat]
			var context := "seat %d at %d players in %s" % [seat, player_count, viewport_size]
			distinct_positions[seat_rect.position] = true
			var seat_node: Control = table.get_node(
				"TableMargin/Felt/TableSurface/Seats/Seat%d" % seat
			)
			var phone_layout: bool = table.get_layout_profile() in [0, 1]
			if phone_layout and seat == 0:
				assert_false(
					seat_node.is_visible_in_tree(), "%s uses bottom human region" % context
				)
				assert_true(table.get_node("%PhoneHeroSummary").is_visible_in_tree())
				continue
			assert_true(surface_rect.encloses(seat_rect), context)
			for placed_rect: Rect2 in placed_rects:
				assert_false(
					seat_rect.intersects(placed_rect),
					"%s: %s intersects %s" % [context, seat_rect, placed_rect]
				)
			placed_rects.append(seat_rect)
			var avatar := seat_node.find_child("Avatar", true, false) as TextureRect
			if phone_layout:
				assert_true(seat_node.is_visible_in_tree(), context)
				assert_null(avatar, "%s phone opponents hide avatars" % context)
			else:
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
				424.0,
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
		var surface_width: float = _surface_size(table).x
		for seat: int in range(1, (player_count + 1) / 2):
			var mirrored_seat: int = player_count - seat
			var seat_center: Vector2 = seat_rects[seat].get_center()
			var mirrored_center: Vector2 = seat_rects[mirrored_seat].get_center()
			var context := "%d-player seats %d and %d" % [player_count, seat, mirrored_seat]
			assert_almost_eq(seat_center.x + mirrored_center.x, surface_width, 0.01, context)
			assert_almost_eq(seat_center.y, mirrored_center.y, 0.01, context)


func test_position_markers_follow_clockwise_core_order_at_every_table_size() -> void:
	for player_count: int in range(2, 10):
		var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = Vector2(1920, 1080)

		for button_seat: int in range(player_count):
			var view: GameView = _hero_table_view(player_count)
			view.button_seat = button_seat
			view.small_blind_seat = button_seat
			view.big_blind_seat = posmod(button_seat + 1, player_count)
			if player_count > 2:
				view.small_blind_seat = posmod(button_seat + 1, player_count)
				view.big_blind_seat = posmod(button_seat + 2, player_count)
			table.bind_view(view, _avatar_assignments(player_count))
			table.show()
			await get_tree().process_frame

			var seat_rects: Dictionary[int, Rect2] = table.get_seat_rects()
			var dealer_center: Vector2 = seat_rects[button_seat].get_center()
			var small_blind_center: Vector2 = seat_rects[view.small_blind_seat].get_center()
			var big_blind_center: Vector2 = seat_rects[view.big_blind_seat].get_center()
			var surface_center: Vector2 = _surface_size(table) * 0.5
			var context: String = "%d players, button seat %d" % [player_count, button_seat]

			assert_eq(
				view.hero_seat, 0, "%s must preserve the recipient's core seat identity" % context
			)
			assert_gt(
				seat_rects[view.hero_seat].get_center().y,
				_surface_size(table).y * 0.75,
				"%s must keep the human seat at the bottom" % context
			)
			if player_count == 2:
				assert_eq(
					dealer_center,
					small_blind_center,
					"%s heads-up dealer is the small blind" % context
				)
				assert_almost_eq(
					_clockwise_distance(small_blind_center, big_blind_center, surface_center),
					PI,
					0.001,
					"%s big blind is opposite the dealer/small blind" % context
				)
			else:
				_assert_clockwise_after(
					dealer_center,
					small_blind_center,
					surface_center,
					"%s dealer to small blind" % context
				)
				_assert_clockwise_after(
					small_blind_center,
					big_blind_center,
					surface_center,
					"%s small blind to big blind" % context
				)


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
	view.small_blind = 5
	view.big_blind = 10
	view.blind_level = 2
	view.completed_hands_in_level = 3
	view.hands_until_next_level = 9
	view._seats = [_player_view(0, 5), _player_view(1, 10)]

	var avatar_paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var avatar_assignments: Dictionary[int, String] = {0: avatar_paths[0], 1: avatar_paths[1]}
	table.bind_view(view, avatar_assignments)

	assert_eq(table.board_card_count, 3)
	assert_eq(table.wager_amounts, {0: 5, 1: 10})
	assert_eq(table.displayed_pot_amount, 55)
	assert_eq(table.get_node("%CardSlots").get_child_count(), 5)
	assert_string_contains(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/CenterZone/BoardZone/BoardContent/BoardLabel")
			. text
		),
		"Community cards"
	)
	assert_eq(
		table.get_node("%CardSlots/CardSlot1/Content/Rank").get_theme_color("font_color"),
		Color("172331")
	)
	assert_eq(
		table.get_node("%CardSlots/CardSlot2/Content/Rank").get_theme_color("font_color"),
		Color("ad2636")
	)
	assert_eq(
		table.get_node("%CardSlots/CardSlot3/Content/Rank").get_theme_color("font_color"),
		Color("ad2636")
	)
	assert_eq(
		table.get_node("%CardSlots/CardSlot1").get_theme_stylebox("panel").bg_color, Color("f5f0dc")
	)
	assert_eq(
		table.get_node("%CardSlots/CardSlot4").get_theme_stylebox("panel").bg_color, Color("294c5c")
	)
	assert_eq(
		table.get_node("TableMargin/Felt/TableSurface/CenterZone/WagerZone/WagerLabel").text,
		"Wagers  •  2 active"
	)
	assert_eq(
		table.get_node("TableMargin/Felt/TableSurface/CenterZone/PotZone/PotLabel").text,
		"Pot: 55 | SB 5 BB 10 | L2"
	)
	var name_label := table.find_child("Name", true, false) as Label
	assert_not_null(name_label)
	assert_eq(name_label.autowrap_mode, TextServer.AUTOWRAP_OFF)
	assert_true(name_label.clip_text)
	var avatar := table.find_child("Avatar", true, false) as TextureRect
	assert_not_null(avatar)
	assert_not_null(avatar.texture)
	assert_eq(avatar.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)


func test_center_zone_is_centered_from_its_resolved_bounds() -> void:
	var table = PokerTableScene.instantiate()
	table.hide()
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1920, 1080)
	table.bind_view(_hero_table_view(6), _avatar_assignments(6))
	table.show()
	await get_tree().process_frame
	await get_tree().process_frame

	var center_zone: Control = table.get_node("TableMargin/Felt/TableSurface/CenterZone")
	assert_almost_eq(center_zone.get_rect().get_center().x, _surface_size(table).x * 0.5, 0.01)
	assert_almost_eq(center_zone.get_rect().get_center().y, _surface_size(table).y * 0.5, 0.01)


func test_community_cards_keep_fixed_equal_bounds_when_wide_ranks_are_revealed() -> void:
	for viewport_size: Vector2 in [Vector2(950, 532), Vector2(1920, 1080)]:
		var table = PokerTableScene.instantiate()
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = viewport_size
		var view := _hero_table_view(6)
		table.bind_view(view, _avatar_assignments(6))
		table.show()
		await get_tree().process_frame
		await get_tree().process_frame

		var card_slots: HBoxContainer = table.get_node("%CardSlots")
		var preflop_size: Vector2 = card_slots.size
		view._community_cards = [
			CardData.new(10, CardData.Suit.HEARTS),
			CardData.new(12, CardData.Suit.CLUBS),
			CardData.new(3, CardData.Suit.HEARTS),
			CardData.new(6, CardData.Suit.DIAMONDS),
			CardData.new(14, CardData.Suit.SPADES),
		]
		table.bind_view(view, _avatar_assignments(6))
		await get_tree().process_frame
		await get_tree().process_frame

		assert_eq(card_slots.size, preflop_size, str(viewport_size))
		var expected_card_size := Vector2(52, 57) if viewport_size.x < 1200.0 else Vector2(68, 76)
		var board_zone: Panel = table.get_node("TableMargin/Felt/TableSurface/CenterZone/BoardZone")
		var board_rect := board_zone.get_global_rect()
		for card: Control in card_slots.get_children():
			assert_eq(card.size, expected_card_size, "%s %s" % [viewport_size, card.name])
			assert_true(
				board_rect.encloses(card.get_global_rect()),
				"%s must enclose %s" % [viewport_size, card.name],
			)
			var rank: Label = card.get_node("Content/Rank")
			var suit: TextureRect = card.get_node("Content/Suit")
			assert_true(card.get_global_rect().encloses(rank.get_global_rect()))
			assert_true(card.get_global_rect().encloses(suit.get_global_rect()))
			assert_lte(
				rank.get_global_rect().end.x,
				suit.get_global_rect().position.x,
				"%s rank and suit must use separate columns" % viewport_size,
			)
			var rank_text_width: float = (
				rank
				. get_theme_font("font")
				. get_string_size(
					rank.text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					rank.get_theme_font_size("font_size"),
				)
				. x
			)
			assert_lte(
				rank_text_width, rank.size.x, "%s %s rank must fit" % [viewport_size, rank.text]
			)
			var minimum_suit_width: float = 20.0 if viewport_size.x < 1200.0 else 26.0
			assert_gte(
				suit.size.x,
				minimum_suit_width,
				"%s %s suit must remain distinguishable" % [viewport_size, card.name],
			)


func test_player_facing_gui_text_never_falls_below_twenty_pixels() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	_assert_minimum_gui_font_size(main)

	var table = PokerTableScene.instantiate()
	table.hide()
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(390, 780)
	table.bind_view(_hero_table_view(6), _avatar_assignments(6))
	table.show()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_minimum_gui_font_size(table)


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
	assert_eq(table.get_node("%CardSlots/CardSlot1/Content/Rank").text, "A")
	assert_eq(
		table.get_node("%CardSlots/CardSlot1/Content/Suit").texture.resource_path,
		"res://assets/ui/club.svg"
	)
	assert_eq(table.get_node("%CardSlots/CardSlot1/Content/Suit").custom_minimum_size, Vector2.ZERO)
	assert_string_contains(table.get_node(seat_prefix % 0 + "Header/Marker").text, "D")
	assert_string_contains(table.get_node(seat_prefix % 1 + "Header/Marker").text, "SB")
	assert_eq(table.get_node(seat_prefix % 2 + "Header/Marker").text, "BB")
	assert_eq(table.get_node(seat_prefix % 0 + "Header/Identity/Stack").text, "95 chips")
	assert_eq(table.get_node(seat_prefix % 0 + "HeroCards/HeroCard1/Content/Rank").text, "K")
	assert_eq(
		table.get_node(seat_prefix % 0 + "HeroCards/HeroCard1/Content/Suit").texture.resource_path,
		"res://assets/ui/diamond.svg"
	)
	assert_not_null(table.get_node(seat_prefix % 1 + "Footer/HoleCards/CardBack1"))
	assert_string_contains(table.get_node(seat_prefix % 2 + "Header/Identity/Name").text, "Out")

	view._community_cards.append(CardData.new(2, CardData.Suit.DIAMONDS))
	view.pot_amount = 65
	view.small_blind = 5
	view.big_blind = 10
	view.blind_level = 1
	view.completed_hands_in_level = 0
	view.hands_until_next_level = 10
	view._pots = [
		PotLayer.new(40, 15, [0, 1, 2], [0, 1, 2]),
		PotLayer.new(25, 25, [0, 1], [0, 1]),
	]
	table.bind_view(view, _avatar_assignments(3))
	await get_tree().process_frame

	var card_slots: HBoxContainer = table.get_node(
		"TableMargin/Felt/TableSurface/CenterZone/BoardZone/BoardContent/CardSlots"
	)
	var third_card: PanelContainer = card_slots.get_child(2)
	assert_eq(third_card.get_node("Content/Rank").text, "2")
	assert_eq(
		third_card.get_node("Content/Suit").texture.resource_path, "res://assets/ui/diamond.svg"
	)
	assert_eq(
		table.find_child("PotLabel", true, false).text,
		"Pot: 65 | SB 5 BB 10 | L1",
	)


func test_table_refreshes_from_a_recipient_safe_match_view() -> void:
	var adapter = GuiStartupConfigAdapter.new()
	assert_true(adapter.try_start())
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(adapter.match_instance, 0, _avatar_assignments(6))

	assert_eq(table.displayed_hero_cards.size(), 2)
	var recipient_view: GameView = adapter.match_instance.get_view_for(0)
	var active_opponent_seat: int = Table.NO_SEAT
	for player_view: PlayerView in recipient_view.seats:
		if player_view.seat != recipient_view.hero_seat and not player_view.folded:
			active_opponent_seat = player_view.seat
			break
	assert_ne(active_opponent_seat, Table.NO_SEAT)
	assert_not_null(
		table.get_node(
			(
				"TableMargin/Felt/TableSurface/Seats/Seat%d/Content/Footer/HoleCards/CardBack1"
				% active_opponent_seat
			)
		)
	)
	table.refresh_from_match()
	assert_eq(table.board_card_count, 0)


func test_gui_startup_displays_the_initial_read_only_table() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)

	main.get_node("%StartButton").emit_signal("pressed")

	var table = main.get_node("PokerTable")
	assert_true(table.visible)
	assert_false(main.get_node("Center").visible)
	assert_eq(table.displayed_hero_cards.size(), 2)
	assert_eq(table.board_card_count, 0)
	var assigned_names: Dictionary[int, String] = main.startup_adapter.name_assignments
	var assigned_avatars: Dictionary[int, String] = main.startup_adapter.avatar_assignments
	var hero_name: Label = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat0/Content/Header/Identity/Name"
	)
	var bot_name: Label = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/Identity/Name"
	)
	var bot_avatar: TextureRect = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/AvatarRegion/Avatar"
	)
	assert_eq(hero_name.text, "Human")
	assert_eq(bot_name.text, assigned_names[1])
	assert_eq(bot_avatar.texture.resource_path, assigned_avatars[1])


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
		(
			table
			. bind_view(
				_hero_table_view(player_count),
				_avatar_assignments(player_count),
				_visual_name_assignments(player_count),
			)
		)
		table.show()
		await get_tree().process_frame
		await get_tree().process_frame

		var hero_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0")
		var hero_name: Label = hero_panel.find_child("Name", true, false)
		var hero_card: PanelContainer = hero_panel.find_child("HeroCard1", true, false)
		var hero_status: Label = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Status")
		if table.get_layout_profile() in [0, 1]:
			var action_panel: PanelContainer = table.get_node(
				"TableMargin/Felt/TableSurface/ActionPanel"
			)
			assert_false(hero_panel.visible)
			assert_true(table.get_node("%PhoneHeroSummary").visible)
			assert_gt(action_panel.get_rect().get_center().y, _surface_size(table).y * 0.75)
		else:
			assert_gt(
				(
					Rect2(hero_panel.position, hero_panel.size)
					. merge(hero_status.get_rect())
					. get_center()
					. y
				),
				_surface_size(table).y * 0.75,
			)
		assert_eq(hero_name.text, "Human")
		assert_eq(hero_card.get_node("Content/Rank").text, "A")
		assert_eq(
			hero_card.get_node("Content/Suit").texture.resource_path, "res://assets/ui/heart.svg"
		)
		assert_not_null(hero_card.get_theme_stylebox("panel"))
		for seat: int in range(1, player_count):
			var opponent: PanelContainer = table.get_node(
				"TableMargin/Felt/TableSurface/Seats/Seat%d" % seat
			)
			var name_label: Label = opponent.find_child("Name", true, false)
			assert_eq(name_label.text, _visual_name_assignments(player_count)[seat])


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
	assert_string_contains(table.get_node(seat_prefix % 0 + "Header/Marker").text, "BB")
	for seat: int in range(3):
		var marker: Label = table.get_node(seat_prefix % seat + "Header/Marker")
		assert_false("ACT" in marker.text, "seat %d must not show a redundant ACT marker" % seat)
	assert_eq(table.get_node(seat_prefix % 1 + "Header/Identity/Stack").text, "990 chips")
	var chip_detail: Label = table.get_node(seat_prefix % 1 + "Header/Identity/Stack")
	var avatar_region: Control = table.get_node(seat_prefix % 1 + "Header/AvatarRegion")
	var card_back: Label = table.get_node(seat_prefix % 2 + "Footer/HoleCards/CardBack1")
	assert_eq(chip_detail.get_theme_font_size("font_size"), 44)
	assert_eq(avatar_region.custom_minimum_size, Vector2(112, 112))
	assert_eq(card_back.custom_minimum_size, Vector2(60, 76))
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
	var revealed_card: PanelContainer = showdown_table.get_node(
		seat_prefix % 1 + "Footer/HoleCards/ShowdownCard1"
	)

	assert_eq(revealed_card.get_node("Content/Rank").text, "A")
	assert_eq(
		revealed_card.get_node("Content/Suit").texture.resource_path, "res://assets/ui/spade.svg"
	)
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


func _avatar_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _visual_name_assignments(player_count: int) -> Dictionary[int, String]:
	var bot_names: PackedStringArray = [
		"Youssef", "Leilani", "Alexandr", "Minseo", "Haruto", "Anahit", "Adaeze", "Priya"
	]
	var assignments: Dictionary[int, String] = {0: "Human"}
	for seat: int in range(1, player_count):
		assignments[seat] = bot_names[seat - 1]
	return assignments


func _surface_size(table: PokerTableController) -> Vector2:
	return table.get_node("TableMargin/Felt/TableSurface").size


func _assert_clockwise_after(from: Vector2, to: Vector2, center: Vector2, context: String) -> void:
	var clockwise_distance := _clockwise_distance(from, to, center)
	assert_gt(clockwise_distance, 0.0, context)
	assert_lt(clockwise_distance, PI, context)


func _clockwise_distance(from: Vector2, to: Vector2, center: Vector2) -> float:
	var from_angle: float = atan2(from.x - center.x, center.y - from.y)
	var to_angle: float = atan2(to.x - center.x, center.y - to.y)
	return fposmod(to_angle - from_angle, TAU)


func _assert_minimum_gui_font_size(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit:
		assert_gte(node.get_theme_font_size("font_size"), 20, str(node.get_path()))
	elif node is RichTextLabel:
		assert_gte(node.get_theme_font_size("normal_font_size"), 20, str(node.get_path()))
	for child: Node in node.get_children():
		_assert_minimum_gui_font_size(child)


func _touch_press() -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	return event


func _left_mouse_press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event
