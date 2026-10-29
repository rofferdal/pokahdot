extends SceneTree

## Review fixture of actual reusable scenes, independent of table composition.
const Action := preload("res://scenes/gui/components/ActionButton.tscn")
const Field := preload("res://scenes/gui/components/InputField.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const OUTPUT: String = "res://localtmp/gui-elements/rg39-shared-controls"

var _controls: Array[Control] = []


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1120, 850)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("0b271b")
	background.size = Vector2(viewport.size)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var margin := MarginContainer.new()
	margin.position = Vector2(32, 24)
	margin.size = Vector2(1056, 802)
	margin.theme = Palette
	viewport.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)
	_label(stack, "Shared actions & fields", &"HeadingText")
	_label(stack, "Reusable controls • 20 px text • minimum 48 px targets")
	var buttons := GridContainer.new()
	buttons.columns = 5
	buttons.add_theme_constant_override("h_separation", 12)
	buttons.add_theme_constant_override("v_separation", 8)
	stack.add_child(buttons)
	for state: String in ["Normal", "Hover", "Pressed", "Focus", "Disabled"]:
		_label(buttons, state)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var model := ActionButtonViewModel.new()
		model.label = "Raise"
		model.enabled = state != "disabled"
		var button: GuiActionButton = Action.instantiate()
		button.render(model)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
		_controls.append(button)
		_preview_state(button, state)
	_label(stack, "One button family for every action", &"HeadingText")
	var roles := HBoxContainer.new()
	roles.add_theme_constant_override("separation", 8)
	stack.add_child(roles)
	for title: String in ["Start", "Quit", "Cancel", "Log", "More / Pots", "1", "Done"]:
		var model := ActionButtonViewModel.new()
		model.label = title
		model.primary = title == "Start"
		model.keypad = title == "1"
		var button: GuiActionButton = Action.instantiate()
		button.render(model)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roles.add_child(button)
		_controls.append(button)
	_label(stack, "Text & number entry", &"HeadingText")
	var fields := GridContainer.new()
	fields.columns = 4
	fields.add_theme_constant_override("h_separation", 12)
	fields.add_theme_constant_override("v_separation", 8)
	stack.add_child(fields)
	for title: String in ["Normal", "Focus", "Disabled", "Error"]:
		_label(fields, title)
	for total: bool in [false, true]:
		for state: String in ["normal", "focus", "disabled", "error"]:
			var model := InputFieldViewModel.new()
			model.value = "Total 1,000" if total else "1,000"
			model.total = total
			model.enabled = state != "disabled"
			model.invalid = state == "error"
			var field: GuiInputField = Field.instantiate()
			field.render(model)
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fields.add_child(field)
			_controls.append(field)
			_preview_state(field, state)
	_label(stack, "Total keeps its sharp, shorter face inside the full hit area.")
	_label(stack, "Keypad entry keeps the field appearance", &"HeadingText")
	var touch_row := HBoxContainer.new()
	touch_row.add_theme_constant_override("separation", 12)
	stack.add_child(touch_row)
	var draft := InputFieldViewModel.new()
	draft.value = "00042"
	draft.touch_entry = true
	var touch: GuiInputField = Field.instantiate()
	touch.render(draft)
	touch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	touch_row.add_child(touch)
	_controls.append(touch)
	_label(touch_row, "Touch requests entry; draft stays exact.")
	_label(stack, "Review sample — table, keypad and startup composition follow later.")
	for frame: int in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var escaped := PackedStringArray()
	var observations: Array[Dictionary] = []
	for control: Control in _controls:
		var rect: Rect2 = control.get_global_rect()
		if not bounds.encloses(rect):
			escaped.append(str(control.get_path()))
		observations.append(
			{
				"variation": control.theme_type_variation,
				"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
				"font_size": control.get_theme_font_size("font_size")
			}
		)
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	var error: Error = viewport.get_texture().get_image().save_png(OUTPUT + ".png")
	var metadata := FileAccess.open(OUTPUT + ".json", FileAccess.WRITE)
	if metadata == null:
		push_error("Cannot save shared-control capture metadata.")
		quit(1)
		return
	var hashes: Dictionary = {}
	for path: String in [
		"scenes/gui/components/ActionButton.tscn",
		"scenes/gui/components/InputField.tscn",
		"scripts/gui/components/gui_action_button.gd",
		"scripts/gui/components/gui_input_field.gd",
		"scripts/gui/view_models/action_button_view_model.gd",
		"scripts/gui/view_models/input_field_view_model.gd",
		"resources/gui_theme.tres",
		"tests/visual/gui_shared_controls_capture.gd"
	]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	metadata.store_string(
		JSON.stringify(
			{
				"image": OUTPUT + ".png",
				"save_error": error,
				"escaped_controls": escaped,
				"controls": observations,
				"source_sha256": hashes,
				"states": "simultaneous authored state previews; focus/hover simulated",
				"device_acceptance": false
			},
			"\t"
		)
	)
	viewport.queue_free()
	quit(0 if error == OK and escaped.is_empty() else 1)


func _label(parent: Node, copy: String, variation: StringName = &"BodyText") -> void:
	var label := Label.new()
	label.text = copy
	label.theme_type_variation = variation
	parent.add_child(label)


func _preview_state(control: Control, state: String) -> void:
	# Fixture-only overrides show several interaction states in a single image.
	var variation: StringName = control.theme_type_variation
	if state in ["hover", "pressed"]:
		control.add_theme_stylebox_override("normal", Palette.get_stylebox(state, variation))
	elif state == "focus":
		var normal: StyleBoxFlat = Palette.get_stylebox("normal", variation).duplicate()
		var focus: StyleBoxFlat = Palette.get_stylebox("focus", variation)
		normal.border_color = focus.border_color
		for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			normal.set_border_width(edge, focus.get_border_width(edge))
		control.add_theme_stylebox_override("normal", normal)
