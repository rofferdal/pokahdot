extends "res://tests/support/poker_gut_test.gd"

const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")
const LogScene := preload("res://scenes/gui/components/EventLog.tscn")
const Measure := preload("res://scripts/gui/gui_snapshot_measurement.gd")


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
	var root := Control.new()
	root.size = Vector2(800, 600)
	add_child_autofree(root)
	var log := LogScene.instantiate() as GuiEventLog
	root.add_child(log)
	log.size = Vector2(360, 260)
	log.render(EventLogViewModel.from_lines(["Public event"]))
	var actual: RichTextLabel = log.get_body()
	actual.add_theme_font_size_override("normal_font_size", 18)
	var unrelated := RichTextLabel.new()
	unrelated.name = "EventLog"
	unrelated.text = "Unrelated text must keep the normal font floor."
	unrelated.size = Vector2(400, 60)
	unrelated.add_theme_font_size_override("normal_font_size", 18)
	root.add_child(unrelated)
	await wait_process_frames(3)
	var event: GuiLayoutElement = log.get_observation(root)
	assert_eq(event.font_size, 18)
	assert_eq(event.text_kind, &"rich_text")
	assert_eq(_failures(event), PackedStringArray())
	var other: GuiLayoutElement = Measure.element(unrelated, root, &"unrelated")
	assert_string_contains("\n".join(_failures(other)), "font-floor:")


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
