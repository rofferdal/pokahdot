extends GutTest

const ActionScene := preload("res://scenes/gui/components/ActionButton.tscn")
const FieldScene := preload("res://scenes/gui/components/InputField.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")

var _viewport: SubViewport


func test_all_action_roles_render_complete_copy_and_states_at_their_minimum() -> void:
	var root: Control = _root()
	for title: String in [
		"Start tournament", "Quit", "Confirm", "Menu", "Log", "More / Pots", "Raise", "7"
	]:
		for enabled: bool in [true, false]:
			var model := ActionButtonViewModel.new()
			model.label = title
			model.intent = StringName(title)
			model.enabled = enabled
			model.primary = title == "Start tournament"
			model.keypad = title == "7"
			var button: GuiActionButton = ActionScene.instantiate()
			button.render(model)
			root.add_child(button)
			await wait_process_frames(2)
			button.size = button.get_combined_minimum_size()
			assert_eq(button.text, title)
			assert_eq(button.disabled, not enabled)
			_assert_minimum_content(button, root)
			assert_eq(button.get_theme_color("font_color"), Color.WHITE)
			assert_eq(button.get_theme_color("font_disabled_color"), Color("a8a8a8"))
			for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
				var style: StyleBoxFlat = button.get_theme_stylebox(state)
				assert_gt(style.corner_radius_top_left, 0, "%s/%s" % [title, state])
				assert_gt(style.corner_radius_bottom_right, 0, "%s/%s" % [title, state])
			root.remove_child(button)
			button.free()


func test_action_keyboard_and_touch_emit_intent_once_and_disabled_emits_nothing() -> void:
	var root: Control = _input_root()
	var model := ActionButtonViewModel.new()
	model.label = "Quit"
	model.intent = &"quit"
	var button: GuiActionButton = ActionScene.instantiate()
	root.add_child(button)
	button.render(model)
	button.size = button.get_combined_minimum_size()
	watch_signals(button)
	await wait_process_frames(3)
	button.grab_focus()
	await _key(KEY_ENTER)
	assert_signal_emit_count(button, "activated", 1)
	assert_signal_emitted_with_parameters(button, "activated", [&"quit"])
	await _touch(button.get_global_rect().get_center())
	assert_signal_emit_count(button, "activated", 2)
	model.enabled = false
	button.render(model)
	await _key(KEY_ENTER)
	await _touch(button.get_global_rect().get_center())
	assert_signal_emit_count(button, "activated", 2)


func test_input_states_keep_sharp_field_family_and_full_copy_at_minimum() -> void:
	var root: Control = _root()
	for total: bool in [false, true]:
		for invalid: bool in [false, true]:
			for enabled: bool in [true, false]:
				var model := InputFieldViewModel.new()
				model.value = "9999999"
				model.total = total
				model.invalid = invalid
				model.enabled = enabled
				var field: GuiInputField = FieldScene.instantiate()
				field.render(model)
				root.add_child(field)
				await wait_process_frames(2)
				field.size = field.get_combined_minimum_size()
				_assert_minimum_content(field, root)
				assert_eq(field.text, model.value)
				assert_eq(field.editable, enabled)
				for state: StringName in [&"normal", &"focus", &"read_only"]:
					var style: StyleBoxFlat = field.get_theme_stylebox(state)
					assert_eq(style.corner_radius_top_left, 0)
					assert_eq(style.corner_radius_bottom_right, 0)
					if total:
						assert_eq(style.expand_margin_top, -4.0)
						assert_eq(style.expand_margin_bottom, -4.0)
				var normal: StyleBoxFlat = field.get_theme_stylebox("normal")
				if total:
					assert_lt(normal.bg_color.get_luminance(), 0.2)
					assert_eq(field.get_theme_color("font_color"), Color("b8c3bb"))
				else:
					assert_gt(normal.bg_color.get_luminance(), 0.8)
					var ink: Color = field.get_theme_color("font_color")
					assert_gt(ink.g, ink.r)
					assert_gt(ink.g, ink.b)
				root.remove_child(field)
				field.free()


func test_invalid_field_focus_and_readonly_are_recognizable_without_changing_allocation() -> void:
	var root: Control = _root()
	for total: bool in [false, true]:
		var field: GuiInputField = FieldScene.instantiate()
		root.add_child(field)
		var model := InputFieldViewModel.new()
		model.value = "1000"
		model.total = total
		field.render(model)
		var normal: StyleBoxFlat = field.get_theme_stylebox("normal")
		var focus: StyleBoxFlat = field.get_theme_stylebox("focus")
		var readonly: StyleBoxFlat = field.get_theme_stylebox("read_only")
		assert_ne(normal.border_color, focus.border_color)
		assert_ne(normal.bg_color, readonly.bg_color)
		model.invalid = true
		field.render(model)
		var error: StyleBoxFlat = field.get_theme_stylebox("normal")
		var error_focus: StyleBoxFlat = field.get_theme_stylebox("focus")
		assert_ne(error.border_color, normal.border_color)
		assert_eq(error.border_color, error_focus.border_color)
		assert_eq(error.expand_margin_top, normal.expand_margin_top)
		assert_eq(error.expand_margin_bottom, normal.expand_margin_bottom)
		field.size = field.get_combined_minimum_size()
		_assert_minimum_content(field, root)


func test_repeated_render_preserves_exact_draft_caret_and_selection_without_edit_signal() -> void:
	var root: Control = _root()
	var model := InputFieldViewModel.new()
	model.value = " 00042 "
	var field: GuiInputField = FieldScene.instantiate()
	root.add_child(field)
	watch_signals(field)
	field.render(model)
	field.caret_column = 4
	field.select(1, 5)
	field.render(model)
	assert_eq(field.text, " 00042 ")
	assert_eq(field.caret_column, 4)
	assert_true(field.has_selection())
	assert_eq(field.get_selection_from_column(), 1)
	assert_eq(field.get_selection_to_column(), 5)
	assert_signal_not_emitted(field, "edited")
	assert_signal_not_emitted(field, "submitted")
	field.apply_draft("00000000invalid")
	assert_eq(field.text, "00000000invalid", "The adapter owns numeric validation")
	assert_signal_emitted_with_parameters(field, "edited", ["00000000invalid"])


func test_native_keyboard_edits_and_submits_exact_text() -> void:
	var root: Control = _input_root()
	var field: GuiInputField = FieldScene.instantiate()
	root.add_child(field)
	var model := InputFieldViewModel.new()
	model.value = "0004"
	field.render(model)
	field.size = Vector2(240, 48)
	watch_signals(field)
	await wait_process_frames(3)
	field.grab_focus()
	field.caret_column = field.text.length()
	await _key(KEY_2, 50)
	assert_eq(field.text, "00042")
	assert_signal_emitted_with_parameters(field, "edited", ["00042"])
	await _key(KEY_ENTER)
	assert_signal_emitted_with_parameters(field, "submitted", ["00042"])
	assert_signal_not_emitted(field, "entry_requested")


func test_touch_requests_entry_with_exact_draft_and_disabled_ignores_input() -> void:
	var root: Control = _input_root()
	var field: GuiInputField = FieldScene.instantiate()
	root.add_child(field)
	var model := InputFieldViewModel.new()
	model.value = " 00042 "
	model.touch_entry = true
	field.render(model)
	field.size = Vector2(240, 48)
	watch_signals(field)
	await wait_process_frames(3)
	await _touch(field.get_global_rect().get_center())
	assert_signal_emit_count(field, "entry_requested", 1)
	assert_signal_emitted_with_parameters(field, "entry_requested", [" 00042 "])
	assert_eq(field.text, " 00042 ")
	assert_signal_not_emitted(field, "edited")
	assert_signal_not_emitted(field, "submitted")
	model.enabled = false
	field.render(model)
	await _touch(field.get_global_rect().get_center())
	await _key(KEY_8, 56)
	assert_signal_emit_count(field, "entry_requested", 1)
	assert_eq(field.text, " 00042 ")
	assert_eq(field.focus_mode, Control.FOCUS_NONE)


func test_placeholder_and_rebinding_do_not_retain_previous_field_state() -> void:
	var root: Control = _root()
	var field: GuiInputField = FieldScene.instantiate()
	var first := InputFieldViewModel.new()
	first.value = "draft"
	first.invalid = true
	first.total = true
	first.touch_entry = true
	first.enabled = false
	field.render(first)
	root.add_child(field)
	var next := InputFieldViewModel.new()
	next.placeholder = "Enter amount"
	field.render(next)
	field.size = field.get_combined_minimum_size()
	_assert_minimum_content(field, root)
	assert_eq(field.text, "")
	assert_eq(field.placeholder_text, "Enter amount")
	assert_true(field.editable)
	assert_eq(field.focus_mode, Control.FOCUS_ALL)
	assert_eq(field.theme_type_variation, &"InputField")


func test_real_touch_routes_keyboard_field_to_adapter_without_mutating_or_submitting() -> void:
	var root: Control = _input_root()
	var field: GuiInputField = FieldScene.instantiate()
	root.add_child(field)
	var model := InputFieldViewModel.new()
	model.value = "00042"
	field.render(model)
	field.size = Vector2(240, 48)
	watch_signals(field)
	await wait_process_frames(3)
	assert_true(field.editable)
	await _touch(field.get_global_rect().get_center())
	assert_signal_emit_count(field, "entry_requested", 1)
	assert_signal_emitted_with_parameters(field, "entry_requested", ["00042"])
	assert_eq(field.text, "00042")
	assert_signal_not_emitted(field, "edited")
	assert_signal_not_emitted(field, "submitted")


func test_touch_entry_pointer_and_keyboard_request_draft_instead_of_native_editing() -> void:
	var root: Control = _input_root()
	var field: GuiInputField = FieldScene.instantiate()
	root.add_child(field)
	var model := InputFieldViewModel.new()
	model.value = " 00042 "
	model.touch_entry = true
	field.render(model)
	field.size = Vector2(240, 48)
	watch_signals(field)
	await wait_process_frames(3)
	await _click(field.get_global_rect().get_center())
	assert_signal_emit_count(field, "entry_requested", 1)
	field.grab_focus()
	await _key(KEY_ENTER)
	assert_signal_emit_count(field, "entry_requested", 2)
	assert_signal_emitted_with_parameters(field, "entry_requested", [" 00042 "])
	await _key(KEY_8, 56)
	assert_eq(field.text, " 00042 ")
	assert_signal_not_emitted(field, "edited")
	assert_signal_not_emitted(field, "submitted")
	model.enabled = false
	field.render(model)
	field.apply_draft("changed")
	assert_eq(field.text, " 00042 ")
	assert_signal_not_emitted(field, "edited")


func test_button_rebinding_replaces_intent_and_family_without_retaining_mutable_model() -> void:
	var root: Control = _input_root()
	var button: GuiActionButton = ActionScene.instantiate()
	root.add_child(button)
	var model := ActionButtonViewModel.new()
	model.label = "Done"
	model.intent = &"done"
	model.primary = true
	button.render(model)
	watch_signals(button)
	button.size = button.get_combined_minimum_size()
	await wait_process_frames(3)
	model.intent = &"unrendered"
	button.grab_focus()
	await _key(KEY_ENTER)
	assert_signal_emitted_with_parameters(button, "activated", [&"done"])
	model.label = "7"
	model.intent = &"digit7"
	model.primary = false
	model.keypad = true
	button.render(model)
	await _key(KEY_ENTER)
	assert_signal_emit_count(button, "activated", 2)
	assert_signal_emitted_with_parameters(button, "activated", [&"digit7"], 1)
	assert_eq(button.theme_type_variation, &"KeypadKey")
	model.keypad = false
	button.render(model)
	assert_eq(button.theme_type_variation, &"ActionButton")


func test_components_inherit_composition_metrics_and_palette_in_both_densities() -> void:
	var root: Control = _root()
	var layer := Control.new()
	root.add_child(layer)
	var button: GuiActionButton = ActionScene.instantiate()
	var field: GuiInputField = FieldScene.instantiate()
	layer.add_child(button)
	layer.add_child(field)
	var button_model := ActionButtonViewModel.new()
	button_model.label = "Log"
	button.render(button_model)
	var field_model := InputFieldViewModel.new()
	field_model.value = "42"
	field.render(field_model)
	assert_null(button.theme)
	assert_null(field.theme)
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		layer.theme = metrics
		await wait_process_frames(2)
		for control: Control in [button, field]:
			assert_eq(control.get_theme_font_size("font_size"), 20)
			assert_false(control.has_theme_font_size_override("font_size"))
			control.size = control.get_combined_minimum_size()
			_assert_minimum_content(control, root)
		assert_same(
			button.get_theme_stylebox("normal"), Palette.get_stylebox("normal", "ActionButton")
		)
		assert_same(
			field.get_theme_stylebox("normal"), Palette.get_stylebox("normal", "InputField")
		)


func test_enabled_keypad_fields_retain_normal_fill_and_disabled_fields_dim() -> void:
	var root: Control = _root()
	for total: bool in [false, true]:
		for invalid: bool in [false, true]:
			var field: GuiInputField = FieldScene.instantiate()
			root.add_child(field)
			var model := InputFieldViewModel.new()
			model.value = "00042"
			model.total = total
			model.invalid = invalid
			model.touch_entry = true
			model.accessible_name = "Wager total" if total else "Starting stack"
			field.render(model)
			assert_false(field.editable)
			assert_eq(field.accessibility_name, model.accessible_name)
			assert_eq(field.get_theme_stylebox("normal"), field.get_theme_stylebox("read_only"))
			var enabled_fill: Color = (
				(field.get_theme_stylebox("read_only") as StyleBoxFlat).bg_color
			)
			field.size = field.get_combined_minimum_size()
			_assert_minimum_content(field, root)
			model.enabled = false
			model.invalid = false
			field.render(model)
			var disabled_fill: Color = (
				(field.get_theme_stylebox("read_only") as StyleBoxFlat).bg_color
			)
			assert_ne(disabled_fill, enabled_fill)


func test_emulated_mouse_and_real_touch_only_request_one_keypad_entry() -> void:
	var root: Control = _input_root()
	var field: GuiInputField = FieldScene.instantiate()
	root.add_child(field)
	var model := InputFieldViewModel.new()
	model.value = "00042"
	model.touch_entry = true
	field.render(model)
	field.size = Vector2(240, 48)
	watch_signals(field)
	await wait_process_frames(3)
	await _click(field.get_global_rect().get_center(), -1)
	assert_signal_not_emitted(field, "entry_requested")
	await _touch(field.get_global_rect().get_center())
	assert_signal_emit_count(field, "entry_requested", 1)
	assert_eq(field.text, "00042")
	assert_signal_not_emitted(field, "edited")


func test_missing_models_disable_focused_controls_without_changing_existing_draft() -> void:
	var root: Control = _input_root()
	var field: GuiInputField = FieldScene.instantiate()
	root.add_child(field)
	var field_model := InputFieldViewModel.new()
	field_model.value = "00042"
	field.render(field_model)
	field.size = Vector2(240, 48)
	var button: GuiActionButton = ActionScene.instantiate()
	root.add_child(button)
	var button_model := ActionButtonViewModel.new()
	button_model.label = "Quit"
	button_model.intent = &"quit"
	button.render(button_model)
	button.position = Vector2(0, 80)
	button.size = button.get_combined_minimum_size()
	await wait_process_frames(3)
	watch_signals(field)
	watch_signals(button)
	field.grab_focus()
	assert_true(field.has_focus())
	field.render(null)
	assert_push_error_count(1)
	assert_false(field.has_focus())
	assert_false(field.editable)
	assert_eq(field.focus_mode, Control.FOCUS_NONE)
	field.apply_draft("replacement")
	assert_eq(field.text, "00042")
	button.grab_focus()
	assert_true(button.has_focus())
	button.render(null)
	assert_push_error_count(2)
	assert_false(button.has_focus())
	assert_true(button.disabled)
	await _key(KEY_ENTER)
	await _touch(button.get_global_rect().get_center())
	assert_signal_not_emitted(button, "activated")
	assert_signal_not_emitted(field, "edited")
	assert_signal_not_emitted(field, "entry_requested")


func _root() -> Control:
	var root := Control.new()
	root.size = Vector2(800, 600)
	root.theme = Palette
	add_child_autofree(root)
	return root


func _input_root() -> Control:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 600)
	add_child_autofree(_viewport)
	var root := Control.new()
	root.size = Vector2(800, 600)
	root.theme = Palette
	_viewport.add_child(root)
	return root


func _assert_minimum_content(control: Control, root: Control) -> void:
	var observation: GuiLayoutElement = GuiSnapshotMeasurement.element(control, root, &"component")
	var failures := PackedStringArray()
	Invariants.validate_element(observation, failures)
	assert_eq(failures, PackedStringArray())
	assert_gte(control.size.x, 48.0)
	assert_gte(control.size.y, 48.0)
	assert_gte(control.get_theme_font_size("font_size"), 20)
	assert_lte(observation.required_size.x, observation.local_content_size.x)
	assert_lte(observation.required_size.y, observation.local_content_size.y)


func _key(code: Key, unicode_value: int = 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.unicode = unicode_value
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame


func _touch(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = position
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame


func _click(position: Vector2, device: int = 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.device = device
		event.position = position
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame
