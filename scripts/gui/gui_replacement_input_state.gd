class_name GuiReplacementInputState
extends RefCounted

# This service is owned by the replacement table controller.
var _input_caret: int = -1
var _input_selection := Vector2i(-1, -1)
var _focus_intent: StringName = &""


func reset() -> void:
	_input_caret = -1
	_input_selection = Vector2i(-1, -1)
	_focus_intent = &""


func remember(composition: GuiTableComposition, overlay_active: bool) -> void:
	if composition == null or not composition.is_visible_in_tree():
		return
	var field := composition.get_control(&"total") as LineEdit
	if field != null and field.is_visible_in_tree():
		_input_caret = field.caret_column
		_input_selection = (
			Vector2i(field.get_selection_from_column(), field.get_selection_to_column())
			if field.has_selection()
			else Vector2i(-1, -1)
		)
	if overlay_active:
		return
	for role: StringName in [
		&"total",
		&"fold",
		&"check_call",
		&"minimum",
		&"pot",
		&"wager",
		&"all_in",
		&"continue",
		&"more"
	]:
		var control: Control = composition.get_control(role)
		if control != null and control.has_focus():
			_focus_intent = role
			break


func restore(composition: GuiTableComposition, overlay_active: bool) -> void:
	if composition == null:
		return
	var field := composition.get_control(&"total") as LineEdit
	if field != null and _input_caret >= 0:
		field.caret_column = mini(_input_caret, field.text.length())
		if _input_selection.x >= 0:
			field.select(_input_selection.x, _input_selection.y)
	if not _focus_intent.is_empty() and not overlay_active:
		var control: Control = composition.get_control(_focus_intent)
		if (
			control != null
			and control.is_visible_in_tree()
			and control.focus_mode != Control.FOCUS_NONE
			and not (control is BaseButton and (control as BaseButton).disabled)
		):
			control.grab_focus()
		_focus_intent = &""
