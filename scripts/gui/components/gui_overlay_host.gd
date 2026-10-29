class_name GuiOverlayHost
extends Control

## Persistent in-canvas modal ownership outside replaceable table layouts.
signal number_committed(value: String)
signal number_cancelled
signal quit_confirmed

var _kind: StringName = &""
var _requested_kind: StringName = &""
var _presented_kind: StringName = &""
var _area_pending: bool = false
var _usable := Rect2()
var _fallback: Control
var _configured: bool = false
var _switching: bool = false
var _closing: bool = false
var _summary_available: bool = false
var _quit_confirmation_required: bool = true
var _panels: Dictionary[StringName, Control] = {}
var _controls: Dictionary[StringName, GuiActionButton] = {}


func _ready() -> void:
	_init_controls()
	(get_node("Guard") as GuiModalGuard).configure(self, self, get_node("Backdrop"))
	_configured = true
	(get_node("Backdrop") as Control).gui_input.connect(_on_backdrop_input)
	for button: GuiActionButton in _controls.values():
		button.activated.connect(_on_action)
	get_keypad().committed.connect(_on_number_committed)
	get_keypad().cancelled.connect(_on_number_cancelled)
	resized.connect(_reflow)
	_reflow()
	hide()


func _init_controls() -> void:
	if not _panels.is_empty():
		return
	for kind: StringName in [&"menu", &"summary", &"seat", &"log", &"quit", &"number", &"guidance"]:
		_panels[kind] = get_node("Area/Center/" + str(kind)) as Control
	var labels: Dictionary[StringName, String] = {
		&"menu_log": "Log",
		&"menu_summary": "Pots / Summary",
		&"menu_quit": "Quit",
		&"menu_close": "Close",
		&"summary_close": "Close",
		&"seat_close": "Close",
		&"log_close": "Close",
		&"quit_keep": "Keep playing",
		&"quit_confirm": "Quit",
		&"guide_close": "Cancel"
	}
	for role: StringName in labels:
		var button := get_node("%" + str(role)) as GuiActionButton
		_controls[role] = button
		var model := ActionButtonViewModel.new()
		model.label = labels[role]
		model.intent = role
		model.enabled = role != &"menu_summary" or _summary_available
		button.render(model)


func set_usable_rect(rect: Rect2) -> void:
	if (
		not rect.position.is_finite()
		or not rect.size.is_finite()
		or rect.size.x <= 0.0
		or rect.size.y <= 0.0
	):
		push_error("OverlayHost requires a positive finite usable rectangle.")
		return
	_usable = rect
	_reflow()


func set_fallback_focus(control: Control) -> void:
	_fallback = control


func render_log(model: EventLogViewModel) -> void:
	get_log().render(model)


func render_summary(model: HandSummaryViewModel) -> void:
	_summary_available = model != null and model.visible
	var body: RichTextLabel = get_control(&"summary_body") as RichTextLabel
	body.clear()
	if model != null:
		if model.lines.is_empty():
			body.add_text(model.text)
		else:
			for index: int in model.lines.size():
				var line: HandSummaryLineViewModel = model.lines[index]
				if line.winner_emphasis:
					body.push_bold()
					body.push_color(Color.YELLOW)
				body.add_text(line.text)
				if line.winner_emphasis:
					body.pop()
					body.pop()
				if index < model.lines.size() - 1:
					body.add_text("\n")
	_init_controls()
	_controls[&"menu_summary"].disabled = not _summary_available


func set_quit_confirmation_required(required: bool) -> void:
	_quit_confirmation_required = required


func open_menu() -> void:
	_activate(&"menu")


func open_summary(model: HandSummaryViewModel) -> void:
	render_summary(model)
	_activate(&"summary")


func open_log() -> void:
	_activate(&"log")


func open_seat(model: SeatViewModel) -> void:
	if model == null or not model.valid or model.cards == null:
		push_error("OverlayHost seat details require a valid safe seat model.")
		return
	var lines: Array[String] = [model.display_name, model.stack_text, model.wager_text]
	if not model.markers.is_empty():
		lines.append(model.markers)
	if not model.state_text.is_empty():
		lines.append(model.state_text)
	if not model.status_text.is_empty():
		lines.append(model.status_text)
	(get_control(&"seat_body") as RichTextLabel).text = "\n".join(lines)
	(get_control(&"seat_cards") as GuiHoleCards).render(model.cards)
	_activate(&"seat")


func open_quit() -> void:
	_activate(&"quit")


func open_number(model: NumberEntryViewModel) -> void:
	if get_keypad().is_active():
		_switching = true
		get_keypad().cancel()
		_switching = false
	get_keypad().render(model)
	if get_keypad().is_active():
		_activate(&"number")


func close() -> void:
	if _closing:
		return
	_closing = true
	if get_keypad().is_active():
		get_keypad().cancel()
	if _configured:
		(get_node("Guard") as GuiModalGuard).finish()
	_kind = &""
	_requested_kind = &""
	_presented_kind = &""
	for panel: Control in _panels.values():
		panel.hide()
	hide()
	_closing = false


func is_active() -> bool:
	return _configured and (get_node("Guard") as GuiModalGuard).is_active()


func get_active_kind() -> StringName:
	return _kind


func hold_advance(callback: Callable) -> bool:
	return (get_node("Guard") as GuiModalGuard).hold_advance(callback) if _configured else false


func cancel_advance() -> void:
	if _configured:
		(get_node("Guard") as GuiModalGuard).cancel_advance()


func on_layout_mode_changed() -> void:
	if get_keypad().is_active():
		get_keypad().cancel()
		call_deferred("_restore_mode_fallback")
	else:
		_reflow()


func _restore_mode_fallback() -> void:
	if not is_inside_tree():
		return
	# Bound frame callbacks disconnect automatically if this node is freed.
	if not get_tree().process_frame.is_connected(_finish_mode_fallback):
		get_tree().process_frame.connect(_finish_mode_fallback, CONNECT_ONE_SHOT)


func _finish_mode_fallback() -> void:
	if is_inside_tree() and not is_active() and is_instance_valid(_fallback):
		if (
			_fallback.is_inside_tree()
			and _fallback.is_visible_in_tree()
			and _fallback.focus_mode != Control.FOCUS_NONE
		):
			_fallback.grab_focus()


func get_keypad() -> GuiNumericKeypad:
	return get_node("Area/Center/number/Content/Keypad") as GuiNumericKeypad


func get_log() -> GuiEventLog:
	return get_node("Area/Center/log/Content/Log") as GuiEventLog


func get_control(role: StringName) -> Control:
	if role == &"active":
		return _panels.get(_kind)
	if role == &"summary_body":
		return get_node("Area/Center/summary/Content/Body") as Control
	if role == &"seat_body":
		return get_node("Area/Center/seat/Content/Body") as Control
	if role == &"seat_cards":
		return get_node("Area/Center/seat/Content/Cards") as Control
	_init_controls()
	return _controls.get(role)


func _activate(kind: StringName) -> void:
	if not is_inside_tree() or not _configured:
		push_error("OverlayHost must be mounted before opening a modal.")
		return
	_init_controls()
	if kind != &"number" and get_keypad().is_active():
		_switching = true
		get_keypad().cancel()
		_switching = false
	_kind = kind
	_requested_kind = kind
	show()
	_reflow()
	_show_active()


func _show_active() -> void:
	for kind: StringName in _panels:
		_panels[kind].visible = kind == _kind
	var focus: Control
	match _kind:
		&"number":
			focus = get_keypad().get_control(&"done")
		&"guidance":
			focus = _controls[&"guide_close"]
		&"menu":
			focus = _controls[&"menu_log"]
		_:
			focus = _controls[{
				&"summary": &"summary_close",
				&"seat": &"seat_close",
				&"log": &"log_close",
				&"quit": &"quit_keep"
			}[_kind]]
	if is_active() and _presented_kind == _kind:
		var owner: Control = get_viewport().gui_get_focus_owner()
		if owner != null and _panels[_kind].is_ancestor_of(owner):
			focus = owner
	(get_node("Guard") as GuiModalGuard).begin(_panels[_kind], _cancel_active, focus, _fallback)
	_presented_kind = _kind
	(get_node("Area/Center") as CenterContainer).queue_sort()


func _reflow() -> void:
	var rect: Rect2 = (
		_usable if _usable.size.x > 0.0 and _usable.size.y > 0.0 else Rect2(Vector2.ZERO, size)
	)
	var area: MarginContainer = get_node("Area")
	var margins := Vector2(
		area.get_theme_constant("margin_left") + area.get_theme_constant("margin_right"),
		area.get_theme_constant("margin_top") + area.get_theme_constant("margin_bottom")
	)
	if _requested_kind == &"number" and get_keypad().is_active():
		var frame: Control = get_node("Area/Center/number")
		var padding: Vector2 = frame.get_theme_stylebox("panel").get_minimum_size()
		_kind = (
			&"number"
			if get_keypad().fit_available((rect.size - margins - padding).max(Vector2.ZERO))
			else &"guidance"
		)
	elif not _requested_kind.is_empty():
		var minimum: Vector2 = _panels[_requested_kind].get_combined_minimum_size()
		_kind = (
			_requested_kind
			if (rect.size - margins).x >= minimum.x and (rect.size - margins).y >= minimum.y
			else &"guidance"
		)
	if is_active():
		_show_active()
	area.position = rect.position
	area.size = rect.size
	if not _area_pending and is_inside_tree():
		_area_pending = true
		call_deferred("_settle_area")


func _settle_area() -> void:
	if not is_inside_tree():
		_area_pending = false
		return
	# Bound frame callbacks disconnect automatically if this node is freed.
	if not get_tree().process_frame.is_connected(_finish_area):
		get_tree().process_frame.connect(_finish_area, CONNECT_ONE_SHOT)


func _finish_area() -> void:
	_area_pending = false
	if is_inside_tree():
		# Native min invalidation follows the child mode/visibility update.
		# Reapply the same adapter rectangle after that pass; never add its origin.
		var rect: Rect2 = (
			_usable if _usable.size.x > 0.0 and _usable.size.y > 0.0 else Rect2(Vector2.ZERO, size)
		)
		var area: MarginContainer = get_node("Area")
		area.position = rect.position
		area.size = rect.size


func _on_action(role: StringName) -> void:
	if not is_active():
		return
	match role:
		&"menu_log":
			open_log()
		&"menu_summary":
			if _summary_available:
				_activate(&"summary")
		&"menu_quit":
			if _quit_confirmation_required:
				open_quit()
			else:
				cancel_advance()
				close()
				quit_confirmed.emit()
		&"quit_confirm":
			cancel_advance()
			close()
			quit_confirmed.emit()
		_:
			_cancel_active()


func _cancel_active() -> void:
	if get_keypad().is_active():
		get_keypad().cancel()
	else:
		close()


func _on_number_committed(value: String) -> void:
	close()
	number_committed.emit(value)


func _on_number_cancelled() -> void:
	number_cancelled.emit()
	if not _switching and not _closing:
		close()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_cancel_active()
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.device != -1
	):
		_cancel_active()


func _exit_tree() -> void:
	if _configured:
		(get_node("Guard") as GuiModalGuard).cancel_advance()
		_closing = true
		if get_keypad().is_active():
			get_keypad().cancel()
		(get_node("Guard") as GuiModalGuard).finish()
		_closing = false
	_kind = &""
	_requested_kind = &""
	_presented_kind = &""
	for panel: Control in _panels.values():
		panel.hide()
	hide()
