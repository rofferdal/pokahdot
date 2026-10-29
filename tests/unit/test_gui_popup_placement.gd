extends "res://tests/support/poker_gut_test.gd"

const Placement := preload("res://scripts/gui/platform/gui_popup_placement.gd")


func test_hidden_unmounted_popup_does_not_require_a_native_or_embedded_layout() -> void:
	var popup := PopupPanel.new()
	assert_false(popup.visible)
	popup.size = Vector2i(280, 414)
	Placement.apply(popup, self, Rect2(11, 24, 618, 302), Vector2i(618, 302), true)
	assert_false(popup.visible)
	assert_eq(popup.size, Vector2i(280, 414))
	assert_push_error_count(0)
	popup.free()


func test_unsupported_visible_popup_is_hidden_without_changing_native_geometry() -> void:
	# Keep the expected engine diagnostic captured, rather than emitting an
	# ERROR line in make check that correctly blocks the strict LAN builder.
	var output: Array = []
	var arguments := PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://tests/fixtures/gui_native_popup_guard.gd",
		]
	)
	var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	assert_eq(exit_code, 0)
	var captured: String = "\n".join(output)
	assert_eq(captured.count("ERROR:"), 1, "Only the expected guard error is allowed")
	assert_string_contains(captured, "GUI popups require embedded subwindows")
	var result: Dictionary = {}
	for line: String in captured.split("\n"):
		if line.begins_with("POPUP_GUARD_RESULT:"):
			result = JSON.parse_string(line.trim_prefix("POPUP_GUARD_RESULT:"))
	assert_false(result.is_empty(), "The child must report its popup state")
	if result.is_empty():
		return
	assert_false(result.embedded)
	assert_false(result.visible)
	assert_eq(Vector2i(result.width, result.height), Vector2i(1236, 604))
	assert_eq(Vector2i(result.scale_width, result.scale_height), Vector2i(618, 302))
