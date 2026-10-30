class_name GuiPhoneSeatRows
extends Container

## Positions scene-owned opponent tokens without changing their parent or identity.
var _rows: Array[PackedInt32Array] = []
var _seats: Dictionary[int, Control] = {}
var _hero: int = -1
var _cell_width: float = 0.0
var _gap: float = 0.0


func configure(
	rows: Array[PackedInt32Array],
	seats: Dictionary[int, Control],
	hero: int,
	cell_width: float,
	gap: float
) -> void:
	if (
		_rows == rows
		and _seats == seats
		and _hero == hero
		and _cell_width == cell_width
		and _gap == gap
	):
		return
	_rows = rows.duplicate()
	_seats = seats.duplicate()
	_hero = hero
	_cell_width = cell_width
	_gap = gap
	update_minimum_size()
	queue_sort()


func _get_minimum_size() -> Vector2:
	var minimum := Vector2.ZERO
	var row_count: int = 0
	for row: PackedInt32Array in _rows:
		if row.has(_hero):
			continue
		var height: float = 0.0
		for id: int in row:
			if _seats.has(id):
				height = maxf(height, _seats[id].get_combined_minimum_size().y)
		minimum.x = maxf(minimum.x, row.size() * _cell_width + max(0, row.size() - 1) * _gap)
		minimum.y += height
		row_count += 1
	minimum.y += max(0, row_count - 1) * _gap
	return minimum


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_arrange()


func _arrange() -> void:
	var top: float = 0.0
	for row: PackedInt32Array in _rows:
		if row.has(_hero):
			continue
		var height: float = 0.0
		for id: int in row:
			if _seats.has(id):
				height = maxf(height, _seats[id].get_combined_minimum_size().y)
		var left: float = (size.x - row.size() * _cell_width - max(0, row.size() - 1) * _gap) / 2.0
		for id: int in row:
			if _seats.has(id):
				fit_child_in_rect(_seats[id], Rect2(left, top, _cell_width, height))
			left += _cell_width + _gap
		top += height + _gap
