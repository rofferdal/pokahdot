class_name GuiActionButton
extends Button

signal activated(intent: StringName)

var _intent: StringName = &""


func render(model: ActionButtonViewModel) -> void:
	if model == null:
		push_error("ActionButton requires a presentation model.")
		disabled = true
		if has_focus():
			release_focus()
		return
	text = model.label
	_intent = model.intent
	disabled = not model.enabled
	theme_type_variation = (
		&"KeypadKey"
		if model.keypad
		else (&"PrimaryActionButton" if model.primary else &"ActionButton")
	)
	if disabled and has_focus():
		release_focus()


func _pressed() -> void:
	if not disabled:
		activated.emit(_intent)
