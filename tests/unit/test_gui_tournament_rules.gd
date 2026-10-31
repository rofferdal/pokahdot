extends GutTest

const MainScene := preload("res://scenes/main.tscn")
const Document := preload("res://resources/presentation/tournament_rules.tres")
const CliReference := preload("res://scripts/cli/cli_rules_reference.gd")

var _viewport: SubViewport
var _main: StartupConfigController


func test_pointer_navigation_preserves_invalid_drafts_errors_and_return_focus() -> void:
	assert_same(GuiTournamentRulesPage.Document, CliReference.DOCUMENT)
	await _mount(Vector2i(390, 844))
	var stack := _main.get_node("%StartingStackInput") as LineEdit
	stack.text = "bad"
	(_main.get_node("%SmallBlindInput") as LineEdit).text = " 005 "
	(_main.get_node("%UseLegacyModelsCheckBox") as CheckBox).button_pressed = true
	(_main.get_node("%StartButton") as Button).pressed.emit()
	var errors: Dictionary = _main.startup_adapter.field_errors.duplicate()
	var message: String = (_main.get_node("%StartingStackError") as Label).text
	var rules := _main.get_node("%RulesButton") as Button
	await _click(rules.get_global_rect().get_center())
	assert_true(_page().is_visible_in_tree())
	assert_false((_main.get_node("Center") as Control).is_visible_in_tree())
	assert_null(_main.startup_adapter.match_instance)
	assert_eq(_viewport.gui_get_focus_owner(), _page().get_back_button())
	assert_eq(
		_page().get_body().get_parsed_text(),
		Document.render_plain_text().text.trim_prefix(Document.title + "\n\n")
	)
	assert_false(_page().get_body().bbcode_enabled)
	await _click(_page().get_back_button().get_global_rect().get_center())
	assert_false(_page().is_visible_in_tree())
	assert_eq(_viewport.gui_get_focus_owner(), rules)
	assert_eq(stack.text, "bad")
	assert_eq((_main.get_node("%SmallBlindInput") as LineEdit).text, " 005 ")
	assert_true((_main.get_node("%UseLegacyModelsCheckBox") as CheckBox).button_pressed)
	assert_eq(_main.startup_adapter.field_errors, errors)
	assert_eq((_main.get_node("%StartingStackError") as Label).text, message)


func test_keyboard_navigation_cancel_and_platform_back_preserve_valid_raw_drafts() -> void:
	await _mount(Vector2i(1920, 1080))
	var stack := _main.get_node("%StartingStackInput") as LineEdit
	stack.text = " 0123 "
	var rules := _main.get_node("%RulesButton") as Button
	rules.grab_focus()
	await _key(KEY_ENTER)
	assert_true(_page().is_visible_in_tree())
	await _key(KEY_ESCAPE)
	assert_false(_page().is_visible_in_tree())
	assert_eq(_viewport.gui_get_focus_owner(), rules)
	assert_eq(stack.text, " 0123 ")
	# Programmatic entry also restores the control that actually owned focus.
	stack.grab_focus()
	rules.pressed.emit()
	_main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(_viewport.gui_get_focus_owner(), stack)
	assert_eq(stack.text, " 0123 ")
	assert_null(_main.startup_adapter.match_instance)
	(_main.get_node("%StartButton") as Button).pressed.emit()
	assert_not_null(_main.startup_adapter.match_instance)
	assert_eq(_main.startup_adapter.resolved_config.starting_stack, 123)


func test_rules_and_hidden_start_cannot_bypass_keypad_or_mutate_its_transaction() -> void:
	await _mount(Vector2i(844, 390))
	var input := _main.get_node("%StartingStackInput") as LineEdit
	var overlay := _main.get_node("StartupOverlay") as GuiOverlayHost
	_main.show_numeric_keypad(input)
	var keypad: GuiNumericKeypad = overlay.get_keypad()
	await wait_process_frames(5)
	await _click(keypad.get_control(&"clear").get_global_rect().get_center())
	await _click(keypad.get_control(&"2").get_global_rect().get_center())
	var draft: String = keypad.get_draft()
	(_main.get_node("%RulesButton") as Button).pressed.emit()
	(_main.get_node("%StartButton") as Button).pressed.emit()
	assert_false(_page().visible)
	assert_true(overlay.is_active())
	assert_eq(keypad.get_draft(), draft)
	assert_eq(input.text, "1000")
	assert_eq(draft, "2")
	assert_null(_main.startup_adapter.match_instance)
	keypad.cancel()
	assert_eq(input.text, "1000")
	(_main.get_node("%RulesButton") as Button).pressed.emit()
	(_main.get_node("%StartButton") as Button).pressed.emit()
	_main.show_numeric_keypad(input)
	input.text_submitted.emit(input.text)
	assert_true(_page().visible)
	assert_false(overlay.is_active())
	assert_null(_main.startup_adapter.match_instance)
	_page().get_back_button().pressed.emit()
	_main.show_numeric_keypad(input)
	await wait_process_frames(5)
	await _click(keypad.get_control(&"clear").get_global_rect().get_center())
	await _click(keypad.get_control(&"2").get_global_rect().get_center())
	await _click(keypad.get_control(&"done").get_global_rect().get_center())
	assert_eq(input.text, "2")


func test_rules_page_fits_safe_areas_rotation_and_scrolls_without_moving_back() -> void:
	await _mount(Vector2i(390, 844))
	(_main.get_node("%RulesButton") as Button).pressed.emit()
	for dimensions: Vector2i in [
		Vector2i(360, 720), Vector2i(780, 360), Vector2i(1080, 1920), Vector2i(1920, 1080)
	]:
		_viewport.size = dimensions
		_main.size = Vector2(dimensions)
		var safe := Rect2(Vector2(8, 14), Vector2(dimensions) - Vector2(20, 32))
		_main.get_viewport_adapter().inject_geometry(
			GuiViewportGeometry.injected(Vector2(dimensions), safe)
		)
		await wait_process_frames(8)
		assert_eq(_page().get_rect(), safe)
		var back := _page().get_back_button()
		var back_rect: Rect2 = back.get_global_rect()
		assert_true(safe.encloses(back_rect))
		assert_gte(back_rect.size.x, 48.0)
		assert_gte(back_rect.size.y, 48.0)
		var body: RichTextLabel = _page().get_body()
		assert_true(safe.encloses(body.get_global_rect()))
		assert_gte(body.get_theme_font_size("normal_font_size"), 20)
		body.get_v_scroll_bar().value = body.get_v_scroll_bar().max_value
		await wait_process_frames(2)
		assert_eq(back.get_global_rect(), back_rect)
		if dimensions.y < 1000:
			assert_gt(body.get_v_scroll_bar().value, 0.0)
	_page().get_back_button().pressed.emit()
	assert_eq((_main.get_node("%StartingStackInput") as LineEdit).text, "1000")


func test_start_rules_action_fits_small_landscape_and_portrait_without_scrollbars() -> void:
	await _mount(Vector2i(360, 720))
	for dimensions: Vector2i in [
		Vector2i(360, 720), Vector2i(780, 360), Vector2i(390, 744), Vector2i(1920, 1080)
	]:
		_viewport.size = dimensions
		_main.size = Vector2(dimensions)
		_main.get_viewport_adapter().inject_geometry(
			GuiViewportGeometry.injected(Vector2(dimensions))
		)
		await wait_process_frames(8)
		var area := Rect2(Vector2.ZERO, Vector2(dimensions))
		for path: String in [
			"%StartButton",
			"%RulesButton",
			"%QuitApplicationButton",
			"%PlayerCountInput",
			"%StartingStackInput"
		]:
			var control := _main.get_node(path) as Control
			assert_true(area.encloses(control.get_global_rect()), "%s at %s" % [path, dimensions])
			assert_gte(control.size.y, 48.0)
		assert_false((_main.get_node("Center") as Control) is ScrollContainer)


func test_touch_navigation_and_reader_scroll_keep_back_reachable_and_reset_on_reopen() -> void:
	await _mount(Vector2i(390, 744))
	var rules := _main.get_node("%RulesButton") as Button
	await _touch(rules.get_global_rect().get_center())
	assert_true(_page().visible)
	var body: RichTextLabel = _page().get_body()
	var origin: Vector2 = body.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.position = origin
	press.pressed = true
	_viewport.push_input(press)
	await wait_process_frames(1)
	var drag := InputEventScreenDrag.new()
	drag.position = origin - Vector2(0, 100)
	drag.relative = Vector2(0, -100)
	_viewport.push_input(drag)
	await wait_process_frames(1)
	var release := InputEventScreenTouch.new()
	release.position = drag.position
	_viewport.push_input(release)
	await wait_process_frames(3)
	assert_gt(body.get_v_scroll_bar().value, 0.0)
	await _touch(_page().get_back_button().get_global_rect().get_center())
	assert_false(_page().visible)
	await _touch(rules.get_global_rect().get_center())
	assert_eq(body.get_v_scroll_bar().value, 0.0)
	await _touch(_page().get_back_button().get_global_rect().get_center())
	assert_null(_main.startup_adapter.match_instance)


func test_keyboard_reader_can_scroll_and_cancel_back_to_the_same_form() -> void:
	await _mount(Vector2i(390, 744))
	(_main.get_node("%RulesButton") as Button).grab_focus()
	await _key(KEY_ENTER)
	_page().get_body().grab_focus()
	await _key(KEY_PAGEDOWN)
	assert_gt(_page().get_body().get_v_scroll_bar().value, 0.0)
	await _key(KEY_ESCAPE)
	assert_false(_page().visible)
	assert_eq(_viewport.gui_get_focus_owner(), _main.get_node("%RulesButton"))


func test_platform_back_ownership_restores_tree_policy_on_back_and_free() -> void:
	await _mount(Vector2i(390, 744))
	var previous: bool = get_tree().quit_on_go_back
	for policy: bool in [true, false]:
		get_tree().quit_on_go_back = policy
		(_main.get_node("%RulesButton") as Button).pressed.emit()
		assert_false(get_tree().quit_on_go_back)
		_main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		assert_false(_page().visible)
		assert_eq(get_tree().quit_on_go_back, policy)
	get_tree().quit_on_go_back = true
	(_main.get_node("%RulesButton") as Button).pressed.emit()
	_main.free()
	assert_true(get_tree().quit_on_go_back)
	get_tree().quit_on_go_back = previous


func _touch(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = position
		event.pressed = pressed
		_viewport.push_input(event)
		await wait_process_frames(1)


func _mount(dimensions: Vector2i) -> void:
	_viewport = SubViewport.new()
	_viewport.size = dimensions
	add_child_autofree(_viewport)
	_main = MainScene.instantiate() as StartupConfigController
	_main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_main.size = Vector2(dimensions)
	_viewport.add_child(_main)
	await wait_process_frames(8)


func _page() -> GuiTournamentRulesPage:
	return _main.get_node("RulesPage") as GuiTournamentRulesPage


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		_viewport.push_input(event)
		await wait_process_frames(1)


func _click(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_viewport.push_input(event)
		await wait_process_frames(1)
