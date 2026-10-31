class_name GuiPhoneLandscapeContainer
extends Container

## Sole landscape geometry owner; native child containers own seat interiors.
@export var separation: float = 2.0
@export var tablet_mode: bool = false
var _seats: Dictionary[int, Control] = {}
var _hero: int = -1
var _center: Control
var _actions: Control
var _observed: Array[Control] = []
var _limit := Vector2.ZERO
var _measuring: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and is_node_ready():
		_arrange()
	elif what == NOTIFICATION_THEME_CHANGED:
		_invalidate()


func bind(seats: Dictionary[int, Control], hero: int, center: Control, actions: Control) -> bool:
	for control: Control in _observed:
		if is_instance_valid(control) and control.minimum_size_changed.is_connected(_invalidate):
			control.minimum_size_changed.disconnect(_invalidate)
	_observed.clear()
	_seats = seats.duplicate()
	_hero = hero
	_center = center
	_actions = actions
	var controls: Array[Control] = [center, actions]
	controls.append_array(seats.values())
	for control: Control in controls:
		if not is_instance_valid(control) or control.get_parent() != self or _observed.has(control):
			push_error("Phone landscape requires distinct direct child seats and regions.")
			return false
		_observed.append(control)
		control.minimum_size_changed.connect(_invalidate)
	_invalidate()
	return _seats.has(hero)


func set_allocation_limit(value: Vector2) -> void:
	if _limit != value:
		_limit = value
		queue_sort()


func set_measurement_mode(enabled: bool) -> void:
	if _measuring != enabled:
		_measuring = enabled
		queue_sort()


func get_layout_plan() -> GuiPhoneLandscapePlan:
	return _resolve(_limit if _limit.x > 0 else size)


func _resolve(available: Vector2) -> GuiPhoneLandscapePlan:
	if not is_instance_valid(_center) or not is_instance_valid(_actions):
		return GuiPhoneLandscapePlan.new()
	if _center.get_parent() != self or _actions.get_parent() != self:
		return GuiPhoneLandscapePlan.new()
	var minima: Dictionary[int, Vector2] = {}
	for id: int in _seats:
		if not is_instance_valid(_seats[id]) or _seats[id].get_parent() != self:
			return GuiPhoneLandscapePlan.new()
		minima[id] = _seats[id].get_combined_minimum_size()
	var ids := PackedInt32Array(_seats.keys())
	ids.sort()
	var planner: Callable = (
		GuiTabletTablePlan.geometry if tablet_mode else GuiPhoneLandscapePlan.resolve
	)
	return planner.call(
		ids,
		_hero,
		minima,
		_center.get_combined_minimum_size(),
		_actions.get_combined_minimum_size(),
		available,
		separation
	)


func _get_minimum_size() -> Vector2:
	return get_layout_plan().minimum


func _arrange() -> void:
	var plan: GuiPhoneLandscapePlan = get_layout_plan()
	if _measuring and plan.valid and not plan.feasible:
		# An invisible measurement pass still needs real widths for wrapped copy.
		plan = _resolve((_limit if _limit.x > 0 else size).max(plan.minimum))
	for control: Control in _observed:
		if is_instance_valid(control) and control.get_parent() == self:
			control.visible = plan.feasible
	if not plan.feasible:
		return
	for id: int in plan.seats:
		fit_child_in_rect(_seats[id], plan.seats[id])
	if tablet_mode:
		var hero := _seats[_hero] as GuiSeatToken
		var panel := hero.get_node("Panel") as Control
		(_center as GuiCenterBoard).set_card_group_width(floorf(plan.seats[_hero].size.x))
		_align_tablet_actions(plan, hero.position.y + panel.position.y + panel.size.y)
		GuiTabletTablePlan.center_board(
			plan,
			_limit if _limit.x > 0 else size,
			(_center as GuiCenterBoard).get_card_group_height(),
			separation
		)
	fit_child_in_rect(_center, plan.center)
	fit_child_in_rect(_actions, plan.actions)


func _invalidate() -> void:
	update_minimum_size()
	queue_sort()


func _align_tablet_actions(plan: GuiPhoneLandscapePlan, panel_bottom: float) -> void:
	# Below-seat actions keep their own band; only the side rail shares this edge.
	if plan.actions.position.x < plan.seats[_hero].end.x:
		return
	var desired: float = panel_bottom - plan.actions.size.y
	var clearance: float = 0.0
	for id: int in plan.seats:
		if id == _hero:
			continue
		var rect: Rect2 = plan.seats[id]
		if rect.position.x < plan.actions.end.x and rect.end.x > plan.actions.position.x:
			clearance = maxf(clearance, rect.end.y + separation)
	plan.actions.position.y = minf(plan.actions.position.y, maxf(desired, clearance))
