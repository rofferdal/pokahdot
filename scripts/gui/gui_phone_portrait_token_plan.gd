class_name GuiPhonePortraitTokenPlan
extends RefCounted

## Finite packing of disjoint public-information rows on portrait phones.
const INSET: float = 4.0
const GAP: float = 4.0
const ROW_HEIGHT: float = 30.0
var rects: Dictionary[String, Rect2] = {}
var height: float = 0.0
var _rows: Array[Array] = []
var _widths: Dictionary[String, float] = {}
var _available: float = 0.0
var _revealed: bool = false
var _comfortable: bool = false
var _text_row_height: float = ROW_HEIGHT


static func minimum_width(widths: Dictionary[String, float]) -> float:
	var result: float = 48.0
	for width: float in widths.values():
		result = maxf(result, width + INSET * 2.0)
	return result


func configure(
	width: float,
	widths: Dictionary[String, float],
	comfortable: bool = false,
	text_row_height: float = ROW_HEIGHT,
	vertical_cards: bool = false,
) -> bool:
	rects.clear()
	if minimum_width(widths) > width:
		return false
	_widths = widths
	_available = width - INSET * 2.0
	_revealed = widths.HoleCards > 40.0
	_comfortable = comfortable
	_text_row_height = text_row_height
	if vertical_cards and _revealed and _configure_vertical_cards(width, widths):
		return true
	var pending: Array[String] = []
	for key: String in ["Badge", "HoleCards", "ActionBadge"]:
		if widths.get(key, 0.0) > 0.0:
			pending.append(key)
	for row_count: int in range(3, 6):
		_rows = [["Name"], ["Stack"]]
		while _rows.size() < row_count:
			_rows.append([])
		if _assign(pending, 0):
			break
		if row_count == 5:
			return false
	var vertical_inset: float = INSET if comfortable else 2.0
	var y: float = vertical_inset
	for row: Array in _rows:
		if row.is_empty():
			continue
		var row_height: float = maxf(
			_text_row_height + (2.0 if "Badge" in row else 0.0),
			30.0 if "HoleCards" in row else 0.0,
		)
		var remaining: float = 0.0
		for key: String in row.slice(1):
			remaining += widths[key] + GAP
		var x: float = INSET
		for index: int in range(row.size()):
			var key: String = row[index]
			var field_width: float = _available - remaining if index == 0 else widths[key]
			rects[key] = Rect2(x, y, field_width, row_height)
			x += field_width + GAP
		y += row_height
	# Empty state labels remain available to semantic observers, below the name.
	if not rects.has("Badge"):
		rects["Badge"] = Rect2(INSET, vertical_inset + _text_row_height, 0.0, _text_row_height)
	height = y + vertical_inset
	return true


func _configure_vertical_cards(width: float, widths: Dictionary[String, float]) -> bool:
	var inset: float = 3.0
	var card_width: float = (widths.HoleCards - 2.0) * 0.5
	var left_width: float = width - inset * 2.0 - card_width - GAP
	var badge_width: float = widths.get("Badge", 0.0)
	if widths.Name > left_width or widths.Stack > left_width:
		return false
	var badge_on_name: bool = badge_width > 0.0 and widths.Name + badge_width + GAP <= left_width
	if badge_width > 0.0 and not badge_on_name and widths.Stack + badge_width + GAP > left_width:
		return false
	var first_height: float = _text_row_height + (2.0 if badge_on_name else 0.0)
	rects["Name"] = Rect2(
		inset, 2.0, left_width - (badge_width + GAP if badge_on_name else 0.0), first_height
	)
	rects["Stack"] = Rect2(
		inset,
		2.0 + first_height,
		left_width - (badge_width + GAP if badge_width > 0.0 and not badge_on_name else 0.0),
		_text_row_height + (2.0 if badge_width > 0.0 and not badge_on_name else 0.0)
	)
	rects["Badge"] = Rect2(
		inset + left_width - badge_width,
		2.0 if badge_on_name else 2.0 + first_height,
		badge_width,
		first_height if badge_on_name else _text_row_height + 2.0
	)
	rects["HoleCards"] = Rect2(width - inset - card_width, 2.0, card_width, 60.0)
	height = maxf(60.0, first_height + rects.Stack.size.y) + 4.0
	return true


func _assign(pending: Array[String], index: int) -> bool:
	if index == pending.size():
		return true
	var key: String = pending[index]
	var choices: Array[int] = []
	if key == "Badge":
		choices.assign(range(_rows.size()))
	elif key == "HoleCards":
		choices.assign(range(2 if _revealed or _comfortable else 1, _rows.size()))
	else:
		choices.assign(range(2, _rows.size()))
		choices.append(1)
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
