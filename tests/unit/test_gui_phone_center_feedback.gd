extends "res://tests/support/poker_gut_test.gd"

const GuiActionTimingConfigScript := preload("res://scripts/gui/gui_action_timing_config.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")


func test_phone_center_keeps_decision_information_visible_and_moves_blinds_to_more() -> void:
	var table: PokerTableController = await _phone_table(&"human-turn-preflop")

	assert_eq((table.get_node("%BoardLabel") as Label).text, "Community cards")
	assert_eq(table.get_node("%CardSlots").get_child_count(), 5)
	assert_eq((table.get_node("%PotLabel") as Label).text, "Pot: 45")
	assert_eq((table.get_node("%WagerLabel") as Label).text, "Current wager: 10")
	assert_string_contains((table.get_node("%ActionStatus") as Label).text, "Your turn")
	assert_eq((table.get_node("%CheckCallButton") as Button).text, "Call 10")
	assert_false((table.get_node("%PhoneOverflowMenu") as Control).visible)
	assert_false("SB" in (table.get_node("%PotLabel") as Label).text)

	table.get_node("%PhoneMoreButton").emit_signal("pressed")
	assert_true((table.get_node("%PhoneOverflowMenu") as Control).visible)
	var blind_detail := table.get_node("%PhoneBlindLevelDetail") as Label
	assert_eq(blind_detail.text, "Blinds 5 / 10  ·  Level 3  ·  8 hands to next level")

	table.get_node("%PhoneMenuCloseButton").emit_signal("pressed")
	table.get_node("%WagerButton").emit_signal("pressed")
	var keypad := table.get_node("WagerKeypad") as WagerKeypad
	assert_eq((keypad.get_node("Content/Range") as Label).text, "Min 20  •  Max 1000")
	keypad.cancel()


func test_short_landscape_keeps_center_status_and_human_summary_readable() -> void:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 7)
	var table: PokerTableController = await _phone_view_table(
		descriptor.view, Vector2(640.0, 360.0)
	)
	var action_panel := table.get_node("TableMargin/Felt/TableSurface/ActionPanel") as Control
	var more_button := table.get_node("%PhoneMoreButton") as Button
	var hero_stack := table.get_node("%PhoneHeroStack") as Label
	assert_gte(action_panel.size.x, 440.0)
	assert_false(hero_stack.get_global_rect().intersects(more_button.get_global_rect()))
	for label: Label in [table.get_node("%PotLabel"), table.get_node("%WagerLabel")]:
		var rendered_width: float = (
			label
			. get_theme_font("font")
			. get_string_size(
				label.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				label.get_theme_font_size("font_size"),
			)
			. x
		)
		assert_lte(rendered_width, label.size.x, "%s must render in full" % label.name)


func test_phone_keeps_each_seats_latest_round_action_visible_until_street_change() -> void:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 4)
	var view: GameView = descriptor.view
	view._action_history = [
		PublicActionRecord.new(1, PlayerAction.Kind.CALL, 10),
		PublicActionRecord.new(2, PlayerAction.Kind.CALL, 10),
		PublicActionRecord.new(3, PlayerAction.Kind.RAISE, 30),
	]
	var table: PokerTableController = await _phone_view_table(view)
	assert_eq(_visible_action_text(table, 1), "C10")
	assert_eq(_visible_action_text(table, 2), "C10")
	assert_eq(_visible_action_text(table, 3), "R30")
	assert_false((table.get_node("%PhoneHeroActionBadge") as Label).visible)

	view._action_history.append(PublicActionRecord.new(0, PlayerAction.Kind.CHECK, 0))
	view._action_history.append(PublicActionRecord.new(1, PlayerAction.Kind.CALL, 30))
	table.bind_view(view, {}, {})
	await _settle()
	assert_eq((table.get_node("%PhoneHeroActionBadge") as Label).text, "Chk")
	assert_true((table.get_node("%PhoneHeroActionBadge") as Label).visible)
	assert_eq(_visible_action_text(table, 1), "C30")
	assert_eq(_visible_action_text(table, 2), "C10")
	assert_eq(_visible_action_text(table, 3), "R30")
	assert_eq((table.get_node("%PhoneHeroActionBadge") as Label).text, "Chk")

	# Presentation timers from the former transient-badge behavior must not
	# remove any seat's current-round action.
	await get_tree().create_timer(0.03).timeout
	assert_eq(_visible_action_text(table, 1), "C30")
	assert_eq(_visible_action_text(table, 2), "C10")
	assert_eq(_visible_action_text(table, 3), "R30")

	view._seats[3].folded = true
	view._action_history.append(PublicActionRecord.new(3, PlayerAction.Kind.FOLD, 0))
	table.bind_view(view, {}, {})
	(
		table
		. _render_events(
			[
				DomainEvent.new(DomainEvent.Kind.HAND_STARTED),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1, 10),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 2, 10),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 3, 30),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0, 0),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1, 30),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 3, 0),
				DomainEvent.new(DomainEvent.Kind.STREET_CHANGED),
			]
		)
	)
	await _settle()
	for seat: int in range(1, 4):
		assert_eq(_visible_action_text(table, seat), "", "seat %d street reset" % seat)
	assert_false((table.get_node("%PhoneHeroActionBadge") as Label).visible)
	assert_has(
		(_seat(table, 3).find_child("Badge", true, false) as Label).text.split(" "),
		"F",
	)


func test_phone_fold_action_and_durable_state_stay_visible_during_round() -> void:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 4)
	var view: GameView = descriptor.view
	view._seats[3].folded = true
	view._action_history.append(PublicActionRecord.new(3, PlayerAction.Kind.FOLD, 0))
	var table: PokerTableController = await _phone_view_table(view)
	var seat := _seat(table, 3)
	assert_true((seat.find_child("ActionBadge", true, false) as Label).visible)
	assert_not_null(seat.find_child("Badge", true, false))
	assert_has((seat.find_child("Badge", true, false) as Label).text.split(" "), "F")
	assert_null(seat.find_child("ShowdownCard1", true, false))
	assert_not_null(seat.find_child("HoleCardField1", true, false))
	assert_not_null(seat.find_child("HoleCardField2", true, false))

	await get_tree().create_timer(0.03).timeout
	assert_true((seat.find_child("ActionBadge", true, false) as Label).visible)
	assert_eq((seat.find_child("ActionBadge", true, false) as Label).text, "F")
	assert_has((seat.find_child("Badge", true, false) as Label).text.split(" "), "F")
	assert_null(seat.find_child("CardBack1", true, false))


func test_desktop_copy_and_status_rows_are_restored_after_phone_profile() -> void:
	var table: PokerTableController = await _phone_table(&"human-turn-preflop")
	assert_eq((table.get_node("%PotLabel") as Label).text, "Pot: 45")

	table.size = Vector2(1280, 720)
	await _settle()
	assert_string_contains((table.get_node("%PotLabel") as Label).text, "SB 5 BB 10")
	assert_eq((table.get_node("%WagerLabel") as Label).text, "Wagers  •  3 active")
	assert_true(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status").visible)
	assert_null(_seat(table, 2).find_child("ActionBadge", true, false))

	table.size = Vector2(390, 844)
	await _settle()
	assert_eq((table.get_node("%PotLabel") as Label).text, "Pot: 45")
	assert_eq((table.get_node("%WagerLabel") as Label).text, "Current wager: 10")
	assert_not_null(_seat(table, 2).find_child("ActionBadge", true, false))


func _phone_table(state_id: StringName) -> PokerTableController:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(state_id, 4)
	return await _phone_view_table(descriptor.view)


func _phone_view_table(
	view: GameView, table_size: Vector2 = Vector2(390, 844)
) -> PokerTableController:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = table_size
	var timing_config := GuiActionTimingConfigScript.new()
	table.set_action_timing_config(timing_config)
	add_child_autofree(table)
	table.bind_view(view, {}, {})
	await _settle()
	return table


func _seat(table: PokerTableController, seat: int) -> PanelContainer:
	return table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as PanelContainer


func _action_badge(table: PokerTableController, seat: int) -> Label:
	return _seat(table, seat).find_child("ActionBadge", true, false) as Label


func _visible_action_text(table: PokerTableController, seat: int) -> String:
	var badge := _action_badge(table, seat)
	return badge.text if badge.visible else ""


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
