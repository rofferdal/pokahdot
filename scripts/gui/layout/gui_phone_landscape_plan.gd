class_name GuiPhoneLandscapePlan
extends RefCounted

## Symmetric complete footprints around one shared board/hero vertical midline.
var valid: bool = false
var feasible: bool = false
var minimum := Vector2.ZERO
var seats: Dictionary[int, Rect2] = {}
var rows: Array[PackedInt32Array] = []
var center := Rect2()
var actions := Rect2()
var opponent_width: float = 0.0
var hero_width: float = 0.0


static func resolve(
	ids: PackedInt32Array,
	hero: int,
	minima: Dictionary[int, Vector2],
	board: Vector2,
	action_minimum: Vector2,
	available: Vector2,
	gap: float = 4.0
) -> GuiPhoneLandscapePlan:
	var result := GuiPhoneLandscapePlan.new()
	if ids.size() < 2 or ids.size() > 7 or minima.size() != ids.size():
		return result
	if not _positive(board) or not _positive(action_minimum) or not available.is_finite():
		return result
	if available.x < 0 or available.y < 0 or not is_finite(gap) or gap < 0:
		return result
	for id: int in ids:
		if not minima.has(id) or not _positive(minima[id]):
			return result
	var ordered: GuiSeatRows = GuiSeatRows.compose(ids, hero, true)
	if not ordered.valid:
		return result
	result.rows = ordered.rows.duplicate()
	for id: int in ids:
		if id != hero:
			result.opponent_width = maxf(result.opponent_width, minima[id].x)
	result.hero_width = maxf(minima[hero].x, result.opponent_width + 2.0 * gap)
	var has_apex: bool = result.rows[0].size() == 1
	var body_top: float = minima[result.rows[0][0]].y + gap if has_apex else 0.0
	var pair_heights: Array[float] = []
	var side_height: float = 0.0
	for index: int in range(1 if has_apex else 0, result.rows.size() - 1):
		var row: PackedInt32Array = result.rows[index]
		var height: float = maxf(minima[row[0]].y, minima[row[1]].y)
		pair_heights.append(height)
		side_height += height + (gap if pair_heights.size() > 1 else 0.0)
	var center_width: float = maxf(board.x, result.hero_width)
	var upper_width: float = board.x
	if not pair_heights.is_empty():
		upper_width += 2.0 * (result.opponent_width + gap)
	result.minimum = Vector2(
		maxf(upper_width, center_width + 2.0 * (action_minimum.x + gap)),
		body_top + maxf(side_height, board.y) + gap + maxf(minima[hero].y, action_minimum.y)
	)
	result.valid = result.minimum.is_finite()
	if not result.valid or available.x < result.minimum.x or available.y < result.minimum.y:
		return result
	result.feasible = true
	result.seats[hero] = Rect2(
		Vector2((available.x - result.hero_width) * 0.5, available.y - minima[hero].y),
		Vector2(result.hero_width, minima[hero].y)
	)
	result.center = Rect2(
		Vector2((available.x - board.x) * 0.5, result.seats[hero].position.y - gap - board.y), board
	)
	result.actions = Rect2(
		Vector2((available.x + center_width) * 0.5 + gap, available.y - action_minimum.y),
		action_minimum
	)
	if has_apex:
		var apex: int = result.rows[0][0]
		result.seats[apex] = Rect2(
			Vector2((available.x - result.opponent_width) * 0.5, 0),
			Vector2(result.opponent_width, minima[apex].y)
		)
	var y: float = body_top
	for index: int in pair_heights.size():
		var row: PackedInt32Array = result.rows[index + (1 if has_apex else 0)]
		var extent := Vector2(result.opponent_width, pair_heights[index])
		result.seats[row[0]] = Rect2(Vector2(0, y), extent)
		result.seats[row[1]] = Rect2(Vector2(available.x - result.opponent_width, y), extent)
		y += extent.y + gap
	return result


static func _positive(value: Vector2) -> bool:
	return value.is_finite() and value.x > 0 and value.y > 0
