extends "res://tests/support/poker_gut_test.gd"

const Measure := preload("res://scripts/gui/gui_snapshot_measurement.gd")
const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")
const GuiTheme := preload("res://resources/gui_theme.tres")


func test_fractional_wrapped_allocation_measures_actual_label_trim_settings() -> void:
	var label: Label = _label()
	label.text = "Small blind 5"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(112.333335876465, 56)
	var value: GuiLayoutElement = Measure.element(label, label, &"wrapped")
	assert_eq(value.line_count, 2)
	assert_lte(value.required_size.x, label.size.x)
	var failures := PackedStringArray()
	Content.validate_element(value, failures)
	assert_eq(failures, PackedStringArray())
	label.autowrap_trim_flags = 0
	value = Measure.element(label, label, &"untrimmed")
	assert_gt(value.required_size.x, label.size.x + 0.5)
	Content.validate_element(value, failures)
	assert_true("text-clipping:" in "\n".join(failures))


func test_matching_whitespace_trimming_does_not_hide_actual_horizontal_or_line_limit_clipping(
) -> void:
	var label: Label = _label()
	label.text = "Small blind 5"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 1
	label.size = Vector2(112.333335876465, 56)
	var value: GuiLayoutElement = Measure.element(label, label, &"limited")
	var failures := PackedStringArray()
	Content.validate_element(value, failures)
	assert_true("hides wrapped lines" in "\n".join(failures))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = -1
	label.clip_text = true
	label.text = "WWWW"
	label.size = Vector2(5, 56)
	value = Measure.element(label, label, &"clipped")
	failures.clear()
	Content.validate_element(value, failures)
	assert_true("text-clipping:" in "\n".join(failures))


func _label() -> Label:
	var label := Label.new()
	label.theme = GuiTheme
	label.add_theme_font_size_override("font_size", 20)
	add_child_autofree(label)
	return label
