class_name WagerKeypad
extends PopupPanel

signal confirmed

const GUI_MINIMUM_FONT_SIZE: int = 20
const KEYPAD_WIDTH: float = 280.0
const KEYPAD_HEIGHT: float = 360.0
const KEY_WIDTH: float = 80.0
const TOUCH_TARGET_HEIGHT: float = 48.0
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")
const PopupPlacement := preload("res://scripts/gui/platform/gui_popup_placement.gd")

var _target_input: LineEdit
var _content: VBoxContainer
var _value_label: Label
var _range_label: Label
var _title: Label
var _keys_grid: GridContainer
var _body: BoxContainer
var _actions: VBoxContainer
var _utilities_grid: GridContainer
var _keys: Array[Button] = []
var _key_controls: Dictionary[String, Button] = {}
var _minimum_button: Button
var _pot_button: Button
var _done_button: Button
var _cancel_button: Button
var _layout_generation: int = 0
var _requested_popup_size := Vector2i.ZERO
var _requested_usable_size := Vector2i.ZERO
var _geometry_usable_rect := Rect2()
var _requested_usable_rect := Rect2()
var _last_content_scale: float = 1.0
var _draft_value: String = ""
var _transactional: bool = false
var _bottom_sheet: bool = false
var _maximum_value: int = 999_999_999


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
	_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_range_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_content.add_child(_range_label)
	_body = BoxContainer.new()
	_body.name = "Body"
	_body.vertical = true
	_body.add_theme_constant_override("separation", 6)
	_content.add_child(_body)
	_keys_grid = GridContainer.new()
	_keys_grid.name = "Keys"
	_keys_grid.columns = 3
	_keys_grid.add_theme_constant_override("h_separation", 6)
	_keys_grid.add_theme_constant_override("v_separation", 6)
	_keys_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_keys_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_body.add_child(_keys_grid)
	for key_text: String in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		_add_key(_keys_grid, key_text, _append_digit.bind(key_text))
	var zero_spacer := Control.new()
	zero_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_grid.add_child(zero_spacer)
	_add_key(_keys_grid, "0", _append_digit.bind("0"))
	zero_spacer = Control.new()
	zero_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_grid.add_child(zero_spacer)
	_actions = VBoxContainer.new()
	_actions.name = "Actions"
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_actions)
	_utilities_grid = GridContainer.new()
	_utilities_grid.name = "Utilities"
	_utilities_grid.columns = 2
	_utilities_grid.add_theme_constant_override("h_separation", 6)
	_actions.add_child(_utilities_grid)
	_add_key(_utilities_grid, "Clear", _clear_input)
	_add_key(_utilities_grid, "Back", _erase_digit)
	_minimum_button = _add_key(_utilities_grid, "Min", _replace_with_minimum)
	_pot_button = _add_key(_utilities_grid, "Pot", _replace_with_pot)
	_done_button = Button.new()
	_done_button.name = "Done"
	_done_button.text = "Done"
	_done_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_done_button.pressed.connect(_confirm)
	_done_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button = Button.new()
	_cancel_button.name = "Cancel"
	_cancel_button.text = "Cancel"
	_cancel_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_cancel_button.pressed.connect(_cancel)
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_utilities_grid.add_child(_cancel_button)
	_utilities_grid.add_child(_done_button)
	_key_controls["done"] = _done_button
	_key_controls["cancel"] = _cancel_button
	for action: String in ["clear", "back", "min", "pot", "cancel", "done"]:
		_key_controls[action].size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_target_input = input
	# Keypad edits are drafts on every profile. Layout mode must not decide
	# whether Cancel can restore the committed LineEdit value.
	_transactional = true
	_bottom_sheet = bottom_sheet
	_maximum_value = maximum
	_draft_value = _target_input.text if _target_input.text.is_valid_int() else ""
	_title.text = "Enter wager total"
	_value_label.text = _draft_value if not _draft_value.is_empty() else "—"
	_range_label.text = "Min %d  •  Max %d" % [minimum, maximum]
	_range_label.show()
	_minimum_button.show()
	_minimum_button.text = "Min %d" % minimum
	_minimum_button.set_meta("wager_value", minimum)
	_pot_button.show()
	_pot_button.text = "Pot %d" % maxi(0, pot_contribution)
	_pot_button.set_meta("wager_value", pot_wager_total)
	_pot_button.disabled = pot_wager_total < minimum or pot_wager_total > maximum
	var scale: float = clampf(content_scale, 1.0, 2.0)
	_refresh_popup_layout(scale, usable_size)


func open_number(input: LineEdit, content_scale: float = 1.0, maximum: int = 999_999_999) -> void:
	_target_input = input
	_transactional = true
	_bottom_sheet = false
	_maximum_value = maximum
	_draft_value = _target_input.text if _target_input.text.is_valid_int() else ""
	_title.text = "Enter number"
	_value_label.text = _draft_value if not _draft_value.is_empty() else "—"
	_range_label.hide()
	_minimum_button.hide()
	_pot_button.hide()
	var scale: float = clampf(content_scale, 1.0, 2.0)
	_refresh_popup_layout(scale)


func get_cancel_control() -> Button:
	return _cancel_button


func get_action_control(action: StringName) -> Button:
	return _key_controls.get(String(action))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls: Array[Button] = []
		for button: Button in _keys + [_done_button, _cancel_button]:
			if button.is_visible_in_tree() and not button.disabled:
				controls.append(button)
		var index: int = controls.find(get_viewport().gui_get_focus_owner())
		var direction: int = -1 if event.is_action_pressed("ui_focus_prev") else 1
		controls[posmod(index + direction, controls.size())].grab_focus()
		get_viewport().set_input_as_handled()


func refresh_layout(content_scale: float = 1.0, usable_size: Vector2i = Vector2i.ZERO) -> void:
	if not visible:
		return
	var scale: float = clampf(content_scale, 1.0, 2.0)
	_refresh_popup_layout(scale, usable_size)


func set_usable_rect(usable: Rect2) -> void:
	if _geometry_usable_rect == usable:
		return
	_geometry_usable_rect = usable
	if visible:
		_refresh_popup_layout(_last_content_scale)


func cancel() -> void:
	_cancel()


func is_bottom_sheet() -> bool:
	return _bottom_sheet


func _refresh_popup_layout(scale: float, usable_size: Vector2i = Vector2i.ZERO) -> void:
	_layout_generation += 1
	_last_content_scale = scale
	_apply_content_scale(scale)
	var viewport_size: Vector2i = (
		usable_size if usable_size != Vector2i.ZERO else _owner_viewport_size()
	)
	_requested_usable_rect = Rect2(Vector2.ZERO, Vector2(viewport_size))
	if _geometry_usable_rect.size.x > 0.0 and _geometry_usable_rect.size.y > 0.0:
		_requested_usable_rect = _geometry_usable_rect
		viewport_size = Vector2i(_geometry_usable_rect.size.floor())
	_requested_usable_size = viewport_size
	var sheet_height: float = KEYPAD_HEIGHT + TOUCH_TARGET_HEIGHT + 6.0
	var compact_height: bool = viewport_size.y <= roundi(sheet_height * scale)
	var popup_style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	popup_style.content_margin_top = 2.0 if compact_height else 5.0
	popup_style.content_margin_bottom = 2.0 if compact_height else 5.0
	add_theme_stylebox_override("panel", popup_style)
	if compact_height:
		_value_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	_title.visible = not compact_height
	_content.add_theme_constant_override("separation", 0 if compact_height else 6)
	_keys_grid.add_theme_constant_override("v_separation", 0 if compact_height else 6)
	_utilities_grid.add_theme_constant_override("v_separation", 0 if compact_height else 6)
	_actions.add_theme_constant_override("separation", 0 if compact_height else 6)
	var horizontal_minimum: float = (
		_keys_grid.get_combined_minimum_size().x
		+ _actions.get_combined_minimum_size().x
		+ _body.get_theme_constant("separation")
		+ popup_style.get_minimum_size().x
	)
	_body.vertical = not (
		viewport_size.x > viewport_size.y
		and compact_height
		and viewport_size.x >= horizontal_minimum
	)
	var requested_size := Vector2i(roundi(KEYPAD_WIDTH * scale), roundi(sheet_height * scale))
	if _bottom_sheet:
		requested_size.x = viewport_size.x
	requested_size.x = mini(requested_size.x, viewport_size.x)
	requested_size.y = mini(requested_size.y, viewport_size.y)
	_requested_popup_size = requested_size
	min_size = Vector2i(requested_size.x, 0) if _bottom_sheet else Vector2i.ZERO
	popup_centered(requested_size)
	_place_popup()
	call_deferred("_recenter_if_current", _layout_generation)


func _recenter_if_current(generation: int) -> void:
	if generation != _layout_generation or not visible:
		return
	_place_popup()
	call_deferred("_recenter_after_container_if_current", generation)


func _recenter_after_container_if_current(generation: int) -> void:
	if generation != _layout_generation or not visible:
		return
	_place_popup()


func _place_popup() -> void:
	PopupPlacement.apply(
		self, get_parent(), _requested_usable_rect, _requested_popup_size, _bottom_sheet
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
	_key_controls[key_text.to_lower()] = key
	return key


func _apply_content_scale(content_scale: float) -> void:
	var scale: float = clampf(content_scale, 1.0, 2.0)
	_title.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	_value_label.add_theme_font_size_override("font_size", 28 * scale)
	_range_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	for key: Button in _keys:
		key.custom_minimum_size = Vector2(KEY_WIDTH * scale, TOUCH_TARGET_HEIGHT * scale)
		key.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	_done_button.custom_minimum_size = Vector2(KEY_WIDTH * scale, TOUCH_TARGET_HEIGHT * scale)
	_done_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	_cancel_button.custom_minimum_size = Vector2(KEY_WIDTH * scale, TOUCH_TARGET_HEIGHT * scale)
	_cancel_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	var cell_width: float = KEY_WIDTH * scale
	for action: String in ["clear", "back", "min", "pot", "cancel", "done"]:
		var button: Button = _key_controls[action]
		if button.visible:
			cell_width = maxf(cell_width, button.get_combined_minimum_size().x)
	for action: String in ["clear", "back", "min", "pot", "cancel", "done"]:
		_key_controls[action].custom_minimum_size.x = cell_width


func _append_digit(digit: String) -> void:
	if _target_input == null or _current_value().length() >= 9:
		return
	var candidate: String = _current_value() + digit
	if candidate.to_int() > _maximum_value:
		return
	_set_current_value(candidate)
	_refresh_value()


func _clear_input() -> void:
	if _target_input == null:
		return
	_set_current_value("")
	_refresh_value()


func _erase_digit() -> void:
	if _target_input == null:
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
	if _transactional and _target_input != null:
		_target_input.text = _draft_value
	hide()
	confirmed.emit()


func _cancel() -> void:
	hide()


func _current_value() -> String:
	if _transactional:
		return _draft_value
	return _target_input.text if _target_input != null else ""


func _set_current_value(value: String) -> void:
	if _transactional:
		_draft_value = value
	elif _target_input != null:
		_target_input.text = value
