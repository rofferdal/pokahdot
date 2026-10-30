class_name GuiNumericKeyIntent
extends RefCounted


# Maps native key events to keypad intents without changing focus or draft state.
static func from_event(key: InputEventKey, button_focused: bool) -> StringName:
	if not key.pressed or key.ctrl_pressed or key.meta_pressed or key.alt_pressed:
		return &""
	var intent: StringName = &""
	if key.unicode >= 48 and key.unicode <= 57:
		intent = StringName(String.chr(key.unicode))
	elif key.unicode == 0:
		var top: Array[Key] = [KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
		var pad: Array[Key] = [
			KEY_KP_0,
			KEY_KP_1,
			KEY_KP_2,
			KEY_KP_3,
			KEY_KP_4,
			KEY_KP_5,
			KEY_KP_6,
			KEY_KP_7,
			KEY_KP_8,
			KEY_KP_9
		]
		var index: int = top.find(key.keycode)
		if index < 0:
			index = pad.find(key.keycode)
		if index >= 0:
			intent = StringName(str(index))
	match key.keycode:
		KEY_BACKSPACE:
			intent = &"back"
		KEY_DELETE:
			intent = &"clear"
		KEY_ENTER, KEY_KP_ENTER:
			if button_focused:
				return &""
			intent = &"done"
		KEY_ESCAPE:
			intent = &"cancel"
	return intent
