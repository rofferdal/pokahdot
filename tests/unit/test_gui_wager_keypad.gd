extends "res://tests/support/poker_gut_test.gd"

const WagerKeypadScript := preload("res://scripts/gui/wager_keypad.gd")


func test_keypad_keeps_a_free_wager_draft_until_done() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)

	keypad.open(input, 20, 100)

	assert_true(keypad.visible)
	assert_eq(keypad.get_node("Content/Range").text, "Min 20  •  Max 100")
	keypad.get_node("Content/Keys/Key2").emit_signal("pressed")
	keypad.get_node("Content/Keys/Key5").emit_signal("pressed")
	assert_eq(input.text, "")
	assert_eq(keypad.get_node("Content/Value").text, "25")
	keypad.get_node("Content/Keys/KeyBack").emit_signal("pressed")
	assert_eq(input.text, "")
	keypad.get_node("Content/Keys/KeyClear").emit_signal("pressed")
	assert_eq(input.text, "")
	keypad.get_node("Content/Keys/Key2").emit_signal("pressed")
	keypad.get_node("Content/Keys/Key5").emit_signal("pressed")
	keypad.get_node("Content/Done").emit_signal("pressed")
	assert_eq(input.text, "25")


func test_keypad_scales_its_buttons_for_a_high_resolution_mobile_surface() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)

	keypad.open(input, 20, 100, 2.0)

	assert_gte(float(keypad.size.x), 500.0)
	assert_gte(float(keypad.size.y), 700.0)
	assert_eq(keypad.get_node("Content/Keys/Key1").custom_minimum_size, Vector2(160.0, 96.0))
	assert_eq(keypad.get_node("Content/Done").custom_minimum_size, Vector2(0.0, 96.0))


func test_number_entry_done_commits_and_cancel_preserves_the_previous_value() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)

	keypad.open_number(input)
	keypad.get_node("Content/Keys/Key4").emit_signal("pressed")
	keypad.get_node("Content/Done").emit_signal("pressed")

	assert_eq(input.text, "4")
	assert_false(keypad.visible)

	keypad.open_number(input)
	keypad.get_node("Content/Keys/Key2").emit_signal("pressed")
	assert_eq(input.text, "4")
	assert_eq(keypad.get_node("Content/Value").text, "42")
	keypad.get_node("Content/Cancel").emit_signal("pressed")

	assert_eq(input.text, "4")
	assert_false(keypad.visible)


func test_keypad_uses_opaque_grouping_and_high_contrast_key_boundaries() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)
	keypad.open_number(input)

	assert_false(keypad.transparent_bg)
	var panel_style := keypad.get_theme_stylebox("panel") as StyleBoxFlat
	var key_style := (
		keypad.get_node("Content/Keys/Key1").get_theme_stylebox("normal") as StyleBoxFlat
	)
	var done_style := keypad.get_node("Content/Done").get_theme_stylebox("normal") as StyleBoxFlat
	assert_gt(panel_style.bg_color.a, 0.9)
	assert_gte(key_style.border_width_left, 2)
	assert_ne(key_style.bg_color, done_style.bg_color)
