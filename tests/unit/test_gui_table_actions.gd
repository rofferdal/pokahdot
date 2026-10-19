extends "res://tests/support/poker_gut_test.gd"

const PokerTableScene := preload("res://scenes/poker_table.tscn")


func test_action_controls_follow_recipient_legal_actions_and_submit_wagers() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	var view: GameView = match_instance.get_view_for(0)
	assert_true(view.acting_seat == 0)
	assert_false(table.get_node("%FoldButton").disabled)
	assert_false(table.get_node("%CheckCallButton").disabled)
	assert_string_contains(table.get_node("%CheckCallButton").text, "Call")
	assert_false(table.get_node("%MinWagerButton").disabled)
	assert_false(table.get_node("%WagerButton").disabled)
	assert_false(table.get_node("%AllInButton").disabled)

	table.submit_wager_total(view.minimum_wager_total)

	assert_gt(match_instance.get_view_for(0).pot_amount, 15)
	assert_true(table.get_event_texts().any(func(text: String) -> bool: return "wagered" in text))


func test_rejected_free_wager_keeps_human_turn_and_displays_core_error() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	var input: LineEdit = table.get_node("%WagerInput")
	input.text = "1"
	table.get_node("%WagerButton").emit_signal("pressed")

	assert_eq(match_instance.get_view_for(0).acting_seat, 0)
	assert_false(table.get_node("%ActionStatus").text.is_empty())
	assert_true(table.get_event_texts()[-1].contains("action rejected"))


func test_event_log_preserves_domain_event_order_and_fold_settlement() -> void:
	var match_instance := _waiting_match([PlayerAction.fold_action()])
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())
	table.get_node("%FoldButton").emit_signal("pressed")

	var event_texts: Array[String] = table.get_event_texts()
	assert_eq(event_texts[0], "Hand started")
	assert_string_contains(event_texts[1], "posted")
	assert_string_contains(event_texts[2], "posted")
	assert_eq(event_texts[3], "Hole cards dealt")
	assert_string_contains(event_texts[-2], "received")
	assert_eq(event_texts[-1], "Hand complete")
	assert_eq(match_instance.get_view_for(0).hand_winner_seat, 1)


func test_gui_actions_complete_a_checked_down_showdown_and_render_its_events() -> void:
	var match_instance := _waiting_match(
		[
			PlayerAction.call_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
		]
	)
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")
	for _street: int in range(3):
		table.get_node("%CheckCallButton").emit_signal("pressed")

	var view: GameView = match_instance.get_view_for(0)
	assert_true(view.hand_complete)
	assert_eq(view.community_cards.size(), 5)
	assert_true(table.get_event_texts().has("Showdown"))
	assert_eq(table.get_event_texts()[-1], "Hand complete")


func _waiting_match(bot_actions: Array[PlayerAction]) -> TournamentMatch:
	var config := (
		ResolvedTournamentConfig
		. new(
			2,
			100,
			5,
			10,
			9123,
			&"single_table",
			{0: &"human", 1: &"scripted"},
		)
	)
	var match_instance := (
		TournamentMatch
		. new(
			config,
			{0: HumanAgent.new(), 1: ScriptedAgent.new(bot_actions)},
		)
	)
	assert_eq(match_instance.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	return match_instance


func _empty_assignments() -> Dictionary[int, String]:
	return {}
