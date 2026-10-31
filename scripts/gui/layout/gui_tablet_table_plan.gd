class_name GuiTabletTablePlan
extends RefCounted


## Paired side seats around a shared board and a centered, equal-sized human.
static func geometry(
	ids: PackedInt32Array,
	hero: int,
	minima: Dictionary[int, Vector2],
	board: Vector2,
	actions: Vector2,
	available: Vector2,
	gap: float
) -> GuiPhoneLandscapePlan:
	var plan: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan._symmetric(
		ids, hero, minima, board, actions, available, gap, 9
	)
	if plan.valid and available.x < plan.minimum.x:
		var below: GuiPhoneLandscapePlan = _below_actions(
			ids, hero, minima, board, actions, available, gap
		)
		if below.feasible:
			return below
		return _stacked(ids, hero, minima, board, actions, available, gap)
	if not plan.feasible:
		return plan
	# Grow all seats equally when the central corridor and height permit it.
	var seat_size: Vector2 = plan.seats[hero].size
	var growth: float = maxf(0.0, (available.y - plan.minimum.y) / (plan.rows.size() + 1))
	var width_limit: float = minf(
		(available.x - board.x - 2.0 * gap) * 0.5, available.x - 2.0 * (actions.x + gap)
	)
	seat_size.x = maxf(seat_size.x, minf(width_limit, available.x * 0.27))
	seat_size.y += growth
	var expanded: Dictionary[int, Vector2] = {}
	for id: int in ids:
		expanded[id] = seat_size
	var grown: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan._symmetric(
		ids, hero, expanded, board, actions, available, gap, 9
	)
	if grown.feasible:
		grown.minimum = plan.minimum
		grown.center.size = Vector2(maxf(board.x, seat_size.x), board.y)
		grown.center.position = Vector2(
			(available.x - grown.center.size.x) * 0.5,
			grown.seats[hero].position.y - gap - grown.center.size.y
		)
		return grown
	return plan


static func resolve(
	ids: PackedInt32Array,
	hero: int,
	minima: Dictionary[int, Vector2],
	board: Vector2,
	actions: Vector2,
	available: Vector2,
	gap: float
) -> GuiPhoneTablePlan:
	var geometry_plan: GuiPhoneLandscapePlan = geometry(
		ids, hero, minima, board, actions, available, gap
	)
	var result := GuiPhoneTablePlan.new()
	result.valid = geometry_plan.valid
	result.feasible = geometry_plan.feasible
	result.minimum = geometry_plan.minimum
	result.rows = geometry_plan.rows.duplicate()
	result.opponent_width = geometry_plan.opponent_width
	result.hero_width = geometry_plan.hero_width
	return result


## Narrow tablets put the board between the bot rows and the human/action rows.
static func _stacked(
	ids: PackedInt32Array,
	hero: int,
	minima: Dictionary[int, Vector2],
	board: Vector2,
	actions: Vector2,
	available: Vector2,
	gap: float
) -> GuiPhoneLandscapePlan:
	var result := GuiPhoneLandscapePlan.new()
	var order: GuiSeatRows = GuiSeatRows.compose(ids, hero, true)
	var extent := Vector2.ZERO
	for value: Vector2 in minima.values():
		extent = extent.max(value)
	result.rows = order.rows.duplicate()
	var bots: int = order.rows.size() - 1
	result.minimum = Vector2(
		maxf(maxf(extent.x * mini(2, ids.size() - 1) + gap, board.x), actions.x),
		bots * extent.y + board.y + extent.y + actions.y + (bots + 2) * gap
	)
	result.valid = result.minimum.is_finite()
	result.feasible = available.x >= result.minimum.x and available.y >= result.minimum.y
	result.opponent_width = extent.x
	result.hero_width = extent.x
	if not result.feasible:
		return result
	extent.x = maxf(extent.x, minf(available.x * 0.38, (available.x - gap) * 0.5))
	result.opponent_width = extent.x
	result.hero_width = extent.x
	var y: float = 0.0
	for index: int in bots:
		var row: PackedInt32Array = order.rows[index]
		for column: int in row.size():
			var x: float = (available.x - extent.x) * 0.5
			if row.size() == 2:
				x = 0.0 if column == 0 else available.x - extent.x
			result.seats[row[column]] = Rect2(Vector2(x, y), extent)
		y += extent.y + gap
	result.actions = Rect2(
		Vector2((available.x - actions.x) * 0.5, available.y - actions.y), actions
	)
	result.seats[hero] = Rect2(
		Vector2((available.x - extent.x) * 0.5, result.actions.position.y - gap - extent.y), extent
	)
	result.center = Rect2(
		Vector2(
			(available.x - maxf(board.x, extent.x)) * 0.5,
			result.seats[hero].position.y - gap - board.y
		),
		Vector2(maxf(board.x, extent.x), board.y)
	)
	return result


static func _below_actions(
	ids: PackedInt32Array,
	hero: int,
	minima: Dictionary[int, Vector2],
	board: Vector2,
	actions: Vector2,
	available: Vector2,
	gap: float
) -> GuiPhoneLandscapePlan:
	var reserve: float = actions.y + gap
	var upper := Vector2(available.x, maxf(0.0, available.y - reserve))
	var result: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan._symmetric(
		ids, hero, minima, board, Vector2(1, 1), upper, gap, 9
	)
	result.minimum.x = maxf(result.minimum.x, actions.x)
	result.minimum.y += reserve
	result.feasible = (
		result.valid and available.x >= result.minimum.x and available.y >= result.minimum.y
	)
	if result.feasible:
		result.actions = Rect2(
			Vector2((available.x - actions.x) * 0.5, available.y - actions.y), actions
		)
	return result


## Choose the nearest free vertical band to center the slots, with copy below.
static func center_board(
	plan: GuiPhoneLandscapePlan, available: Vector2, card_height: float, gap: float
) -> void:
	if not plan.feasible or card_height <= 0.0:
		return
	var maximum: float = available.y - plan.center.size.y
	if maximum < 0.0:
		return
	var desired: float = (available.y - card_height) * 0.5
	var candidates: Array[float] = [clampf(desired, 0.0, maximum), 0.0, maximum]
	var obstacles: Array[Rect2] = [plan.actions]
	obstacles.append_array(plan.seats.values())
	for rect: Rect2 in obstacles:
		if rect.position.x < plan.center.end.x and rect.end.x > plan.center.position.x:
			candidates.append(clampf(rect.position.y - plan.center.size.y - gap, 0.0, maximum))
			candidates.append(clampf(rect.end.y + gap, 0.0, maximum))
	var closest: float = INF
	for y: float in candidates:
		var candidate := Rect2(Vector2(plan.center.position.x, y), plan.center.size)
		var clear: bool = true
		for rect: Rect2 in obstacles:
			if candidate.intersects(rect.grow_individual(0.0, gap, 0.0, gap)):
				clear = false
				break
		var distance: float = absf(y - desired)
		if clear and distance < closest:
			closest = distance
			plan.center.position.y = y
