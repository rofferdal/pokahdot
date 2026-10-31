class_name GuiActionBar
extends VBoxContainer

signal action_requested(intent: StringName)
signal wager_edited(text: String)
signal wager_submitted(text: String)
signal entry_requested(draft: String)
signal menu_requested
signal layout_resolved

@export var compact_controls: bool = false
@export var show_status: bool = true
@export var compact_status: bool = false
var layout_rows: int = 1
var _keypad: bool = false
var _can_wager: bool = false
var _status_copy: String = ""
var _hero_width: float = 0.0
var _available_width: float = 0.0
var _inline_budget := Vector2.ZERO
var _full_minimum_visible: bool = false
var _full_pot_visible: bool = false
var _pending: bool = false
var _status_pending: bool = false
var _buttons: Dictionary[StringName, GuiActionButton] = {}
var _units: Array[Control] = []


func _enter_tree() -> void:
	_queue_layout()
	_queue_status()


func _ready() -> void:
	(get_node("StatusArea") as Control).visible = show_status
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
	_full_minimum_visible = model.minimum_visible
	_full_pot_visible = model.pot_visible
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
		&"more": "…" if compact_controls else "More / Pots"
	}
	for intent: StringName in _buttons:
		var button: GuiActionButton = _buttons[intent]
		var state := ActionButtonViewModel.new()
		state.label = labels[intent]
		state.intent = intent
		state.enabled = flags[intent]
		state.primary = intent == &"wager" or intent == &"continue"
		button.render(state)
		if intent == &"more":
			button.accessibility_name = "More / Pots"
			button.tooltip_text = "More / Pots"
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
	_status_copy = (
		model.phone_status_text if compact_controls or compact_status else model.status_text
	)
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


func set_available_width(width: float) -> void:
	if is_finite(width) and width > 0.0 and _available_width != width:
		_available_width = width
		_queue_layout()


func set_inline_budget(available: Vector2) -> void:
	if (
		available.is_finite()
		and available.x > 0
		and available.y >= 0
		and _inline_budget != available
	):
		_inline_budget = available
		_queue_layout()


func _fit_inline_shortcuts() -> void:
	if not compact_controls or _inline_budget.x <= 0:
		return
	var widths: Array[float] = []
	var heights: Array[float] = []
	for key: StringName in [
		&"fold", &"check_call", &"minimum", &"pot", &"wager", &"all_in", &"continue", &"more"
	]:
		var control: Control = get_node("%WagerUnit") if key == &"wager" else _buttons[key]
		if control.visible or key in [&"minimum", &"pot"]:
			widths.append(control.get_combined_minimum_size().x)
			heights.append(control.get_combined_minimum_size().y)
	var gap: float = get_theme_constant("separation", &"ActionRows")
	var plan: GuiActionRows = GuiActionRows.resolve(widths, heights, _inline_budget.x, gap)
	var needed: float = heights.max() if plan.row_count == 1 else plan.reserved_height
	needed += (
		get_node("StatusArea").get_combined_minimum_size().y + get_theme_constant("separation")
	)
	var fits: bool = plan.valid and needed <= _inline_budget.y
	_buttons[&"minimum"].visible = fits and _full_minimum_visible
	_buttons[&"pot"].visible = fits and _full_pot_visible


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
		call_deferred("_next_layout")


func _next_layout() -> void:
	if is_inside_tree() and not get_tree().process_frame.is_connected(_layout):
		get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)


func is_layout_pending() -> bool:
	return _pending or _status_pending


func _layout() -> void:
	_pending = false
	if not is_inside_tree():
		return
	_init_controls()
	_fit_inline_shortcuts()
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
	var plan: GuiActionRows = GuiActionRows.resolve(
		widths, heights, maxf(_available_width if _available_width > 0 else body.size.x, 1.0), gap
	)
	var single: bool = compact_controls and plan.row_count == 1
	var required_width: float = plan.minimum_width
	if single:
		required_width = gap * (widths.size() - 1)
		for width: float in widths:
			required_width += width
	body.custom_minimum_size = Vector2(
		required_width, heights.max() if single else plan.reserved_height
	)
	layout_rows = plan.row_count
	var rows := get_node("Body/Rows") as GuiActionUnitsContainer
	rows.configure(_units, plan.split, gap, _hero_width > 0.0)
	_measure_status(plan.minimum_width)
	_align_status()
	layout_resolved.emit()


func _measure_status(width: float) -> void:
	var status: Label = get_node("%Status")
	var paragraph := TextParagraph.new()
	# Status occupies the hero-aligned column, independently of visible buttons.
	# A bot turn can leave only More; measuring at that button's width adds
	# artificial wrapped lines and can reject an otherwise fitting phone table.
	var status_width: float = _available_width if _available_width > 0.0 else width
	paragraph.width = minf(status_width, _hero_width) if _hero_width > 0.0 else status_width
	paragraph.break_flags = (
		TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	)
	paragraph.add_string(_status_copy, status.get_theme_font("font"), 20)
	var spacing: float = status.get_theme_constant("line_spacing")
	var reserved_lines: int = 1 if compact_controls or compact_status else 2
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
