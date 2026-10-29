extends "res://tests/support/poker_gut_test.gd"

const PokerTableScene := preload("res://scenes/poker_table.tscn")

var _input_viewport: SubViewport


class CallingAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		return (
			PlayerAction.check_action()
			if PlayerAction.Kind.CHECK in view.legal_actions
			else PlayerAction.call_action()
		)


func test_summary_holds_completed_hand_until_closed_and_resumes_once() -> void:
	var table: PokerTableController = await _table()
	table._on_fold_pressed()
	table._action_pacer.cancel()
	for transition: int in range(10):
		if table._match.get_view_for(0).hand_complete:
			break
		table._match.advance_one_action()
	table.refresh_from_match()
	table._schedule_after_completed_hand()
	var hand_number: int = table._bound_view.hand_number
	assert_true(table._bound_view.hand_complete)
	table._open_phone_showdown()
	await get_tree().create_timer(0.12).timeout
	assert_eq(table._match.get_view_for(0).hand_number, hand_number)
	assert_true(table._phone_showdown_overlay.visible)
	assert_true(table._modal_guard.is_active())
	table._open_phone_overflow_menu()
	await _settle()
	assert_eq(
		table._match.get_view_for(0).hand_number, hand_number, "Switching surfaces must not resume"
	)
	table._close_phone_overflow_menu()
	await get_tree().create_timer(0.12).timeout
	assert_eq(table._match.get_view_for(0).hand_number, hand_number + 1)
	assert_false(table._modal_guard.is_active())


func test_menu_blocks_actual_touch_and_keyboard_actions_and_restores_focus() -> void:
	var table: PokerTableController = await _table()
	var history_count: int = table._bound_view.action_history.size()
	table._phone_more_button.grab_focus()
	table._open_phone_overflow_menu()
	await _settle()
	assert_true(table._phone_menu_close_button.has_focus())
	await _touch(table._fold_button.get_global_rect().get_center())
	assert_eq(table._bound_view.action_history.size(), history_count)
	# Even a stray focused underlying control cannot submit a keyboard action.
	table._fold_button.grab_focus()
	await _key(KEY_ENTER)
	assert_eq(table._bound_view.action_history.size(), history_count)
	await _key(KEY_TAB)
	var focused: Control = table.get_viewport().gui_get_focus_owner()
	assert_true(table._phone_overflow_menu.is_ancestor_of(focused))
	await _key(KEY_ESCAPE)
	assert_false(table._phone_overflow_menu.visible)
	assert_true(table._phone_more_button.has_focus())
	assert_eq(table._bound_view.action_history.size(), history_count)
	await _touch(table._fold_button.get_global_rect().get_center())
	assert_gt(
		table._bound_view.action_history.size(),
		history_count,
		"Positive control: same touch folds after closing"
	)


func test_keypad_cancel_then_menu_quit_preserves_draft_and_modal_exclusivity() -> void:
	var table: PokerTableController = await _table()
	var original_back_policy: bool = get_tree().quit_on_go_back
	table._open_phone_seat_detail(1)
	await _settle()
	assert_true(table._overlay_views.detail_overlay.visible)
	assert_false(get_tree().quit_on_go_back)
	table.show_wager_keypad()
	await _settle()
	assert_false(table._overlay_views.detail_overlay.visible)
	assert_true(table._wager_keypad.visible)
	assert_null(table._wager_keypad.get_action_control(&"quit"))
	assert_null(table._wager_keypad.find_child("Quit", true, false))
	table._wager_keypad.get_action_control(&"2").emit_signal("pressed")
	table._wager_keypad.get_action_control(&"cancel").emit_signal("pressed")
	assert_false(table._wager_keypad.visible)
	assert_false(table._phone_quit_confirmation.visible)
	assert_eq(table._wager_input.text, "")
	table._open_phone_overflow_menu()
	table._phone_menu_quit_button.pressed.emit()
	assert_false(table._phone_overflow_menu.visible)
	assert_true(table._phone_quit_confirmation.visible)
	assert_eq(table._wager_input.text, "")
	# Synthetic engine notification covers the engine path, not browser history.
	table._modal_guard.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle()
	assert_false(table._phone_quit_confirmation.visible)
	assert_eq(get_tree().quit_on_go_back, original_back_policy)
	assert_eq(table._match.state, TournamentMatch.State.RUNNING)


func test_seat_refresh_and_profile_exit_release_modal_and_restore_valid_focus() -> void:
	var table: PokerTableController = await _table()
	table._open_phone_seat_detail(1)
	table.refresh_from_match()
	await _settle()
	assert_true(
		table._overlay_views.detail_overlay.is_ancestor_of(
			table.get_viewport().gui_get_focus_owner()
		)
	)
	table.size = Vector2(1280, 720)
	await _settle()
	assert_false(table._modal_guard.is_active())
	assert_false(table._overlay_views.detail_overlay.visible)
	assert_eq(table._overlay_views.detail_seat, Table.NO_SEAT)


func test_nonphone_keypad_cancel_then_table_quit_preserves_original_field() -> void:
	var table: PokerTableController = await _table(Vector2i(1280, 720))
	table._wager_input.text = "  "
	table.show_wager_keypad()
	assert_null(table._wager_keypad.get_action_control(&"quit"))
	table._wager_keypad.get_action_control(&"2").pressed.emit()
	table._wager_keypad.get_action_control(&"cancel").pressed.emit()
	assert_false(table._wager_keypad.visible)
	assert_eq(table._wager_input.text, "  ")
	assert_false(table._quit_confirmation.visible)
	table._quit_button.pressed.emit()
	assert_true(table._quit_confirmation.visible)
	assert_true(table._modal_guard.is_active())
	table._quit_confirmation.get_cancel_button().pressed.emit()
	await _settle()
	assert_false(table._quit_confirmation.visible)
	assert_false(table._modal_guard.is_active())
	assert_eq(table._match.state, TournamentMatch.State.RUNNING)
	assert_eq(table._wager_input.text, "  ")


func test_outside_keypad_touch_does_not_click_through_or_commit_draft() -> void:
	var table: PokerTableController = await _table(Vector2i(1280, 720))
	table._wager_input.text = "75"
	var history_count: int = table._bound_view.action_history.size()
	table.show_wager_keypad()
	table.show_wager_keypad()
	await _settle()
	assert_true(table._wager_keypad.visible, "Reopening must not queue a stale popup hide")
	table._wager_keypad.get_action_control(&"clear").emit_signal("pressed")
	table._wager_keypad.get_action_control(&"2").emit_signal("pressed")
	var target: Vector2 = table._fold_button.get_global_rect().get_center()
	assert_false(
		Rect2(Vector2(table._wager_keypad.position), Vector2(table._wager_keypad.size)).has_point(
			target
		)
	)
	await _touch(target)
	assert_eq(table._bound_view.action_history.size(), history_count)
	assert_eq(table._wager_input.text, "75")
	table._wager_keypad.cancel()


func _table(viewport_size: Vector2i = Vector2i(390, 844)) -> PokerTableController:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(viewport_size)
	_input_viewport = SubViewport.new()
	_input_viewport.size = viewport_size
	add_child_autofree(_input_viewport)
	_input_viewport.add_child(table)
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 0.05
	timing.showdown_pause_seconds = 0.05
	table.set_action_timing_config(timing)
	var match_instance := (
		TournamentMatch
		. new(
			ResolvedTournamentConfig.new(
				2, 100, 5, 10, 9123, &"single_table", {0: &"human", 1: &"scripted"}
			),
			{0: HumanAgent.new(), 1: CallingAgent.new()},
		)
	)
	assert_eq(match_instance.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	table.bind_match(match_instance, 0, {})
	await _settle()
	return table


func _touch(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = position
		event.pressed = pressed
		_input_viewport.push_input(event)
		await get_tree().process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		_input_viewport.push_input(event)
		await get_tree().process_frame


func _settle() -> void:
	for index: int in range(4):
		await get_tree().process_frame
