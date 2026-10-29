class_name GuiPhoneTableLayout
extends GuiTableComposition

## Authored orientation and measured native rows; no viewport or core inference.
const TokenScene := preload("res://scenes/gui/components/SeatToken.tscn")
const CenterScene := preload("res://scenes/gui/components/CenterBoard.tscn")
const ActionScene := preload("res://scenes/gui/components/ActionBar.tscn")
@export var landscape_mode: bool = false
var _seats: Dictionary[int, Control] = {}
var _cells: Dictionary[int, MarginContainer] = {}
var _hero: int = -1
var _rows: VBoxContainer
var _center: GuiCenterBoard
var _actions: GuiActionBar
var _spacer: Control
var _holding: Control
var _hero_slot: CenterContainer
var _hero_cell: MarginContainer
var _landscape: GuiPhoneLandscapeContainer
var _plan := GuiPhoneTablePlan.new()
var _row_ids: Array[PackedInt32Array] = []
var _pending: bool = false
var _generation: int = 0
var _has_model: bool = false
var _capacity: bool = true
var _limit := Vector2.ZERO
var _keypad: bool = true
var _draft: String = ""
var _legal_actions: Array[int] = []
var _action_roles: Dictionary[int, Array] = {}
var _board_count: int = 0
var _guidance: String = ""
var _measuring: bool = false
var _render_epoch: int = 0
var _conceal_measurement: bool = true
var _measured_theme: Theme


func _ready() -> void:
	_ensure_regions()
	resized.connect(_queue_layout)
	(get_node("Boundary") as Control).resized.connect(_queue_layout)
	_queue_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_queue_layout()


func apply_policy(state: GuiCompositionState) -> void:
	super.apply_policy(state)
	if state.geometry != null and state.geometry.valid:
		_limit = state.geometry.usable_rect.size
	_queue_layout()


func _mode() -> GuiSizeClass.LayoutMode:
	return (
		GuiSizeClass.LayoutMode.PHONE_LANDSCAPE if landscape_mode else GuiSizeClass.LayoutMode.PHONE
	)


func _ensure_regions() -> void:
	if _center != null:
		return
	var portrait: Control = get_node("Boundary/Content/Portrait")
	var landscape: Control = get_node("Boundary/Content/Landscape")
	portrait.visible = not landscape_mode
	landscape.visible = landscape_mode
	_center = CenterScene.instantiate()
	_center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_actions = ActionScene.instantiate()
	_actions.compact_controls = true
	_holding = Control.new()
	_holding.hide()
	get_node("Boundary").add_child(_holding)
	_landscape = landscape as GuiPhoneLandscapeContainer
	if landscape_mode:
		_center.add_theme_constant_override("separation", 2)
		_landscape.add_child(_center)
		_landscape.add_child(_actions)
	else:
		_rows = VBoxContainer.new()
		_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spacer = Control.new()
		_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait.add_child(_rows)
		portrait.add_child(_spacer)
		portrait.add_child(_center)
		_hero_slot = CenterContainer.new()
		_hero_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hero_cell = MarginContainer.new()
		_hero_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hero_slot.add_child(_hero_cell)
		portrait.add_child(_hero_slot)
		portrait.add_child(_actions)
	_center.minimum_size_changed.connect(_queue_layout)
	_actions.minimum_size_changed.connect(_queue_layout)
	_actions.action_requested.connect(
		func(intent: StringName) -> void: action_requested.emit(intent)
	)
	_actions.wager_edited.connect(func(text: String) -> void: wager_edited.emit(text))
	_actions.wager_submitted.connect(func(text: String) -> void: wager_submitted.emit(text))
	_actions.entry_requested.connect(func(text: String) -> void: entry_requested.emit(text))
	_actions.menu_requested.connect(func() -> void: menu_requested.emit())
	_actions.use_keypad(_keypad)
	_actions.set_wager_draft(_draft)


func _lower() -> Node:
	return _landscape if landscape_mode else _hero_cell


func render(model: TableViewModel) -> bool:
	_ensure_regions()
	if model == null or not model.valid or model.seats.size() < 2 or model.seats.size() > 9:
		return _reject("PhoneTableLayout requires a valid table presentation model.")
	var ids: Dictionary[int, bool] = {}
	for seat: SeatViewModel in model.seats:
		if seat == null or not seat.valid or seat.cards == null or ids.has(seat.seat):
			return _reject("PhoneTableLayout requires valid unique seat models.")
		ids[seat.seat] = true
	if not ids.has(model.hero_seat):
		return _reject("PhoneTableLayout requires the recipient seat.")
	var same_identity: bool = (
		_has_model and _hero == model.hero_seat and ids.size() == _seats.size()
	)
	for id: int in _seats:
		same_identity = same_identity and ids.has(id)
	_conceal_measurement = not (
		same_identity
		and _guidance.is_empty()
		and not (_measuring and _conceal_measurement)
		and _measured_theme == theme
		and get_control(&"content").is_visible_in_tree()
	)
	_measured_theme = theme
	_has_model = true
	_capacity = ids.size() <= 7
	_legal_actions = model.actions.legal_actions.duplicate()
	_action_roles = model.actions.action_roles.duplicate(true)
	_board_count = 0
	for card: CardViewModel in model.center.board.cards:
		if card.state == CardViewModel.State.FACE:
			_board_count += 1
	for id: int in _seats.keys():
		if not ids.has(id) or ((id == _hero) != (id == model.hero_seat)):
			var old: Control = _seats[id]
			old.get_parent().remove_child(old)
			old.queue_free()
			_seats.erase(id)
	_hero = model.hero_seat
	for seat: SeatViewModel in model.seats:
		if not _seats.has(seat.seat):
			var token: GuiSeatToken = TokenScene.instantiate()
			_holding.add_child(token)
			token.minimum_size_changed.connect(_queue_layout)
			token.detail_requested.connect(func(id: int) -> void: seat_detail_requested.emit(id))
			_seats[seat.seat] = token
		(_seats[seat.seat] as GuiSeatToken).render(seat)
	if _seats[_hero].get_parent() != _lower():
		_seats[_hero].reparent(_lower(), false)
	if landscape_mode:
		for seat: Control in _seats.values():
			if seat.get_parent() != _landscape:
				seat.reparent(_landscape, false)
		_landscape.bind(_seats, _hero, _center, _actions)
	_center.render(model.center)
	_actions.render(model.actions)
	_render_epoch += 1
	_measuring = true
	call_deferred("_finish_measurement", _render_epoch)
	_queue_layout()
	return true


func _finish_measurement(epoch: int, remaining: int = 4) -> void:
	# Native wrapped labels and flow rows need a real width before their heights
	# are meaningful. Measure transparently before deciding to hide unsupported
	# content; hiding first would prevent their first native allocation.
	if is_inside_tree():
		var completion: Callable = _finish_measurement_frame.bind(epoch, remaining)
		if not get_tree().process_frame.is_connected(completion):
			get_tree().process_frame.connect(completion, CONNECT_ONE_SHOT)


func _finish_measurement_frame(epoch: int, remaining: int) -> void:
	if not is_inside_tree() or epoch != _render_epoch:
		return
	if remaining > 1:
		_finish_measurement(epoch, remaining - 1)
		return
	_measuring = false
	_queue_layout()


func _reject(message: String) -> bool:
	push_error(message)
	_has_model = false
	_render_epoch += 1
	_measuring = false
	_legal_actions.clear()
	_action_roles.clear()
	_queue_layout()
	return false


func set_wager_draft(text: String) -> void:
	_draft = text
	_ensure_regions()
	if _actions.get_wager_draft() != text:
		_actions.set_wager_draft(text)
	_queue_layout()


func get_wager_draft() -> String:
	return _actions.get_wager_draft() if _actions != null else _draft


func use_keypad(enabled: bool) -> void:
	_keypad = enabled
	_ensure_regions()
	_actions.use_keypad(enabled)
	_queue_layout()


func set_allocation_limit(value: Vector2) -> bool:
	if not value.is_finite() or value.x < 0 or value.y < 0 or ((value.x == 0) != (value.y == 0)):
		push_error("PhoneTableLayout allocation must be positive and finite, or zero.")
		return false
	_limit = value
	_queue_layout()
	return true


func _queue_layout() -> void:
	if not _pending and is_inside_tree():
		_pending = true
		call_deferred("_next_layout")


func _next_layout() -> void:
	if not is_inside_tree():
		_pending = false
		return
	if not get_tree().process_frame.is_connected(_complete_layout_frame):
		get_tree().process_frame.connect(_complete_layout_frame, CONNECT_ONE_SHOT)


func _complete_layout_frame() -> void:
	if not is_inside_tree():
		_pending = false
		return
	_layout()


func _ids() -> PackedInt32Array:
	var ids := PackedInt32Array(_seats.keys())
	ids.sort()
	return ids


func _gap() -> float:
	return get_theme_constant("separation", &"VBoxContainer")


func _resolve(available: Vector2) -> GuiPhoneTablePlan:
	var minima: Dictionary[int, Vector2] = {}
	for id: int in _seats:
		minima[id] = _seats[id].get_combined_minimum_size()
	return GuiPhoneTablePlan.resolve(
		_ids(),
		_hero,
		minima,
		_center.get_combined_minimum_size(),
		_actions.get_combined_minimum_size(),
		landscape_mode,
		available,
		_gap()
	)


func _layout() -> void:
	_pending = false
	_generation += 1
	var boundary: Control = get_node("Boundary")
	var available: Vector2 = boundary.size.min(_limit) if _limit.x > 0 else boundary.size
	var content: Control = get_node("Boundary/Content")
	content.size = available
	_plan = _resolve(available) if _has_model and _capacity else GuiPhoneTablePlan.new()
	var minimum: Vector2 = _plan.minimum if _plan.valid else Vector2.ZERO
	if not _measuring and custom_minimum_size != minimum:
		custom_minimum_size = minimum
	_guidance = ""
	if not _measuring and (not _has_model or not _plan.feasible):
		_guidance = (
			"Eight or nine players require a larger layout."
			if not _capacity
			else (
				"More space is needed. Try portrait mode or use a larger screen."
				if landscape_mode
				else "More space is needed. Enlarge the window or rotate the screen."
			)
		)
	(get_node("Boundary/Guidance") as GuiSpaceGuidance).render_message(_guidance)
	content.visible = _measuring or _guidance.is_empty()
	var concealed: bool = _measuring and _conceal_measurement
	content.modulate.a = 0.0 if concealed else 1.0
	content.mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_DISABLED if concealed else Control.MOUSE_BEHAVIOR_INHERITED
	)
	content.focus_behavior_recursive = (
		Control.FOCUS_BEHAVIOR_DISABLED if concealed else Control.FOCUS_BEHAVIOR_INHERITED
	)
	if landscape_mode:
		_landscape.set_allocation_limit(available)
		_landscape.set_measurement_mode(_measuring)
		_landscape.queue_sort()
		_actions.align_with_hero(_actions.get_combined_minimum_size().x)
		return
	if not _plan.valid:
		return
	_rebuild_rows()
	var cell_width: float = maxf(
		_plan.opponent_width,
		floorf(
			minf(
				(available.x - (_plan.columns - 1) * _gap()) / _plan.columns,
				available.x - 2.0 * _gap()
			)
		)
	)
	for cell: MarginContainer in _cells.values():
		if cell.custom_minimum_size.x != cell_width:
			cell.custom_minimum_size.x = cell_width
	var hero_width: float = maxf(
		_seats[_hero].get_combined_minimum_size().x, cell_width + 2.0 * _gap()
	)
	if _hero_cell.custom_minimum_size.x != hero_width:
		_hero_cell.custom_minimum_size.x = hero_width
	_actions.align_with_hero(hero_width)


func _rebuild_rows() -> void:
	if _row_ids == _plan.rows:
		return
	for id: int in _seats:
		if id != _hero:
			_seats[id].reparent(_holding, false)
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_cells.clear()
	_row_ids = _plan.rows.duplicate()
	for ids: PackedInt32Array in _row_ids:
		if ids.has(_hero):
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_rows.add_child(row)
		for id: int in ids:
			var cell := MarginContainer.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(cell)
			_seats[id].reparent(cell, false)
			_cells[id] = cell


func get_seat_controls() -> Dictionary[int, Control]:
	return _seats.duplicate()


func get_control(role: StringName) -> Control:
	var roles: Dictionary[StringName, Control] = {
		&"center": _center,
		&"actions": _actions,
		&"hero": _seats.get(_hero),
		&"logo": get_node("Boundary/BrandLogo"),
		&"guidance": get_node("Boundary/Guidance"),
		&"content": get_node("Boundary/Content"),
		&"landscape": _landscape
	}
	return (
		roles[role]
		if roles.has(role)
		else (_actions.get_control(role) if _actions != null else null)
	)


func get_fit_candidate(
	mode: GuiSizeClass.LayoutMode,
	density: GuiFitCandidate.Density,
	flow: GuiFitCandidate.ActionFlow
) -> GuiFitCandidate:
	var result := GuiFitCandidate.new()
	if (
		not _has_model
		or not _capacity
		or _pending
		or _measuring
		or mode != _mode()
		or not _plan.valid
	):
		return result
	result.mode = mode
	result.density = density
	result.action_flow = flow
	result.minimum = _plan.minimum
	result.seats = GuiSeatRows.compose(_ids(), _hero, true)
	result.seats.rows = _plan.rows.duplicate()
	result.evidence = &"phone-native-components"
	result.valid = result.seats.valid
	return result


func get_layout_snapshot(root: Control) -> GuiLayoutSnapshot:
	var snapshot := GuiLayoutSnapshot.new()
	snapshot.schema_version = 2
	snapshot.layout_mode = _mode()
	snapshot.profile = GuiSnapshotMeasurement.profile_for_mode(_mode())
	snapshot.root_rect = Rect2(Vector2.ZERO, root.size)
	snapshot.viewport_rect = snapshot.root_rect
	snapshot.usable_rect = GuiSnapshotMeasurement.rect(self, root)
	snapshot.surface_rect = GuiSnapshotMeasurement.rect(get_node("Boundary"), root)
	snapshot.surface_size = (get_node("Boundary") as Control).size
	snapshot.surface_transform = (
		(get_node("Boundary") as Control).get_global_transform_with_canvas()
	)
	snapshot.generation = (
		policy.geometry.generation if policy != null and policy.geometry != null else _generation
	)
	snapshot.pending = _pending or _measuring
	snapshot.ready = (
		_has_model
		and _plan.feasible
		and get_control(&"content").is_visible_in_tree()
		and not _pending
		and not _measuring
	)
	snapshot.fit_guidance = _guidance
	snapshot.seat_rows = _plan.rows.duplicate()
	snapshot.menu_routes = {&"quit": &"more", &"event": &"more"}
	var roles: Dictionary[StringName, Control] = {
		&"center": _center,
		&"board": _center.get_node("Cards"),
		&"pot": _center.get_node("Totals/Pot"),
		&"wager": _center.get_node("Totals/Wager"),
		&"action": _actions,
		&"logo": get_control(&"logo"),
		&"guidance": get_control(&"guidance").get_node("Center/Message")
	}
	for role: StringName in [
		&"fold",
		&"check_call",
		&"minimum",
		&"pot",
		&"wager",
		&"all_in",
		&"continue",
		&"more",
		&"total",
		&"status"
	]:
		roles[StringName("action/" + str(role))] = _actions.get_control(role)
	for role: StringName in roles:
		var element: GuiLayoutElement = GuiSnapshotMeasurement.element(roles[role], root, role)
		snapshot.elements[role] = element
		snapshot.measured.append(element)
	var event := GuiLayoutElement.new()
	event.role = &"event"
	snapshot.elements[&"event"] = event
	for id: int in _seats:
		snapshot.seats[id] = (_seats[id] as GuiSeatToken).get_seat_snapshot(root)
	var cards := _center.get_node("Cards") as GuiCardRow
	for index: int in cards.cards.size():
		snapshot.board_cards.append(
			cards.cards[index].get_card_snapshot(root, StringName("board/%d" % index), true)
		)
	snapshot.expected_board_card_count = _board_count
	snapshot.legal_actions = _legal_actions.duplicate()
	snapshot.actions = _action_roles.duplicate(true)
	return snapshot
