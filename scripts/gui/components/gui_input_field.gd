class_name GuiInputField
extends LineEdit

signal edited(value: String)
signal submitted(value: String)
signal entry_requested(draft: String)

var _enabled: bool = true
var _touch_entry: bool = false


func render(model: InputFieldViewModel) -> void:
	if model == null:
		push_error("InputField requires a presentation model.")
		_enabled = false
		editable = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		if has_focus():
			release_focus()
		return
	_enabled = model.enabled
	_touch_entry = model.touch_entry
	# Repeated state renders must not reset selection, caret or undo history.
	if text != model.value:
		text = model.value
	placeholder_text = model.placeholder
	tooltip_text = model.accessible_name
	accessibility_name = model.accessible_name
	editable = _enabled and not _touch_entry
	focus_mode = Control.FOCUS_ALL if _enabled else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if _enabled else Control.MOUSE_FILTER_IGNORE
	theme_type_variation = (
		(&"WagerTotalFieldInvalid" if model.invalid else &"WagerTotalField")
		if model.total
		else (&"InputFieldInvalid" if model.invalid else &"InputField")
	)
	if _enabled and _touch_entry:
		theme_type_variation = StringName(str(theme_type_variation) + "Keypad")
	if not _enabled and has_focus():
		release_focus()


func apply_draft(value: String) -> void:
	if not _enabled:
		return
	text = value
	edited.emit(value)


func _on_text_changed(value: String) -> void:
	if _enabled:
		edited.emit(value)


func _on_text_submitted(value: String) -> void:
	if _enabled:
		submitted.emit(value)


func _gui_input(event: InputEvent) -> void:
	if not _enabled:
		return
	var request: bool = event is InputEventScreenTouch and event.pressed
	if _touch_entry:
		request = (
			request
			or (
				event is InputEventMouseButton
				and event.device != -1  # Godot emits this mouse event alongside the real touch.
				and event.button_index == MOUSE_BUTTON_LEFT
				and event.pressed
			)
		)
		request = request or (event.is_action_pressed(&"ui_accept") and not event.is_echo())
	if request:
		accept_event()
		entry_requested.emit(text)
