extends GutTest

const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")
var _viewport: SubViewport
var _table: GuiReplacementTableController


func after_each() -> void:
	if is_instance_valid(_table):
		_table.teardown()
	await wait_process_frames(2)


func test_name_only_hover_and_switching_preserve_focus_for_full_seats() -> void:
	await _setup(Vector2(1600, 1200), GuiSizeClass.LayoutMode.WIDE)
	var name: Control = _name(1)
	assert_eq(name.focus_mode, Control.FOCUS_NONE)
	await _move(name.get_global_rect().get_center())
	assert_false(_tooltip().visible, "The hover delay must precede presentation.")
	await _delay()
	assert_true(_tooltip().visible)
	assert_eq(_tooltip().get_text(), "Bot profile: Tight Passive")
	assert_eq(_tooltip().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_tooltip().focus_mode, Control.FOCUS_NONE)
	assert_eq(name.focus_mode, Control.FOCUS_NONE)
	await _move(_name(2).get_global_rect().get_center())
	assert_false(_tooltip().visible)
	await _delay()
	assert_eq(_tooltip().get_text(), "Bot profile: Loose Aggressive")
	assert_true(_tooltip().visible)
	var seat: Control = _table.get_composition().get_seat_controls()[2]
	for role: StringName in [&"stack", &"action", &"cards", &"avatar", &"status"]:
		var field: Control = seat.get_field(role)
		if field != null:
			await _move(field.get_global_rect().get_center())
			await _delay()
			assert_false(_tooltip().visible, "Non-name region: " + String(role))


func test_compact_real_pointer_touch_suppression_and_detail_activation() -> void:
	await _setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE)
	var token: Control = _table.get_composition().get_seat_controls()[1]
	assert_eq(token.focus_mode, Control.FOCUS_ALL)
	await _move(_name(1).get_global_rect().get_center(), -1)
	await _delay()
	assert_false(_tooltip().visible, "Touch-emulated mouse motion cannot show a tooltip.")
	await _move(_name(1).get_global_rect().get_center())
	await _delay()
	assert_true(_tooltip().visible, "Compact layouts must accept a real pointer.")
	var touch := InputEventScreenTouch.new()
	touch.position = _name(1).get_global_rect().get_center()
	touch.pressed = true
	_viewport.push_input(touch)
	await wait_process_frames(2)
	assert_false(_tooltip().visible)
	touch = InputEventScreenTouch.new()
	touch.position = _name(1).get_global_rect().get_center()
	touch.pressed = false
	_viewport.push_input(touch)
	assert_true(_table.get_overlay_host().is_active(), "Seat-detail taps still open details.")
	_table.get_overlay_host().close()
	await wait_process_frames(2)
	token.grab_focus()
	assert_true(token.has_focus())
	var key := InputEventAction.new()
	key.action = &"ui_accept"
	key.pressed = true
	_viewport.push_input(key)
	await wait_process_frames(2)
	assert_true(_table.get_overlay_host().is_active(), "Keyboard seat activation is preserved.")


func test_humans_missing_metadata_and_modal_rebind_cleanup() -> void:
	await _setup(Vector2(1600, 1200), GuiSizeClass.LayoutMode.WIDE)
	await _move(_name(0).get_global_rect().get_center())
	await _delay()
	assert_false(_tooltip().visible, "Erroneous metadata cannot enable a human tooltip.")
	await _move(_name(3).get_global_rect().get_center())
	await _delay()
	assert_false(_tooltip().visible, "Missing metadata cannot enable a tooltip.")
	await _move(_name(1).get_global_rect().get_center())
	await _delay()
	assert_true(_tooltip().visible)
	_table.open_menu()
	await wait_process_frames(2)
	assert_false(_tooltip().visible)
	_table.get_overlay_host().close()
	await _move(_name(1).get_global_rect().get_center())
	await _delay()
	assert_true(_tooltip().visible)
	assert_true(_table.bind_view(_fixture(), {}, _names()))
	assert_false(_tooltip().visible)
	assert_true(await _settle())
	await _move(_name(1).get_global_rect().get_center())
	await _delay()
	assert_false(_tooltip().visible)
	assert_false(_table.bind_view(null, {}))
	assert_false(_tooltip().visible)


func test_long_name_safe_area_containment_and_rotation_cleanup() -> void:
	var long_name: String = "Very Long Public Strategic Profile Name ".repeat(5).strip_edges()
	await _setup(Vector2(390, 844), GuiSizeClass.LayoutMode.PHONE, {1: long_name})
	var usable := Rect2(12, 24, 366, 790)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(390, 844), usable))
	assert_true(await _settle())
	await _move(_name(1).get_global_rect().get_center())
	await _delay()
	assert_true(_tooltip().visible)
	assert_eq(_tooltip().get_text(), "Bot profile: " + long_name)
	assert_true(
		usable.encloses(_tooltip().get_global_rect()),
		"Popup %s stays inside actual usable bounds %s." % [_tooltip().get_global_rect(), usable]
	)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(844, 390)))
	_viewport.size = Vector2i(844, 390)
	assert_false(_tooltip().visible)
	assert_true(await _settle())
	await _move(_name(1).get_global_rect().get_center())
	await _delay()
	assert_true(_tooltip().visible)
	_table.set_layout_mode_override(GuiSizeClass.LayoutMode.PHONE_LANDSCAPE)
	await wait_process_frames(2)
	assert_false(_tooltip().visible)


func test_folded_and_eliminated_names_keep_public_profile_without_changing_actions() -> void:
	await _setup(Vector2(1600, 1200), GuiSizeClass.LayoutMode.WIDE)
	var view: GameView = _fixture()
	var players: Array[PlayerView] = view.seats
	players[1].folded = true
	players[1].busted = true
	view._seats = players
	assert_true(_table.bind_view(view, {}, _names(), [], _profiles()))
	assert_true(await _settle())
	await _move(_name(1).get_global_rect().get_center())
	await _delay()
	assert_true(_tooltip().visible)
	assert_eq(_tooltip().get_text(), "Bot profile: Tight Passive")
	assert_eq(_table.get_table_view_model().seat_for(1).display_name, "Amina")
	_table.teardown()
	assert_false(_tooltip().visible)


func test_live_refresh_closes_popup_preserves_mapping_and_keeps_game_actions_available() -> void:
	await _setup(Vector2(1600, 1200), GuiSizeClass.LayoutMode.WIDE)
	var defaults := TournamentConfig.new()
	defaults.player_count = 4
	defaults.rng_seed = 5150
	var adapter := GuiStartupConfigAdapter.new(defaults)
	assert_true(adapter.try_start())
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 10000.0
	timing.showdown_pause_seconds = 10000.0
	_table.set_action_timing_config(timing)
	assert_true(_table.bind_match(adapter.match_instance, 0, {}, _names(), _profiles()))
	assert_true(await _settle())
	await _move(_name(1).get_global_rect().get_center())
	await _delay()
	assert_true(_tooltip().visible)
	assert_true(_table.refresh_from_match())
	await wait_process_frames(2)
	assert_false(_tooltip().visible)
	assert_eq(
		_table.get_table_view_model().seat_for(1).bot_profile_tooltip_text,
		"Bot profile: Tight Passive"
	)
	await _move(_name(1).get_global_rect().get_center())
	await _delay()
	assert_true(_tooltip().visible)
	for transition: int in 100:
		var view: GameView = adapter.match_instance.get_view_for(0)
		if view.acting_seat == 0:
			assert_ne(_table.submit_intent(&"fold").status, StepResult.Status.ERROR)
			return
		if view.hand_complete:
			adapter.match_instance.advance_until_blocked()
		else:
			adapter.match_instance.advance_one_action()
		assert_true(_table.refresh_from_match())
	fail_test("The seeded fixture must reach an actionable human turn.")


func _setup(
	allocation: Vector2, mode: GuiSizeClass.LayoutMode, profiles: Dictionary[int, String] = {}
) -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(allocation)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(_viewport)
	_table = TableScene.instantiate()
	_table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_viewport.add_child(_table)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(allocation))
	_table.set_layout_mode_override(mode)
	assert_true(
		_table.bind_view(
			_fixture(), {}, _names(), [], _profiles() if profiles.is_empty() else profiles
		)
	)
	assert_true(await _settle())


func _settle() -> bool:
	for frame: int in 180:
		await wait_process_frames(1)
		var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
		if snapshot.ready and not snapshot.pending:
			return true
	return false


func _tooltip() -> GuiBotProfileTooltip:
	return _table.get_profile_tooltip()


func _name(seat: int) -> Control:
	return _table.get_composition().get_seat_controls()[seat].get_field(&"name")


func _move(point: Vector2, device: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.device = device
	event.position = point
	event.global_position = point
	_viewport.push_input(event)
	await wait_process_frames(2)


func _delay() -> void:
	await get_tree().create_timer(0.6).timeout
	await wait_process_frames(2)


func _fixture() -> GameView:
	return GuiVisualStateFixtures.replacement_flop(4).view as GameView


static func _names() -> Dictionary[int, String]:
	return {0: "Human", 1: "Amina", 2: "Leilani", 3: "Haruto"}


static func _profiles() -> Dictionary[int, String]:
	return {0: "Erroneous Human Metadata", 1: "Tight Passive", 2: "Loose Aggressive"}
