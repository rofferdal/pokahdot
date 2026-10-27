class_name GuiPhoneTokenContentPlan
extends RefCounted

## Finite row packing for measured phone token content. Name and stack retain
## their first/second rows; every remaining public field occupies one whole cell.
const GAP: float = 2.0
const ROW_HEIGHT: float = 28.0
var rects: Dictionary[String, Rect2] = {}
var _rows: Array[Array] = [[], [], []]
var _widths: Dictionary[String, float] = {}
var _available: float
var _revealed: bool


func configure(token_width: float, widths: Dictionary[String, float], revealed: bool) -> bool:
	rects.clear()
	_rows = [["Name"], ["Stack"], []]
	_widths = widths
	_available = token_width - 8.0
	_revealed = revealed
	if widths.Name > _available or widths.Stack > _available:
		return false
	var pending: Array[String] = []
	for key: String in widths:
		if key not in ["Name", "Stack"]:
			pending.append(key)
	if not _assign(pending, 0):
		return false
	for row: int in range(3):
		var x: float = 4.0
		for key: String in _rows[row]:
			rects[key] = Rect2(x, row * ROW_HEIGHT, widths[key], 30.0 if row == 2 else ROW_HEIGHT)
			x += widths[key] + GAP
	return true


func _assign(pending: Array[String], index: int) -> bool:
	if index == pending.size():
		return true
	var key: String = pending[index]
	var choices: Array[int] = [0, 1, 2]
	if not key.begins_with("Badge"):
		choices.assign([2, 1, 0])
	if key == "HoleCards" and _revealed:
		choices.assign([2])
	for row: int in choices:
		var used: float = 0.0
		for existing: String in _rows[row]:
			used += _widths[existing] + GAP
		if used + _widths[key] > _available:
			continue
		_rows[row].append(key)
		if _assign(pending, index + 1):
			return true
		_rows[row].pop_back()
	return false
