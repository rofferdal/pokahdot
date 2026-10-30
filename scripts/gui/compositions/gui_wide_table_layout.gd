class_name GuiWideTableLayout
extends GuiTableComposition

## Ring geometry remains owned by the ring; optional history lives outside felt.
const SeatScene := preload("res://scenes/gui/components/SeatPanel.tscn")
const HeroScene := preload("res://scenes/gui/components/HeroPanel.tscn")
@export_range(1, 80) var dock_characters: int = 32
var _seats: Dictionary[int, Control] = {}
var _hero: int = -1
var _has_model: bool = false
var _legal_actions: Array[int] = []
var _action_roles: Dictionary[int, Array] = {}
var _board_count: int = 0
var _center: GuiCenterBoard
var _actions: GuiActionBar
var _pending: bool = false
var _generation: int = 0
var _limit := Vector2.ZERO
var _keypad: bool = false
var _draft: String = ""
var _bound: bool = false
var _binding_generation: int = 0


func _ready() -> void:
	_ensure_regions()
	resized.connect(_queue_layout)
	(get_node("Boundary") as Control).resized.connect(_queue_layout)
	_ring().minimum_size_changed.connect(_queue_layout)
	_ring().layout_resolved.connect(_on_ring_resolved)
	_log().minimum_size_changed.connect(_queue_layout)
	_queue_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_queue_layout()


func apply_policy(state: GuiCompositionState) -> void:
	super.apply_policy(state)
	_queue_layout()


func _ensure_regions() -> void:
	if _center != null:
		return
	_ring().theme = null
	_center = _ring().get_node("CenterBoard") as GuiCenterBoard
	_actions = _ring().get_node("ActionBar") as GuiActionBar
	_actions.action_requested.connect(
		func(intent: StringName) -> void: action_requested.emit(intent)
	)
	_actions.wager_edited.connect(_on_wager_edited)
	_actions.wager_submitted.connect(func(text: String) -> void: wager_submitted.emit(text))
	_actions.entry_requested.connect(func(text: String) -> void: entry_requested.emit(text))
	_actions.menu_requested.connect(func() -> void: menu_requested.emit())
	_actions.use_keypad(_keypad)
	_actions.set_wager_draft(_draft)


func render(model: TableViewModel) -> bool:
	_ensure_regions()
	if model == null or not model.valid or model.seats.size() < 2 or model.seats.size() > 9:
		return _reject_model(
			"WideTableLayout requires a valid two-to-nine-seat presentation model."
		)
	var expected: Dictionary[int, bool] = {}
	for seat: SeatViewModel in model.seats:
		if seat == null or not seat.valid or expected.has(seat.seat):
			return _reject_model("WideTableLayout requires valid unique seat models.")
		expected[seat.seat] = true
	if not expected.has(model.hero_seat):
		return _reject_model("WideTableLayout requires the recipient seat.")
	_has_model = true
	_legal_actions = model.actions.legal_actions.duplicate()
	_action_roles = model.actions.action_roles.duplicate(true)
	_board_count = 0
	for card: CardViewModel in model.center.board.cards:
		if card.state == CardViewModel.State.FACE:
			_board_count += 1
	_draft = _actions.get_wager_draft()
	# A recipient change changes scene roles; ordinary model refreshes reuse seats.
	for id: int in _seats.keys():
		if not expected.has(id) or ((id == _hero) != (id == model.hero_seat)):
			var old: Control = _seats[id]
			_ring().remove_child(old)
			old.queue_free()
			_seats.erase(id)
	_hero = model.hero_seat
	for seat: SeatViewModel in model.seats:
		if not _seats.has(seat.seat):
			var view: GuiSeatPanel = (HeroScene if seat.seat == _hero else SeatScene).instantiate()
			_ring().add_child(view)
			_seats[seat.seat] = view
		(_seats[seat.seat] as GuiSeatPanel).render(seat)
	_center.render(model.center)
	_actions.render(model.actions)
	_log().render(model.history)
	_binding_generation += 1
	call_deferred("_finish_binding", _binding_generation)
	_queue_layout()
	return true


func _reject_model(message: String) -> bool:
	push_error(message)
	_has_model = false
	_bound = false
	_legal_actions.clear()
	_action_roles.clear()
	_board_count = 0
	_queue_layout()
	return false


func _finish_binding(generation: int, remaining: int = 2) -> void:
	# Action rows and wrapped board copy publish their native minima after layout.
	if not is_inside_tree():
		return
	var completion: Callable = _finish_binding_frame.bind(generation, remaining)
	if not get_tree().process_frame.is_connected(completion):
		get_tree().process_frame.connect(completion, CONNECT_ONE_SHOT)


func _finish_binding_frame(generation: int, remaining: int) -> void:
	if not is_inside_tree() or generation != _binding_generation or not _has_model:
		return
	if remaining > 1:
		_finish_binding(generation, remaining - 1)
		return
	_bound = _ring().bind(_seats, _hero, _center, _actions)
	_queue_layout()


func set_wager_draft(text: String) -> void:
	_draft = text
	_ensure_regions()
	if _actions.get_wager_draft() != text:
		_actions.set_wager_draft(text)
	_queue_layout()


func get_wager_draft() -> String:
	return _actions.get_wager_draft() if _actions != null else _draft


func _on_wager_edited(text: String) -> void:
	_draft = text
	wager_edited.emit(text)


func use_keypad(enabled: bool) -> void:
	_keypad = enabled
	_ensure_regions()
	_actions.use_keypad(enabled)
	_queue_layout()


func set_allocation_limit(value: Vector2) -> bool:
	if not value.is_finite() or value.x < 0 or value.y < 0 or ((value.x == 0) != (value.y == 0)):
		push_error("WideTableLayout allocation must be positive and finite, or zero.")
		return false
	_limit = value
	_queue_layout()
	return true


func _queue_layout() -> void:
	if not _pending and is_inside_tree():
		_pending = true
		call_deferred("_layout_after_frame")


func _layout_after_frame() -> void:
	if not is_inside_tree():
		_pending = false
		return
	if not get_tree().process_frame.is_connected(_complete_layout_frame):
		get_tree().process_frame.connect(_complete_layout_frame, CONNECT_ONE_SHOT)


func _complete_layout_frame() -> void:
	if is_inside_tree():
		_layout()
	else:
		_pending = false


func _padding() -> Vector2:
	return Vector2(
		get_theme_constant("margin_left") + get_theme_constant("margin_right"),
		get_theme_constant("margin_top") + get_theme_constant("margin_bottom")
	)


func _layout() -> void:
	_pending = false
	if not is_inside_tree():
		return
	_generation += 1
	var boundary: Control = get_node("Boundary")
	var available: Vector2 = boundary.size
	if _limit.x > 0:
		available = available.min((_limit - _padding()).max(Vector2.ZERO))
	if _seats.has(_hero):
		var hero_width: float = _seats[_hero].get_combined_minimum_size().x
		if _actions.custom_minimum_size.x != hero_width:
			_actions.custom_minimum_size.x = hero_width
	var minimum: Vector2 = _ring().get_combined_minimum_size()
	var measured_minimum: Vector2 = minimum + _padding() if _bound else Vector2.ZERO
	if custom_minimum_size != measured_minimum:
		custom_minimum_size = measured_minimum
	var fits: bool = _bound and available.x >= minimum.x and available.y >= minimum.y
	var guidance: GuiSpaceGuidance = get_node("Boundary/Guidance")
	guidance.render_message(
		"" if fits else "More space is needed. Enlarge the window or rotate the screen."
	)
	_ring().visible = fits
	var dock: Control = get_node("Boundary/Dock")
	if not fits:
		dock.hide()
		return
	var gap: float = _ring().get_theme_constant("separation", &"SeatRing")
	var width: float = GuiEventLogMeasurement.minimum_dock_width(_log(), dock_characters)
	var leading: float = (
		_log().get_combined_minimum_size().y - _log().get_body().get_combined_minimum_size().y
	)
	var dock_fits: bool = available.x >= minimum.x + width + gap
	_ring().position = Vector2.ZERO
	_ring().size = Vector2(available.x - width - gap, available.y) if dock_fits else available
	var plan: GuiSeatRingPlan = _ring().get_layout_plan()
	if dock_fits:
		var span: float = plan.lower.end.y - plan.seats[_hero].position.y if plan.feasible else 0.0
		dock_fits = (
			span >= _log().get_body().get_combined_minimum_size().y
			and plan.seats[_hero].position.y >= leading
		)
	if not dock_fits:
		dock.hide()
		_ring().size = available
		return
	# Reveal before reflow so the log restores its saved reader intent while resizing.
	dock.show()
	dock.position = Vector2(_ring().size.x + gap, 0)
	dock.size = Vector2(width, available.y)
	var frame: MarginContainer = get_node("Boundary/Dock/Frame")
	frame.add_theme_constant_override("margin_top", ceili(plan.seats[_hero].position.y - leading))
	frame.add_theme_constant_override("margin_bottom", floori(available.y - plan.lower.end.y))
	dock.show()


func _on_ring_resolved(_plan: GuiSeatRingPlan) -> void:
	# Native component minima may settle one frame after the outer allocation.
	if not _pending and is_inside_tree():
		call_deferred("_settled", _generation)


func _settled(generation: int) -> void:
	if is_inside_tree():
		var completion: Callable = _check_settled.bind(generation)
		if not get_tree().process_frame.is_connected(completion):
			get_tree().process_frame.connect(completion, CONNECT_ONE_SHOT)


func _check_settled(generation: int) -> void:
	if is_inside_tree() and generation == _generation and not _pending:
		var minimum: Vector2 = _ring().get_combined_minimum_size() + _padding()
		if _bound and custom_minimum_size != minimum:
			_queue_layout()


func get_seat_controls() -> Dictionary[int, Control]:
	return _seats.duplicate()


func get_control(role: StringName) -> Control:
	var roles: Dictionary[StringName, Control] = {
		&"ring": _ring(),
		&"logo": get_node("Boundary/Ring/BrandLogo"),
		&"center": _center,
		&"actions": _actions,
		&"hero": _seats.get(_hero),
		&"log": _log(),
		&"guidance": get_node("Boundary/Guidance"),
		&"dock": get_node("Boundary/Dock")
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
		not _bound
		or mode not in [GuiSizeClass.LayoutMode.WIDE_COMPACT, GuiSizeClass.LayoutMode.WIDE]
	):
		return result
	var ids := PackedInt32Array(_seats.keys())
	ids.sort()
	result.mode = mode
	result.density = density
	result.action_flow = flow
	result.minimum = _ring().get_combined_minimum_size() + _padding()
	result.seats = GuiSeatRows.compose(ids, _hero, false)
	result.seats.rows = _ring().get_layout_plan().rows.duplicate()
	result.evidence = &"wide-native-components"
	result.valid = result.seats.valid and result.minimum.x > 0 and result.minimum.y > 0
	return result


func get_layout_snapshot(root: Control) -> GuiLayoutSnapshot:
	var snapshot := GuiLayoutSnapshot.new()
	snapshot.schema_version = 2
	snapshot.layout_mode = policy.mode if policy != null else GuiSizeClass.LayoutMode.WIDE
	snapshot.profile = GuiSnapshotMeasurement.profile_for_mode(snapshot.layout_mode)
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
	snapshot.pending = _pending
	var plan: GuiSeatRingPlan = _ring().get_layout_plan()
	snapshot.fit_guidance = (
		"More space is needed. Enlarge the window or rotate the screen."
		if get_control(&"guidance").visible
		else ""
	)
	snapshot.ready = _bound and not _pending and _ring().is_visible_in_tree() and plan.feasible
	snapshot.seat_rows = plan.rows.duplicate()
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
	var event: GuiLayoutElement = _log().get_observation(root)
	snapshot.elements[&"event"] = event
	snapshot.measured.append(event)
	for id: int in _seats:
		snapshot.seats[id] = (_seats[id] as GuiSeatPanel).get_seat_snapshot(root)
	var cards := _center.get_node("Cards") as GuiCardRow
	for index: int in cards.cards.size():
		snapshot.board_cards.append(
			cards.cards[index].get_card_snapshot(root, StringName("board/%d" % index), true)
		)
	snapshot.expected_board_card_count = _board_count
	snapshot.legal_actions = _legal_actions.duplicate()
	snapshot.actions = _action_roles.duplicate(true)
	return snapshot


func _ring() -> GuiSeatRingContainer:
	return get_node("Boundary/Ring") as GuiSeatRingContainer


func _log() -> GuiEventLog:
	return get_node("Boundary/Dock/Frame/EventLog") as GuiEventLog
