class_name GuiSeatRingPlan
extends RefCounted

## Detached complete-footprint plan. Invalid/infeasible plans publish no geometry.
var valid: bool = false
var feasible: bool = false
var error: String = ""
var minimum := Vector2.ZERO
var seats: Dictionary[int, Rect2] = {}
var rows: Array[PackedInt32Array] = []
var center := Rect2()
var lower := Rect2()
var visual_slots: Dictionary[int, int] = {}


static func resolve(
	minima: Dictionary[int, Vector2],
	hero: int,
	template: GuiSeatSlotTemplate,
	center_min: Vector2,
	lower_min: Vector2,
	available: Vector2,
	gap: float = 8.0,
	margin: Vector2 = Vector2(8, 8),
	corner_radius: float = 0.0,
	border_width: float = 0.0,
	hero_drop: float = 0.0,
	apex_gap: float = 0.0
) -> GuiSeatRingPlan:
	if template == null:
		return _invalid("missing-template")
	var template_error: String = template.validation_error()
	if not template_error.is_empty():
		return _invalid(template_error)
	if minima.size() != template.seat_count or not minima.has(hero):
		return _invalid("seat-identity")
	if not _positive(center_min) or not (lower_min == Vector2.ZERO or _positive(lower_min)):
		return _invalid("reserved-minimum")
	if not _nonnegative(available) or not _nonnegative(margin):
		return _invalid("available-or-margin")
	for metric: float in [gap, corner_radius, border_width, hero_drop, apex_gap]:
		if not is_finite(metric) or metric < 0.0:
			return _invalid("invalid-metric")
	var ids: Array[int] = []
	var opponent_width: float = 0.0
	for id: int in minima:
		if id < 0 or id > 2147483647 or not _positive(minima[id]):
			return _invalid("seat-minimum")
		ids.append(id)
		if id != hero:
			opponent_width = maxf(opponent_width, minima[id].x)
	ids.sort()
	var result := GuiSeatRingPlan.new()
	var hero_rank: int = ids.find(hero)
	var hero_visual: int = floori(ids.size() / 2.0)
	var bottom: int = template.slots[hero_visual].y
	var row_heights: Array[float] = []
	for row: int in range(bottom + 1):
		result.rows.append(PackedInt32Array())
		row_heights.append(0.0)
	for rank: int in ids.size():
		var id: int = ids[rank]
		var visual: int = posmod(hero_visual + rank - hero_rank, ids.size())
		result.visual_slots[id] = visual
		var slot: Vector2i = template.slots[visual]
		row_heights[slot.y] = maxf(row_heights[slot.y], minima[id].y)
	for row: int in range(bottom + 1):
		for column: int in 3:
			for id: int in ids:
				if template.slots[result.visual_slots[id]] == Vector2i(column, row):
					result.rows[row].append(id)
	var pair_gap: float = maxf(gap, apex_gap)
	var content_width: float = maxf(center_min.x, lower_min.x)
	for row_index: int in result.rows.size():
		var row: PackedInt32Array = result.rows[row_index]
		var row_gap: float = pair_gap if row_index == 0 and row.size() == 2 else gap
		var width: float = maxf(0.0, row.size() - 1) * row_gap
		for id: int in row:
			width += (
				minima[id].x if template.slots[result.visual_slots[id]].x == 1 else opponent_width
			)
		content_width = maxf(content_width, width)
	var body_height: float = 0.0
	for row: int in range(1, bottom):
		body_height += row_heights[row]
		if row > 1:
			body_height += gap
	if bottom > 1:
		content_width = maxf(content_width, 2.0 * opponent_width + center_min.x + 2.0 * gap)
	body_height = maxf(body_height, center_min.y)
	var content_height: float = row_heights[0] + body_height + row_heights[bottom] + 2.0 * gap
	var has_lower: bool = lower_min != Vector2.ZERO
	if has_lower:
		content_height += gap + lower_min.y
	# Equal horizontal/vertical insets keep every point of the inner rectangle
	# inside the rounded inner felt, including its 45-degree corner tangency.
	var inner_radius: float = maxf(0.0, corner_radius - border_width)
	var safe_inset: float = border_width + ceilf(inner_radius * (1.0 - 1.0 / sqrt(2.0)))
	var padding: Vector2 = margin + Vector2.ONE * safe_inset
	result.minimum = Vector2(
		maxf(content_width + 2.0 * padding.x, 2.0 * corner_radius),
		maxf(content_height + 2.0 * padding.y, 2.0 * corner_radius) + hero_drop
	)
	if not result.minimum.is_finite():
		return _invalid("minimum-overflow")
	result.valid = true
	if available.x < result.minimum.x or available.y < result.minimum.y:
		result.error = "insufficient-space"
		return result
	result.feasible = true
	var top_y: float = padding.y
	var bottom_y: float = available.y - padding.y - row_heights[bottom] - hero_drop
	if has_lower:
		result.lower = Rect2(
			Vector2((available.x - lower_min.x) * 0.5, available.y - padding.y - lower_min.y),
			lower_min
		)
		bottom_y -= gap + lower_min.y
	var body_y: float = top_y + row_heights[0] + gap
	body_height = bottom_y - gap - body_y
	result.center = Rect2(
		Vector2((available.x - center_min.x) * 0.5, body_y + (body_height - center_min.y) * 0.5),
		center_min
	)
	var row_y: Array[float] = [top_y]
	if bottom > 1:
		var side_height: float = 0.0
		for row: int in range(1, bottom):
			side_height += row_heights[row]
		var side_gap: float = (body_height - side_height) / float(bottom - 2) if bottom > 2 else 0.0
		var cursor: float = body_y if bottom > 2 else body_y + (body_height - side_height) * 0.5
		for row: int in range(1, bottom):
			row_y.append(cursor)
			cursor += row_heights[row] + side_gap
	row_y.append(bottom_y)
	for id: int in ids:
		var slot: Vector2i = template.slots[result.visual_slots[id]]
		var extent: Vector2 = minima[id]
		var x: float = (available.x - extent.x) * 0.5
		if slot.x == 0:
			x = padding.x
		elif slot.x == 2:
			x = available.x - padding.x - extent.x
		var y: float = row_y[slot.y]
		if slot.y == bottom:
			y += row_heights[bottom] - extent.y
			if id == hero:
				y += hero_drop
		elif slot.y > 0:
			y += (row_heights[slot.y] - extent.y) * 0.5
		result.seats[id] = Rect2(Vector2(x, y), extent)
	return result


static func _invalid(reason: String) -> GuiSeatRingPlan:
	var result := GuiSeatRingPlan.new()
	result.error = reason
	return result


static func _positive(value: Vector2) -> bool:
	return value.is_finite() and value.x > 0.0 and value.y > 0.0


static func _nonnegative(value: Vector2) -> bool:
	return value.is_finite() and value.x >= 0.0 and value.y >= 0.0
