extends GutTest

const Controller := preload("res://scenes/gui/ReplacementPokerTable.tscn")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const BrowserFixture := preload("res://tests/support/gui_browser_capture_fixture.gd")
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
	await wait_process_frames(2)


func test_live_binding_keeps_private_cards_safe_and_reuses_widgets_without_new_probes() -> void:
	_setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE)
	var game: TournamentMatch = _game(2)
	assert_true(_table.bind_match(game, 0, _avatars(2), _names(2)))
	assert_true(await _settle())
	var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
	assert_true(snapshot.ready)
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	assert_eq(snapshot.seats[1].cards[0].kind, GuiCardSnapshot.Kind.BACK)
	var composition: GuiTableComposition = _table.get_composition()
	var counters: Dictionary = _table.get_render_counters()
	assert_eq(counters.active_probes, 0)
	assert_true(_table.get_table_view_model().valid)
	assert_ne(_table.submit_intent(&"check_call").status, StepResult.Status.ERROR)
	assert_true(await _settle())
	assert_same(_table.get_composition(), composition)
	assert_eq(_table.get_render_counters().probes, counters.probes)
	assert_eq(_table.get_render_counters().mounts, counters.mounts)
	assert_eq(_table.get_render_counters().active_probes, 0)
	assert_eq(Invariants.validate_snapshot(_table.get_layout_snapshot()), PackedStringArray())


func test_builtin_font_and_stress_copy_fit_actual_phone_allocations() -> void:
	_setup(Vector2(1000, 500), GuiSizeClass.LayoutMode.PHONE_LANDSCAPE)
	var descriptor: Dictionary = BrowserFixture.descriptor(3, true)
	assert_true(_table.bind_view(descriptor.view, descriptor.avatars, descriptor.names))
	assert_true(await _settle())
	var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
	assert_true(snapshot.ready)
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	var opponent: GuiSeatSnapshot = snapshot.seats[1]
	assert_eq(opponent.fields[&"name"].text, "Annalise")
	assert_eq(opponent.fields[&"stack"].text, "1000000")
	assert_string_contains(opponent.fields[&"action"].text, "1000000")
	for role: StringName in [&"name", &"stack", &"action"]:
		var value: GuiLayoutElement = opponent.fields[role]
		assert_lte(value.required_size.x, value.allocated_size.x + 0.5, String(role))
		assert_lte(value.required_size.y, value.allocated_size.y + 0.5, String(role))
	var compact_action: GuiLayoutElement = snapshot.elements[&"action/check_call"]
	assert_eq(compact_action.text, "Call 1000000")
	assert_lte(compact_action.required_size.x, compact_action.allocated_size.x + 0.5)
	assert_lte(compact_action.required_size.y, compact_action.allocated_size.y + 0.5)
	for control: Control in _table.get_composition().get_seat_controls().values():
		assert_true(control.get_theme_font("font").resource_path.is_empty())


func test_safe_origin_is_applied_once_and_geometry_reuses_active_composition_and_value_cache(
) -> void:
	_setup(Vector2(1920, 1200), GuiSizeClass.LayoutMode.WIDE)
	_table.set_viewport_geometry(
		GuiViewportGeometry.injected(_table.size, Rect2(23, 31, 1850, 1120))
	)
	assert_true(_table.bind_view(_fixture(6), _avatars(6), _names(6)))
	assert_true(await _settle())
	var composition: GuiTableComposition = _table.get_composition()
	var counters: Dictionary = _table.get_render_counters()
	assert_eq(_table.position, Vector2.ZERO)
	assert_eq(_table.get_layout_snapshot().usable_rect, Rect2(23, 31, 1850, 1120))
	assert_eq(composition.global_position, Vector2(23, 31))
	_table.set_viewport_geometry(
		GuiViewportGeometry.injected(_table.size, Rect2(41, 53, 1800, 1100))
	)
	assert_true(await _settle())
	assert_same(_table.get_composition(), composition)
	assert_eq(_table.get_render_counters().probes, counters.probes)
	assert_eq(_table.get_layout_snapshot().usable_rect, Rect2(41, 53, 1800, 1100))
	assert_eq(composition.global_position, Vector2(41, 53))
	assert_eq(Invariants.validate_snapshot(_table.get_layout_snapshot()), PackedStringArray())


func test_mode_exit_cancels_number_once_preserves_raw_draft_and_focuses_new_more() -> void:
	_setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE)
	assert_true(_table.bind_view(_fixture(4), {}, _names(4)))
	assert_true(await _settle())
	_table.set_wager_draft("00075")
	var old_id: int = _table.get_composition().get_instance_id()
	var overlay: GuiOverlayHost = _table.get_overlay_host()
	var overlay_id: int = overlay.get_instance_id()
	watch_signals(overlay)
	await _tap(_table.get_composition().get_control(&"wager"))
	assert_true(overlay.get_keypad().is_active())
	await _tap(overlay.get_keypad().get_control(&"9"))
	assert_ne(overlay.get_keypad().get_draft(), "00075")
	_viewport.size = Vector2i(1920, 1200)
	_table.set_layout_mode_override(GuiSizeClass.LayoutMode.WIDE)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(_viewport.size)))
	assert_true(await _settle())
	assert_ne(_table.get_composition().get_instance_id(), old_id)
	assert_eq(overlay.get_instance_id(), overlay_id)
	assert_false(overlay.is_active())
	assert_signal_emit_count(overlay, "number_cancelled", 1)
	assert_eq(_table.get_wager_draft(), "00075")
	assert_eq(_table.get_composition().get_wager_draft(), "00075")
	assert_true(_table.get_composition().get_control(&"more").has_focus())


func test_leaving_a_fitting_layout_for_capacity_guidance_cancels_numeric_transaction() -> void:
	_setup(Vector2(1920, 1400), GuiSizeClass.LayoutMode.WIDE)
	assert_true(_table.bind_view(_fixture(9), _avatars(9), _names(9)))
	assert_true(await _settle())
	_table.set_wager_draft("00075")
	var overlay: GuiOverlayHost = _table.get_overlay_host()
	watch_signals(overlay)
	await _tap(_table.get_composition().get_control(&"wager"))
	assert_true(overlay.get_keypad().is_active())
	_viewport.size = Vector2i(390, 844)
	_table.set_layout_mode_override(GuiSizeClass.LayoutMode.PHONE)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(_viewport.size)))
	assert_true(await _settle())
	assert_false(overlay.is_active())
	assert_signal_emit_count(overlay, "number_cancelled", 1)
	assert_eq(_table.get_wager_draft(), "00075")
	assert_false(_table.get_layout_snapshot().ready)
	assert_string_contains(_table.get_layout_snapshot().fit_guidance, "larger layout")
	assert_eq(_table.submit_intent(&"wager", "75").status, StepResult.Status.ERROR)
	assert_eq(Invariants.validate_snapshot(_table.get_layout_snapshot()), PackedStringArray())


func test_inline_draft_caret_selection_and_focus_survive_mode_reconstruction() -> void:
	_setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE)
	_table.use_keypad(false)
	assert_true(_table.bind_view(_fixture(2), {}, _names(2)))
	assert_true(await _settle())
	_table.set_wager_draft("00075")
	var field := _table.get_composition().get_control(&"total") as LineEdit
	field.grab_focus()
	field.caret_column = 4
	field.select(1, 3)
	_viewport.size = Vector2i(1920, 1200)
	_table.set_layout_mode_override(GuiSizeClass.LayoutMode.WIDE)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(_viewport.size)))
	assert_true(await _settle())
	var replaced := _table.get_composition().get_control(&"total") as LineEdit
	assert_eq(replaced.text, "00075")
	assert_eq(replaced.caret_column, 4)
	assert_eq(replaced.get_selection_from_column(), 1)
	assert_eq(replaced.get_selection_to_column(), 3)
	assert_true(replaced.has_focus())


func test_numeric_pot_caption_shows_contribution_but_selects_the_street_total() -> void:
	_setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE)
	assert_true(_table.bind_view(_fixture(4), {}, _names(4)))
	assert_true(await _settle())
	_table.set_wager_draft("00075")
	var actions: ActionBarViewModel = _table.get_table_view_model().actions
	assert_eq(actions.pot_contribution, 45)
	assert_eq(actions.pot_total, 55)
	await _tap(_table.get_composition().get_control(&"wager"))
	var keypad: GuiNumericKeypad = _table.get_overlay_host().get_keypad()
	assert_eq((keypad.get_control(&"pot") as Button).text.replace("\n", " "), "Pot 45")
	await _tap(keypad.get_control(&"pot"))
	assert_eq(keypad.get_draft(), "55")
	await _tap(keypad.get_control(&"cancel"))
	assert_eq(_table.get_wager_draft(), "00075")


func test_menu_log_blocks_core_actions_and_holds_pacing_across_panel_switches() -> void:
	_setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE)
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 0.025
	_table.set_action_timing_config(timing)
	var game: TournamentMatch = _game(2)
	assert_true(_table.bind_match(game, 0, _avatars(2), _names(2)))
	assert_true(await _settle())
	assert_ne(_table.submit_intent(&"minimum").status, StepResult.Status.ERROR)
	_table.open_menu()
	var before: int = game.get_view_for(0).action_history.size()
	assert_eq(_table.submit_intent(&"fold").status, StepResult.Status.ERROR)
	await wait_seconds(0.08)
	assert_eq(game.get_view_for(0).action_history.size(), before)
	assert_true(_table.is_action_advance_pending())
	var overlay: GuiOverlayHost = _table.get_overlay_host()
	await _tap(overlay.get_control(&"menu_log"))
	assert_eq(overlay.get_active_kind(), &"log")
	assert_false(overlay.get_log().get_log_text().is_empty())
	assert_eq(
		Invariants.validate_snapshot(_table.get_layout_snapshot(), [&"log"]), PackedStringArray()
	)
	assert_eq(game.get_view_for(0).action_history.size(), before)
	overlay.close()
	await wait_seconds(0.08)
	assert_gt(game.get_view_for(0).action_history.size(), before)


func test_detail_snapshots_redact_unauthorized_child_faces_and_leave_bound_cards_private() -> void:
	_setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE)
	assert_true(_table.bind_view(_fixture(4), {}, _names(4)))
	assert_true(await _settle())
	var token: Control = _table.get_composition().get_seat_controls()[1]
	token.grab_focus()
	await _enter()
	var overlay: GuiOverlayHost = _table.get_overlay_host()
	assert_eq(overlay.get_active_kind(), &"seat")
	var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
	assert_eq(Invariants.validate_snapshot(snapshot, [&"seat_detail"]), PackedStringArray())
	assert_eq(snapshot.overlays[0].cards[0].kind, GuiCardSnapshot.Kind.BACK)
	var cards := overlay.get_control(&"seat_cards") as GuiHoleCards
	cards.cards[0].render(CardViewModel.face(CardData.new(14, CardData.Suit.SPADES)))
	await wait_process_frames(3)
	snapshot = _table.get_layout_snapshot()
	assert_false(snapshot.overlays[0].cards[0].authorized)
	assert_true(snapshot.overlays[0].cards[0].rank.privacy_redacted)
	assert_eq(snapshot.overlays[0].cards[0].rank.text, "")
	assert_eq(snapshot.seats[1].cards[0].kind, GuiCardSnapshot.Kind.BACK)


func test_guidance_keeps_menu_quit_reachable_and_stops_the_adopted_match() -> void:
	_setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE)
	var game: TournamentMatch = _game(6)
	assert_true(_table.bind_match(game, 0, _avatars(6), _names(6)))
	assert_true(await _settle())
	var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
	assert_false(snapshot.ready)
	assert_false(snapshot.fit_guidance.is_empty())
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	watch_signals(_table)
	_table.open_menu()
	await _tap(_table.get_overlay_host().get_control(&"menu_quit"))
	assert_eq(_table.get_overlay_host().get_active_kind(), &"quit")
	await _tap(_table.get_overlay_host().get_control(&"quit_confirm"))
	assert_eq(game.state, TournamentMatch.State.FINISHED)
	assert_eq(game.end_reason, &"player_quit")
	assert_signal_emit_count(_table, "tournament_quit_confirmed", 1)
	assert_false(_table.get_overlay_host().is_active())


func test_modality_changes_during_measurement_discard_stale_probe_minima_and_keep_draft() -> void:
	_setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE)
	assert_true(_table.bind_view(_fixture(2), {}, _names(2)))
	await wait_process_frames(3)
	_table.set_wager_draft("00075")
	_table.use_keypad(false)
	assert_true(await _settle())
	assert_true(_table.get_composition().get_control(&"total").visible)
	assert_eq(_table.get_wager_draft(), "00075")
	_table.use_keypad(true)
	assert_true(await _settle())
	assert_false(_table.get_composition().get_control(&"total").visible)
	assert_eq(_table.get_render_counters().active_probes, 0)
	assert_eq(_table.get_wager_draft(), "00075")


func test_stale_measurements_and_invalid_rebinding_never_publish_prior_recipient_identity() -> void:
	_setup(Vector2(1920, 1200), GuiSizeClass.LayoutMode.WIDE)
	assert_true(_table.bind_view(_fixture(6), _avatars(6), _names(6)))
	await wait_process_frames(3)
	assert_true(_table.bind_view(_fixture(2), _avatars(2), {0: "New recipient", 1: "New opponent"}))
	assert_true(await _settle())
	assert_eq(_table.get_layout_snapshot().seats.size(), 2)
	assert_eq(_table.get_layout_snapshot().seats[1].fields[&"name"].text, "New opponent")
	assert_eq(_table.get_render_counters().active_probes, 0)
	_table.open_menu()
	assert_false(_table.bind_view(null, {}))
	await wait_process_frames(3)
	assert_false(_table.get_overlay_host().is_active())
	assert_false(_table.get_layout_snapshot().ready)
	assert_false(_table.get_layout_snapshot().pending)


func test_freeing_controller_during_probe_wait_releases_owned_frame_continuations() -> void:
	_setup(Vector2(1920, 1200), GuiSizeClass.LayoutMode.WIDE)
	assert_true(_table.bind_view(_fixture(6), _avatars(6), _names(6)))
	await wait_process_frames(2)
	assert_gt(_table.get_render_counters().active_probes, 0)
	var reference: WeakRef = weakref(_table)
	_table.free()
	_table = null
	await wait_process_frames(6)
	assert_null(reference.get_ref())
	assert_true(_viewport.find_children("*", "SubViewport", true, false).is_empty())
	assert_push_error_count(0)


func _setup(size: Vector2, mode: GuiSizeClass.LayoutMode) -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(_viewport)
	_table = Controller.instantiate()
	_table.touch_entry = true
	_table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_viewport.add_child(_table)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(size))
	_table.set_layout_mode_override(mode)
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 10.0
	timing.showdown_pause_seconds = 10.0
	_table.set_action_timing_config(timing)


func _settle() -> bool:
	for frame: int in 180:
		await wait_process_frames(1)
		var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
		if not snapshot.pending and (snapshot.ready or not snapshot.fit_guidance.is_empty()):
			return true
	return false


func _fixture(count: int) -> GameView:
	return GuiVisualStateFixtures.by_id(&"human-turn-flop", count).view as GameView


func _names(count: int) -> Dictionary[int, String]:
	var names: Dictionary[int, String] = {}
	for id: int in count:
		names[id] = "Human" if id == 0 else "Emiliano"
	return names


func _avatars(count: int) -> Dictionary[int, String]:
	var avatars: Dictionary[int, String] = {}
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	for id: int in count:
		avatars[id] = paths[id]
	return avatars


func _game(count: int) -> TournamentMatch:
	var ids: Dictionary[int, StringName] = {}
	var agents: Dictionary[int, Agent] = {}
	for id: int in count:
		ids[id] = &"human" if id == 0 else &"scripted"
		agents[id] = HumanAgent.new() if id == 0 else PassiveAgent.new()
	var config := ResolvedTournamentConfig.new(count, 100, 5, 10, 9123, &"single_table", ids)
	var game := TournamentMatch.new(config, agents)
	assert_ne(game.start().status, StepResult.Status.ERROR)
	return game


func _tap(control: Control) -> void:
	await wait_process_frames(4)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = control.get_global_rect().get_center()
		_viewport.push_input(event)
		await get_tree().process_frame


func _enter() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame
