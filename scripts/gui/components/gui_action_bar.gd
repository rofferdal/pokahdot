class_name GuiActionBar
extends VBoxContainer

signal action_requested(intent: StringName)
signal wager_edited(text: String)
signal wager_submitted(text: String)
signal entry_requested(draft: String)
signal menu_requested

@export var compact_controls: bool = false
var layout_rows: int = 1
var _keypad: bool = false
var _can_wager: bool = false
var _status_copy: String = ""
var _hero_width: float = 0.0
var _pending: bool = false
var _status_pending: bool = false
var _buttons: Dictionary[StringName, GuiActionButton] = {}
var _units: Array[Control] = []


func _enter_tree() -> void:
	_queue_layout()
	_queue_status()


func _ready() -> void:
	_init_controls()
	for button: GuiActionButton in _buttons.values():
		button.activated.connect(_on_action)
	var field: GuiInputField = get_node("%Total")
	field.edited.connect(_on_edit)
	field.submitted.connect(func(value: String) -> void: wager_submitted.emit(value))
	field.entry_requested.connect(func(value: String) -> void: entry_requested.emit(value))
	(get_node("Body") as Control).resized.connect(_queue_layout)
	(get_node("StatusArea") as Control).resized.connect(_align_status)
	_queue_layout()


func _init_controls() -> void:
	if _buttons.is_empty():
		for key: StringName in [
			&"fold", &"check_call", &"minimum", &"pot", &"wager", &"all_in", &"continue", &"more"
		]:
			_buttons[key] = get_node("%" + str(key)) as GuiActionButton


func render(model: ActionBarViewModel) -> void:
	_init_controls()
	var enabled: bool = model != null and model.valid
	if not enabled:
		push_error("ActionBar requires a valid presentation model.")
		model = ActionBarViewModel.new()
	_can_wager = enabled and model.wager_enabled
	var visibility: Dictionary[StringName, bool] = {
		&"fold": model.phone_fold_visible if compact_controls else model.fold_visible,
		&"check_call":
		model.phone_check_call_visible if compact_controls else model.check_call_visible,
		&"minimum": model.phone_minimum_visible if compact_controls else model.minimum_visible,
		&"pot": model.phone_pot_visible if compact_controls else model.pot_visible,
		&"wager": model.phone_wager_visible if compact_controls else model.wager_visible,
		&"all_in": model.phone_all_in_visible if compact_controls else model.all_in_visible,
		&"continue": model.can_continue,
		&"more": true
	}
	var flags: Dictionary[StringName, bool] = {
		&"fold": model.fold_enabled,
		&"check_call": model.check_call_enabled,
		&"minimum": model.minimum_enabled,
		&"pot": model.pot_enabled,
		&"wager": model.wager_enabled,
		&"all_in": model.all_in_enabled,
		&"continue": model.can_continue,
		&"more": true
	}
	var labels: Dictionary[StringName, String] = {
		&"fold": "Fold",
		&"check_call": model.check_call_text,
		&"minimum": model.minimum_text,
		&"pot": model.pot_text,
		&"wager": model.wager_text,
		&"all_in": model.all_in_text,
		&"continue": "Next hand",
		&"more": "More / Pots"
	}
	for intent: StringName in _buttons:
		var button: GuiActionButton = _buttons[intent]
		var state := ActionButtonViewModel.new()
		state.label = labels[intent]
		state.intent = intent
		state.enabled = flags[intent]
		state.primary = intent == &"wager" or intent == &"continue"
		button.render(state)
		button.visible = visibility[intent]
	(get_node("%WagerUnit") as Control).visible = visibility[&"wager"]
	var field := InputFieldViewModel.new()
	field.value = get_wager_draft()
	field.placeholder = model.input_placeholder
	field.total = true
	field.enabled = _can_wager
	field.touch_entry = _keypad
	(get_node("%Total") as GuiInputField).render(field)
	(get_node("%Total") as Control).visible = not _keypad
	_status_copy = model.phone_status_text if compact_controls else model.status_text
	_queue_layout()
	_queue_status()


func _on_edit(value: String) -> void:
	wager_edited.emit(value)
	_queue_layout()


func use_keypad(enabled: bool) -> void:
	_keypad = enabled
	var field := InputFieldViewModel.new()
	field.value = get_wager_draft()
	field.placeholder = (get_node("%Total") as LineEdit).placeholder_text
	field.total = true
	field.enabled = _can_wager
	field.touch_entry = enabled
	(get_node("%Total") as GuiInputField).render(field)
	(get_node("%Total") as Control).visible = not enabled
	_queue_layout()


func render_hero(model: SeatViewModel) -> void:
	var hero: GuiHeroActionSummary = get_node("Hero")
	hero.render(model)
	hero.visible = model != null and model.valid


func set_wager_draft(text: String) -> void:
	(get_node("%Total") as LineEdit).text = text
	_queue_layout()


func get_wager_draft() -> String:
	return (get_node("%Total") as LineEdit).text


func align_with_hero(width: float) -> bool:
	if not is_finite(width) or width < 0.0:
		push_error("ActionBar hero alignment requires a finite nonnegative width.")
		return false
	if not is_equal_approx(_hero_width, width):
		_hero_width = width
		_queue_layout()
	return true


func _align_status() -> void:
	var area: Control = get_node("StatusArea")
	var frame: MarginContainer = get_node("StatusArea/Frame")
	var inset: float = maxf(0.0, (area.size.x - _hero_width) * 0.5) if _hero_width > 0.0 else 0.0
	frame.add_theme_constant_override("margin_left", floori(inset))
	frame.add_theme_constant_override("margin_right", ceili(inset))


func get_control(role: StringName) -> Control:
	_init_controls()
	if role == &"total":
		return get_node("%Total") as Control
	if role == &"status":
		return get_node("%Status") as Control
	if role == &"hero":
		return get_node("Hero") as Control
	return _buttons.get(role)


func _on_action(intent: StringName) -> void:
	if intent == &"more":
		menu_requested.emit()
	elif intent == &"wager" and _keypad:
		if _can_wager:
			entry_requested.emit(get_wager_draft())
	else:
		action_requested.emit(intent)


func _queue_layout() -> void:
	if not _pending and is_inside_tree():
		_pending = true
		call_deferred("_layout")


func _layout() -> void:
	_pending = false
	if not is_inside_tree():
		return
	_init_controls()
	_units.clear()
	for key: StringName in [
		&"fold", &"check_call", &"minimum", &"pot", &"wager", &"all_in", &"continue", &"more"
	]:
		var control: Control = get_node("%WagerUnit") if key == &"wager" else _buttons[key]
		if control.visible:
			_units.append(control)
	if _units.is_empty():
		return
	var widths: Array[float] = []
	var heights: Array[float] = []
	for control: Control in _units:
		widths.append(control.get_combined_minimum_size().x)
		heights.append(control.get_combined_minimum_size().y)
	var body: Control = get_node("Body")
	var gap: float = get_theme_constant("separation", &"ActionRows")
	var plan: GuiActionRows = GuiActionRows.resolve(widths, heights, maxf(body.size.x, 1.0), gap)
	body.custom_minimum_size = Vector2(plan.minimum_width, plan.reserved_height)
	layout_rows = plan.row_count
	var first: HBoxContainer = get_node("Body/Rows/First")
	var second: HBoxContainer = get_node("Body/Rows/Second")
	first.alignment = (
		BoxContainer.ALIGNMENT_CENTER if _hero_width > 0.0 else BoxContainer.ALIGNMENT_BEGIN
	)
	second.alignment = first.alignment
	second.visible = layout_rows == 2
	for index: int in _units.size():
		var target: HBoxContainer = first if index < plan.split else second
		if _units[index].get_parent() != target:
			_units[index].reparent(target, false)
		target.move_child(_units[index], index if index < plan.split else index - plan.split)
	_measure_status(plan.minimum_width)
	_align_status()


func _measure_status(width: float) -> void:
	var status: Label = get_node("%Status")
	var paragraph := TextParagraph.new()
	paragraph.width = minf(width, _hero_width) if _hero_width > 0.0 else width
	paragraph.break_flags = (
		TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	)
	paragraph.add_string(_status_copy, status.get_theme_font("font"), 20)
	var spacing: float = status.get_theme_constant("line_spacing")
	var reserved_lines: int = 1 if compact_controls else 2
	status.custom_minimum_size.y = maxf(
		paragraph.get_size().y + maxi(0, paragraph.get_line_count() - 1) * spacing,
		(
			ceilf(status.get_theme_font("font").get_height(20)) * reserved_lines
			+ (reserved_lines - 1) * spacing
		)
	)

	(get_node("StatusArea") as Control).custom_minimum_size.y = status.custom_minimum_size.y


func _queue_status() -> void:
	if not _status_pending and is_inside_tree():
		_status_pending = true
		call_deferred("_apply_status")


func _apply_status() -> void:
	if not is_inside_tree():
		_status_pending = false
		return
	# Bound frame callbacks disconnect automatically if this node is freed.
	if not get_tree().process_frame.is_connected(_finish_status_copy):
		get_tree().process_frame.connect(_finish_status_copy, CONNECT_ONE_SHOT)


func _finish_status_copy() -> void:
	_status_pending = false
	if is_inside_tree():
		(get_node("%Status") as Label).text = _status_copy
