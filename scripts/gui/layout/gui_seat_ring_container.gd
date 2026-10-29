class_name GuiSeatRingContainer
extends Container

## The parent supplies a local allocation; this container owns all ring geometry.
## Assign template/felt resources before bind(), and rebind after changing them.
signal layout_resolved(plan: GuiSeatRingPlan)

@export var slot_template: GuiSeatSlotTemplate
@export var felt_style: StyleBoxFlat
var _seats: Dictionary[int, Control] = {}
var _hero: int = -1
var _center: Control
var _lower: Control
var _observed: Array[Control] = []
var _allocation_limit := Vector2.ZERO
var _configured: bool = false
var _binding_error: String = ""
var _automatic_template: GuiSeatSlotTemplate


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and is_node_ready():
		_arrange()
	elif what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_invalidate()


func _ready() -> void:
	_invalidate()


func bind(
	seats: Dictionary[int, Control], hero: int, center: Control, lower: Control = null
) -> bool:
	_disconnect_measurements()
	_seats = seats.duplicate()
	_hero = hero
	_center = center
	_lower = lower
	_binding_error = ""
	var controls: Array[Control] = []
	for control: Control in seats.values():
		controls.append(control)
	controls.append(center)
	if lower != null:
		controls.append(lower)
	for control: Control in controls:
		if (
			not is_instance_valid(control)
			or control.get_parent() != self
			or control == get_node("Guidance")
			or _observed.has(control)
		):
			_binding_error = "Seat ring requires distinct direct children for seats and regions."
			continue
		_observed.append(control)
	_configured = _binding_error.is_empty()
	if slot_template == null or slot_template == _automatic_template:
		slot_template = GuiSeatSlotTemplate.load_for_count(seats.size())
		_automatic_template = slot_template
	if _configured:
		for control: Control in _observed:
			control.minimum_size_changed.connect(_invalidate)
		var measured: GuiSeatRingPlan = get_layout_plan()
		if not measured.valid:
			_binding_error = measured.error
			_configured = false
	if not _configured:
		push_error(_binding_error)
	_invalidate()
	return _configured


func set_allocation_limit(value: Vector2) -> bool:
	if (
		not value.is_finite()
		or value.x < 0.0
		or value.y < 0.0
		or ((value.x == 0.0) != (value.y == 0.0))
	):
		push_error("Seat ring allocation must be positive and finite, or zero to use its own size.")
		return false
	_allocation_limit = value
	_invalidate()
	return true


func get_layout_plan() -> GuiSeatRingPlan:
	var invalid := GuiSeatRingPlan.new()
	if not _binding_error.is_empty():
		invalid.error = _binding_error
		return invalid
	if not _configured:
		invalid.error = "Seat ring has not been bound."
		return invalid
	var minima: Dictionary[int, Vector2] = {}
	for id: int in _seats:
		if not is_instance_valid(_seats[id]) or _seats[id].get_parent() != self:
			invalid.error = "A bound seat was removed."
			return invalid
		minima[id] = _seats[id].get_combined_minimum_size()
	if (
		not is_instance_valid(_center)
		or _center.get_parent() != self
		or (_lower != null and (not is_instance_valid(_lower) or _lower.get_parent() != self))
	):
		invalid.error = "A reserved region was removed."
		return invalid
	return _resolve(minima, _available_size())


func _resolve(minima: Dictionary[int, Vector2], available: Vector2) -> GuiSeatRingPlan:
	var style: StyleBoxFlat = _felt()
	var radius: float = 0.0
	var border: float = 0.0
	for corner: Corner in [
		CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT
	]:
		radius = maxf(radius, style.get_corner_radius(corner))
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		border = maxf(border, style.get_border_width(side))
	var apex_gap: float = 0.0
	for id: int in minima:
		if id != _hero:
			apex_gap = maxf(apex_gap, _seats[id].get_theme_constant("avatar_size", &"SeatPanel"))
	return GuiSeatRingPlan.resolve(
		minima,
		_hero,
		slot_template,
		_center.get_combined_minimum_size(),
		_lower.get_combined_minimum_size() if is_instance_valid(_lower) else Vector2.ZERO,
		available,
		get_theme_constant("separation", &"SeatRing"),
		Vector2(
			get_theme_constant("margin", &"SeatRing"), get_theme_constant("margin", &"SeatRing")
		),
		radius,
		border,
		get_theme_constant("hero_drop", &"SeatRing"),
		apex_gap
	)


func _get_minimum_size() -> Vector2:
	if not _configured or not _binding_error.is_empty():
		return Vector2.ZERO
	return get_layout_plan().minimum


func _available_size() -> Vector2:
	return size.min(_allocation_limit) if _allocation_limit.x > 0.0 else size


func _felt() -> StyleBoxFlat:
	return (
		felt_style if felt_style != null else get_theme_stylebox("panel", &"SeatRingFelt")
		as StyleBoxFlat
	)


func _draw() -> void:
	_felt().draw(get_canvas_item(), Rect2(Vector2.ZERO, _available_size()))


func _arrange() -> void:
	var plan: GuiSeatRingPlan = get_layout_plan()
	var guidance: Label = get_node("Guidance")
	guidance.visible = not plan.feasible
	guidance.text = (
		"More space needed for these seats." if plan.valid else "Unable to display seats."
	)
	for control: Control in _observed:
		if is_instance_valid(control) and control.get_parent() == self:
			control.visible = plan.feasible
	if plan.feasible:
		for id: int in plan.seats:
			fit_child_in_rect(_seats[id], plan.seats[id])
		fit_child_in_rect(_center, plan.center)
		if is_instance_valid(_lower):
			fit_child_in_rect(_lower, plan.lower)
	else:
		fit_child_in_rect(guidance, Rect2(Vector2.ZERO, _available_size()))
	guidance.move_to_front()
	queue_redraw()
	layout_resolved.emit(plan)


func _align_lower() -> void:
	if (
		_configured
		and _binding_error.is_empty()
		and _lower is GuiActionBar
		and _seats.has(_hero)
		and is_instance_valid(_seats[_hero])
		and _seats[_hero].get_parent() == self
	):
		(_lower as GuiActionBar).align_with_hero(_seats[_hero].get_combined_minimum_size().x)


func _invalidate() -> void:
	_align_lower()
	update_minimum_size()
	queue_sort()
	queue_redraw()


func _disconnect_measurements() -> void:
	for control: Control in _observed:
		if is_instance_valid(control):
			if control.get_parent() == self:
				control.visible = false
			if control.minimum_size_changed.is_connected(_invalidate):
				control.minimum_size_changed.disconnect(_invalidate)
	_observed.clear()
