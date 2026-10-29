class_name GuiPhoneTablePlan
extends RefCounted

## Pure measured envelopes; no viewport classification or poker rules.
var valid: bool = false
var feasible: bool = false
var minimum := Vector2.ZERO
var rows: Array[PackedInt32Array] = []
var columns: int = 2
var opponent_width: float = 0.0
var left_width: float = 0.0
var right_width: float = 0.0
var hero_width: float = 0.0


static func resolve(
	ids: PackedInt32Array,
	hero: int,
	minima: Dictionary[int, Vector2],
	board: Vector2,
	actions: Vector2,
	landscape: bool,
	available: Vector2,
	gap: float = 4.0
) -> GuiPhoneTablePlan:
	var invalid := GuiPhoneTablePlan.new()
	if ids.size() < 2 or ids.size() > 7 or not minima.has(hero) or not available.is_finite():
		return invalid
	if available.x < 0 or available.y < 0 or not is_finite(gap) or gap < 0:
		return invalid
	if not _positive(board) or not _positive(actions) or minima.size() != ids.size():
		return invalid
	for id: int in ids:
		if not minima.has(id) or not _positive(minima[id]):
			return invalid
	if landscape:
		var geometry: GuiPhoneLandscapePlan = GuiPhoneLandscapePlan.resolve(
			ids, hero, minima, board, actions, available, gap
		)
		var measured := GuiPhoneTablePlan.new()
		measured.valid = geometry.valid
		measured.feasible = geometry.feasible
		measured.minimum = geometry.minimum
		measured.rows = geometry.rows.duplicate()
		measured.opponent_width = geometry.opponent_width
		measured.hero_width = geometry.hero_width
		measured.right_width = actions.x
		return measured
	var ordered: GuiSeatRows = GuiSeatRows.compose(ids, hero, true)
	if not ordered.valid:
		return invalid
	var candidates: Array[GuiPhoneTablePlan] = []
	for columns: int in [2, 1]:
		var candidate := GuiPhoneTablePlan.new()
		candidate.columns = columns
		candidate.rows = ordered.rows.duplicate()
		if columns == 1:
			candidate.rows.clear()
			for id: int in ordered.clockwise_ids:
				if id != hero:
					candidate.rows.append(PackedInt32Array([id]))
			candidate.rows.append(PackedInt32Array([hero]))
		var grid_height: float = 0.0
		for row: PackedInt32Array in candidate.rows:
			if row.has(hero):
				continue
			var height: float = 0.0
			for id: int in row:
				if not minima.has(id) or minima[id].x <= 0 or minima[id].y <= 0:
					return invalid
				candidate.opponent_width = maxf(candidate.opponent_width, minima[id].x)
				height = maxf(height, minima[id].y)
			grid_height += height + (gap if grid_height > 0 else 0.0)
		var grid_columns: int = mini(columns, ids.size() - 1)
		var grid_width: float = grid_columns * candidate.opponent_width + (grid_columns - 1) * gap
		candidate.left_width = maxf(grid_width, board.x)
		candidate.hero_width = maxf(minima[hero].x, candidate.opponent_width + 2.0 * gap)
		candidate.right_width = maxf(candidate.hero_width, actions.x)
		candidate.minimum = Vector2(
			maxf(candidate.left_width, candidate.right_width),
			grid_height + board.y + minima[hero].y + actions.y + 4.0 * gap
		)

		candidate.valid = (
			candidate.minimum.is_finite() and candidate.minimum.x > 0 and candidate.minimum.y > 0
		)
		candidate.feasible = (
			candidate.valid
			and available.x >= candidate.minimum.x
			and available.y >= candidate.minimum.y
		)
		candidates.append(candidate)
		if candidate.feasible:
			return candidate
	# Prefer the shorter two-column presentation when neither fits; retain its
	# truthful complete envelope instead of combining incompatible minima.
	return candidates[0]


static func _positive(value: Vector2) -> bool:
	return value.is_finite() and value.x > 0 and value.y > 0
