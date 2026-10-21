# gdlint: disable=max-public-methods
extends "res://tests/support/poker_gut_test.gd"

const PokerTableScene := preload("res://scenes/poker_table.tscn")
const GuiActionTimingConfigScript := preload("res://scripts/gui/gui_action_timing_config.gd")


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
	assert_string_contains(table.get_node("%MinWagerButton").text, "Min Raise")
	assert_eq(table.get_node("%PotRaiseButton").text, "Pot raise")
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
	assert_eq(wager_input.text, "2")

	table.submit_wager_total(view.minimum_wager_total)

	assert_gt(match_instance.get_view_for(0).pot_amount, 15)
	assert_true(_event_texts(table).any(func(text: String) -> bool: return "action" in text))


func test_pot_raise_uses_displayed_pot_and_respects_minimum_and_stack_bounds() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_disable_action_pacing(table)
	table.bind_match(match_instance, 0, _empty_assignments())
	assert_eq(table.get_node("%PotRaiseButton").text, "Pot raise")
	assert_true(table.get_node("%PotRaiseButton").disabled)

	var view: GameView = match_instance.get_view_for(0)
	view.pot_amount = 25
	view.minimum_wager_total = 20
	view.maximum_wager_total = 100
	view._legal_actions = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CALL,
		PlayerAction.Kind.RAISE,
		PlayerAction.Kind.ALL_IN,
	]
	table.bind_view(view, _empty_assignments())
	assert_eq(table.displayed_pot_amount, 25)
	assert_false(table.get_node("%PotRaiseButton").disabled)
	table.get_node("%PotRaiseButton").emit_signal("pressed")
	assert_true(_event_texts(table).any(func(text: String) -> bool: return "Raise 25" in text))

	view.pot_amount = 120
	table.bind_view(view, _empty_assignments())
	assert_true(table.get_node("%PotRaiseButton").disabled)
	assert_eq(table.get_node("%WagerInput").text, "")
	view.pot_amount = 10
	view.minimum_wager_total = 20
	table.bind_view(view, _empty_assignments())
	assert_true(table.get_node("%PotRaiseButton").disabled)


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
	assert_false(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Action") as Label).visible
	)
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action") as Label).text, "Check"
	)
	assert_true(_event_texts(table).any(func(text: String) -> bool: return "Call" in text))

	table.get_node("%CheckCallButton").emit_signal("pressed")
	var turn_view: GameView = match_instance.get_view_for(0)
	assert_eq(turn_view.street, &"turn")
	assert_false(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Action") as Label).visible
	)
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action") as Label).text, "Check"
	)
	assert_true(_event_texts(table).any(func(text: String) -> bool: return "Flop begins" in text))

	table.get_node("%CheckCallButton").emit_signal("pressed")
	var river_view: GameView = match_instance.get_view_for(0)
	assert_eq(river_view.street, &"river")
	assert_false(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Action") as Label).visible
	)
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action") as Label).text, "Check"
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
	table.bind_view(view, _empty_assignments())

	assert_eq(table.get_node("%ActionStatus").text, "Player 1 wins the tournament!")
	assert_string_contains(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/Identity/Name")
			. text
		),
		"(eliminated)"
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
	_disable_action_pacing(table)
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
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Action").text, "Small blind 5"
	)
	assert_eq(
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action").text, "Big blind 10"
	)
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Action").text, "Raise 30")
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
	var action_label := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Action") as Label
	assert_eq(action_label.text, "Call 10")
	assert_true(action_label.visible)

	var next_hand_view := _action_view(3)
	table.bind_view(next_hand_view, _empty_assignments())
	action_label = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Action") as Label
	assert_eq(action_label.text, "")
	assert_false(action_label.visible)


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
	assert_true(folded_seat.get_node("Content/Header/Avatar").use_parent_material)
	assert_eq(hole_cards.get_child_count(), 0)
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action").text, "Fold")


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
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action").text, "All-in 100")
	assert_eq(marker.custom_minimum_size.x, 96.0)


func test_showdown_summaries_use_recipient_safe_results_above_revealed_seats() -> void:
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

	var pair_label: Label = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Showdown")
	var full_house_label: Label = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1Showdown"
	)
	var hero_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0")
	assert_eq(pair_label.text, "Pair of Kings")
	assert_eq(full_house_label.text, "Full house: Aces full of Tens")
	assert_true(pair_label.visible)
	assert_false(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Showdown").visible)
	assert_lte(pair_label.position.y + pair_label.size.y, hero_panel.position.y)


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
		table.has_node("TableMargin/Felt/TableSurface/Seats/Seat2/Content/Header/MainPotWinnerStar")
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
		"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/MainPotWinnerStar"
	)
	assert_eq(winner_star.texture.resource_path, "res://assets/ui/winner_star.svg")
	assert_eq(winner_star.custom_minimum_size, Vector2(56, 56))
	assert_eq(winner_star.get_parent().name, "Header")
	assert_false(
		table.has_node("TableMargin/Felt/TableSurface/Seats/Seat0/Content/Header/MainPotWinnerStar")
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


func _disable_action_pacing(table: PokerTableController) -> void:
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 0.0
	timing_config.showdown_pause_seconds = 0.0
	table.set_action_timing_config(timing_config)


func _empty_assignments() -> Dictionary[int, String]:
	return {}


func _event_texts(table: PokerTableController) -> Array[String]:
	var event_texts: Array[String] = []
	for event_text: String in (table.get_node("%EventLog") as RichTextLabel).text.split("\n"):
		event_texts.append(event_text)
	return event_texts


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
