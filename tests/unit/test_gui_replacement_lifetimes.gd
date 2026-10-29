extends GutTest

const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")

var _viewport: SubViewport
var _table: GuiReplacementTableController


class PassiveAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		return (
			PlayerAction.check_action()
			if PlayerAction.Kind.CHECK in view.legal_actions
			else PlayerAction.call_action()
		)


func after_each() -> void:
	if is_instance_valid(_table):
		_table.teardown()
		await _await_idle()


func test_new_match_cancels_the_old_numeric_transaction_without_submitting_its_draft() -> void:
	var original: TournamentMatch = _game()
	_mount(original)
	assert_true(await _settle())
	_table.use_keypad(true)
	assert_true(await _settle())
	_table.set_wager_draft("00020")
	await _activate(_table.get_composition().get_control(&"wager"))
	var host: GuiOverlayHost = _table.get_overlay_host()
	assert_eq(host.get_active_kind(), &"number")
	watch_signals(host)
	await _activate(host.get_keypad().get_control(&"clear"))
	await _activate(host.get_keypad().get_control(&"9"))
	assert_eq(host.get_keypad().get_draft(), "9")
	var old_count: int = original.get_view_for(0).action_history.size()
	var replacement: TournamentMatch = _game()
	var new_count: int = replacement.get_view_for(0).action_history.size()
	assert_true(_table.bind_match(replacement, 0, {}))
	assert_true(await _settle())
	assert_signal_emit_count(host, "number_cancelled", 1)
	assert_signal_not_emitted(host, "number_committed")
	assert_false(host.is_active())
	assert_false(host.get_keypad().is_active())
	assert_eq(original.get_view_for(0).action_history.size(), old_count)
	assert_eq(replacement.get_view_for(0).action_history.size(), new_count)
	assert_ne(_table.get_wager_draft(), "9")
	await _key(KEY_ENTER)
	assert_eq(replacement.get_view_for(0).action_history.size(), new_count)
	assert_signal_not_emitted(host, "number_committed")


func test_new_recipient_with_fewer_seats_closes_revealed_detail_and_removes_old_cards() -> void:
	var game: TournamentMatch = _game(3)
	for index: int in 8:
		var view: GameView = game.get_view_for(0)
		if view.hand_complete:
			break
		var action: PlayerAction = (
			PlayerAction.check_action()
			if PlayerAction.Kind.CHECK in view.legal_actions
			else PlayerAction.call_action()
		)
		game.submit_human_action(action)
	var shown: GameView = game.get_view_for(0)
	assert_true(shown.hand_complete)
	assert_true(shown.revealed_hole_cards.has(2))
	_mount(null)
	assert_true(_table.bind_view(shown, {}))
	assert_true(await _settle())
	_table.get_composition().seat_detail_requested.emit(2)
	await wait_process_frames(4)
	var host: GuiOverlayHost = _table.get_overlay_host()
	assert_eq(host.get_active_kind(), &"seat")
	var before: GuiLayoutSnapshot = _table.get_layout_snapshot()
	assert_eq(before.overlays.size(), 1)
	assert_eq(before.overlays[0].selected_seat, 2)
	assert_eq(before.overlays[0].cards.size(), 2)
	for card: GuiCardSnapshot in before.overlays[0].cards:
		assert_true(card.authorized)
		assert_eq(card.kind, GuiCardSnapshot.Kind.FACE)
		assert_false(card.rank.text.is_empty())
	assert_true(_table.bind_view(_game().get_view_for(0), {}))
	assert_true(await _settle())
	assert_false(host.is_active())
	assert_false(host.get_control(&"seat_cards").is_visible_in_tree())
	var after: GuiLayoutSnapshot = _table.get_layout_snapshot()
	assert_true(after.overlays.is_empty())
	for seat: GuiSeatSnapshot in after.seats.values():
		assert_ne(seat.seat_id, 2)
	for card: GuiCardSnapshot in before.overlays[0].cards:
		assert_false(card.rank.text.is_empty(), "Prior detached snapshots remain unchanged")


func test_invalid_bind_during_measurement_settles_and_exposes_no_previous_private_snapshot(
) -> void:
	_mount(_game())
	assert_true(await _settle())
	var shown: bool = false
	for seat: GuiSeatSnapshot in _table.get_layout_snapshot().seats.values():
		if seat.hero:
			shown = shown or seat.cards[0].kind == GuiCardSnapshot.Kind.FACE
	assert_true(shown, "Positive control: the previous recipient had visible private cards")
	_table.open_menu()
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(390, 844)))
	assert_true(_table.refresh_from_match())
	assert_true(await _await_probes())
	assert_false(_table.bind_view(null, {}))
	assert_true(await _await_idle())
	assert_false(_table.get_overlay_host().is_active())
	assert_false(_table.is_action_advance_pending())
	assert_eq(_table.get_render_counters().active_probes, 0)
	assert_true(_table.get_layout_snapshot().overlays.is_empty())
	assert_true(_table.get_layout_snapshot().seats.is_empty())
	assert_true(_table.find_children("*", "SubViewport", true, false).is_empty())
	assert_false(_table.bind_match(null, 0, {}))
	assert_true(await _await_idle())
	assert_true(_table.get_layout_snapshot().seats.is_empty())
	assert_false(_table.get_table_view_model().valid)


func test_teardown_and_rebinding_retire_probes_and_invalidate_held_advancement() -> void:
	var original: TournamentMatch = _game()
	_mount(original)
	assert_true(await _settle())
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 0.0
	timing.showdown_pause_seconds = 0.0
	_table.set_action_timing_config(timing)
	assert_ne(_table.submit_intent(&"minimum").status, StepResult.Status.ERROR)
	_table.open_menu()
	assert_true(await _settle())
	await wait_process_frames(3)
	assert_true(_table.get_overlay_host().is_active())
	assert_true(_table.is_action_advance_pending())
	var old_count: int = original.get_view_for(0).action_history.size()
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(390, 844)))
	assert_true(await _await_probes())
	_table.teardown()
	assert_false(_table.get_overlay_host().is_active())
	assert_false(_table.is_action_advance_pending())
	var replacement: TournamentMatch = _game()
	var new_count: int = replacement.get_view_for(0).action_history.size()
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(1920, 1200)))
	assert_true(_table.bind_match(replacement, 0, {}))
	assert_true(await _settle())
	assert_true(await _await_idle())
	assert_false(_table.get_overlay_host().is_active())
	assert_false(_table.is_action_advance_pending())
	assert_eq(original.get_view_for(0).action_history.size(), old_count)
	assert_eq(replacement.get_view_for(0).action_history.size(), new_count)
	assert_eq(_table.get_render_counters().active_probes, 0)
	assert_true(_table.find_children("*", "SubViewport", true, false).is_empty())
	assert_eq(_table.get_table_view_model().hero_seat, 0)


func _mount(game: TournamentMatch) -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1200)
	add_child_autofree(_viewport)
	_table = TableScene.instantiate()
	_table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_table.size = Vector2(1920, 1200)
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 1.0
	timing.showdown_pause_seconds = 1.0
	_table.action_timing_config = timing
	_viewport.add_child(_table)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(_table.size))
	if game != null:
		assert_true(_table.bind_match(game, 0, {}))


func _settle() -> bool:
	for frame: int in 180:
		await get_tree().process_frame
		var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
		if not snapshot.pending and snapshot.ready:
			return true
	return false


func _await_probes() -> bool:
	for frame: int in 180:
		await get_tree().process_frame
		if _table.get_render_counters().active_probes > 0:
			return true
	return false


func _await_idle() -> bool:
	for frame: int in 180:
		await get_tree().process_frame
		if (
			not _table.get_layout_snapshot().pending
			and _table.get_render_counters().active_probes == 0
		):
			return true
	return false


func _activate(control: Control) -> void:
	assert_not_null(control)
	assert_true(control.is_visible_in_tree())
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame
	await wait_process_frames(3)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame


func _game(count: int = 2) -> TournamentMatch:
	var ids: Dictionary[int, StringName] = {0: &"human"}
	var agents: Dictionary[int, Agent] = {0: HumanAgent.new()}
	for seat: int in range(1, count):
		ids[seat] = &"scripted"
		agents[seat] = PassiveAgent.new()
	var config := ResolvedTournamentConfig.new(count, 100, 5, 10, 9123, &"single_table", ids)
	var game := TournamentMatch.new(config, agents)
	assert_eq(game.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	return game
