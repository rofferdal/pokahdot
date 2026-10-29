extends "res://tests/support/poker_gut_test.gd"

const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")
const Harness := preload("res://tests/support/gui_scene_harness.gd")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")


func test_only_the_semantic_rich_text_event_log_accepts_eighteen() -> void:
	assert_eq(_failures(_element(&"event", &"rich_text", 18)), PackedStringArray())
	assert_string_contains(
		"\n".join(_failures(_element(&"event", &"rich_text", 17))), "font-floor:"
	)
	for role: StringName in [
		&"table/child/4", &"event/child/0", &"overlay/keypad/title", &"board/cards/0/rank"
	]:
		assert_string_contains(
			"\n".join(_failures(_element(role, &"rich_text", 18))), "font-floor:"
		)
	for kind: StringName in [&"label", &"button", &"input"]:
		assert_string_contains("\n".join(_failures(_element(&"event", kind, 18))), "font-floor:")


func test_event_log_font_exception_never_reduces_interaction_target_floor() -> void:
	var element: GuiLayoutElement = _element(&"event", &"rich_text", 18)
	element.interactive = true
	element.allocated_size = Vector2(47, 48)
	assert_string_contains("\n".join(_failures(element)), "touch-target:")


func test_measured_event_identity_uses_the_actual_control_handle_and_not_its_name() -> void:
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	var rendered: Dictionary = harness.render(
		States.by_id(&"event-history-full", 6), Vector2i(1280, 720)
	)
	assert_true(await harness.settle_layout())
	var actual := rendered.table.get_node("%EventLog") as RichTextLabel
	actual.add_theme_font_size_override("normal_font_size", 18)
	var unrelated := RichTextLabel.new()
	unrelated.name = "EventLog"
	unrelated.text = "Unrelated text must keep the normal font floor."
	unrelated.size = Vector2(400, 60)
	unrelated.add_theme_font_size_override("normal_font_size", 18)
	rendered.table.add_child(unrelated)
	var snapshot: GuiLayoutSnapshot = rendered.table.get_layout_snapshot()
	assert_eq(snapshot.elements[&"event"].font_size, 18)
	assert_eq(_failures(snapshot.elements[&"event"]), PackedStringArray())
	var event_count: int = 0
	var unrelated_count: int = 0
	for element: GuiLayoutElement in snapshot.measured:
		if element.role == &"event":
			event_count += 1
			assert_eq(element.text_kind, &"rich_text")
			assert_eq(element.rect, snapshot.elements[&"event"].rect)
			assert_eq(_failures(element), PackedStringArray())
		elif element.text == unrelated.text:
			unrelated_count += 1
			assert_string_contains("\n".join(_failures(element)), "font-floor:")
	assert_eq(event_count, 1)
	assert_eq(unrelated_count, 1)


func _element(role: StringName, kind: StringName, font_size: int) -> GuiLayoutElement:
	var element := GuiLayoutElement.new()
	element.role = role
	element.text_kind = kind
	element.font_size = font_size
	element.visible = true
	return element


func _failures(element: GuiLayoutElement) -> PackedStringArray:
	var failures := PackedStringArray()
	Content.validate_element(element, failures)
	return failures
