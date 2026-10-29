extends "res://tests/support/poker_gut_test.gd"

const WagerKeypadScript := preload("res://scripts/gui/wager_keypad.gd")
const Measurement := preload("res://scripts/gui/gui_snapshot_measurement.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")


func test_keypad_keeps_a_free_wager_draft_until_done() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)

	keypad.open(input, 20, 100)

	assert_true(keypad.visible)
	assert_eq(keypad.get_node("Content/Range").text, "Min 20  •  Max 100")
	keypad.get_action_control(&"2").emit_signal("pressed")
	keypad.get_action_control(&"5").emit_signal("pressed")
	assert_eq(input.text, "")
	assert_eq(keypad.get_node("Content/Value").text, "25")
	keypad.get_action_control(&"back").emit_signal("pressed")
	assert_eq(input.text, "")
	keypad.get_action_control(&"clear").emit_signal("pressed")
	assert_eq(input.text, "")
	keypad.get_action_control(&"2").emit_signal("pressed")
	keypad.get_action_control(&"5").emit_signal("pressed")
	keypad.get_action_control(&"done").emit_signal("pressed")
	assert_eq(input.text, "25")


func test_keypad_scales_its_buttons_for_a_high_resolution_mobile_surface() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)

	keypad.open(input, 20, 100, 2.0)

	assert_gte(float(keypad.size.x), 500.0)
	assert_gte(float(keypad.size.y), 700.0)
	assert_eq(keypad.get_action_control(&"1").custom_minimum_size, Vector2(160.0, 96.0))
	assert_gte(keypad.get_action_control(&"done").custom_minimum_size.x, 160.0)
	assert_eq(keypad.get_action_control(&"done").custom_minimum_size.y, 96.0)


func test_number_entry_done_commits_and_cancel_preserves_the_previous_value() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)

	keypad.open_number(input)
	keypad.get_action_control(&"4").emit_signal("pressed")
	keypad.get_action_control(&"done").emit_signal("pressed")

	assert_eq(input.text, "4")
	assert_false(keypad.visible)

	keypad.open_number(input)
	keypad.get_action_control(&"2").emit_signal("pressed")
	assert_eq(input.text, "4")
	assert_eq(keypad.get_node("Content/Value").text, "42")
	keypad.get_action_control(&"cancel").emit_signal("pressed")

	assert_eq(input.text, "4")
	assert_false(keypad.visible)


func test_keypad_geometry_scale_does_not_multiply_text_sizes() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad := WagerKeypadScript.new()
	add_child_autofree(keypad)
	keypad.set_usable_rect(Rect2(0, 0, 2000, 2000))
	for geometry_scale: float in [1.0, 2.0, 1.0]:
		keypad.open(input, 20, 100, geometry_scale)
		assert_same(keypad.theme, GuiTypography.Regular)
		for action: StringName in [&"1", &"clear", &"min", &"pot", &"done", &"cancel"]:
			var button: Button = keypad.get_action_control(action)
			assert_eq(button.get_theme_font_size("font_size"), 20)
			assert_gte(button.custom_minimum_size.y, 48.0)
		assert_eq(keypad.get_node("Content/Title").get_theme_font_size("font_size"), 20)
		assert_eq(keypad.get_node("Content/Range").get_theme_font_size("font_size"), 20)
		assert_eq(keypad.get_node("Content/Value").get_theme_font_size("font_size"), 28)
		keypad.cancel()
	keypad.set_usable_rect(Rect2(0, 0, 844, 330))
	keypad.open(input, 20, 100)
	assert_same(keypad.theme, GuiTypography.Compact)
	assert_eq(keypad.get_node("Content/Value").get_theme_font_size("font_size"), 20)
	assert_eq(keypad.get_action_control(&"1").get_theme_font_size("font_size"), 20)
	keypad.cancel()


func test_keypad_uses_opaque_grouping_and_high_contrast_key_boundaries() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)
	keypad.open_number(input)

	assert_false(keypad.transparent_bg)
	var panel_style := keypad.get_theme_stylebox("panel") as StyleBoxFlat
	var key_style := keypad.get_action_control(&"1").get_theme_stylebox("normal") as StyleBoxFlat
	var done_style := (
		keypad.get_action_control(&"done").get_theme_stylebox("normal") as StyleBoxFlat
	)
	assert_gt(panel_style.bg_color.a, 0.9)
	assert_gte(key_style.border_width_left, 2)
	assert_ne(key_style.bg_color, done_style.bg_color)


func test_cancel_preserves_exact_original_text_for_every_entry_mode() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)
	for mode: int in range(3):
		for original: String in ["25", "-3", "invalid", "", "   ", " 25 "]:
			input.text = original
			if mode == 0:
				keypad.open_number(input)
			else:
				keypad.open(input, 20, 100, 1.0, mode == 2)
			assert_eq(input.text, original, "Opening must leave committed text unchanged")
			keypad.get_action_control(&"clear").emit_signal("pressed")
			keypad.get_action_control(&"2").emit_signal("pressed")
			keypad.get_action_control(&"5").emit_signal("pressed")
			assert_eq(input.text, original, "Draft edits must not commit")
			keypad.get_action_control(&"cancel").emit_signal("pressed")
			assert_eq(input.text, original, "Cancel must preserve original bytes")
			assert_false(keypad.visible)
			if mode == 0:
				keypad.open_number(input)
			else:
				keypad.open(input, 20, 100, 1.0, mode == 2)
			keypad.get_action_control(&"clear").emit_signal("pressed")
			keypad.get_action_control(&"2").emit_signal("pressed")
			keypad.get_action_control(&"5").emit_signal("pressed")
			assert_eq(input.text, original, "Only Done may commit")
			keypad.get_action_control(&"done").emit_signal("pressed")
			assert_eq(input.text, "25")


func test_standard_digit_positions_and_long_copy_survive_compact_and_portrait_resizing() -> void:
	var input := LineEdit.new()
	input.text = "  "
	add_child_autofree(input)
	var keypad := WagerKeypadScript.new()
	add_child_autofree(keypad)
	keypad.set_usable_rect(Rect2(11, 24, 390, 844))
	keypad.open(input, 9000000, 9000000, 1.0, true, 9000000, 9000000)
	var focused: Button = keypad.get_action_control(&"2")
	focused.grab_focus()
	focused.pressed.emit()
	for size: Vector2 in [Vector2(390, 844), Vector2(618, 302), Vector2(390, 844)]:
		var usable := Rect2(Vector2(11, 24), size)
		keypad.set_usable_rect(usable)
		for _frame: int in range(10):
			await get_tree().process_frame
		assert_eq(input.text, "  ")
		assert_eq((keypad.get_node("Content/Value") as Label).text, "2")
		assert_same(keypad.gui_get_focus_owner(), focused)
		for row: int in range(3):
			var left: Button = keypad.get_action_control(StringName(str(row * 3 + 1)))
			for column: int in range(3):
				var key: Button = keypad.get_action_control(StringName(str(row * 3 + column + 1)))
				assert_almost_eq(key.global_position.y, left.global_position.y, 0.01)
				assert_almost_eq(
					key.global_position.x,
					keypad.get_action_control(StringName(str(column + 1))).global_position.x,
					0.01
				)
		var zero: Button = keypad.get_action_control(&"0")
		var eight: Button = keypad.get_action_control(&"8")
		assert_almost_eq(
			zero.get_global_rect().get_center().x, eight.get_global_rect().get_center().x, 0.01
		)
		assert_gte(zero.global_position.y, eight.get_global_rect().end.y)
		var first_digit: Button = keypad.get_action_control(&"1")
		var last_digit: Button = keypad.get_action_control(&"3")
		var first_utility: Button = keypad.get_action_control(&"clear")
		if size.x > size.y:
			assert_gte(first_utility.global_position.x, last_digit.get_global_rect().end.x)
		else:
			assert_gte(first_utility.global_position.y, zero.get_global_rect().end.y)
			assert_gte(first_utility.global_position.y, first_digit.global_position.y)
		_assert_utility_rectangle(keypad, [&"clear", &"back", &"min", &"pot", &"cancel", &"done"])
		var failures := PackedStringArray()
		for node: Node in keypad.find_children("*", "Control", true, false):
			var control := node as Control
			if not control.is_visible_in_tree():
				continue
			var measured: GuiLayoutElement = Measurement.element(
				control, input, StringName(control.name)
			)
			assert_true(usable.encloses(measured.rect), "%s escapes %s" % [control.name, usable])
			Invariants.validate_element(measured, failures)
		assert_eq(failures, PackedStringArray(), "All required copy, fonts and targets must fit")
	keypad.get_action_control(&"cancel").pressed.emit()
	assert_eq(input.text, "  ")


func test_number_mode_has_a_filled_two_by_two_utility_grid_without_tournament_exit() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad := WagerKeypadScript.new()
	add_child_autofree(keypad)
	keypad.set_usable_rect(Rect2(11, 24, 618, 302))
	keypad.open_number(input)
	for _frame: int in range(10):
		await get_tree().process_frame
	_assert_utility_rectangle(keypad, [&"clear", &"back", &"cancel", &"done"])
	assert_false(keypad.get_action_control(&"min").visible)
	assert_false(keypad.get_action_control(&"pot").visible)
	assert_null(keypad.get_action_control(&"quit"))
	assert_false(keypad.has_signal("quit_requested"))
	assert_false(keypad.has_method("set_quit_available"))


func _assert_utility_rectangle(keypad: WagerKeypad, actions: Array[StringName]) -> void:
	var first: Button = keypad.get_action_control(actions[0])
	for index: int in range(actions.size()):
		var button: Button = keypad.get_action_control(actions[index])
		assert_true(button.is_visible_in_tree())
		assert_eq(button.size, first.size, "Utility cells must have uniform dimensions")
		var column: Button = keypad.get_action_control(actions[index % 2])
		var row: Button = keypad.get_action_control(actions[(index / 2) * 2])
		assert_almost_eq(button.global_position.x, column.global_position.x, 0.01)
		assert_almost_eq(button.global_position.y, row.global_position.y, 0.01)
