extends GutTest

const BarScene := preload("res://scenes/gui/components/ActionBar.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const ACTION_ROLES: Array[StringName] = [
	&"fold", &"check_call", &"minimum", &"pot", &"wager", &"all_in"
]

var _viewport: SubViewport


func test_measured_action_rows_have_exact_partition_boundaries_and_stable_reservation() -> void:
	var widths: Array[float] = [60, 104, 150, 80, 200, 80, 100]
	var heights: Array[float] = [48, 48, 48, 48, 48, 48, 48]
	var gap: float = 4.0
	var total: float = gap * (widths.size() - 1)
	for width: float in widths:
		total += width
	var expected_minimum: float = total
	for split: int in range(1, widths.size()):
		var first: float = gap * (split - 1)
		var second: float = gap * (widths.size() - split - 1)
		for index: int in widths.size():
			if index < split:
				first += widths[index]
			else:
				second += widths[index]
		expected_minimum = minf(expected_minimum, maxf(first, second))
	var exact: GuiActionRows = GuiActionRows.resolve(widths, heights, expected_minimum)
	assert_true(exact.valid)
	assert_eq(exact.minimum_width, expected_minimum)
	assert_eq(exact.row_count, 2)
	assert_gt(exact.split, 0)
	assert_lt(exact.split, widths.size())
	assert_eq(exact.reserved_height, 100.0)
	var too_small: GuiActionRows = GuiActionRows.resolve(widths, heights, expected_minimum - 1)
	assert_false(too_small.valid)
	assert_eq(too_small.minimum_width, expected_minimum)
	var wide: GuiActionRows = GuiActionRows.resolve(widths, heights, total)
	assert_true(wide.valid)
	assert_eq(wide.row_count, 1)
	assert_eq(wide.split, widths.size())
	assert_eq(wide.minimum_width, expected_minimum)
	assert_eq(wide.reserved_height, exact.reserved_height)
	for invalid: float in [0.0, -1.0, NAN, INF]:
		assert_false(GuiActionRows.resolve(widths, heights, invalid).valid)
	assert_false(GuiActionRows.resolve([], [], 500).valid)
	assert_false(GuiActionRows.resolve([60.0], [], 500).valid)
	assert_false(GuiActionRows.resolve([0.0], [48.0], 500).valid)
	assert_false(GuiActionRows.resolve([60.0], [-1.0], 500).valid)
	assert_false(GuiActionRows.resolve([60.0], [48.0], 500, -1.0).valid)


func test_action_controls_bind_every_visibility_and_enabled_flag_without_rule_logic() -> void:
	var root: Control = _root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	for selected: StringName in ACTION_ROLES:
		var model: ActionBarViewModel = _model()
		for role: StringName in ACTION_ROLES:
			model.set(String(role) + "_enabled", role == selected)
			model.set(String(role) + "_visible", role == selected)
		bar.render(model)
		await wait_process_frames(6)
		bar.size = bar.get_combined_minimum_size()
		await wait_process_frames(5)
		for role: StringName in ACTION_ROLES:
			var button := bar.get_control(role) as GuiActionButton
			assert_not_null(button)
			assert_eq(button.visible, role == selected, role)
			assert_eq(button.disabled, role != selected, role)
			assert_eq(button.scene_file_path, "res://scenes/gui/components/ActionButton.tscn")
		var more := bar.get_control(&"more") as Button
		assert_true(more.is_visible_in_tree())
		assert_false(more.disabled)
		_assert_visible_controls(bar, root)


func test_compact_visibility_uses_only_the_supplied_phone_flags() -> void:
	var root: Control = _root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	var model: ActionBarViewModel = _model()
	bar.compact_controls = true
	bar.render(model)
	bar.size = Vector2(420, 300).max(bar.get_combined_minimum_size())
	await wait_process_frames(6)
	assert_false(bar.get_control(&"minimum").is_visible_in_tree())
	assert_false(bar.get_control(&"pot").is_visible_in_tree())
	for role: StringName in [&"fold", &"check_call", &"wager", &"all_in", &"more"]:
		assert_true(bar.get_control(role).is_visible_in_tree())
	bar.compact_controls = false
	bar.render(model)
	await wait_process_frames(5)
	assert_true(bar.get_control(&"minimum").is_visible_in_tree())
	assert_true(bar.get_control(&"pot").is_visible_in_tree())
	_assert_visible_controls(bar, root)


func test_total_remains_a_short_sharp_field_with_a_full_target_beside_wager() -> void:
	var root: Control = _root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	bar.set_wager_draft("9000000")
	bar.render(_model())
	bar.size = Vector2(1200, 280).max(bar.get_combined_minimum_size())
	await wait_process_frames(7)
	var total := bar.get_control(&"total") as GuiInputField
	var wager := bar.get_control(&"wager") as GuiActionButton
	assert_not_null(total)
	assert_eq(total.scene_file_path, "res://scenes/gui/components/InputField.tscn")
	assert_eq(total.text, "9000000")
	assert_gte(total.size.x, 48.0)
	assert_gte(total.size.y, 48.0)
	assert_gte(wager.size.x, 48.0)
	assert_gte(wager.size.y, 48.0)
	assert_almost_eq(
		total.get_global_rect().get_center().y, wager.get_global_rect().get_center().y, 0.5
	)
	assert_false(total.get_global_rect().intersects(wager.get_global_rect()))
	assert_eq(total.get_parent(), wager.get_parent(), "Total and wager form one responsive unit")
	for state: StringName in [&"normal", &"focus", &"read_only"]:
		var style := total.get_theme_stylebox(state) as StyleBoxFlat
		assert_eq(style.corner_radius_top_left, 0)
		assert_eq(style.corner_radius_bottom_right, 0)
		assert_eq(style.expand_margin_top, -4.0)
		assert_eq(style.expand_margin_bottom, -4.0)
	assert_eq(total.get_theme_color("font_color"), Color("b8c3bb"))
	assert_gt((wager.get_theme_stylebox("normal") as StyleBoxFlat).corner_radius_top_left, 0)
	_assert_visible_controls(bar, root)


func test_raw_wager_draft_caret_and_selection_survive_renders_and_modality_changes() -> void:
	var root: Control = _root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	bar.render(_model())
	bar.set_wager_draft(" 00042 ")
	var total := bar.get_control(&"total") as GuiInputField
	total.caret_column = 4
	total.select(1, 5)
	watch_signals(bar)
	var model: ActionBarViewModel = _model()
	model.minimum_total = 999999
	model.maximum_total = 1000000
	for keypad: bool in [true, false, true, false]:
		bar.use_keypad(keypad)
		bar.render(model)
		bar.size = Vector2(1100, 300) if keypad else bar.get_combined_minimum_size()
		await wait_process_frames(5)
		assert_eq(bar.get_wager_draft(), " 00042 ")
		assert_eq(total.text, " 00042 ")
		assert_eq(total.is_visible_in_tree(), not keypad)
		assert_eq(total.editable, not keypad)
		assert_eq(total.caret_column, 4)
		assert_true(total.has_selection())
		assert_eq(total.get_selection_from_column(), 1)
		assert_eq(total.get_selection_to_column(), 5)
	assert_signal_not_emitted(bar, "wager_submitted")
	assert_signal_not_emitted(bar, "action_requested")
	bar.set_wager_draft("not-a-number -9223372036854775808")
	assert_eq(bar.get_wager_draft(), "not-a-number -9223372036854775808")


func test_native_keyboard_edits_and_submits_the_exact_draft_without_parsing() -> void:
	var root: Control = _input_root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	bar.render(_model())
	bar.set_wager_draft("0004")
	bar.size = Vector2(1200, 300)
	watch_signals(bar)
	await wait_process_frames(7)
	var total := bar.get_control(&"total") as GuiInputField
	total.grab_focus()
	total.caret_column = total.text.length()
	await _key(KEY_2, 50)
	assert_eq(bar.get_wager_draft(), "00042")
	assert_signal_emitted_with_parameters(bar, "wager_edited", ["00042"])
	await _key(KEY_ENTER)
	assert_signal_emitted_with_parameters(bar, "wager_submitted", ["00042"])
	assert_signal_not_emitted(bar, "action_requested")
	assert_signal_not_emitted(bar, "entry_requested")


func test_keypad_modality_dispatches_one_entry_intent_for_touch_and_native_acceptance() -> void:
	var root: Control = _input_root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	bar.render(_model())
	bar.use_keypad(true)
	bar.set_wager_draft(" 00042 ")
	bar.size = Vector2(1200, 300)
	watch_signals(bar)
	await wait_process_frames(7)
	var total := bar.get_control(&"total") as GuiInputField
	var trigger := bar.get_control(&"wager") as GuiActionButton
	assert_false(total.editable)
	assert_false(total.is_visible_in_tree(), "Keypad modality uses the wager trigger")
	await _touch(trigger.get_global_rect().get_center())
	assert_signal_emit_count(bar, "entry_requested", 1)
	assert_signal_emitted_with_parameters(bar, "entry_requested", [" 00042 "])
	trigger.grab_focus()
	await _key(KEY_ENTER)
	assert_signal_emit_count(bar, "entry_requested", 2)
	assert_eq(bar.get_wager_draft(), " 00042 ")
	assert_signal_not_emitted(bar, "wager_submitted")
	assert_signal_not_emitted(bar, "action_requested")


func test_each_visible_native_button_emits_only_its_bound_ui_intent() -> void:
	var root: Control = _input_root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	bar.render(_model())
	bar.size = Vector2(1600, 300)
	watch_signals(bar)
	await wait_process_frames(7)
	for index: int in ACTION_ROLES.size():
		var role: StringName = ACTION_ROLES[index]
		await _click(bar.get_control(role).get_global_rect().get_center())
		assert_signal_emit_count(bar, "action_requested", index + 1)
		assert_signal_emitted_with_parameters(bar, "action_requested", [role], index)
	await _click(bar.get_control(&"more").get_global_rect().get_center())
	assert_signal_emit_count(bar, "menu_requested", 1)
	assert_signal_emit_count(bar, "action_requested", ACTION_ROLES.size())


func test_disabled_action_flags_and_total_block_player_intents_while_more_remains_reachable(
) -> void:
	var root: Control = _input_root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	var model: ActionBarViewModel = _model()
	model.can_wager = false
	for role: StringName in ACTION_ROLES:
		model.set(String(role) + "_enabled", false)
	bar.render(model)
	bar.size = Vector2(1600, 300)
	bar.set_wager_draft("00042")
	watch_signals(bar)
	await wait_process_frames(7)
	for role: StringName in ACTION_ROLES:
		await _click(bar.get_control(role).get_global_rect().get_center())
	var total := bar.get_control(&"total") as GuiInputField
	await _click(total.get_global_rect().get_center())
	await _touch(total.get_global_rect().get_center())
	await _key(KEY_ENTER)
	assert_signal_not_emitted(bar, "action_requested")
	assert_signal_not_emitted(bar, "wager_submitted")
	assert_signal_not_emitted(bar, "entry_requested")
	assert_eq(bar.get_wager_draft(), "00042")
	await _click(bar.get_control(&"more").get_global_rect().get_center())
	assert_signal_emit_count(bar, "menu_requested", 1)


func test_model_continue_state_and_more_are_correct_between_hands_and_after_tournament_end(
) -> void:
	var root: Control = _input_root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	var view: GameView = _view()
	view.acting_seat = Table.NO_SEAT
	view._legal_actions.clear()
	view.hand_complete = true
	var model: ActionBarViewModel = ActionBarViewModel.build(view)
	assert_true(model.can_continue)
	bar.render(model)
	bar.size = Vector2(800, 260)
	watch_signals(bar)
	await wait_process_frames(7)
	var advance := bar.get_control(&"continue") as Button
	assert_true(advance.is_visible_in_tree())
	assert_false(advance.disabled)
	await _click(advance.get_global_rect().get_center())
	assert_signal_emitted_with_parameters(bar, "action_requested", [&"continue"])
	for reason: StringName in [&"winner", &"player_quit"]:
		view.tournament_status = &"finished"
		view.end_reason = reason
		view.tournament_winner_seat = 1
		model = ActionBarViewModel.build(view)
		assert_false(model.can_continue)
		bar.render(model)
		await wait_process_frames(6)
		assert_false(advance.is_visible_in_tree() and not advance.disabled)
		var more := bar.get_control(&"more") as Button
		assert_true(more.is_visible_in_tree())
		assert_false(more.disabled)
		_assert_visible_controls(bar, root)


func test_maximum_copy_and_two_row_layout_keep_all_targets_and_full_numbers_inside() -> void:
	var root: Control = _root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	var model: ActionBarViewModel = _model()
	model.check_call_text = "Call 9000000"
	model.minimum_text = "Min Raise 9000000"
	model.pot_text = "Pot 9000000"
	model.wager_text = "Raise"
	model.status_text = "Your turn — River."
	bar.set_wager_draft("9000000")
	bar.render(model)
	await wait_process_frames(7)
	var host := VBoxContainer.new()
	root.add_child(host)
	bar.reparent(host)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	await wait_process_frames(5)
	var initial: Vector2 = host.get_combined_minimum_size()
	host.size = initial
	await wait_process_frames(7)
	assert_eq(bar.layout_rows, 2)
	assert_eq((bar.get_control(&"check_call") as Button).text, "Call 9000000")
	assert_eq((bar.get_control(&"minimum") as Button).text, "Min Raise 9000000")
	assert_eq((bar.get_control(&"pot") as Button).text, "Pot 9000000")
	assert_eq((bar.get_control(&"total") as LineEdit).text, "9000000")
	_assert_visible_controls(bar, root)
	_assert_button_units_do_not_overlap(bar)
	host.size = Vector2(2200, 400)
	await wait_process_frames(8)
	assert_eq(bar.layout_rows, 1)
	assert_eq(host.get_combined_minimum_size(), initial)
	_assert_visible_controls(bar, root)
	_assert_button_units_do_not_overlap(bar)
	host.size = initial
	await wait_process_frames(8)
	assert_eq(host.size, initial)
	assert_eq(bar.layout_rows, 2)
	assert_true(Rect2(host.global_position, initial).encloses(bar.get_global_rect()))
	_assert_visible_controls(bar, root)


func test_hero_alignment_centers_rows_and_keeps_status_inset_out_of_intrinsic_width() -> void:
	var root: Control = _root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	bar.position = Vector2(23, 31)
	var model: ActionBarViewModel = _model()
	model.status_text = "Your turn — Flop."
	bar.render(model)
	assert_true(bar.align_with_hero(378.0))
	await wait_process_frames(7)
	var minimum: Vector2 = bar.get_combined_minimum_size()
	for allocation: Vector2 in [Vector2(600, 280), Vector2(1800, 400), minimum]:
		bar.size = allocation.max(minimum)
		await wait_process_frames(7)
		assert_eq(bar.get_combined_minimum_size(), minimum)
		var status: Control = bar.get_control(&"status")
		var inset: float = maxf(0.0, (bar.size.x - 378.0) * 0.5)
		assert_almost_eq(status.global_position.x, bar.global_position.x + inset, 0.5)
		var spans: Dictionary[float, Rect2] = {}
		for child: Control in bar.get_node("Body/Rows").get_children():
			if child.visible:
				var y: float = child.global_position.y
				spans[y] = (
					spans[y].merge(child.get_global_rect())
					if spans.has(y)
					else child.get_global_rect()
				)
		assert_eq(spans.size(), bar.layout_rows)
		for span: Rect2 in spans.values():
			assert_almost_eq(span.get_center().x, bar.get_global_rect().get_center().x, 0.5)
		_assert_visible_controls(bar, root)
	assert_false(bar.align_with_hero(NAN))
	assert_push_error_count(1)
	assert_true(bar.align_with_hero(0.0))
	await wait_process_frames(6)
	assert_eq(bar.get_control(&"status").global_position.x, bar.global_position.x)


func test_hero_summary_binds_exact_identity_values_and_shared_card_views_then_clears() -> void:
	var root: Control = _root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	bar.render(_model())
	var model: SeatViewModel = _hero_model()
	bar.render_hero(model)
	bar.size = Vector2(1000, 500)
	await wait_process_frames(8)
	var hero: Control = bar.get_control(&"hero")
	assert_true(hero.is_visible_in_tree())
	var visible_copy := PackedStringArray()
	for node: Node in hero.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree():
			visible_copy.append(label.text)
	assert_true(model.display_name in visible_copy)
	assert_true(model.stack_value_text in visible_copy)
	assert_true(model.wager_text in visible_copy)
	var cards_found: int = 0
	for node: Node in hero.find_children("*", "Control", true, false):
		if node is GuiHoleCards:
			for card: GuiPlayingCard in (node as GuiHoleCards).cards:
				cards_found += 1
				var snapshot: GuiCardSnapshot = card.get_card_snapshot(root, &"hero/card", true)
				assert_eq(snapshot.kind, GuiCardSnapshot.Kind.FACE)
				assert_gte(snapshot.rank.font_size, 20)
				assert_true(hero.get_global_rect().encloses(snapshot.element.rect))
	assert_eq(cards_found, 2)
	bar.render_hero(null)
	await wait_process_frames(5)
	assert_false(hero.is_visible_in_tree())
	for node: Node in hero.find_children("*", "Label", true, false):
		assert_eq((node as Label).text, "")


func test_invalid_model_preserves_draft_and_clears_player_actions_without_losing_menu() -> void:
	var root: Control = _input_root()
	var bar: GuiActionBar = BarScene.instantiate()
	bar.set_wager_draft(" 00042 ")
	root.add_child(bar)
	bar.render(_model())
	bar.size = Vector2(1000, 300)
	await wait_process_frames(7)
	watch_signals(bar)
	bar.render(null)
	assert_push_error_count(1)
	await wait_process_frames(5)
	assert_eq(bar.get_wager_draft(), " 00042 ")
	for role: StringName in ACTION_ROLES:
		var control := bar.get_control(role) as Button
		if control.is_visible_in_tree():
			assert_true(control.disabled)
	await _key(KEY_ENTER)
	assert_signal_not_emitted(bar, "action_requested")
	assert_signal_not_emitted(bar, "wager_submitted")
	var more := bar.get_control(&"more") as Button
	assert_true(more.is_visible_in_tree())
	assert_false(more.disabled)


func _assert_visible_controls(bar: GuiActionBar, root: Control) -> void:
	for role: StringName in ACTION_ROLES + [&"continue", &"more", &"total", &"status"]:
		var control: Control = bar.get_control(role)
		if not control.is_visible_in_tree():
			continue
		var observation: GuiLayoutElement = GuiSnapshotMeasurement.element(control, root, role)
		assert_true(bar.get_global_rect().encloses(observation.rect), role)
		var failures := PackedStringArray()
		Invariants.validate_element(observation, failures)
		assert_eq(failures, PackedStringArray(), role)
		assert_gte(observation.font_size, 20, role)


func _assert_button_units_do_not_overlap(bar: GuiActionBar) -> void:
	var controls: Array[Control] = []
	for role: StringName in ACTION_ROLES + [&"continue", &"more", &"total"]:
		var control: Control = bar.get_control(role)
		if control.is_visible_in_tree():
			controls.append(control)
	for first: int in controls.size():
		for second: int in range(first + 1, controls.size()):
			assert_false(
				controls[first].get_global_rect().intersects(controls[second].get_global_rect())
			)


func test_bot_status_uses_the_hero_column_instead_of_the_lone_menu_button_width() -> void:
	var root: Control = _root()
	var bar: GuiActionBar = BarScene.instantiate()
	bar.compact_controls = true
	root.add_child(bar)
	bar.use_keypad(true)
	bar.set_available_width(360.0)
	bar.align_with_hero(181.0)
	bar.size = Vector2(360, 200)
	var view: GameView = GuiBrowserCaptureFixture.descriptor(6).view
	view.acting_seat = 1
	bar.render(ActionBarViewModel.build(view, {1: "Emiliano"}))
	await wait_process_frames(10)
	var status := bar.get_control(&"status") as Label
	assert_eq(status.text, "Act: Emiliano")
	assert_eq(status.get_line_count(), 1)
	assert_almost_eq(
		status.custom_minimum_size.y, ceilf(status.get_theme_font("font").get_height(20)), 1.0
	)
	assert_lt(bar.get_combined_minimum_size().y, 100.0)


func _model() -> ActionBarViewModel:
	var result := ActionBarViewModel.new()
	result.valid = true
	result.is_human_turn = true
	result.can_wager = true
	for role: StringName in ACTION_ROLES:
		result.set(String(role) + "_enabled", true)
		result.set(String(role) + "_visible", true)
		result.set("phone_" + String(role) + "_visible", role not in [&"minimum", &"pot"])
	result.check_call_text = "Call 10"
	result.minimum_text = "Min Raise 20"
	result.pot_text = "Pot 50"
	result.wager_text = "Raise"
	result.all_in_text = "All In"
	result.input_placeholder = "Total"
	result.minimum_total = 20
	result.maximum_total = 1000
	result.status_text = "Your turn — Preflop."
	result.phone_status_text = "Your turn: Preflop"
	return result


func _hero_model() -> SeatViewModel:
	var result := SeatViewModel.new()
	result.valid = true
	result.seat = 0
	result.is_hero = true
	result.display_name = "You"
	result.stack_text = "9000000 chips"
	result.stack_value_text = "9000000"
	result.wager_text = "Bet 1000000"
	result.cards = CardRowViewModel.new()
	result.cards.cards = [
		CardViewModel.face(CardData.new(14, CardData.Suit.SPADES)),
		CardViewModel.face(CardData.new(10, CardData.Suit.HEARTS))
	]
	return result


func _view() -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	view.acting_seat = 0
	view.pot_amount = 50
	view.minimum_wager_total = 20
	view.maximum_wager_total = 1000
	view.call_amount = 10
	view._legal_actions = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CALL,
		PlayerAction.Kind.RAISE,
		PlayerAction.Kind.ALL_IN
	]
	view._seats = [
		PlayerView.new(Player.new(&"human", "Human", 0, 1000, HumanAgent.new())),
		PlayerView.new(Player.new(&"bot", "Bot", 1, 1000))
	]
	return view


func _root() -> Control:
	var root := Control.new()
	root.theme = Palette
	root.size = Vector2(2400, 1000)
	add_child_autofree(root)
	return root


func _input_root() -> Control:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(2400, 1000)
	add_child_autofree(_viewport)
	var root := Control.new()
	root.size = Vector2(2400, 1000)
	root.theme = Palette
	_viewport.add_child(root)
	return root


func _key(code: Key, unicode_value: int = 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.unicode = unicode_value
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame


func _click(position: Vector2, device: int = 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.device = device
		event.position = position
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame


func _touch(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = position
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame


func test_finished_status_wrap_keeps_exact_minimum_after_a_wide_allocation() -> void:
	var root: Control = _root()
	var host := VBoxContainer.new()
	root.add_child(host)
	var bar: GuiActionBar = BarScene.instantiate()
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(bar)
	var model := ActionBarViewModel.new()
	model.valid = true
	model.status_text = "Emiliano wins the tournament!"
	bar.render(model)
	await wait_process_frames(8)
	var minimum: Vector2 = host.get_combined_minimum_size()
	host.size = minimum
	await wait_process_frames(6)
	_assert_visible_controls(bar, root)
	host.size = Vector2(1800, 500)
	await wait_process_frames(8)
	assert_eq(host.get_combined_minimum_size(), minimum)
	host.size = minimum
	await wait_process_frames(8)
	assert_eq(host.size, minimum)
	_assert_visible_controls(bar, root)
	root.remove_child(host)
	host.free()


func test_visible_action_order_is_independent_of_row_resize_history() -> void:
	var root: Control = _root()
	var bar: GuiActionBar = BarScene.instantiate()
	root.add_child(bar)
	bar.render(_model())
	await wait_process_frames(6)
	var expected: Array[StringName] = [
		&"fold", &"check_call", &"minimum", &"pot", &"wager", &"all_in", &"more"
	]
	for allocation: Vector2 in [
		Vector2(2000, 400), bar.get_combined_minimum_size(), Vector2(2000, 400)
	]:
		bar.size = allocation
		await wait_process_frames(7)
		var positions: Array[Dictionary] = []
		for role: StringName in expected:
			var control: Control = bar.get_control(role)
			positions.append({"role": role, "point": control.get_global_rect().position})
		positions.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return (
					a.point.x < b.point.x
					if is_equal_approx(a.point.y, b.point.y)
					else a.point.y < b.point.y
				)
		)
		var observed: Array[StringName] = []
		for value: Dictionary in positions:
			observed.append(value.role)
		assert_eq(observed, expected)
