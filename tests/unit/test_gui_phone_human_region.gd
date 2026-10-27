extends "res://tests/support/poker_gut_test.gd"

const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")


func test_phone_region_combines_human_cards_stack_status_and_legal_actions() -> void:
	var table: PokerTableController = await _phone_table(&"human-turn-preflop")
	var action_panel := (
		table.get_node("TableMargin/Felt/TableSurface/ActionPanel") as PanelContainer
	)
	var surface := table.get_node("TableMargin/Felt/TableSurface") as Control

	assert_false(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0").visible)
	assert_true(table.get_node("%PhoneHeroSummary").visible)
	assert_eq(table.get_node("%PhoneHeroCards").get_child_count(), 2)
	assert_eq(table.get_node("%PhoneHeroStack").text, "1000")
	assert_string_contains(table.get_node("%ActionStatus").text, "Your turn")
	assert_almost_eq(action_panel.position.y + action_panel.size.y, surface.size.y, 0.001)
	_assert_visible_action(table, "%FoldButton", "Fold")
	_assert_visible_action(table, "%CheckCallButton", "Call")
	_assert_visible_action(table, "%WagerButton", "Raise")
	_assert_visible_action(table, "%AllInButton", "All-in")
	for hidden_path: String in ["%MinWagerButton", "%PotRaiseButton", "%WagerInput"]:
		assert_false((table.get_node(hidden_path) as Control).visible, hidden_path)


func test_phone_region_tracks_each_legal_action_combination() -> void:
	var table: PokerTableController = await _phone_table(&"human-turn-preflop")
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 4)
	var view: GameView = descriptor.view
	view.call_amount = 0
	view._legal_actions = [PlayerAction.Kind.CHECK]
	table.bind_view(view, {}, {})
	await _settle()
	assert_false(table.get_node("%FoldButton").visible)
	assert_eq(table.get_node("%CheckCallButton").text, "Check")
	assert_true(table.get_node("%CheckCallButton").visible)
	assert_false(table.get_node("%WagerButton").visible)
	assert_false(table.get_node("%AllInButton").visible)

	view._legal_actions = [PlayerAction.Kind.BET, PlayerAction.Kind.ALL_IN]
	table.bind_view(view, {}, {})
	await _settle()
	assert_false(table.get_node("%FoldButton").visible)
	assert_false(table.get_node("%CheckCallButton").visible)
	assert_eq(table.get_node("%WagerButton").text, "Bet")
	assert_true(table.get_node("%WagerButton").visible)
	assert_true(table.get_node("%AllInButton").visible)


func test_phone_waiting_state_keeps_summary_and_hides_action_rows() -> void:
	var table: PokerTableController = await _phone_table(&"bot-turn")
	assert_true(table.get_node("%PhoneHeroSummary").visible)
	assert_eq(table.get_node("%ActionStatus").text, "Act: Player 2")
	assert_false(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/ActionPanel/Margin/Content/ActionRows")
			. visible
		)
	)
	for path: String in ["%FoldButton", "%CheckCallButton", "%WagerButton", "%AllInButton"]:
		assert_false((table.get_node(path) as Control).visible, path)


func test_phone_wager_action_launches_entry_and_desktop_profile_restores_controls() -> void:
	var table: PokerTableController = await _phone_table(&"human-turn-preflop")
	table.get_node("%WagerButton").emit_signal("pressed")
	assert_true(table.get_node("WagerKeypad").visible)
	table.get_node("WagerKeypad").hide()

	table.size = Vector2(1280, 720)
	await _settle()
	assert_false(table.get_node("%PhoneHeroSummary").visible)
	assert_true(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0").visible)
	for path: String in [
		"%FoldButton",
		"%CheckCallButton",
		"%MinWagerButton",
		"%PotRaiseButton",
		"%WagerInput",
		"%WagerButton",
		"%AllInButton",
	]:
		assert_true((table.get_node(path) as Control).visible, path)


func _assert_visible_action(table: PokerTableController, path: String, copy: String) -> void:
	var button := table.get_node(path) as Button
	assert_true(button.visible, path)
	assert_string_contains(button.text, copy)
	assert_gte(button.size.x, 48.0, "%s width" % path)
	assert_gte(button.size.y, 48.0, "%s height" % path)


func _phone_table(state_id: StringName) -> PokerTableController:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(state_id, 4)
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(390, 844)
	add_child_autofree(table)
	table.bind_view(descriptor.view, {}, {})
	await _settle()
	return table


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
