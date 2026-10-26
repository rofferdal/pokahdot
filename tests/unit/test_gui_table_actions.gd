# gdlint: disable=max-public-methods
# gdlint: disable=max-file-lines
extends "res://tests/support/poker_gut_test.gd"

const PokerTableScene := preload("res://scenes/poker_table.tscn")
const GuiActionTimingConfigScript := preload("res://scripts/gui/gui_action_timing_config.gd")
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")


func test_acting_seat_uses_a_white_frame_three_times_thicker_than_ordinary_seats() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(3)
	view.acting_seat = 1
	table.bind_view(view, _empty_assignments())

	var acting_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1")
	var ordinary_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2")
	var acting_style: StyleBoxFlat = acting_panel.get_theme_stylebox("panel")
	var ordinary_style: StyleBoxFlat = ordinary_panel.get_theme_stylebox("panel")

	assert_eq(acting_style.border_color, Color.WHITE)
	assert_eq(acting_style.border_width_left, ordinary_style.border_width_left * 3)
	assert_eq(ordinary_style.border_color, Color("5dbf86"))


func test_action_controls_follow_recipient_legal_actions_and_submit_wagers() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	var view: GameView = match_instance.get_view_for(0)
	assert_true(view.acting_seat == 0)
	assert_false(table.get_node("%FoldButton").disabled)
	assert_false(table.get_node("%CheckCallButton").disabled)
	assert_string_contains(table.get_node("%CheckCallButton").text, "Call")
	assert_false(table.get_node("%MinWagerButton").disabled)
	assert_false(table.get_node("%WagerButton").disabled)
	assert_false(table.get_node("%AllInButton").disabled)
	assert_true(table.get_node("%MinWagerButton").text in ["Min Raise 20", "Min 20"])
	assert_eq(table.get_node("%PotRaiseButton").text, "Pot 30")
	assert_eq(table.get_node("%WagerButton").text, "Raise")
	assert_eq(table.get_node("%AllInButton").text, "All-in")
	var wager_input: LineEdit = table.get_node("%WagerInput")
	assert_false(wager_input.virtual_keyboard_enabled)
	assert_false(wager_input.virtual_keyboard_show_on_focus)
	assert_eq(wager_input.virtual_keyboard_type, LineEdit.KEYBOARD_TYPE_NUMBER)
	table.get_node("%MinWagerButton").emit_signal("pressed")
	assert_true(_event_texts(table).any(func(text: String) -> bool: return "Raise 20" in text))

	# Rebind the unchanged initial view so the remaining input controls can be tested.
	table.bind_view(match_instance.get_view_for(0), _empty_assignments())
	table.show_wager_keypad()
	assert_true(table.get_node("WagerKeypad").visible)
	table.get_node("WagerKeypad/Content/Keys/Key2").emit_signal("pressed")
	assert_eq(wager_input.text, "")
	assert_eq(table.get_node("WagerKeypad/Content/Value").text, "2")
	table.get_node("WagerKeypad/Content/Cancel").emit_signal("pressed")

	table.submit_wager_total(view.minimum_wager_total)

	assert_gt(match_instance.get_view_for(0).pot_amount, 15)
	assert_true(_event_texts(table).any(func(text: String) -> bool: return "action" in text))


func test_live_wager_input_uses_touch_keypad_and_pointer_keyboard_across_profiles() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())
	var input := table.get_node("%WagerInput") as LineEdit
	var keypad := table.get_node("WagerKeypad") as WagerKeypad

	for profile: int in [
		GuiLayoutProfileScript.Kind.PHONE_LANDSCAPE,
		GuiLayoutProfileScript.Kind.TABLET,
		GuiLayoutProfileScript.Kind.SMALL_DESKTOP,
		GuiLayoutProfileScript.Kind.DESKTOP,
	]:
		table.set_layout_profile_override(profile)
		input.gui_input.emit(_left_mouse_press())
		assert_false(keypad.visible, "mouse profile %d" % profile)
		input.gui_input.emit(_touch_press())
		assert_true(keypad.visible, "touch profile %d" % profile)
		assert_eq(
			(keypad.get_node("Content/Keys/KeyPot") as Button).text,
			"Pot 30",
			"pot target profile %d" % profile,
		)
		keypad.cancel()


func test_live_wager_touch_done_submits_across_layout_profiles() -> void:
	for profile: int in [
		GuiLayoutProfileScript.Kind.PHONE_LANDSCAPE,
		GuiLayoutProfileScript.Kind.TABLET,
		GuiLayoutProfileScript.Kind.SMALL_DESKTOP,
		GuiLayoutProfileScript.Kind.DESKTOP,
	]:
		var match_instance := _waiting_match([PlayerAction.call_action()])
		var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
		add_child_autofree(table)
		_disable_action_pacing(table)
		table.bind_match(match_instance, 0, _empty_assignments())
		table.set_layout_profile_override(profile)
		var input := table.get_node("%WagerInput") as LineEdit
		var keypad := table.get_node("WagerKeypad") as WagerKeypad
		input.text = str(match_instance.get_view_for(0).minimum_wager_total)
		input.gui_input.emit(_touch_press())
		assert_true(keypad.visible, "touch profile %d" % profile)
		keypad.get_node("Content/Done").emit_signal("pressed")
		assert_gt(match_instance.get_view_for(0).pot_amount, 15, "touch profile %d" % profile)


func test_live_wager_touch_cancel_and_keyboard_correction_submission_preserve_bounds() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())
	table.set_layout_profile_override(GuiLayoutProfileScript.Kind.DESKTOP)
	var input := table.get_node("%WagerInput") as LineEdit
	var keypad := table.get_node("WagerKeypad") as WagerKeypad
	var view: GameView = match_instance.get_view_for(0)

	input.text = str(view.minimum_wager_total)
	input.gui_input.emit(_touch_press())
	keypad.get_node("Content/Keys/Key9").emit_signal("pressed")
	assert_eq(input.text, str(view.minimum_wager_total))
	input.gui_input.emit(_left_mouse_press())
	assert_false(keypad.visible)
	assert_eq(input.text, str(view.minimum_wager_total))

	# Invalid keyboard text and out-of-range totals retain the human turn.
	input.text = "2x"
	input.text_submitted.emit(input.text)
	assert_eq((table.get_node("%ActionStatus") as Label).text, "Enter a whole-number wager total.")
	input.text = str(view.maximum_wager_total + 1)
	input.text_submitted.emit(input.text)
	assert_eq(match_instance.get_view_for(0).acting_seat, 0)

	# Backspace/correction is native LineEdit behavior; submit the corrected value with Enter.
	input.text = str(view.minimum_wager_total)
	input.text_submitted.emit(input.text)
	assert_gt(match_instance.get_view_for(0).pot_amount, 15)


func test_pot_bet_submits_the_exact_target_through_the_live_match() -> void:
	var match_instance := _waiting_match([PlayerAction.check_action(), PlayerAction.check_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")
	var view: GameView = match_instance.get_view_for(0)
	assert_eq(view.street, &"flop")
	assert_true(PlayerAction.Kind.BET in view.legal_actions)
	assert_eq(view.pot_amount, 20)
	assert_eq(view.minimum_wager_total, 10)
	assert_eq(table.get_node("%PotRaiseButton").text, "Pot 20")
	assert_false(table.get_node("%PotRaiseButton").disabled)

	_freeze_action_pacing(table)
	table.get_node("%PotRaiseButton").emit_signal("pressed")
	var submitted_view: GameView = match_instance.get_view_for(0)
	var submitted_action: PublicActionRecord = _latest_player_action_for(submitted_view, 0)
	assert_not_null(submitted_action)
	assert_eq(submitted_action.seat, 0)
	assert_eq(submitted_action.kind, PlayerAction.Kind.BET)
	assert_eq(submitted_action.amount, 20)
	assert_eq(_seat_view(submitted_view, 0).bet_this_round, 20)
	assert_eq(_current_bet(submitted_view), 20)
	assert_eq(_seat_view(submitted_view, 0).stack, 70)
	assert_eq(submitted_view.pot_amount, 40)
	assert_eq(_total_chips(submitted_view), 200)


func test_pot_raise_submits_the_post_call_target_through_the_live_match() -> void:
	var match_instance := _waiting_match([PlayerAction.check_action(), PlayerAction.bet_to(10)])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")
	var view: GameView = match_instance.get_view_for(0)
	assert_eq(view.street, &"flop")
	assert_true(PlayerAction.Kind.RAISE in view.legal_actions)
	assert_eq(view.pot_amount, 30)
	assert_eq(view.minimum_wager_total, 20)
	assert_eq(table.get_node("%PotRaiseButton").text, "Pot 50")
	assert_false(table.get_node("%PotRaiseButton").disabled)

	_freeze_action_pacing(table)
	table.get_node("%PotRaiseButton").emit_signal("pressed")
	var submitted_view: GameView = match_instance.get_view_for(0)
	var submitted_action: PublicActionRecord = _latest_player_action_for(submitted_view, 0)
	assert_not_null(submitted_action)
	assert_eq(submitted_action.seat, 0)
	assert_eq(submitted_action.kind, PlayerAction.Kind.RAISE)
	assert_eq(submitted_action.amount, 50)
	assert_eq(_seat_view(submitted_view, 0).bet_this_round, 50)
	assert_eq(_current_bet(submitted_view), 50)
	assert_eq(_seat_view(submitted_view, 0).stack, 40)
	assert_eq(submitted_view.pot_amount, 80)
	assert_eq(_total_chips(submitted_view), 200)
	var opponent_view: GameView = match_instance.get_view_for(1)
	assert_eq(opponent_view.call_amount, 40)
	assert_true(PlayerAction.Kind.CALL in opponent_view.legal_actions)
	assert_true(PlayerAction.Kind.RAISE in opponent_view.legal_actions)


func test_live_repeated_raise_uses_existing_wager_and_reopens_action() -> void:
	var match_instance := _waiting_match_with_stack(
		[PlayerAction.check_action(), PlayerAction.check_action(), PlayerAction.raise_to(40)],
		500,
	)
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")
	table.get_node("%PotRaiseButton").emit_signal("pressed")
	var reraised_view: GameView = match_instance.get_view_for(0)
	assert_eq(reraised_view.pot_amount, 80)
	assert_eq(_seat_view(reraised_view, 0).bet_this_round, 20)
	assert_eq(reraised_view.call_amount, 20)
	assert_eq((table.get_node("%PotRaiseButton") as Button).text, "Pot 140")
	assert_false((table.get_node("%PotRaiseButton") as Button).disabled)

	_freeze_action_pacing(table)
	table.get_node("%PotRaiseButton").emit_signal("pressed")
	var submitted_view: GameView = match_instance.get_view_for(0)
	var submitted_action: PublicActionRecord = _latest_player_action_for(submitted_view, 0)
	assert_eq(submitted_action.kind, PlayerAction.Kind.RAISE)
	assert_eq(submitted_action.amount, 140)
	assert_eq(_seat_view(submitted_view, 0).bet_this_round, 140)
	assert_eq(_current_bet(submitted_view), 140)
	assert_eq(submitted_view.pot_amount, 200)
	assert_eq(_total_chips(submitted_view), 1000)
	var opponent_view: GameView = match_instance.get_view_for(1)
	assert_eq(opponent_view.call_amount, 100)
	assert_true(PlayerAction.Kind.CALL in opponent_view.legal_actions)
	assert_true(PlayerAction.Kind.RAISE in opponent_view.legal_actions)


func test_live_short_stack_disables_exact_pot_without_clamping_to_all_in() -> void:
	var match_instance := _waiting_match_with_stack(
		[PlayerAction.check_action(), PlayerAction.check_action(), PlayerAction.raise_to(40)],
		100,
	)
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")
	table.get_node("%PotRaiseButton").emit_signal("pressed")
	var short_view: GameView = match_instance.get_view_for(0)
	assert_eq(short_view.maximum_wager_total, 90)
	assert_eq((table.get_node("%PotRaiseButton") as Button).text, "Pot 140")
	assert_true((table.get_node("%PotRaiseButton") as Button).disabled)
	assert_false((table.get_node("%AllInButton") as Button).disabled)
	var action_count_before: int = short_view.action_history.size()
	table.get_node("%PotRaiseButton").emit_signal("pressed")
	assert_eq(match_instance.get_view_for(0).action_history.size(), action_count_before)
	assert_eq(_total_chips(short_view), 200)


func test_pot_wager_shortcut_respects_legal_action_and_inclusive_total_bounds() -> void:
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var view := _action_view(2)
	view.acting_seat = 0
	view._legal_actions = [PlayerAction.Kind.CHECK, PlayerAction.Kind.BET]
	view.minimum_wager_total = 20
	view.maximum_wager_total = 100

	for case: Dictionary in [
		{"target": 19, "disabled": true, "label": "below minimum"},
		{"target": 20, "disabled": false, "label": "at minimum"},
		{"target": 100, "disabled": false, "label": "at maximum"},
		{"target": 101, "disabled": true, "label": "above maximum"},
	]:
		view.pot_amount = case.target
		table.bind_view(view, _empty_assignments())
		assert_eq(table.get_node("%PotRaiseButton").disabled, case.disabled, case.label)

	view.pot_amount = 15
	view.maximum_wager_total = 15
	view._legal_actions = [PlayerAction.Kind.CHECK, PlayerAction.Kind.ALL_IN]
	table.bind_view(view, _empty_assignments())
	assert_true(table.get_node("%PotRaiseButton").disabled, "insufficient stack")
	assert_eq(table.get_node("%PotRaiseButton").text, "Pot 0")

	view.pot_amount = 30
	view.minimum_wager_total = 20
	view.maximum_wager_total = 100
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL]
	table.bind_view(view, _empty_assignments())
	assert_true(table.get_node("%PotRaiseButton").disabled, "wager action unavailable")


func test_gui_renders_an_action_before_its_configured_nonblocking_pause_advances_a_bot() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 0.1
	table.set_action_timing_config(timing_config)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")
	assert_true(table.is_action_advance_pending())
	assert_eq(match_instance.get_events().filter(_is_action_event).size(), 1)

	await get_tree().create_timer(0.15).timeout
	assert_gte(match_instance.get_events().filter(_is_action_event).size(), 2)


func test_community_card_reveal_uses_the_configured_nonblocking_action_pause() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 0.1
	timing_config.showdown_pause_seconds = 0.0
	table.set_action_timing_config(timing_config)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")
	await get_tree().create_timer(0.25).timeout

	assert_eq(match_instance.get_view_for(0).community_cards.size(), 3)
	assert_true(table.is_action_advance_pending())
	assert_eq(match_instance.get_events().filter(_is_action_event).size(), 2)


func test_seat_action_labels_reset_at_each_new_betting_round_without_clearing_history() -> void:
	var match_instance := _waiting_match(
		[
			PlayerAction.call_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
		]
	)
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")
	var flop_view: GameView = match_instance.get_view_for(0)
	assert_eq(flop_view.street, &"flop")
	assert_eq((table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Status") as Label).text, "")
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label).text, "Check"
	)
	assert_true(_event_texts(table).any(func(text: String) -> bool: return "Call" in text))

	table.get_node("%CheckCallButton").emit_signal("pressed")
	var turn_view: GameView = match_instance.get_view_for(0)
	assert_eq(turn_view.street, &"turn")
	assert_eq((table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Status") as Label).text, "")
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label).text, "Check"
	)
	assert_true(_event_texts(table).any(func(text: String) -> bool: return "Flop begins" in text))

	table.get_node("%CheckCallButton").emit_signal("pressed")
	var river_view: GameView = match_instance.get_view_for(0)
	assert_eq(river_view.street, &"river")
	assert_eq((table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Status") as Label).text, "")
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label).text, "Check"
	)
	assert_true(_event_texts(table).any(func(text: String) -> bool: return "Turn begins" in text))


func test_gui_advances_a_complete_startup_round_without_waiting_for_a_player() -> void:
	var config := ResolvedTournamentConfig.new(
		2, 631, 660, 1000, 7123, &"short_start", {0: &"human", 1: &"scripted"}
	)
	var match_instance := (
		TournamentMatch
		. new(
			config,
			{0: HumanAgent.new(), 1: ScriptedAgent.new([])},
		)
	)
	assert_eq(match_instance.start(1).status, StepResult.Status.YIELDED)
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 0.05
	timing_config.showdown_pause_seconds = 0.0
	table.set_action_timing_config(timing_config)
	table.bind_match(match_instance, 0, _empty_assignments())

	var view := match_instance.get_view_for(0)
	assert_eq(view.acting_seat, Table.NO_SEAT)
	assert_true(view.legal_actions.is_empty())
	assert_true(table.is_action_advance_pending())
	assert_false((table.get_node("%ActionStatus") as Label).text.contains("Waiting for Player 1"))

	await get_tree().create_timer(0.35).timeout
	assert_ne(match_instance.state, TournamentMatch.State.NOT_STARTED)
	assert_false((table.get_node("%ActionStatus") as Label).text.contains("Waiting for Player 1"))


func _is_action_event(event: DomainEvent) -> bool:
	return event.kind == DomainEvent.Kind.ACTION_APPLIED


func test_tournament_winner_and_eliminated_seat_are_rendered_from_the_match_view() -> void:
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var view := _action_view(2)
	view.tournament_status = &"finished"
	view.end_reason = &"winner"
	view.tournament_winner_seat = 0
	view._seats[1].busted = true
	var visual_names: Dictionary[int, String] = {0: "Human", 1: "Youssef"}
	table.bind_view(view, _empty_assignments(), visual_names)

	assert_true(
		table.get_node("%ActionStatus").text in ["Player 1 wins the tournament!", "Player 1 wins"]
	)
	assert_eq(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/Identity/Name")
			. text
		),
		"Youssef",
	)
	assert_eq(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/Seats/Seat1/Content/Footer/HoleCards")
			. get_child_count()
		),
		0
	)
	var eliminated_panel: PanelContainer = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1"
	)
	assert_true(eliminated_panel.material is ShaderMaterial)


func test_eliminated_seat_is_greyscale_while_active_seat_retains_its_color_treatment() -> void:
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var view := _action_view(3)
	view._seats[1].busted = true
	table.bind_view(view, _empty_assignments())

	var eliminated_panel: PanelContainer = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1"
	)
	var active_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2")
	assert_true(eliminated_panel.material is ShaderMaterial)
	assert_null(active_panel.material)


func test_rejected_free_wager_keeps_human_turn_and_displays_core_error() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	var input: LineEdit = table.get_node("%WagerInput")
	input.text = "1"
	table.get_node("%WagerButton").emit_signal("pressed")

	assert_eq(match_instance.get_view_for(0).acting_seat, 0)
	assert_false(table.get_node("%ActionStatus").text.is_empty())
	assert_true(_event_texts(table)[-1].contains("rejected"))


func test_event_log_preserves_domain_event_order_and_fold_settlement() -> void:
	var match_instance := _waiting_match([PlayerAction.fold_action()])
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 0.0
	timing_config.showdown_pause_seconds = 1.0
	table.set_action_timing_config(timing_config)
	table.bind_match(match_instance, 0, _empty_assignments())
	table.get_node("%FoldButton").emit_signal("pressed")

	var event_texts: Array[String] = _event_texts(table)
	assert_eq(event_texts[0], "Hand 1 started")
	assert_string_contains(event_texts[1], "Player 1 (you) posted a blind")
	assert_string_contains(event_texts[2], "Player 2 posted a blind")
	assert_eq(event_texts[3], "Hole cards dealt")
	assert_string_contains(event_texts[-2], "wins")
	assert_eq(event_texts[-1], "Hand complete")
	assert_eq(match_instance.get_view_for(0).hand_winner_seat, 1)


func test_gui_renders_checked_down_actions_and_the_flop_transition() -> void:
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
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")

	var view: GameView = match_instance.get_view_for(0)
	assert_eq(view.community_cards.size(), 3)
	assert_eq(_event_texts(table)[-1], "Player 2: Check")


func test_showdown_remains_visible_for_its_configured_pause_before_next_hand() -> void:
	var match_instance := _waiting_match(
		[
			PlayerAction.call_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
		]
	)
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 0.0
	timing_config.showdown_pause_seconds = 0.1
	table.set_action_timing_config(timing_config)
	table.bind_match(match_instance, 0, _empty_assignments())

	for _street: int in range(4):
		table.get_node("%CheckCallButton").emit_signal("pressed")

	assert_true(match_instance.get_view_for(0).hand_complete)
	assert_true(table.is_action_advance_pending())
	await get_tree().create_timer(0.15).timeout
	assert_false(match_instance.get_view_for(0).hand_complete)


func test_pre_showdown_winner_remains_visible_for_completed_hand_pause() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 0.0
	timing_config.showdown_pause_seconds = 0.1
	table.set_action_timing_config(timing_config)
	table.bind_match(match_instance, 0, _empty_assignments())

	var completed_hand_number: int = match_instance.get_view_for(0).hand_number
	table.get_node("%FoldButton").emit_signal("pressed")

	assert_true(match_instance.get_view_for(0).hand_complete)
	assert_eq(match_instance.get_view_for(0).hand_winner_seat, 1)
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label).text,
		"Winner",
	)
	assert_true(table.is_action_advance_pending())
	await get_tree().create_timer(0.05).timeout
	assert_eq(match_instance.get_view_for(0).hand_number, completed_hand_number)
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label).text,
		"Winner",
	)

	await get_tree().create_timer(0.1).timeout
	assert_gt(match_instance.get_view_for(0).hand_number, completed_hand_number)
	assert_false(match_instance.get_view_for(0).hand_complete)
	assert_ne(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label).text,
		"Winner",
	)


func test_completed_non_showdown_view_labels_only_the_winning_seat() -> void:
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var view := _action_view(3)
	view.acting_seat = Table.NO_SEAT
	view.hand_complete = true
	view.hand_winner_seat = 1
	view._action_history = [
		PublicActionRecord.new(1, PlayerAction.Kind.CHECK, 0),
		PublicActionRecord.new(2, PlayerAction.Kind.FOLD, 0),
	]
	table.bind_view(view, _empty_assignments())

	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label).text,
		"Winner",
	)
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status") as Label).text,
		"Fold",
	)
	assert_ne(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Status") as Label).text,
		"Winner",
	)


func test_controller_starts_the_next_hand_and_updates_the_button_after_a_hand_boundary() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())
	var first_view: GameView = match_instance.get_view_for(0)

	table.get_node("%FoldButton").emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	var next_view: GameView = match_instance.get_view_for(0)
	assert_eq(next_view.hand_number, first_view.hand_number + 1)
	assert_ne(next_view.button_seat, first_view.button_seat)
	assert_false(next_view.hand_complete)
	assert_true(_event_texts(table).has("Hand 2 started"))


func test_quit_confirmation_can_cancel_or_finish_the_match_without_a_winner() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())
	var quit_confirmation: ConfirmationDialog = table.get_node("%QuitConfirmation")

	table.get_node("%QuitButton").emit_signal("pressed")
	assert_true(quit_confirmation.visible)
	quit_confirmation.emit_signal("canceled")
	assert_eq(match_instance.state, TournamentMatch.State.RUNNING)

	table.get_node("%QuitButton").emit_signal("pressed")
	quit_confirmation.emit_signal("confirmed")
	var view: GameView = match_instance.get_view_for(0)
	assert_eq(match_instance.state, TournamentMatch.State.FINISHED)
	assert_eq(view.end_reason, &"player_quit")
	assert_eq(view.tournament_winner_seat, Table.NO_SEAT)
	assert_eq(table.get_node("%ActionStatus").text, "Tournament ended: player quit.")


func test_quit_after_a_finished_tournament_requests_a_return_to_startup_without_confirmation(
) -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())
	match_instance.request_quit()
	table.refresh_from_match()
	var returned_to_startup := [false]
	table.return_to_startup_requested.connect(func() -> void: returned_to_startup[0] = true)

	table.get_node("%QuitButton").emit_signal("pressed")

	assert_true(returned_to_startup[0])
	assert_false(table.get_node("%QuitConfirmation").visible)


func test_human_adjacent_panels_do_not_overlap_desktop_seats() -> void:
	for player_count: int in [6, 9]:
		var table = PokerTableScene.instantiate()
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = Vector2(1920, 1080)
		table.bind_view(_action_view(player_count), _empty_assignments())
		table.show()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		var action_rect: Rect2 = (
			table.get_node("TableMargin/Felt/TableSurface/ActionPanel").get_rect()
		)
		var event_rect: Rect2 = table.get_node("%EventLog").get_rect()
		var hero_rect: Rect2 = table.get_seat_rects()[0]
		assert_lte(
			action_rect.size.y,
			hero_rect.size.y,
			"%d-player action panel must not exceed the human seat height" % player_count,
		)
		assert_eq(action_rect.size, event_rect.size, "%d-player side-panel size" % player_count)
		assert_almost_eq(
			event_rect.position.y,
			action_rect.position.y,
			0.001,
			"%d-player side panels must align vertically" % player_count,
		)
		assert_lte(action_rect.size.y, 180.0, "%d-player two-row action height" % player_count)
		assert_gte(event_rect.size.x, 380.0, "%d-player event width" % player_count)
		assert_lte(event_rect.size.y, 180.0, "%d-player event height" % player_count)
		assert_eq(table.get_node("%FoldButton").get_theme_font_size("font_size"), 32)
		assert_eq(table.get_node("%FoldButton").get_theme_stylebox("normal").border_width_left, 1)
		assert_eq(table.get_node("%FoldButton").get_theme_stylebox("hover").border_width_left, 2)
		assert_eq(table.get_node("%WagerInput").get_theme_stylebox("normal").border_width_left, 1)
		assert_gte(table.get_node("%FoldButton").get_theme_font_size("font_size"), 20)
		var event_log: RichTextLabel = table.get_node("%EventLog")
		assert_false(event_log.fit_content)
		assert_true(event_log.scroll_active)
		assert_eq(event_log.get_theme_color("default_color"), Color("111111"))
		assert_eq(event_log.get_theme_stylebox("normal").bg_color, Color("dedede"))
		assert_true(
			(
				(
					table
					. get_node(
						"TableMargin/Felt/TableSurface/ActionPanel/Margin/Content/ActionRows/PrimaryButtons"
					)
				)
				is HBoxContainer
			)
		)
		assert_true(
			(
				(
					table
					. get_node(
						"TableMargin/Felt/TableSurface/ActionPanel/Margin/Content/ActionRows/WagerControls"
					)
				)
				is HBoxContainer
			)
		)
		var primary_buttons := (
			table.get_node(
				"TableMargin/Felt/TableSurface/ActionPanel/Margin/Content/ActionRows/PrimaryButtons"
			)
			as HBoxContainer
		)
		var wager_controls := (
			table.get_node(
				"TableMargin/Felt/TableSurface/ActionPanel/Margin/Content/ActionRows/WagerControls"
			)
			as HBoxContainer
		)
		assert_eq(primary_buttons.get_theme_constant("separation"), 4)
		assert_eq(wager_controls.get_theme_constant("separation"), 4)
		assert_false(
			action_rect.intersects(event_rect),
			"%d-player action/event panels %s / %s" % [player_count, action_rect, event_rect]
		)
		assert_false(
			action_rect.intersects(hero_rect),
			"%d-player action panel must not cover the human seat" % player_count,
		)
		assert_false(
			event_rect.intersects(hero_rect),
			"%d-player event log must not cover the human seat" % player_count,
		)

	# Mobile phones and iPad portrait keep every action control inside the visible strip.
	for viewport_size: Vector2 in [Vector2(320, 568), Vector2(390, 780), Vector2(768, 1024)]:
		var table = PokerTableScene.instantiate()
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = viewport_size
		var view := _action_view(9)
		view.acting_seat = 0
		view._legal_actions = [
			PlayerAction.Kind.FOLD,
			PlayerAction.Kind.CALL,
			PlayerAction.Kind.RAISE,
			PlayerAction.Kind.ALL_IN,
		]
		view.minimum_wager_total = 20
		view.maximum_wager_total = 100
		table.bind_view(view, _empty_assignments())
		table.show()
		await get_tree().process_frame
		await get_tree().process_frame

		var action_panel: PanelContainer = table.get_node(
			"TableMargin/Felt/TableSurface/ActionPanel"
		)
		var action_rect: Rect2 = action_panel.get_global_rect()
		for control: Control in [
			table.get_node("%FoldButton"),
			table.get_node("%CheckCallButton"),
			table.get_node("%MinWagerButton"),
			table.get_node("%PotRaiseButton"),
			table.get_node("%AllInButton"),
			table.get_node("%WagerInput"),
			table.get_node("%WagerButton"),
		]:
			assert_true(
				action_rect.encloses(control.get_global_rect()),
				"%s must fit at %s" % [control.name, viewport_size]
			)


func test_each_seat_displays_its_latest_public_action_below_its_panel() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(3)
	view._action_history = [
		PublicActionRecord.blind(0, 5, true),
		PublicActionRecord.blind(1, 10, false),
		PublicActionRecord.new(2, PlayerAction.Kind.RAISE, 30),
	]
	table.bind_view(view, _empty_assignments())

	assert_eq(
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Status").text, "Small blind 5"
	)
	assert_eq(
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status").text, "Big blind 10"
	)
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status").text, "Raise 30")
	assert_eq(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/Seats/Seat2/Content/Header/Identity/Stack")
			. text
		),
		"100 chips"
	)


func test_new_hand_view_clears_previous_hand_action_labels() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var first_hand_view := _action_view(3)
	first_hand_view._action_history = [
		PublicActionRecord.new(2, PlayerAction.Kind.CALL, 10),
	]
	table.bind_view(first_hand_view, _empty_assignments())
	var action_label := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status") as Label
	assert_eq(action_label.text, "Call 10")
	assert_true(action_label.visible)

	var next_hand_view := _action_view(3)
	table.bind_view(next_hand_view, _empty_assignments())
	action_label = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status") as Label
	assert_eq(action_label.text, "")
	assert_true(action_label.visible)


func test_fold_status_survives_street_transitions_for_six_and_seven_players() -> void:
	for player_count: int in [6, 7]:
		var table := PokerTableScene.instantiate() as PokerTableController
		add_child_autofree(table)
		var folded_seat: int = player_count - 1
		var view := _action_view(player_count)
		view.street = &"flop"
		view._seats[folded_seat].folded = true
		view._action_history = [
			PublicActionRecord.new(2, PlayerAction.Kind.CALL, 10),
			PublicActionRecord.new(folded_seat, PlayerAction.Kind.FOLD, 0),
			PublicActionRecord.new(1, PlayerAction.Kind.CHECK, 0),
		]
		table.bind_view(view, _empty_assignments())
		var events: Array[DomainEvent] = [
			DomainEvent.new(DomainEvent.Kind.HAND_STARTED),
			DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 2, 10),
			DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, folded_seat, 0),
			DomainEvent.new(DomainEvent.Kind.STREET_CHANGED),
			DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1, 0),
		]
		table._render_events(events)

		assert_eq(
			table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%dStatus" % folded_seat).text,
			"Fold",
			"%d-player folded seat" % player_count,
		)
		assert_eq(
			table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status").text,
			"Check",
			"%d-player current-street action" % player_count,
		)
		assert_eq(
			table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status").text,
			"",
			"%d-player non-Fold action clears" % player_count,
		)


func test_folded_seat_stays_visible_grayscale_and_hides_hole_cards() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(3)
	view._seats[1].folded = true
	view._action_history = [PublicActionRecord.new(1, PlayerAction.Kind.FOLD, 0)]
	table.bind_view(view, _empty_assignments())

	var folded_seat: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1")
	var hole_cards: HBoxContainer = folded_seat.get_node("Content/Footer/HoleCards")
	assert_true(folded_seat.visible)
	assert_true(folded_seat.material is ShaderMaterial)
	assert_true(folded_seat.get_node("Content/Header/AvatarRegion/Avatar").use_parent_material)
	assert_eq(hole_cards.get_child_count(), 0)
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status").text, "Fold")


func test_seat_identity_keeps_stack_below_name_and_all_in_outside_the_panel() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(2)
	view._seats[1].all_in = true
	view._action_history = [PublicActionRecord.new(1, PlayerAction.Kind.ALL_IN, 100)]
	table.bind_view(view, _empty_assignments())

	var identity: VBoxContainer = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/Identity"
	)
	var stack_label: Label = identity.get_node("Stack")
	var marker: Label = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/Marker"
	)
	assert_eq(identity.get_child(0).name, "Name")
	assert_eq(identity.get_child(1).name, "Stack")
	assert_eq(stack_label.text, "100 chips")
	assert_false(stack_label.text.contains("ALL-IN"))
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status").text, "All-in 100")
	assert_eq(marker.custom_minimum_size.x, 96.0)


func test_showdown_summaries_use_recipient_safe_results_in_shared_status_bands() -> void:
	var table = PokerTableScene.instantiate()
	table.hide()
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1920, 1080)
	var view := _action_view(3)
	view._showdown_results = {
		0: _showdown_result(0, HandRank.Category.ONE_PAIR, [13, 14, 12, 7]),
		1: _showdown_result(1, HandRank.Category.FULL_HOUSE, [14, 10]),
	}
	table.bind_view(view, _empty_assignments())
	table.show()
	await get_tree().process_frame
	await get_tree().process_frame

	var pair_label: Label = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Status")
	var full_house_label: Label = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status")
	var hero_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0")
	assert_eq(pair_label.text, "Pair of Kings")
	assert_eq(full_house_label.text, "Full house: Aces full of Tens")
	assert_ne(full_house_label.text, "Winner")
	assert_true(pair_label.visible)
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status").text, "")
	assert_gte(pair_label.position.y, hero_panel.position.y + hero_panel.size.y)


func test_showdown_renders_revealed_losing_opponent_hole_cards() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(3)
	view._revealed_hole_cards = {
		1:
		[
			CardData.new(14, CardData.Suit.SPADES),
			CardData.new(2, CardData.Suit.CLUBS),
		],
		2:
		[
			CardData.new(13, CardData.Suit.HEARTS),
			CardData.new(3, CardData.Suit.DIAMONDS),
		],
	}
	view._showdown_results = {
		1: _showdown_result(1, HandRank.Category.ONE_PAIR, [14, 13, 12, 7]),
		2: _showdown_result(2, HandRank.Category.HIGH_CARD, [13, 12, 11, 9, 7]),
	}
	view._pot_awards = [PotAward.new(0, 90, [1], {1: 90})]
	table.bind_view(view, _empty_assignments())

	var losing_card: PanelContainer = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat2/Content/Footer/HoleCards/ShowdownCard1"
	)
	assert_eq(losing_card.get_node("Content/Rank").text, "K")
	assert_eq(
		losing_card.get_node("Content/Suit").texture.resource_path, "res://assets/ui/heart.svg"
	)
	assert_true(losing_card.visible)
	assert_false(
		(
			table
			. has_node(
				"TableMargin/Felt/TableSurface/Seats/Seat2/Content/Header/AvatarRegion/MainPotWinnerStar"
			)
		)
	)


func test_main_pot_showdown_winner_has_a_yellow_half_avatar_star_without_marking_side_pot_winners(
) -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(3)
	view._showdown_results = {
		0: _showdown_result(0, HandRank.Category.ONE_PAIR, [13, 14, 12, 7]),
		1: _showdown_result(1, HandRank.Category.FULL_HOUSE, [14, 10]),
	}
	view._pot_awards = [
		PotAward.new(0, 120, [1], {1: 120}),
		PotAward.new(1, 40, [0], {0: 40}),
	]
	table.bind_view(view, _empty_assignments())

	var winner_star: TextureRect = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/AvatarRegion/MainPotWinnerStar"
	)
	assert_eq(winner_star.texture.resource_path, "res://assets/ui/winner_star.svg")
	assert_eq(winner_star.custom_minimum_size, Vector2(56, 56))
	assert_eq(winner_star.get_parent().name, "AvatarRegion")
	assert_false(
		(
			table
			. has_node(
				"TableMargin/Felt/TableSurface/Seats/Seat0/Content/Header/AvatarRegion/MainPotWinnerStar"
			)
		)
	)


func _showdown_result(
	seat: int,
	category: HandRank.Category,
	tie_break_values: Array[int],
) -> ShowdownResult:
	var cards: Array[CardData] = [
		CardData.new(14, CardData.Suit.SPADES),
		CardData.new(13, CardData.Suit.HEARTS),
		CardData.new(12, CardData.Suit.DIAMONDS),
		CardData.new(11, CardData.Suit.CLUBS),
		CardData.new(10, CardData.Suit.SPADES),
	]
	var rank := HandRank.new(category, tie_break_values, cards)
	return ShowdownResult.new(seat, [cards[0], cards[1]], rank)


func _waiting_match(bot_actions: Array[PlayerAction]) -> TournamentMatch:
	return _waiting_match_with_stack(bot_actions, 100)


func _waiting_match_with_stack(
	bot_actions: Array[PlayerAction], starting_stack: int
) -> TournamentMatch:
	var config := (
		ResolvedTournamentConfig
		. new(
			2,
			starting_stack,
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


func _disable_action_pacing(table: PokerTableController) -> void:
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 0.0
	timing_config.showdown_pause_seconds = 0.0
	table.set_action_timing_config(timing_config)


func _freeze_action_pacing(table: PokerTableController) -> void:
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 60.0
	timing_config.showdown_pause_seconds = 60.0
	table.set_action_timing_config(timing_config)


func _empty_assignments() -> Dictionary[int, String]:
	return {}


func _event_texts(table: PokerTableController) -> Array[String]:
	var event_texts: Array[String] = []
	for event_text: String in (table.get_node("%EventLog") as RichTextLabel).text.split("\n"):
		event_texts.append(event_text)
	return event_texts


func _latest_player_action_for(view: GameView, seat: int) -> PublicActionRecord:
	var latest: PublicActionRecord = null
	for record: PublicActionRecord in view.action_history:
		if record.record_kind == PublicActionRecord.Kind.ACTION and record.seat == seat:
			latest = record
	return latest


func _seat_view(view: GameView, seat: int) -> PlayerView:
	for player_view: PlayerView in view.seats:
		if player_view.seat == seat:
			return player_view
	return null


func _total_chips(view: GameView) -> int:
	var total: int = view.pot_amount
	for player_view: PlayerView in view.seats:
		total += player_view.stack
	return total


func _current_bet(view: GameView) -> int:
	var current_bet: int = 0
	for player_view: PlayerView in view.seats:
		current_bet = maxi(current_bet, player_view.bet_this_round)
	return current_bet


func _action_view(player_count: int) -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	for seat: int in range(player_count):
		var agent: Agent = (
			HumanAgent.new() if seat == 0 else RandomAgent.new(RandomNumberGenerator.new())
		)
		var player := Player.new(&"action_%d" % seat, "Player %d" % (seat + 1), seat, 100, agent)
		view._seats.append(PlayerView.new(player))
	return view


func _touch_press() -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	return event


func _left_mouse_press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event
