extends "res://tests/support/poker_gut_test.gd"

const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")
const Measurement := preload("res://scripts/gui/gui_snapshot_measurement.gd")
const HORIZONTAL_CONTENT_PADDING: float = 12.0
const HERO_HORIZONTAL_CONTENT_PADDING: float = 4.0


func test_web_fallback_font_keeps_complete_opponent_and_hero_action_amounts() -> void:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 6)
	var view: GameView = descriptor.view
	view.pot_amount = 645
	view.call_amount = 310
	view._seats[1].bet_this_round = 310
	view._action_history = [
		PublicActionRecord.new(1, PlayerAction.Kind.RAISE, 310),
		PublicActionRecord.new(2, PlayerAction.Kind.BET, 7),
		PublicActionRecord.new(3, PlayerAction.Kind.CALL, 42),
		PublicActionRecord.new(4, PlayerAction.Kind.BET, 120),
		PublicActionRecord.new(5, PlayerAction.Kind.ALL_IN, 1000),
		PublicActionRecord.new(0, PlayerAction.Kind.RAISE, 310),
	]
	var table: PokerTableController = await _phone_view_table(
		view, {1: "Linh", 2: "Bao", 3: "Lior", 4: "Haruto", 5: "Kwame"}
	)
	var expected_actions: Dictionary[int, String] = {
		1: "Raise to 310", 2: "Bet to 7", 3: "Call to 42", 4: "Bet to 120", 5: "All-in to 1000"
	}
	for seat: int in expected_actions:
		var badge := _seat_action_badge(table, seat)
		assert_eq(badge.text, expected_actions[seat], "seat %d complete copy" % seat)
		_assert_web_font_content_fits(badge, "seat %d" % seat)
		var token: GuiTableSeatView = table._seat_widgets[seat]
		for field_name: String in ["Name", "Stack", "Badge", "HoleCards"]:
			var field: Control = token.field(field_name)
			assert_false(
				badge.get_global_rect().intersects(field.get_global_rect()),
				"seat %d action must not cover %s" % [seat, field_name],
			)

	var hero_badge := table.get_node("%PhoneHeroActionBadge") as Label
	for hero_case: Dictionary in [
		{"kind": PlayerAction.Kind.CHECK, "amount": 0, "text": "Chk"},
		{"kind": PlayerAction.Kind.CALL, "amount": 310, "text": "C310"},
		{"kind": PlayerAction.Kind.BET, "amount": 120, "text": "B120"},
		{"kind": PlayerAction.Kind.RAISE, "amount": 310, "text": "R310"},
		{"kind": PlayerAction.Kind.ALL_IN, "amount": 1000, "text": "A1000"},
		{"kind": PlayerAction.Kind.FOLD, "amount": 0, "text": "F"},
	]:
		view._action_history[-1] = PublicActionRecord.new(
			0, hero_case.kind as PlayerAction.Kind, hero_case.amount
		)
		table.bind_view(view, {}, {})
		await _settle()
		assert_eq(hero_badge.text, hero_case.text, "hero complete copy")
		_assert_web_font_content_fits(
			hero_badge, "hero %s" % hero_case.text, HERO_HORIZONTAL_CONTENT_PADDING
		)


func _phone_view_table(view: GameView, names: Dictionary[int, String]) -> PokerTableController:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(360.0, 780.0)
	add_child_autofree(table)
	table.bind_view(view, {}, names)
	await _settle()
	return table


func _seat_action_badge(table: PokerTableController, seat: int) -> Label:
	var seat_panel := (
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as GuiTableSeatView
	)
	return seat_panel.action_badge


func _assert_web_font_content_fits(
	label: Label, context: String, horizontal_padding: float = HORIZONTAL_CONTENT_PADDING
) -> void:
	var font: Font = label.get_theme_font("font")
	assert_eq(font, ThemeDB.fallback_font, "%s uses the exported fallback-font path" % context)
	var value: GuiLayoutElement = Measurement.element(label, label, &"complete_action")
	assert_lte(
		value.required_size.x + horizontal_padding,
		label.size.x,
		"%s must fit '%s' with horizontal padding" % [context, label.text],
	)
	assert_lte(value.required_size.y, value.allocated_size.y + 0.5, context + " complete lines")
	assert_true(value.max_lines < 0 or value.line_count <= value.max_lines, context + " line limit")
	assert_false(label.clip_text, "%s must not hide clipped glyphs" % context)
	assert_eq(
		label.text_overrun_behavior,
		TextServer.OVERRUN_NO_TRIMMING,
		"%s must not ellipsize action content" % context,
	)


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
