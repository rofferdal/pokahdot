extends GutTest

const KeypadScene := preload("res://scenes/gui/components/NumericKeypad.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const UTILITY: Array[StringName] = [&"clear", &"back", &"minimum", &"pot", &"cancel", &"done"]

var _viewport: SubViewport


func test_plain_and_wager_candidates_keep_conventional_digits_and_filled_utility_rectangles(
) -> void:
	var root: Control = _root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	for presets: bool in [false, true]:
		keypad.render(_model(presets))
		for available: Vector2 in [Vector2(272, 592), Vector2(796, 282), Vector2(592, 282)]:
			assert_true(keypad.fit_available(available), "%s/%s" % [presets, available])
			await wait_process_frames(6)
			assert_lte(keypad.size.x, available.x)
			assert_lte(keypad.size.y, available.y)
			assert_eq(keypad.layout_mode_name, &"portrait" if available.x == 272 else &"landscape")
			_assert_digit_grid(keypad)
			_assert_utility_rectangle(keypad, 6 if presets else 4)
			_assert_containment_and_floors(keypad, root)
			assert_null(keypad.get_control(&"quit"))
			for node: Node in keypad.find_children("*", "Button", true, false):
				assert_ne((node as Button).text, "Quit")


func test_full_pot_amount_and_editing_keys_stay_readable_with_aligned_landscape_rows() -> void:
	var root: Control = _root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model(true)
	model.pot_preset = "9000000"
	model.value = "9000000"
	model.maximum = 9000000
	keypad.render(model)
	assert_eq((keypad.get_control(&"back") as Button).text, "⌫")
	assert_string_contains(keypad.get_control(&"back").tooltip_text, "Delete")
	assert_eq((keypad.get_control(&"cancel") as Button).text, "Cancel")
	for available: Vector2 in [
		Vector2(272, 592), Vector2(796, 282), Vector2(592, 282), Vector2(272, 592)
	]:
		assert_true(keypad.fit_available(available), str(available))
		await wait_process_frames(6)
		var pot := keypad.get_control(&"pot") as Button
		assert_string_contains(pot.text, "9000000")
		assert_eq(pot.text.replace("\n", " "), "Pot 9000000")
		_assert_digit_grid(keypad)
		_assert_utility_rectangle(keypad, 6)
		_assert_containment_and_floors(keypad, root)
		if keypad.layout_mode_name == &"landscape":
			for pair: Array in [[&"3", &"clear"], [&"6", &"minimum"], [&"9", &"cancel"]]:
				var digit: Control = keypad.get_control(pair[0])
				var utility: Control = keypad.get_control(pair[1])
				assert_almost_eq(digit.global_position.y, utility.global_position.y, 0.1)
				assert_eq(digit.size.y, utility.size.y)
				assert_gt(utility.global_position.x, digit.get_global_rect().end.x)
		var previous_size: Vector2 = keypad.size
		var previous_caption: String = pot.text
		assert_false(keypad.fit_available(Vector2(100, 100)))
		await wait_process_frames(4)
		assert_eq(keypad.size, previous_size)
		assert_eq(pot.text, previous_caption)
		_assert_containment_and_floors(keypad, root)


func test_compact_header_places_inline_value_above_one_line_limits_and_recovers_portrait() -> void:
	var root: Control = _root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model(true)
	model.title = "Raise total"
	model.value = "1000000"
	model.minimum = 1000000
	model.maximum = 9000000
	model.pot_preset = "3000000"
	keypad.render(model)
	for available: Vector2 in [Vector2(520, 282), Vector2(796, 700), Vector2(520, 282)]:
		assert_true(keypad.fit_available(available))
		await wait_process_frames(6)
		var title := keypad.get_control(&"title") as Label
		var value := keypad.get_control(&"value") as GuiInputField
		var limits := keypad.get_control(&"limits") as Label
		if available.y == 282:
			assert_eq(keypad.layout_mode_name, &"landscape")
			assert_string_contains(limits.text, "Min 1000000")
			assert_string_contains(limits.text, "Max 9000000")
			assert_false("\n" in limits.text)
			assert_almost_eq(value.global_position.x - title.get_global_rect().end.x, 4.0, 0.1)
			assert_almost_eq(
				title.get_global_rect().get_center().y, value.get_global_rect().get_center().y, 0.1
			)
			assert_gte(limits.global_position.y, value.get_global_rect().end.y)
			assert_lte(limits.get_global_rect().end.y, keypad.get_control(&"1").global_position.y)
			var style := value.get_theme_stylebox("read_only") as StyleBoxFlat
			assert_eq(value.size.y, 48.0, "Retain the selection target")
			assert_eq(style.expand_margin_top, -8.0)
			assert_eq(style.expand_margin_bottom, -8.0)
			keypad.get_control(&"back").emit_signal("activated", &"back")
			assert_eq(value.theme_type_variation, &"NumberFieldInline")
		else:
			assert_eq(
				keypad.layout_mode_name,
				&"portrait",
				"Prefer the accepted stacked arrangement when it fits"
			)
			assert_true("\n" in limits.text)
			assert_eq(value.theme_type_variation, &"InputFieldKeypad")
			assert_gte(value.global_position.y, title.get_global_rect().end.y)
		_assert_digit_grid(keypad)
		_assert_containment_and_floors(keypad, root)


func test_value_is_a_sharp_white_readonly_field_with_exact_full_limits() -> void:
	var root: Control = _root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model(true)
	model.minimum = 1234567
	model.maximum = 9000000
	model.value = "00042"
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(320, 608)))
	await wait_process_frames(6)
	var value := keypad.get_control(&"value") as GuiInputField
	assert_not_null(value)
	assert_eq(value.scene_file_path, "res://scenes/gui/components/InputField.tscn")
	assert_false(value.editable)
	assert_eq(value.text, "00042")
	var style := value.get_theme_stylebox("read_only") as StyleBoxFlat
	assert_eq(style.corner_radius_top_left, 0)
	assert_eq(style.corner_radius_bottom_right, 0)
	assert_eq(style.bg_color, Color.WHITE)
	assert_gt(value.get_theme_color("font_color").g, value.get_theme_color("font_color").r)
	var limits := keypad.get_control(&"limits") as Label
	assert_string_contains(limits.text, "1234567")
	assert_string_contains(limits.text, "9000000")
	assert_eq((keypad.get_control(&"title") as Label).text, model.title)
	_assert_containment_and_floors(keypad, root)


func test_native_key_buttons_edit_only_the_local_draft_and_cancel_restores_original_once() -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model()
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(320, 608)))
	watch_signals(keypad)
	await wait_process_frames(6)
	await _click(keypad.get_control(&"3").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "000423")
	await _click(keypad.get_control(&"back").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "00042")
	await _click(keypad.get_control(&"clear").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "")
	await _click(keypad.get_control(&"8").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "8")
	assert_eq(model.value, "00042")
	assert_signal_not_emitted(keypad, "committed")
	await _click(keypad.get_control(&"cancel").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "00042")
	assert_false(keypad.is_active())
	assert_signal_emit_count(keypad, "cancelled", 1)
	keypad.cancel()
	keypad.commit()
	assert_signal_emit_count(keypad, "cancelled", 1)
	assert_signal_not_emitted(keypad, "committed")


func test_native_done_emits_the_raw_draft_once_without_numeric_or_range_coercion() -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model()
	model.value = " 00042 invalid "
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(320, 608)))
	watch_signals(keypad)
	await wait_process_frames(6)
	await _click(keypad.get_control(&"done").get_global_rect().get_center())
	assert_signal_emitted_with_parameters(keypad, "committed", [" 00042 invalid "])
	assert_signal_emit_count(keypad, "committed", 1)
	assert_false(keypad.is_active())
	keypad.commit()
	keypad.cancel()
	assert_signal_emit_count(keypad, "committed", 1)
	assert_signal_not_emitted(keypad, "cancelled")
	assert_eq(model.value, " 00042 invalid ")


func test_embedded_font_without_delete_glyph_keeps_a_readable_functional_delete_key() -> void:
	var root: Control = _input_root()
	var font := ThemeDB.fallback_font.duplicate() as FontFile
	font.allow_system_fallback = false
	var palette := root.theme.duplicate(true) as Theme
	palette.default_font = font
	root.theme = palette
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model(true)
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(796, 282)))
	watch_signals(keypad)
	await wait_process_frames(5)
	var back := keypad.get_control(&"back") as Button
	assert_eq(back.text, "Delete")
	assert_gte(back.get_theme_font_size("font_size"), 20)
	assert_gte(back.size.x, 48.0)
	assert_gte(back.size.y, 48.0)
	await _click(back.get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "0004")
	assert_signal_not_emitted(keypad, "committed")
	assert_eq(model.value, "00042")


func test_pot_caption_can_show_contribution_while_preset_keeps_the_street_total() -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model(true)
	model.pot_preset = "55"
	model.pot_display_value = "45"
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(796, 282)))
	watch_signals(keypad)
	await wait_process_frames(5)
	assert_eq((keypad.get_control(&"pot") as Button).text.replace("\n", " "), "Pot 45")
	await _click(keypad.get_control(&"pot").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "55")
	assert_signal_not_emitted(keypad, "committed")
	keypad.commit()
	assert_signal_emitted_with_parameters(keypad, "committed", ["55"])
	assert_eq(model.pot_preset, "55")
	assert_eq(model.pot_display_value, "45")
	model.pot_display_value = ""
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(796, 282)))
	await wait_process_frames(5)
	assert_eq((keypad.get_control(&"pot") as Button).text.replace("\n", " "), "Pot 55")


func test_presets_keep_exact_strings_and_disabled_pot_never_edits_or_commits() -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model(true)
	model.minimum_preset = " 00020 "
	model.pot_preset = "999999999999"
	model.pot_enabled = false
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(796, 282)))
	watch_signals(keypad)
	await wait_process_frames(6)
	await _click(keypad.get_control(&"pot").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "00042")
	await _click(keypad.get_control(&"minimum").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), " 00020 ")
	assert_signal_not_emitted(keypad, "committed")
	model.pot_enabled = true
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(796, 282)))
	await wait_process_frames(5)
	await _click(keypad.get_control(&"pot").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "999999999999", "The adapter owns numeric validation")
	keypad.commit()
	assert_signal_emitted_with_parameters(keypad, "committed", ["999999999999"])


func test_empty_minimum_preset_uses_the_declared_limit_and_missing_pot_payload_is_disabled(
) -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model(true)
	model.minimum = 20
	model.minimum_preset = ""
	model.pot_preset = ""
	model.pot_enabled = true
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(796, 282)))
	await wait_process_frames(6)
	assert_true((keypad.get_control(&"pot") as Button).disabled)
	await _click(keypad.get_control(&"pot").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "00042")
	await _click(keypad.get_control(&"minimum").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "20")
	model.minimum_preset = " 00020 "
	model.pot_preset = " 000150 "
	keypad.render(model)
	await wait_process_frames(5)
	assert_false((keypad.get_control(&"pot") as Button).disabled)
	await _click(keypad.get_control(&"pot").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), " 000150 ")
	await _click(keypad.get_control(&"minimum").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), " 00020 ")


func test_native_physical_digits_backspace_delete_enter_and_escape_preserve_transaction_boundaries(
) -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	keypad.render(_model())
	assert_true(keypad.fit_available(Vector2(320, 608)))
	watch_signals(keypad)
	await wait_process_frames(6)
	await _key(KEY_7, 55)
	assert_eq(keypad.get_draft(), "000427")
	await _key(KEY_BACKSPACE)
	assert_eq(keypad.get_draft(), "00042")
	await _key(KEY_DELETE)
	assert_eq(keypad.get_draft(), "")
	await _key(KEY_KP_8)
	assert_eq(keypad.get_draft(), "8")
	await _key(KEY_ENTER)
	assert_signal_emitted_with_parameters(keypad, "committed", ["8"])
	await _key(KEY_1, 49)
	assert_eq(keypad.get_draft(), "8", "An inactive transaction ignores physical input")
	keypad.render(_model())
	await _key(KEY_9, 57)
	assert_eq(keypad.get_draft(), "000429")
	await _key(KEY_ESCAPE)
	assert_eq(keypad.get_draft(), "00042")
	assert_signal_emit_count(keypad, "cancelled", 1)
	assert_signal_emit_count(keypad, "committed", 1)


func test_enter_activates_the_focused_native_button_instead_of_forcing_commit() -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	keypad.render(_model())
	assert_true(keypad.fit_available(Vector2(320, 608)))
	watch_signals(keypad)
	await wait_process_frames(6)
	keypad.get_control(&"cancel").grab_focus()
	await _key(KEY_ENTER)
	assert_signal_emit_count(keypad, "cancelled", 1)
	assert_signal_not_emitted(keypad, "committed")
	assert_false(keypad.is_active())
	assert_eq(keypad.get_draft(), "00042")
	keypad.render(_model())
	keypad.get_control(&"clear").grab_focus()
	await _key(KEY_ENTER)
	assert_eq(keypad.get_draft(), "")
	assert_true(keypad.is_active())
	assert_signal_not_emitted(keypad, "committed")
	keypad.render(_model())
	keypad.get_control(&"5").grab_focus()
	await _key(KEY_ENTER)
	assert_eq(keypad.get_draft(), "000425")
	assert_signal_not_emitted(keypad, "committed")
	keypad.get_control(&"done").grab_focus()
	await _key(KEY_ENTER)
	assert_signal_emitted_with_parameters(keypad, "committed", ["000425"])
	assert_signal_emit_count(keypad, "committed", 1)
	assert_false(keypad.is_active())
	await _key(KEY_ENTER)
	assert_signal_emit_count(keypad, "committed", 1)


func test_hidden_keypad_ignores_physical_input_without_discarding_its_draft() -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	keypad.render(_model())
	assert_true(keypad.fit_available(Vector2(320, 608)))
	watch_signals(keypad)
	await wait_process_frames(5)
	keypad.hide()
	await _key(KEY_1, 49)
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE)
	assert_eq(keypad.get_draft(), "00042")
	assert_true(keypad.is_active())
	assert_signal_not_emitted(keypad, "committed")
	assert_signal_not_emitted(keypad, "cancelled")
	keypad.show()
	await _key(KEY_1, 49)
	assert_eq(keypad.get_draft(), "000421")


func test_large_invalid_initial_value_remains_selectable_and_can_be_replaced_without_parsing(
) -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model()
	model.value = " -9223372036854775808 invalid 00042 "
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(796, 282)))
	await wait_process_frames(6)
	var value := keypad.get_control(&"value") as GuiInputField
	assert_eq(keypad.get_draft(), model.value)
	assert_eq(value.text, model.value)
	value.select_all()
	assert_eq(value.get_selected_text(), model.value)
	await _key(KEY_2, 50)
	assert_eq(keypad.get_draft(), "2")
	assert_eq(value.text, "2")
	assert_eq(model.value, " -9223372036854775808 invalid 00042 ")
	keypad.cancel()
	assert_eq(keypad.get_draft(), model.value)


func test_fit_can_recover_from_unavailable_space_and_previous_large_utility_labels() -> void:
	var root: Control = _root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	var model: NumberEntryViewModel = _model(true)
	model.minimum_label = "Min 9000000"
	model.pot_label = "Pot total"
	model.pot_preset = "9000000"
	keypad.render(model)
	assert_true(keypad.fit_available(Vector2(796, 282)))
	await wait_process_frames(6)
	_assert_utility_rectangle(keypad, 6)
	assert_false(keypad.fit_available(Vector2(100, 100)))
	assert_eq(keypad.get_draft(), model.value)
	for invalid: Vector2 in [Vector2.ZERO, Vector2(-1, 200), Vector2(NAN, 200), Vector2(200, INF)]:
		assert_false(keypad.fit_available(invalid))
	keypad.render(_model())
	assert_true(keypad.fit_available(Vector2(272, 592)))
	await wait_process_frames(6)
	assert_lte(keypad.size.x, 272.0)
	_assert_utility_rectangle(keypad, 4)
	_assert_containment_and_floors(keypad, root)


func test_candidate_changes_preserve_native_buttons_parents_and_exact_draft() -> void:
	var root: Control = _root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	keypad.render(_model(true))
	var first: Control = keypad.get_control(&"1")
	var first_parent: Node = first.get_parent()
	var value_parent: Node = keypad.get_control(&"value").get_parent()
	var pot_parent: Node = keypad.get_control(&"pot").get_parent()
	for available: Vector2 in [Vector2(272, 592), Vector2(796, 282), Vector2(272, 592)]:
		assert_true(keypad.fit_available(available))
		await wait_process_frames(6)
		assert_same(keypad.get_control(&"1"), first)
		assert_same(first.get_parent(), first_parent)
		assert_same(keypad.get_control(&"value").get_parent(), value_parent)
		assert_same(keypad.get_control(&"pot").get_parent(), pot_parent)
		assert_eq(keypad.get_draft(), "00042")
		_assert_digit_grid(keypad)
		_assert_utility_rectangle(keypad, 6)
		_assert_containment_and_floors(keypad, root)


func test_null_and_reversed_limits_fail_closed_with_explicit_errors() -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	root.add_child(keypad)
	keypad.render(_model())
	watch_signals(keypad)
	keypad.render(null)
	assert_push_error_count(1)
	assert_false(keypad.is_active())
	assert_eq(keypad.get_draft(), "")
	assert_true((keypad.get_control(&"done") as Button).disabled)
	var model: NumberEntryViewModel = _model()
	model.minimum = 10
	model.maximum = 9
	keypad.render(model)
	assert_push_error_count(2)
	assert_false(keypad.is_active())
	assert_eq(keypad.get_draft(), "")
	await _key(KEY_ENTER)
	assert_signal_not_emitted(keypad, "committed")


func test_model_values_detach_and_remove_reentry_keeps_one_connection_per_key() -> void:
	var root: Control = _input_root()
	var keypad: GuiNumericKeypad = KeypadScene.instantiate()
	var model: NumberEntryViewModel = _model()
	keypad.render(model)
	model.value = "Changed"
	root.add_child(keypad)
	assert_true(keypad.fit_available(Vector2(320, 608)))
	root.remove_child(keypad)
	await wait_process_frames(3)
	root.add_child(keypad)
	await wait_process_frames(5)
	assert_eq(keypad.get_draft(), "00042")
	await _click(keypad.get_control(&"4").get_global_rect().get_center())
	assert_eq(keypad.get_draft(), "000424")


func _assert_digit_grid(keypad: GuiNumericKeypad) -> void:
	for row: int in 3:
		for column: int in 3:
			var digit: StringName = StringName(str(row * 3 + column + 1))
			var rect: Rect2 = keypad.get_control(digit).get_global_rect()
			assert_almost_eq(
				rect.position.y,
				keypad.get_control(StringName(str(row * 3 + 1))).global_position.y,
				0.5
			)
			assert_almost_eq(
				rect.position.x,
				keypad.get_control(StringName(str(column + 1))).global_position.x,
				0.5
			)
			if column > 0:
				assert_gt(
					rect.position.x,
					keypad.get_control(StringName(str(row * 3 + column))).global_position.x
				)
			if row > 0:
				assert_gt(
					rect.position.y,
					keypad.get_control(StringName(str(column + 1))).global_position.y
				)
	var zero: Rect2 = keypad.get_control(&"0").get_global_rect()
	var eight: Rect2 = keypad.get_control(&"8").get_global_rect()
	assert_almost_eq(zero.get_center().x, eight.get_center().x, 0.5)
	assert_gt(zero.position.y, eight.position.y)


func _assert_utility_rectangle(keypad: GuiNumericKeypad, count: int) -> void:
	var buttons: Array[Control] = []
	for key: StringName in UTILITY:
		var control: Control = keypad.get_control(key)
		if control.is_visible_in_tree():
			buttons.append(control)
	assert_eq(buttons.size(), count)
	assert_eq(count % keypad.utility_columns, 0)
	var xs: Array[float] = []
	var ys: Array[float] = []
	var cell: Vector2 = buttons[0].size
	for button: Control in buttons:
		assert_eq(button.size, cell)
		if not button.global_position.x in xs:
			xs.append(button.global_position.x)
		if not button.global_position.y in ys:
			ys.append(button.global_position.y)
	assert_eq(xs.size(), keypad.utility_columns)
	assert_eq(ys.size(), count / keypad.utility_columns)
	for x: float in xs:
		for y: float in ys:
			var found: bool = false
			for button: Control in buttons:
				found = found or button.global_position == Vector2(x, y)
			assert_true(found, "Every utility cell is filled")


func _assert_containment_and_floors(keypad: GuiNumericKeypad, root: Control) -> void:
	for key: StringName in (
		[&"0", &"1", &"2", &"3", &"4", &"5", &"6", &"7", &"8", &"9"]
		+ UTILITY
		+ [&"value", &"title", &"limits"]
	):
		var control: Control = keypad.get_control(key)
		if not control.is_visible_in_tree():
			continue
		assert_true(keypad.get_global_rect().encloses(control.get_global_rect()), key)
		var observation: GuiLayoutElement = GuiSnapshotMeasurement.element(control, root, key)
		var failures := PackedStringArray()
		Invariants.validate_element(observation, failures)
		assert_eq(failures, PackedStringArray(), key)
		assert_gte(observation.font_size, 20, key)
		if control is GuiActionButton:
			assert_eq(control.scene_file_path, "res://scenes/gui/components/ActionButton.tscn")
			assert_eq(control.theme_type_variation, &"KeypadKey")


func _model(presets: bool = false) -> NumberEntryViewModel:
	var model := NumberEntryViewModel.new()
	model.title = "Enter wager total"
	model.value = "00042"
	model.minimum = 1
	model.maximum = 1000000
	model.show_presets = presets
	model.minimum_preset = "20"
	model.pot_preset = "150"
	model.minimum_label = "Min"
	model.pot_label = "Pot"
	model.pot_enabled = true
	return model


func _root() -> Control:
	var root := Control.new()
	root.size = Vector2(1000, 900)
	root.theme = Palette
	add_child_autofree(root)
	return root


func _input_root() -> Control:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1000, 900)
	add_child_autofree(_viewport)
	var root := Control.new()
	root.size = Vector2(1000, 900)
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


func _click(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame
