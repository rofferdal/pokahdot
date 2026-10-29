class_name GuiNumericKeypad
extends Control

signal committed(value: String)
signal cancelled

const DIGITS: Array[String] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
const UTILITY: Array[StringName] = [&"clear", &"back", &"minimum", &"pot", &"cancel", &"done"]
var layout_mode_name: StringName = &"portrait"
var utility_columns: int = 2
var _active: bool = false
var _original: String = ""
var _draft: String = ""
var _minimum_preset: String = ""
var _pot_preset: String = ""
var _pot_label: String = "Pot"
var _compact_header: bool = false
var _limits_multiline: String = ""
var _show_presets: bool = false
var _pot_enabled: bool = false
var _buttons: Dictionary[StringName, GuiActionButton] = {}


func _ready() -> void:
	_init_controls()
	for button: GuiActionButton in _buttons.values():
		button.activated.connect(_on_key)
	(get_control(&"value") as GuiInputField).edited.connect(_on_value_edited)


func _init_controls() -> void:
	if _buttons.is_empty():
		for digit: String in DIGITS:
			_buttons[StringName(digit)] = get_node("%Key" + digit) as GuiActionButton
		for role: StringName in UTILITY:
			_buttons[role] = get_node("%" + str(role)) as GuiActionButton


func render(model: NumberEntryViewModel) -> void:
	_init_controls()
	_active = model != null and model.valid and model.minimum <= model.maximum
	if not _active:
		push_error("NumericKeypad requires a valid number-entry model and ordered limits.")
		model = NumberEntryViewModel.new()
		model.value = ""
	_original = model.value
	_draft = model.value
	_minimum_preset = (
		str(model.minimum) if model.minimum_preset.is_empty() else model.minimum_preset
	)
	_pot_preset = model.pot_preset
	_pot_label = model.pot_label
	_show_presets = _active and model.show_presets
	_pot_enabled = _active and model.pot_enabled and not model.pot_preset.is_empty()
	(get_control(&"title") as Label).text = model.title if _active else ""
	_limits_multiline = ("Min %d\nMax %d" % [model.minimum, model.maximum] if _active else "")
	(get_control(&"limits") as Label).text = _limits_multiline
	var captions: Dictionary[StringName, String] = {
		&"clear": "Clear",
		&"back": "⌫",
		&"minimum": model.minimum_label,
		&"pot": _pot_caption(false),
		&"cancel": "Cancel",
		&"done": "Done"
	}
	for role: StringName in _buttons:
		var button: GuiActionButton = _buttons[role]
		var view := ActionButtonViewModel.new()
		view.label = captions.get(role, str(role))
		view.intent = role
		view.keypad = true
		view.enabled = _active and (role != &"pot" or _pot_enabled)
		button.render(view)
		button.visible = role not in [&"minimum", &"pot"] or _show_presets
	_buttons[&"back"].tooltip_text = "Delete selected digits or the last digit"
	_sync_value()
	# The compact horizontal header must still show complete legal values.
	# Arbitrarily long invalid drafts retain native horizontal scrolling.
	var field := get_control(&"value") as GuiInputField
	var font: Font = field.get_theme_font("font")
	var font_size: int = field.get_theme_font_size("font_size")
	var legal_width: float = maxf(
		font.get_string_size(str(model.minimum), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x,
		font.get_string_size(str(model.maximum), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	)
	field.custom_minimum_size.x = maxf(
		48.0, ceilf(legal_width + field.get_theme_stylebox("read_only").get_minimum_size().x)
	)


func get_control(key: StringName) -> Control:
	_init_controls()
	match key:
		&"title":
			return get_node("%Title") as Control
		&"value":
			return get_node("%Value") as Control
		&"limits":
			return get_node("%Limits") as Control
	return _buttons.get(key)


func get_draft() -> String:
	return _draft


func is_active() -> bool:
	return _active


func cancel() -> void:
	if not _active:
		return
	_draft = _original
	_active = false
	_sync_value()
	cancelled.emit()


func commit() -> void:
	if not _active:
		return
	_active = false
	committed.emit(_draft)


func _on_value_edited(value: String) -> void:
	if _active:
		_draft = value


func _sync_value() -> void:
	var model := InputFieldViewModel.new()
	model.value = _draft
	model.enabled = _active
	model.touch_entry = true
	model.accessible_name = "Number draft"
	var field := get_control(&"value") as GuiInputField
	field.render(model)
	if _compact_header:
		field.theme_type_variation = &"NumberFieldInline"
	field.caret_column = _draft.length()


func _replace_selection(value: String, erase_last: bool = false) -> void:
	var field := get_control(&"value") as GuiInputField
	if field.has_selection():
		_draft = (
			_draft.substr(0, field.get_selection_from_column())
			+ value
			+ _draft.substr(field.get_selection_to_column())
		)
	elif erase_last:
		_draft = _draft.left(maxi(0, _draft.length() - 1))
	else:
		_draft += value
	field.deselect()
	_sync_value()


func _on_key(intent: StringName) -> void:
	if not _active:
		return
	if str(intent) in DIGITS:
		_replace_selection(str(intent))
		return
	match intent:
		&"back":
			_replace_selection("", true)
		&"clear":
			_draft = ""
			_sync_value()
		&"minimum":
			if _show_presets:
				_draft = _minimum_preset
				_sync_value()
		&"pot":
			if _show_presets and _pot_enabled:
				_draft = _pot_preset
				_sync_value()
		&"cancel":
			cancel()
		&"done":
			commit()


func _input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree() or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.ctrl_pressed or key.meta_pressed or key.alt_pressed:
		return
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
			intent = StringName(DIGITS[index])
	match key.keycode:
		KEY_BACKSPACE:
			intent = &"back"
		KEY_DELETE:
			intent = &"clear"
		KEY_ENTER, KEY_KP_ENTER:
			var focused: Control = get_viewport().gui_get_focus_owner()
			if focused is BaseButton and is_ancestor_of(focused):
				return
			intent = &"done"
		KEY_ESCAPE:
			intent = &"cancel"
	if not intent.is_empty():
		get_viewport().set_input_as_handled()
		_on_key(intent)


func _pot_caption(stacked: bool) -> String:
	if _pot_preset.is_empty():
		return _pot_label
	return _pot_label + ("\n" if stacked else " ") + _pot_preset


func _utility_cell(pot_caption: String) -> Vector2:
	_buttons[&"pot"].text = pot_caption
	var cell := Vector2(48, 48)
	for role: StringName in UTILITY:
		var button: GuiActionButton = _buttons[role]
		button.custom_minimum_size = Vector2(48, 48)
		if button.visible:
			cell = cell.max(button.get_combined_minimum_size())
	return cell


func _set_header_appearance(compact: bool) -> void:
	_compact_header = compact
	(get_control(&"value") as GuiInputField).theme_type_variation = (
		&"NumberFieldInline" if compact else &"InputFieldKeypad"
	)
	(get_control(&"limits") as Label).text = (
		_limits_multiline.replace("\n", "    ") if compact else _limits_multiline
	)


func _header_minimum(compact: bool) -> Vector2:
	_set_header_appearance(compact)
	var title_size: Vector2 = get_control(&"title").get_combined_minimum_size()
	var value_size: Vector2 = get_control(&"value").get_combined_minimum_size()
	var limits_size: Vector2 = get_control(&"limits").get_combined_minimum_size()
	var gap: float = (get_node("%InputRow") as HBoxContainer).get_theme_constant("separation")
	return (
		Vector2(
			maxf(title_size.x + value_size.x + gap, limits_size.x),
			maxf(title_size.y, value_size.y) + limits_size.y
		)
		if compact
		else Vector2(
			maxf(title_size.x, maxf(value_size.x, limits_size.x)),
			title_size.y + value_size.y + limits_size.y + gap * 2.0
		)
	)


func fit_available(available: Vector2) -> bool:
	if not available.is_finite() or available.x <= 0.0 or available.y <= 0.0:
		return false
	_init_controls()
	var previous_caption: String = _buttons[&"pot"].text
	var previous_header: bool = _compact_header
	var previous_sizes: Dictionary[StringName, Vector2] = {}
	var count: int = 0
	for role: StringName in UTILITY:
		previous_sizes[role] = _buttons[role].custom_minimum_size
		if _buttons[role].visible:
			count += 1
	var inline_cell: Vector2 = _utility_cell(_pot_caption(false))
	var portrait_cell: Vector2 = _utility_cell(_pot_caption(true))
	var header_size: Vector2 = _header_minimum(false)
	var compact_header_size: Vector2 = _header_minimum(true)
	var digits: GridContainer = get_node("%Digits")
	var utilities: GridContainer = get_node("%Utilities")
	var gap: float = (get_node("Portrait") as VBoxContainer).get_theme_constant("separation")
	var digit_size: Vector2 = digits.get_combined_minimum_size()
	var utility_rows: int = ceili(count / 2.0)
	var spacing := Vector2(
		utilities.get_theme_constant("h_separation"),
		utilities.get_theme_constant("v_separation") * (utility_rows - 1)
	)
	var candidates: Array[Dictionary] = []
	for stacked: bool in [false, true]:
		var cell: Vector2 = portrait_cell if stacked else inline_cell
		var utility_size: Vector2 = cell * Vector2(2, utility_rows) + spacing
		candidates.append(
			{
				"mode": &"portrait",
				"cell": cell,
				"stack_caption": stacked,
				"minimum":
				Vector2(
					maxf(header_size.x, maxf(digit_size.x, utility_size.x)),
					header_size.y + digit_size.y + utility_size.y + gap * 2.0
				)
			}
		)
	var inline_utilities: Vector2 = inline_cell * Vector2(2, utility_rows) + spacing
	candidates.append(
		{
			"mode": &"landscape",
			"cell": inline_cell,
			"stack_caption": false,
			"minimum":
			Vector2(
				maxf(compact_header_size.x, digit_size.x + inline_utilities.x + gap),
				compact_header_size.y + maxf(digit_size.y, inline_utilities.y)
			)
		}
	)
	var chosen: Dictionary = {}
	for candidate: Dictionary in candidates:
		var minimum: Vector2 = candidate.minimum
		if minimum.x > available.x or minimum.y > available.y:
			continue
		# Prefer the accepted stacked arrangement whenever it fits completely.
		if not chosen.is_empty() and candidate.mode != chosen.mode:
			continue
		if (
			chosen.is_empty()
			or minimum.y < chosen.minimum.y
			or (minimum.y == chosen.minimum.y and minimum.x < chosen.minimum.x)
		):
			chosen = candidate
	if chosen.is_empty():
		_buttons[&"pot"].text = previous_caption
		_set_header_appearance(previous_header)
		for role: StringName in UTILITY:
			_buttons[role].custom_minimum_size = previous_sizes[role]
		return false
	layout_mode_name = chosen.mode
	utility_columns = 2
	utilities.columns = utility_columns
	_buttons[&"pot"].text = _pot_caption(chosen.stack_caption)
	for role: StringName in UTILITY:
		if _buttons[role].visible:
			_buttons[role].custom_minimum_size = chosen.cell
	var portrait: VBoxContainer = get_node("Portrait")
	var landscape: VBoxContainer = get_node("LandscapeStack")
	var key_rows: HBoxContainer = get_node("LandscapeStack/KeyRows")
	var header: VBoxContainer = get_node("%Header")
	var input_row: HBoxContainer = get_node("%InputRow")
	portrait.visible = layout_mode_name == &"portrait"
	landscape.visible = not portrait.visible
	input_row.visible = landscape.visible
	_set_header_appearance(landscape.visible)
	header.add_theme_constant_override("separation", 0 if landscape.visible else int(gap))
	if portrait.visible:
		_move(header, portrait)
		_move(digits, portrait)
		_move(utilities, portrait)
		_move(get_control(&"title"), header)
		_move(get_control(&"value"), header)
		header.move_child(get_control(&"title"), 0)
		header.move_child(get_control(&"value"), 1)
		portrait.move_child(header, 0)
		portrait.move_child(digits, 1)
	else:
		_move(header, landscape)
		_move(get_control(&"title"), input_row)
		_move(get_control(&"value"), input_row)
		_move(digits, key_rows)
		_move(utilities, key_rows)
		header.move_child(input_row, 0)
		landscape.move_child(header, 0)
	custom_minimum_size = chosen.minimum
	size = chosen.minimum
	return true


static func _move(control: Control, parent: Node) -> void:
	if control.get_parent() != parent:
		control.reparent(parent, false)
