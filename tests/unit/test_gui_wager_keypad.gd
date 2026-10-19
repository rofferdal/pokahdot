extends "res://tests/support/poker_gut_test.gd"

const WagerKeypadScript := preload("res://scripts/gui/wager_keypad.gd")


func test_keypad_enters_a_free_wager_without_a_native_keyboard() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)

	keypad.open(input, 20, 100)

	assert_true(keypad.visible)
	assert_eq(keypad.get_node("Content/Range").text, "Min 20  •  Max 100")
	keypad.get_node("Content/Keys/Key2").emit_signal("pressed")
	keypad.get_node("Content/Keys/Key5").emit_signal("pressed")
	assert_eq(input.text, "25")
	assert_eq(keypad.get_node("Content/Value").text, "25")
	keypad.get_node("Content/Keys/KeyBack").emit_signal("pressed")
	assert_eq(input.text, "2")
	keypad.get_node("Content/Keys/KeyClear").emit_signal("pressed")
	assert_eq(input.text, "")


func test_keypad_scales_its_buttons_for_a_high_resolution_mobile_surface() -> void:
	var input := LineEdit.new()
	add_child_autofree(input)
	var keypad = WagerKeypadScript.new()
	add_child_autofree(keypad)

	keypad.open(input, 20, 100, 2.0)

	assert_gte(keypad.size.x, 500.0)
	assert_gte(keypad.size.y, 700.0)
	assert_eq(keypad.get_node("Content/Keys/Key1").custom_minimum_size, Vector2(160, 96))
	assert_eq(keypad.get_node("Content/Done").custom_minimum_size, Vector2(0, 96))
