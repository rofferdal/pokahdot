extends "res://tests/support/poker_gut_test.gd"

const GuiActionTimingConfigScript := preload("res://scripts/gui/gui_action_timing_config.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")


class CheckingCallingAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		if PlayerAction.Kind.CHECK in view.legal_actions:
			return PlayerAction.check_action()
		if PlayerAction.Kind.CALL in view.legal_actions:
			return PlayerAction.call_action()
		return PlayerAction.fold_action()


func test_phone_has_no_event_history_surface_and_overflow_has_a_close_path() -> void:
	var table: PokerTableController = await _phone_match_table()
	var history_size: int = table._bound_view.action_history.size()
	assert_false((table.get_node("%EventLog") as Control).visible)
	assert_false((table.get_node("%QuitButton") as Control).visible)
	assert_true((table.get_node("%PhoneMoreButton") as Control).visible)
	assert_null(table.find_child("PhoneLogDrawer", true, false))
	assert_null(table.find_child("PhoneLog", true, false))
	assert_null(table.find_child("PhoneMenuLogButton", true, false))

	table.get_node("%PhoneMoreButton").emit_signal("pressed")
	assert_true((table.get_node("%PhoneOverflowMenu") as Control).visible)
	table.get_node("%PhoneMenuCloseButton").emit_signal("pressed")
	assert_false((table.get_node("%PhoneOverflowMenu") as Control).visible)
	assert_eq(table._bound_view.action_history.size(), history_size)


func test_phone_wager_sheet_cancel_is_inert_and_done_submits() -> void:
	var table: PokerTableController = await _phone_match_table()
	var match_instance: TournamentMatch = table._match
	var initial_view: GameView = match_instance.get_view_for(0)
	var initial_pot: int = initial_view.pot_amount
	var initial_stack: int = initial_view.seats[0].stack
	var keypad := table.get_node("WagerKeypad") as WagerKeypad

	table.show_wager_keypad()
	assert_true(keypad.visible)
	assert_true(keypad.is_bottom_sheet())
	assert_true((keypad.get_node("Content/Keys/KeyMin") as Button).visible)
	assert_true((keypad.get_node("Content/Keys/KeyPot") as Button).visible)
	assert_false((keypad.get_node("Content/Keys/KeyPot") as Button).disabled)
	assert_eq((keypad.get_node("Content/Keys/KeyPot") as Button).text, "Pot 15")
	keypad.get_node("Content/Keys/KeyMin").emit_signal("pressed")
	assert_eq((table.get_node("%WagerInput") as LineEdit).text, "")
	keypad.get_node("Content/Cancel").emit_signal("pressed")
	assert_false(keypad.visible)
	assert_eq(match_instance.get_view_for(0).pot_amount, initial_pot)
	assert_eq(match_instance.get_view_for(0).seats[0].stack, initial_stack)

	table.show_wager_keypad()
	keypad.get_node("Content/Keys/KeyMin").emit_signal("pressed")
	keypad.get_node("Content/Done").emit_signal("pressed")
	assert_false(keypad.visible)
	assert_gt(match_instance.get_view_for(0).pot_amount, initial_pot)
	assert_lt(match_instance.get_view_for(0).seats[0].stack, initial_stack)


func test_phone_showdown_summary_uses_only_recipient_safe_results() -> void:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"showdown-long", 6)
	var table: PokerTableController = await _phone_view_table(descriptor.view)
	assert_eq((table.get_node("%PhoneMoreButton") as Button).text, "Pots")
	table.get_node("%PhoneMoreButton").emit_signal("pressed")
	assert_false((table.get_node("%PhoneOverflowMenu") as Control).visible)
	var summary := table.get_node("%PhoneShowdownSummary") as Label
	assert_true((table.get_node("%PhoneShowdownOverlay") as Control).visible)
	assert_false(summary.text.is_empty())
	for seat: int in descriptor.view.showdown_results:
		var player_view: PlayerView = descriptor.view.seats[seat]
		assert_string_contains(summary.text, player_view.display_name)
	assert_false("Player 2 —" in summary.text)
	assert_false("Player 3 —" in summary.text)
	table.get_node("%PhoneShowdownCloseButton").emit_signal("pressed")
	assert_false((table.get_node("%PhoneShowdownOverlay") as Control).visible)


func test_phone_summary_names_fold_winner_without_revealing_cards() -> void:
	var view: GameView = GuiVisualStateFixturesScript.by_id(&"showdown-long", 6).view
	view._showdown_results = {}
	view._revealed_hole_cards = {}
	view.hand_winner_seat = 1
	view._pot_awards = [PotAward.new(0, 101, [1], {1: 101})]
	var table: PokerTableController = await _phone_view_table(view)
	table._name_assignments = {1: "Linh"}
	table._refresh_phone_secondary_controls()
	table._open_phone_showdown()
	assert_true(table._phone_showdown_overlay.visible)
	assert_eq(table._phone_showdown_summary.text, "Main pot (101): Linh +101")
	assert_true(table.displayed_hero_cards.size() <= 2)
	assert_true(view.revealed_hole_cards.is_empty())


func test_phone_summary_reports_each_split_and_side_pot_share_and_assigned_winner() -> void:
	var view: GameView = GuiVisualStateFixturesScript.by_id(&"showdown-long", 6).view
	view._pot_awards = [
		PotAward.new(0, 101, [4, 5], {4: 51, 5: 50}),
		PotAward.new(1, 40, [5], {5: 40}),
	]
	view.tournament_status = &"finished"
	view.end_reason = &"winner"
	view.tournament_winner_seat = 5
	var table: PokerTableController = await _phone_view_table(view)
	table._name_assignments = {4: "Bao", 5: "Linh"}
	table._refresh_action_controls()
	var summary: String = table._phone_showdown_summary_text()
	assert_string_contains(summary, "Main pot (101): Bao +51, Linh +50")
	assert_string_contains(summary, "Side pot 1 (40): Linh +40")
	assert_eq(table._action_status.text, "Linh wins")


func test_phone_overflow_quit_waits_for_confirmation_and_profile_exit_restores_desktop() -> void:
	var table: PokerTableController = await _phone_match_table()
	var match_instance: TournamentMatch = table._match
	table.get_node("%PhoneMoreButton").emit_signal("pressed")
	table.get_node("%PhoneMenuQuitButton").emit_signal("pressed")
	assert_false((table.get_node("%PhoneOverflowMenu") as Control).visible)
	assert_true((table.get_node("%PhoneQuitConfirmation") as Control).visible)
	assert_false((table.get_node("%QuitConfirmation") as Window).visible)
	assert_eq(match_instance.state, TournamentMatch.State.RUNNING)
	table.get_node("%PhoneQuitContinueButton").emit_signal("pressed")
	assert_false((table.get_node("%PhoneQuitConfirmation") as Control).visible)
	assert_eq(match_instance.state, TournamentMatch.State.RUNNING)

	table.get_node("%PhoneMoreButton").emit_signal("pressed")
	assert_true((table.get_node("%PhoneOverflowMenu") as Control).visible)
	table.size = Vector2(1280, 720)
	await _settle()
	assert_false((table.get_node("%PhoneOverflowMenu") as Control).visible)
	assert_false((table.get_node("%PhoneMoreButton") as Control).visible)
	assert_true((table.get_node("%EventLog") as Control).visible)
	assert_true((table.get_node("%QuitButton") as Control).visible)
	assert_eq(match_instance.state, TournamentMatch.State.RUNNING)


func _phone_match_table() -> PokerTableController:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(390, 844)
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(_waiting_match(), 0, {})
	await _settle()
	return table


func _phone_view_table(view: GameView) -> PokerTableController:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(390, 844)
	add_child_autofree(table)
	table.bind_view(view, {}, {})
	await _settle()
	return table


func _waiting_match() -> TournamentMatch:
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
			{0: HumanAgent.new(), 1: CheckingCallingAgent.new()},
		)
	)
	assert_eq(match_instance.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	return match_instance


func _disable_action_pacing(table: PokerTableController) -> void:
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 0.0
	timing_config.showdown_pause_seconds = 0.0
	table.set_action_timing_config(timing_config)


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
