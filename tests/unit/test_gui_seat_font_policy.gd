extends "res://tests/support/poker_gut_test.gd"

const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")


func test_only_registered_portrait_seat_labels_can_use_eighteen() -> void:
	for role: StringName in [
		&"seat/0/name",
		&"seat/7/stack",
		&"seat/12/badge",
		&"seat/1/badge_row_2",
		&"seat/1/badge_row_3",
		&"seat/2/marker",
		&"seat/3/action",
		&"status/3"
	]:
		var value: GuiLayoutElement = _copy(role)
		var failures := PackedStringArray()
		Content.validate_element(value, failures, true)
		assert_eq(failures, PackedStringArray(), String(role))
		Content.validate_element(value, failures)
		assert_true(_font_failure(failures), "Landscape/desktop/default retain 20: %s" % role)


func test_card_rank_unknown_label_and_interactive_controls_keep_twenty() -> void:
	for role: StringName in [
		&"table/child/0",
		&"seat/0/cards/0/rank",
		&"seat/0/rank",
		&"hero/cards/0/rank",
		&"seat/0/name/child/0",
		&"seat/00/name",
		&"seat/-1/name",
		&"seat/x/name",
		&"status/0/child/0"
	]:
		var failures := PackedStringArray()
		Content.validate_element(_copy(role), failures, true)
		assert_true(_font_failure(failures), String(role))
	for kind: StringName in [&"button", &"input", &"rich_text"]:
		var value: GuiLayoutElement = _copy(&"seat/0/name")
		value.text_kind = kind
		value.interactive = kind != &"rich_text"
		var failures := PackedStringArray()
		Content.validate_element(value, failures, true)
		assert_true(_font_failure(failures), String(kind))
	var interactive_label: GuiLayoutElement = _copy(&"seat/0/name")
	interactive_label.interactive = true
	var failures := PackedStringArray()
	Content.validate_element(interactive_label, failures, true)
	assert_true(_font_failure(failures))


func test_allowed_seat_copy_floor_cannot_drop_below_eighteen_or_waive_targets() -> void:
	var value: GuiLayoutElement = _copy(&"seat/0/name")
	value.font_size = 17
	var failures := PackedStringArray()
	Content.validate_element(value, failures, true)
	assert_true(_font_failure(failures))
	value.font_size = 20
	value.interactive = true
	value.allocated_size = Vector2(47, 47)
	failures.clear()
	Content.validate_element(value, failures, true)
	assert_true("touch-target:" in "\n".join(failures))


func _copy(role: StringName) -> GuiLayoutElement:
	var value := GuiLayoutElement.new()
	value.role = role
	value.visible = true
	value.text_kind = &"label"
	value.text = "Seat copy"
	value.font_size = 18
	value.line_count = 1
	value.allocated_size = Vector2(160, 48)
	value.required_size = Vector2(80, 26)
	return value


func _font_failure(failures: PackedStringArray) -> bool:
	return "font-floor:" in "\n".join(failures)
