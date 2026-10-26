class_name WagerKeypad
extends PopupPanel

signal confirmed

const GUI_MINIMUM_FONT_SIZE: int = 20
const KEYPAD_WIDTH: float = 280.0
const KEYPAD_HEIGHT: float = 360.0
const KEY_WIDTH: float = 80.0
const TOUCH_TARGET_HEIGHT: float = 48.0
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")

var _input: LineEdit
var _content: VBoxContainer
var _value_label: Label
var _range_label: Label
var _title: Label
var _keys_grid: GridContainer
var _keys: Array[Button] = []
var _minimum_button: Button
var _pot_button: Button
var _done_button: Button
var _cancel_button: Button
var _layout_generation: int = 0
var _requested_popup_size := Vector2i.ZERO
var _requested_usable_size := Vector2i.ZERO
var _draft_value: String = ""
var _transactional: bool = false
var _bottom_sheet: bool = false


static func can_wager(view: GameView) -> bool:
	if view == null or view.acting_seat != view.hero_seat:
		return false
	return (
		PlayerAction.Kind.BET in view.legal_actions or PlayerAction.Kind.RAISE in view.legal_actions
	)


func _init() -> void:
	name = "WagerKeypad"
	exclusive = false
	transparent_bg = false
	add_theme_stylebox_override(
		"panel", GuiTableStyleScript.box(Color("07150ff7"), Color("d9b56d"), 2, 10)
	)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)
	_title = Label.new()
	_title.name = "Title"
	_title.text = "Enter wager total"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_content.add_child(_title)
	_value_label = Label.new()
	_value_label.name = "Value"
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 28)
	_content.add_child(_value_label)
	_range_label = Label.new()
	_range_label.name = "Range"
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_content.add_child(_range_label)
	_keys_grid = GridContainer.new()
	_keys_grid.name = "Keys"
	_keys_grid.columns = 3
	_keys_grid.add_theme_constant_override("h_separation", 6)
	_keys_grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(_keys_grid)
	for key_text: String in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		_add_key(_keys_grid, key_text, _append_digit.bind(key_text))
	_add_key(_keys_grid, "Clear", _clear_input)
	_add_key(_keys_grid, "0", _append_digit.bind("0"))
	_add_key(_keys_grid, "Back", _erase_digit)
	_minimum_button = _add_key(_keys_grid, "Min", _replace_with_minimum)
	_pot_button = _add_key(_keys_grid, "Pot", _replace_with_pot)
	_done_button = Button.new()
	_done_button.name = "Done"
	_done_button.text = "Done"
	_done_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_done_button.pressed.connect(_confirm)
	_content.add_child(_done_button)
	_cancel_button = Button.new()
	_cancel_button.name = "Cancel"
	_cancel_button.text = "Cancel"
	_cancel_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_cancel_button.pressed.connect(_cancel)
	_content.add_child(_cancel_button)
	_apply_keypad_styles()


func _apply_keypad_styles() -> void:
	_value_label.add_theme_color_override("font_color", Color("ffffff"))
	_range_label.add_theme_color_override("font_color", Color("d9b56d"))
	for key: Button in _keys:
		key.add_theme_stylebox_override(
			"normal", GuiTableStyleScript.action_control_box(Color("172331"), Color("75c99a"), 2)
		)
		key.add_theme_stylebox_override(
			"hover", GuiTableStyleScript.action_control_box(Color("24513c"), Color("f5f0dc"), 2)
		)
		key.add_theme_stylebox_override(
			"pressed", GuiTableStyleScript.action_control_box(Color("0b1d15"), Color("d9b56d"), 2)
		)
	for button: Button in [_done_button, _cancel_button]:
		button.add_theme_stylebox_override(
			"normal", GuiTableStyleScript.action_control_box(Color("164c35"), Color("e7d39b"), 2)
		)
		button.add_theme_stylebox_override(
			"pressed", GuiTableStyleScript.action_control_box(Color("0b1d15"), Color("ffffff"), 2)
		)


func open(
	input: LineEdit,
	minimum: int,
	maximum: int,
	content_scale: float = 1.0,
	bottom_sheet: bool = false,
	pot_contribution: int = -1,
	pot_wager_total: int = -1,
	usable_size: Vector2i = Vector2i.ZERO,
) -> void:
	_input = input
	if not _input.text.is_valid_int():
		_input.text = ""
	# Keypad edits are drafts on every profile. Layout mode must not decide
	# whether Cancel can restore the committed LineEdit value.
	_transactional = true
	_bottom_sheet = bottom_sheet
	_draft_value = _input.text
	_title.text = "Enter wager total"
	_value_label.text = _input.text if not _input.text.is_empty() else "—"
	_range_label.text = "Min %d  •  Max %d" % [minimum, maximum]
	_range_label.show()
	_minimum_button.visible = bottom_sheet
	_minimum_button.text = "Min %d" % minimum
	_minimum_button.set_meta("wager_value", minimum)
	_pot_button.visible = bottom_sheet
	_pot_button.text = "Pot %d" % maxi(0, pot_contribution)
	_pot_button.set_meta("wager_value", pot_wager_total)
	_pot_button.disabled = pot_wager_total < minimum or pot_wager_total > maximum
	var scale: float = clampf(content_scale, 1.0, 2.0)
	_refresh_popup_layout(scale, usable_size)


func open_number(input: LineEdit, content_scale: float = 1.0) -> void:
	_input = input
	if not _input.text.is_valid_int():
		_input.text = ""
	_transactional = true
	_bottom_sheet = false
	_draft_value = _input.text
	_title.text = "Enter number"
	_value_label.text = _input.text if not _input.text.is_empty() else "—"
	_range_label.hide()
	_minimum_button.hide()
	_pot_button.hide()
	var scale: float = clampf(content_scale, 1.0, 2.0)
	_refresh_popup_layout(scale)


func refresh_layout(content_scale: float = 1.0, usable_size: Vector2i = Vector2i.ZERO) -> void:
	if not visible:
		return
	var scale: float = clampf(content_scale, 1.0, 2.0)
	_refresh_popup_layout(scale, usable_size)


func cancel() -> void:
	_cancel()


func is_bottom_sheet() -> bool:
	return _bottom_sheet


func _refresh_popup_layout(scale: float, usable_size: Vector2i = Vector2i.ZERO) -> void:
	_layout_generation += 1
	_apply_content_scale(scale)
	var viewport_size: Vector2i = (
		usable_size if usable_size != Vector2i.ZERO else _owner_viewport_size()
	)
	_requested_usable_size = viewport_size
	var sheet_height: float = KEYPAD_HEIGHT + TOUCH_TARGET_HEIGHT + 6.0
	var compact_height: bool = viewport_size.y <= roundi(sheet_height * scale)
	_title.visible = not compact_height
	_content.add_theme_constant_override("separation", 0 if compact_height else 6)
	_keys_grid.columns = 5 if compact_height else 3
	_keys_grid.add_theme_constant_override("v_separation", 0 if compact_height else 6)
	var requested_size := Vector2i(roundi(KEYPAD_WIDTH * scale), roundi(sheet_height * scale))
	if _bottom_sheet:
		requested_size.x = viewport_size.x
	requested_size.x = mini(requested_size.x, viewport_size.x)
	requested_size.y = mini(requested_size.y, viewport_size.y)
	_requested_popup_size = requested_size
	min_size = Vector2i(requested_size.x, 0) if _bottom_sheet else Vector2i.ZERO
	popup_centered(requested_size)
	call_deferred("_recenter_if_current", _layout_generation)


func _recenter_if_current(generation: int) -> void:
	if generation != _layout_generation or not visible:
		return
	size = _requested_popup_size
	call_deferred("_recenter_after_container_if_current", generation)


func _recenter_after_container_if_current(generation: int) -> void:
	if generation != _layout_generation or not visible:
		return
	var viewport_size: Vector2i = _requested_usable_size
	size = _requested_popup_size
	position = Vector2i(
		maxi(0, (viewport_size.x - size.x) / 2),
		(
			maxi(0, viewport_size.y - size.y)
			if _bottom_sheet
			else maxi(0, (viewport_size.y - size.y) / 2)
		),
	)


func _owner_viewport_size() -> Vector2i:
	var owner := get_parent()
	return Vector2i(owner.get_viewport().get_visible_rect().size)


func _add_key(keys: GridContainer, key_text: String, callback: Callable) -> Button:
	var key := Button.new()
	key.name = "Key%s" % key_text.capitalize()
	key.text = key_text
	key.custom_minimum_size = Vector2(KEY_WIDTH, TOUCH_TARGET_HEIGHT)
	key.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	key.pressed.connect(callback)
	keys.add_child(key)
	_keys.append(key)
	return key


func _apply_content_scale(content_scale: float) -> void:
	var scale: float = clampf(content_scale, 1.0, 2.0)
	_title.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	_value_label.add_theme_font_size_override("font_size", 28 * scale)
	_range_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	for key: Button in _keys:
		key.custom_minimum_size = Vector2(KEY_WIDTH * scale, TOUCH_TARGET_HEIGHT * scale)
		key.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	_done_button.custom_minimum_size = Vector2(0.0, TOUCH_TARGET_HEIGHT * scale)
	_done_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	_cancel_button.custom_minimum_size = Vector2(0.0, TOUCH_TARGET_HEIGHT * scale)
	_cancel_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)


func _append_digit(digit: String) -> void:
	if _input == null or _current_value().length() >= 9:
		return
	_set_current_value(_current_value() + digit)
	_refresh_value()


func _clear_input() -> void:
	if _input == null:
		return
	_set_current_value("")
	_refresh_value()


func _erase_digit() -> void:
	if _input == null:
		return
	var current: String = _current_value()
	if not current.is_empty():
		_set_current_value(current.left(current.length() - 1))
	_refresh_value()


func _replace_with_minimum() -> void:
	_set_current_value(str(_minimum_button.get_meta("wager_value")))
	_refresh_value()


func _replace_with_pot() -> void:
	_set_current_value(str(_pot_button.get_meta("wager_value")))
	_refresh_value()


func _refresh_value() -> void:
	var current: String = _current_value()
	_value_label.text = current if not current.is_empty() else "—"


func _confirm() -> void:
	if _transactional and _input != null:
		_input.text = _draft_value
	hide()
	confirmed.emit()


func _cancel() -> void:
	hide()


func _current_value() -> String:
	if _transactional:
		return _draft_value
	return _input.text if _input != null else ""


func _set_current_value(value: String) -> void:
	if _transactional:
		_draft_value = value
	elif _input != null:
		_input.text = value
