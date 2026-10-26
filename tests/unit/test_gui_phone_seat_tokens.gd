extends "res://tests/support/poker_gut_test.gd"

const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const GuiPhoneSeatLayoutScript := preload("res://scripts/gui/gui_phone_seat_layout.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")


func test_phone_opponents_use_canonical_tokens_with_public_state() -> void:
	var table: PokerTableController = await _phone_table(&"all-in-runout", 4)
	var surface: Control = table.get_node("TableMargin/Felt/TableSurface")
	var expected_rects: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(
		surface.size, 4
	)
	for seat: int in range(1, 4):
		var token := _seat(table, seat)
		assert_eq(Rect2(token.position, token.size), expected_rects[seat])
		assert_not_null(token.find_child("Name", true, false))
		assert_not_null(token.find_child("Stack", true, false))
		assert_null(token.find_child("Avatar", true, false))
		assert_not_null(token.find_child("DetailsButton", true, false))
	var all_in_badge: Label = _seat(table, 3).find_child("Badge", true, false)
	assert_string_contains(all_in_badge.text, "AI")
	assert_string_contains((_seat(table, 1).find_child("Badge", true, false) as Label).text, "BB")
	assert_string_contains((_seat(table, 3).find_child("Badge", true, false) as Label).text, "D")

	var public_state: Dictionary = GuiVisualStateFixturesScript.by_id(&"bot-turn", 4)
	public_state.view._seats[1].folded = true
	table.bind_view(public_state.view, {}, {})
	await _settle()
	var folded_acting_badge := _seat(table, 1).find_child("Badge", true, false) as Label
	assert_has(folded_acting_badge.text.split(" "), "F")


func test_seven_player_tokens_keep_readable_text_and_full_size_detail_targets() -> void:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 7)
	var view: GameView = descriptor.view
	var actions: Array[PublicActionRecord] = [
		PublicActionRecord.new(1, PlayerAction.Kind.CHECK, 0),
		PublicActionRecord.new(2, PlayerAction.Kind.CALL, 10),
		PublicActionRecord.new(3, PlayerAction.Kind.BET, 20),
		PublicActionRecord.new(4, PlayerAction.Kind.RAISE, 40),
		PublicActionRecord.new(5, PlayerAction.Kind.ALL_IN, 900),
		PublicActionRecord.new(6, PlayerAction.Kind.FOLD, 0),
	]
	view._action_history = actions
	view._seats[5].all_in = true
	view._seats[6].folded = true
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(360, 640)
	add_child_autofree(table)
	var names: Dictionary[int, String] = {
		1: "Priyanka", 2: "Benedikt", 3: "Aleksia", 4: "Santiago", 5: "Youssef", 6: "Kwame"
	}
	table.bind_view(view, {}, names)
	await _settle()
	var expected_actions: Dictionary[int, String] = {
		1: "Chk", 2: "C10", 3: "B20", 4: "R40", 5: "A900", 6: "F"
	}
	for seat: int in range(1, 7):
		var token := _seat(table, seat)
		var name_label := token.find_child("Name", true, false) as Label
		var stack_label := token.find_child("Stack", true, false) as Label
		var hole_cards := token.find_child("HoleCards", true, false) as Control
		var state_badge := token.find_child("Badge", true, false) as Label
		var action_badge := token.find_child("ActionBadge", true, false) as Label
		var details_button := token.find_child("DetailsButton", true, false) as Button
		var name_width: float = (
			name_label
			. get_theme_font("font")
			. get_string_size(
				name_label.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				name_label.get_theme_font_size("font_size"),
			)
			. x
		)
		var stack_width: float = (
			stack_label
			. get_theme_font("font")
			. get_string_size(
				stack_label.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				stack_label.get_theme_font_size("font_size"),
			)
			. x
		)
		assert_lte(name_width, name_label.size.x, "seat %d full name" % seat)
		assert_lte(stack_width, stack_label.size.x, "seat %d full stack" % seat)
		assert_gte(name_label.get_theme_font_size("font_size"), 20, "seat %d name" % seat)
		assert_gte(stack_label.get_theme_font_size("font_size"), 20, "seat %d stack" % seat)
		assert_eq(hole_cards.get_child_count(), 2, "seat %d hole-card fields" % seat)
		if action_badge.visible:
			assert_eq(action_badge.text, expected_actions[seat], "seat %d action" % seat)
			assert_false(
				action_badge.get_global_rect().intersects(name_label.get_global_rect()),
				(
					"seat %d action %s name %s"
					% [seat, action_badge.get_global_rect(), name_label.get_global_rect()]
				),
			)
			assert_false(
				action_badge.get_global_rect().intersects(stack_label.get_global_rect()),
				(
					"seat %d action %s stack %s"
					% [seat, action_badge.get_global_rect(), stack_label.get_global_rect()]
				),
			)
			assert_false(
				action_badge.get_global_rect().intersects(state_badge.get_global_rect()),
				(
					"seat %d action %s state %s"
					% [seat, action_badge.get_global_rect(), state_badge.get_global_rect()]
				),
			)
			assert_false(
				action_badge.get_global_rect().intersects(hole_cards.get_global_rect()),
				(
					"seat %d action %s cards %s"
					% [seat, action_badge.get_global_rect(), hole_cards.get_global_rect()]
				),
			)
		assert_eq(details_button.get_rect(), Rect2(Vector2.ZERO, token.size), "seat %d" % seat)
		assert_gte(details_button.size.y, 48.0, "seat %d detail target" % seat)
		assert_string_contains(details_button.tooltip_text, name_label.text)


func test_phone_state_badges_hide_empty_cells_and_render_compact_fold_without_clip() -> void:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 6)
	descriptor.view._seats[1].folded = true
	var table: PokerTableController = await _phone_view_table(descriptor.view)
	var found_empty_badge: bool = false
	var found_fold_badge: bool = false
	for seat: int in range(1, 6):
		var badge := _seat(table, seat).find_child("Badge", true, false) as Label
		if badge.text.is_empty():
			found_empty_badge = true
			assert_false(badge.visible, "empty seat %d badge" % seat)
		if "F" in badge.text.split(" "):
			found_fold_badge = true
			assert_lte(
				badge.get_combined_minimum_size().x,
				badge.size.x,
				"Fold-state badge including its frame must not clip",
			)
	assert_true(found_empty_badge)
	assert_true(found_fold_badge)


func test_phone_token_and_detail_never_reveal_private_opponent_cards() -> void:
	var table: PokerTableController = await _phone_table(&"human-turn-preflop", 4)
	var hidden_token := _seat(table, 3)
	assert_not_null(hidden_token.find_child("CardBack1", true, false))
	assert_null(hidden_token.find_child("ShowdownCard1", true, false))

	(hidden_token.find_child("DetailsButton", true, false) as Button).emit_signal("pressed")
	var overlay := table.get_node("TableMargin/Felt/TableSurface/SeatDetailOverlay")
	assert_eq((overlay.find_child("Name", true, false) as Label).text, "Fixture Player 4")
	assert_not_null(overlay.find_child("CardBack1", true, false))
	assert_null(overlay.find_child("ShowdownCard1", true, false))
	var close_button := overlay.find_child("CloseButton", true, false) as Button
	assert_eq(close_button.text, "Close")
	assert_gte(close_button.custom_minimum_size.y, 48.0)

	var showdown: Dictionary = GuiVisualStateFixturesScript.by_id(&"showdown-long", 4)
	table.bind_view(showdown.view, {}, {})
	await get_tree().process_frame
	overlay = table.get_node("TableMargin/Felt/TableSurface/SeatDetailOverlay")
	assert_eq((overlay.find_child("Name", true, false) as Label).text, "Fixture Player 4")
	assert_null(overlay.find_child("CardBack1", true, false))
	assert_not_null(overlay.find_child("ShowdownCard1", true, false))
	(overlay.find_child("CloseButton", true, false) as Button).emit_signal("pressed")
	assert_false(overlay.visible)


func test_folded_and_busted_phone_tokens_keep_two_empty_card_fields() -> void:
	var folded_descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 4)
	folded_descriptor.view._seats[2].folded = true
	var folded_table: PokerTableController = await _phone_view_table(folded_descriptor.view)
	_assert_empty_card_fields(_seat(folded_table, 2))

	var eliminated_descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"elimination", 4)
	var eliminated_table: PokerTableController = await _phone_view_table(eliminated_descriptor.view)
	var busted_seat: int = Table.NO_SEAT
	for player_view: PlayerView in eliminated_descriptor.view.seats:
		if player_view.busted and player_view.seat != eliminated_descriptor.view.hero_seat:
			busted_seat = player_view.seat
			break
	assert_ne(busted_seat, Table.NO_SEAT)
	_assert_empty_card_fields(_seat(eliminated_table, busted_seat))


func test_phone_profile_override_and_resize_restore_full_panels() -> void:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 4)
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1280, 720)
	add_child_autofree(table)
	table.bind_view(descriptor.view, {}, {})
	await _settle()
	assert_not_null(_seat(table, 1).find_child("Avatar", true, false))

	table.set_layout_profile_override(GuiLayoutProfileScript.Kind.PHONE_LANDSCAPE)
	await _settle()
	assert_eq(table.get_layout_profile(), GuiLayoutProfileScript.Kind.PHONE_LANDSCAPE)
	assert_null(_seat(table, 1).find_child("Avatar", true, false))

	table.set_layout_profile_override(GuiLayoutProfileScript.AUTOMATIC)
	await _settle()
	assert_eq(table.get_layout_profile(), GuiLayoutProfileScript.Kind.DESKTOP)
	assert_not_null(_seat(table, 1).find_child("Avatar", true, false))
	assert_not_null(_seat(table, 1).find_child("Identity", true, false))

	table.size = Vector2(390, 844)
	await _settle()
	assert_null(_seat(table, 1).find_child("Avatar", true, false))
	table.size = Vector2(1280, 720)
	await _settle()
	assert_not_null(_seat(table, 1).find_child("Avatar", true, false))


func _phone_table(state_id: StringName, player_count: int) -> PokerTableController:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(state_id, player_count)
	return await _phone_view_table(descriptor.view)


func _phone_view_table(view: GameView) -> PokerTableController:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(390, 844)
	add_child_autofree(table)
	table.bind_view(view, {}, {})
	await _settle()
	return table


func _seat(table: PokerTableController, seat: int) -> PanelContainer:
	return table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as PanelContainer


func _assert_empty_card_fields(token: PanelContainer) -> void:
	var cards := token.find_child("HoleCards", true, false) as Control
	assert_eq(cards.get_child_count(), 2)
	assert_not_null(token.find_child("HoleCardField1", true, false))
	assert_not_null(token.find_child("HoleCardField2", true, false))
	assert_null(token.find_child("CardBack1", true, false))
	assert_null(token.find_child("ShowdownCard1", true, false))


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
