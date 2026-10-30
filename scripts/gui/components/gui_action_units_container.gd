class_name GuiActionUnitsContainer
extends Container

## Places ordered action controls in one or two rows without changing parents.
var _units: Array[Control] = []
var _split: int = 0
var _gap: float = 0.0
var _centered: bool = false


func configure(units: Array[Control], split: int, gap: float, centered: bool) -> void:
	if _units == units and _split == split and _gap == gap and _centered == centered:
		return
	_units = units.duplicate()
	_split = split
	_gap = gap
	_centered = centered
	queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_arrange()


func _arrange() -> void:
	if _units.is_empty():
		return
	var height: float = 48.0
	for unit: Control in _units:
		height = maxf(height, unit.get_combined_minimum_size().y)
	var row_count: int = 2 if _split < _units.size() else 1
	var y: float = (size.y - row_count * height - (row_count - 1) * _gap) / 2.0
	for row: int in row_count:
		var begin: int = 0 if row == 0 else _split
		var end: int = _split if row == 0 else _units.size()
		var width: float = max(0, end - begin - 1) * _gap
		for index: int in range(begin, end):
			width += _units[index].get_combined_minimum_size().x
		var x: float = maxf(0.0, (size.x - width) / 2.0) if _centered else 0.0
		for index: int in range(begin, end):
			var unit: Control = _units[index]
			var unit_width: float = unit.get_combined_minimum_size().x
			fit_child_in_rect(unit, Rect2(x, y, unit_width, height))
			x += unit_width + _gap
		y += height + _gap
