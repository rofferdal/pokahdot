class_name WagerKeypad
extends PopupPanel

const GUI_MINIMUM_FONT_SIZE: int = 20
const KEYPAD_WIDTH: float = 280.0
const KEYPAD_HEIGHT: float = 360.0
const KEY_WIDTH: float = 80.0
const TOUCH_TARGET_HEIGHT: float = 48.0

var _input: LineEdit
var _value_label: Label
var _range_label: Label
var _title: Label
var _keys: Array[Button] = []
var _done_button: Button


static func can_wager(view: GameView) -> bool:
	if view == null or view.acting_seat != view.hero_seat:
		return false
	return (
		PlayerAction.Kind.BET in view.legal_actions or PlayerAction.Kind.RAISE in view.legal_actions
	)


func _init() -> void:
	name = "WagerKeypad"
	exclusive = false
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	_title = Label.new()
	_title.name = "Title"
	_title.text = "Enter wager total"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	content.add_child(_title)
	_value_label = Label.new()
	_value_label.name = "Value"
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 28)
	content.add_child(_value_label)
	_range_label = Label.new()
	_range_label.name = "Range"
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	content.add_child(_range_label)
	var keys := GridContainer.new()
	keys.name = "Keys"
	keys.columns = 3
	keys.add_theme_constant_override("h_separation", 6)
	keys.add_theme_constant_override("v_separation", 6)
	content.add_child(keys)
	for key_text: String in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		_add_key(keys, key_text, _append_digit.bind(key_text))
	_add_key(keys, "Clear", _clear_input)
	_add_key(keys, "0", _append_digit.bind("0"))
	_add_key(keys, "Back", _erase_digit)
	_done_button = Button.new()
	_done_button.name = "Done"
	_done_button.text = "Done"
	_done_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_done_button.pressed.connect(hide)
	content.add_child(_done_button)


func open(input: LineEdit, minimum: int, maximum: int, content_scale: float = 1.0) -> void:
	_input = input
	if not _input.text.is_valid_int():
		_input.text = ""
	_value_label.text = _input.text if not _input.text.is_empty() else "—"
	_range_label.text = "Min %d  •  Max %d" % [minimum, maximum]
	var scale: float = clampf(content_scale, 1.0, 2.0)
	_apply_content_scale(scale)
	popup_centered(Vector2i(roundi(KEYPAD_WIDTH * scale), roundi(KEYPAD_HEIGHT * scale)))


func _add_key(keys: GridContainer, key_text: String, callback: Callable) -> void:
	var key := Button.new()
	key.name = "Key%s" % key_text.capitalize()
	key.text = key_text
	key.custom_minimum_size = Vector2(KEY_WIDTH, TOUCH_TARGET_HEIGHT)
	key.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	key.pressed.connect(callback)
	keys.add_child(key)
	_keys.append(key)


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


func _append_digit(digit: String) -> void:
	if _input == null or _input.text.length() >= 9:
		return
	_input.text += digit
	_refresh_value()


func _clear_input() -> void:
	if _input == null:
		return
	_input.text = ""
	_refresh_value()


func _erase_digit() -> void:
	if _input == null:
		return
	if not _input.text.is_empty():
		_input.text = _input.text.left(_input.text.length() - 1)
	_refresh_value()


func _refresh_value() -> void:
	_value_label.text = _input.text if not _input.text.is_empty() else "—"
