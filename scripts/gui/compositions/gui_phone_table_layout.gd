class_name GuiPhoneTableLayout
extends GuiTableComposition

## Authored orientation and measured native rows; no viewport or core inference.
@export var landscape_mode: bool = false
@export var tablet_mode: bool = false
var _seats: Dictionary[int, Control] = {}
var _hero: int = -1
var _layout_mode: GuiSizeClass.LayoutMode = GuiSizeClass.LayoutMode.PHONE
var _rows: GuiPhoneSeatRows
var _center: GuiCenterBoard
var _actions: GuiActionBar
var _slots: Array[GuiSeatToken] = []
var _hero_token: GuiSeatToken
var _hero_cell: MarginContainer
var _landscape: GuiPhoneLandscapeContainer
var _plan := GuiPhoneTablePlan.new()
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


func _ensure_regions() -> void:
	if _center != null:
		return
	var portrait := get_node_or_null("Boundary/Content/Portrait") as Control
	var landscape: Control = get_node("Boundary/Content/Landscape")
	_layout_mode = (
		GuiSizeClass.LayoutMode.WIDE_COMPACT
		if tablet_mode
		else (
			GuiSizeClass.LayoutMode.PHONE_LANDSCAPE
			if landscape_mode
			else GuiSizeClass.LayoutMode.PHONE
		)
	)
	if portrait != null:
		portrait.visible = not landscape_mode
	landscape.visible = landscape_mode
	_landscape = landscape as GuiPhoneLandscapeContainer
	if not landscape_mode:
		portrait.minimum_size_changed.connect(_queue_layout)
		_rows = portrait.get_node("Rows") as GuiPhoneSeatRows
		var hero_path: String = "Lower/HeroSlot/HeroCell" if tablet_mode else "HeroSlot/HeroCell"
		_hero_cell = portrait.get_node(hero_path) as MarginContainer
		_hero_token = _hero_cell.get_node("Hero") as GuiSeatToken
	var active: Control = landscape if landscape_mode else portrait
	_center = active.get_node("CenterBoard") as GuiCenterBoard
	_actions = (
		active.get_node("Lower/ActionBar" if tablet_mode and not landscape_mode else "ActionBar")
		as GuiActionBar
	)
	(
		_slots
		. assign(
			(
				[
					get_node("Boundary/Content/Portrait/Rows/Opponent0") as GuiSeatToken,
					get_node("Boundary/Content/Portrait/Rows/Opponent1") as GuiSeatToken,
					get_node("Boundary/Content/Portrait/Rows/Opponent2") as GuiSeatToken,
					get_node("Boundary/Content/Portrait/Rows/Opponent3") as GuiSeatToken,
					get_node("Boundary/Content/Portrait/Rows/Opponent4") as GuiSeatToken,
					get_node("Boundary/Content/Portrait/Rows/Opponent5") as GuiSeatToken,
					get_node("Boundary/Content/Portrait/Rows/Opponent6") as GuiSeatToken,
					get_node("Boundary/Content/Portrait/Rows/Opponent7") as GuiSeatToken,
				]
				if not landscape_mode
				else [
					get_node("Boundary/Content/Landscape/Seat0") as GuiSeatToken,
					get_node("Boundary/Content/Landscape/Seat1") as GuiSeatToken,
					get_node("Boundary/Content/Landscape/Seat2") as GuiSeatToken,
					get_node("Boundary/Content/Landscape/Seat3") as GuiSeatToken,
					get_node("Boundary/Content/Landscape/Seat4") as GuiSeatToken,
					get_node("Boundary/Content/Landscape/Seat5") as GuiSeatToken,
					get_node("Boundary/Content/Landscape/Seat6") as GuiSeatToken,
					get_node("Boundary/Content/Landscape/Seat7") as GuiSeatToken,
					get_node("Boundary/Content/Landscape/Seat8") as GuiSeatToken,
				]
			)
		)
	)
	var observed: Array[GuiSeatToken] = _slots.duplicate()
	if not landscape_mode:
		observed.append(_hero_token)
	for token: GuiSeatToken in observed:
		token.minimum_size_changed.connect(_queue_layout)
		token.detail_requested.connect(func(id: int) -> void: seat_detail_requested.emit(id))
	_center.minimum_size_changed.connect(_queue_layout)
	_actions.minimum_size_changed.connect(_queue_layout)
	_actions.layout_resolved.connect(_queue_layout)
	_actions.action_requested.connect(
		func(intent: StringName) -> void: action_requested.emit(intent)
	)
	_actions.wager_edited.connect(func(text: String) -> void: wager_edited.emit(text))
	_actions.wager_submitted.connect(func(text: String) -> void: wager_submitted.emit(text))
	_actions.entry_requested.connect(func(text: String) -> void: entry_requested.emit(text))
	_actions.menu_requested.connect(func() -> void: menu_requested.emit())
	_actions.use_keypad(_keypad)
	_actions.set_wager_draft(_draft)


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
	_capacity = ids.size() <= (9 if tablet_mode else 7)
	_legal_actions = model.actions.legal_actions.duplicate()
	_action_roles = model.actions.action_roles.duplicate(true)
	_board_count = 0
	for card: CardViewModel in model.center.board.cards:
		if card.state == CardViewModel.State.FACE:
			_board_count += 1
	for id: int in _seats.keys():
		if not ids.has(id) or ((id == _hero) != (id == model.hero_seat)):
			_seats[id].hide()
			_seats.erase(id)
	_hero = model.hero_seat
	for seat: SeatViewModel in model.seats:
		if not _seats.has(seat.seat):
			var token: GuiSeatToken = _available_token(seat.seat == _hero)
			if token == null:
				return _reject("PhoneTableLayout has no available authored seat slot.")
			_seats[seat.seat] = token
		var token := _seats[seat.seat] as GuiSeatToken
		token.render(seat)
		token.show()
	if landscape_mode:
		_landscape.bind(_seats, _hero, _center, _actions)
	_center.render(model.center)
	_actions.render(model.actions)
	_render_epoch += 1
	_measuring = true
	call_deferred("_finish_measurement", _render_epoch)
	_queue_layout()
	return true


func _available_token(hero: bool) -> GuiSeatToken:
	if hero and not landscape_mode:
		return _hero_token if not _seats.values().has(_hero_token) else null
	for token: GuiSeatToken in _slots:
		if not _seats.values().has(token):
			return token
	return null


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


func _gap() -> float:
	return (
		_landscape.separation
		if landscape_mode
		else (get_node("Boundary/Content/Portrait") as Control).get_theme_constant("separation")
	)


func _layout() -> void:
	_pending = false
	_generation += 1
	var boundary: Control = get_node("Boundary")
	var available: Vector2 = boundary.size.min(_limit) if _limit.x > 0 else boundary.size
	var content: Control = get_node("Boundary/Content")
	content.size = available
	content.position = Vector2.ZERO
	var native: Control = get_node(
		"Boundary/Content/Landscape" if landscape_mode else "Boundary/Content/Portrait"
	)
	# Minimum-size growth can shift a full-rect Control's offsets. Reapply the
	# owned allocation on shrink so an earlier wide frame cannot leave an inset.
	native.size = available
	native.position = Vector2.ZERO
	if not landscape_mode and not tablet_mode:
		_actions.set_available_width(available.x)
	_plan = (
		GuiPhoneMeasuredPlan.resolve(
			_seats, _hero, _center, _actions, landscape_mode, available, _gap(), tablet_mode
		)
		if _has_model and _capacity
		else GuiPhoneTablePlan.new()
	)
	if _plan.valid and not landscape_mode:
		# Include native wrapped-copy and row allocations after they settle. The
		# outer plan must never promise less space than its authored container.
		var portrait: Control = get_node("Boundary/Content/Portrait")
		_plan.minimum.y = maxf(_plan.minimum.y, portrait.get_combined_minimum_size().y)
		_plan.feasible = available.x >= _plan.minimum.x and available.y >= _plan.minimum.y
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
	if not tablet_mode:
		_actions.set_inline_budget(
			Vector2(
				available.x,
				maxf(0.0, available.y - _plan.minimum.y + _actions.get_combined_minimum_size().y)
			)
		)
	var cell_width: float = maxf(
		_plan.opponent_width,
		floorf(
			minf(
				(available.x - (_plan.columns - 1) * _gap()) / _plan.columns,
				available.x - 2.0 * _gap()
			)
		)
	)
	_rows.configure(_plan.rows, _seats, _hero, cell_width, _gap())
	var hero_width: float = (
		_seats[_hero].get_combined_minimum_size().x
		if tablet_mode
		else maxf(_seats[_hero].get_combined_minimum_size().x, cell_width + 2.0 * _gap())
	)
	if _hero_cell.custom_minimum_size.x != hero_width:
		_hero_cell.custom_minimum_size.x = hero_width
	_actions.align_with_hero(hero_width)


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
		or _actions.is_layout_pending()
		or mode != _layout_mode
		or not _plan.valid
	):
		return result
	result.mode = mode
	result.density = density
	result.action_flow = flow
	result.minimum = _plan.minimum
	result.seats = GuiSeatRows.compose(
		GuiPhoneMeasuredPlan.sorted_ids(_seats), _hero, not tablet_mode
	)
	result.seats.rows = _plan.rows.duplicate()
	result.evidence = &"phone-native-components"
	result.valid = result.seats.valid
	return result


func get_layout_snapshot(root: Control) -> GuiLayoutSnapshot:
	var data := GuiPhoneSnapshotCapture.Data.new()
	data.mode = _layout_mode
	data.surface = get_node("Boundary")
	data.generation = (
		policy.geometry.generation if policy != null and policy.geometry != null else _generation
	)
	data.pending = _pending or _measuring or _actions.is_layout_pending()
	data.ready = (
		_has_model
		and _plan.feasible
		and get_control(&"content").is_visible_in_tree()
		and not data.pending
	)
	data.guidance = _guidance
	data.rows = _plan.rows
	data.board_count = _board_count
	data.legal_actions = _legal_actions
	data.action_roles = _action_roles
	return GuiPhoneSnapshotCapture.capture(root, self, data)
