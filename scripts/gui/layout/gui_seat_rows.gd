class_name GuiSeatRows
extends RefCounted

## Explicit rows, top to bottom. Input IDs are in core clockwise order.
## The recipient occupies its own bottom row; status bands belong to each seat.
var valid: bool = false
var rows: Array[PackedInt32Array] = []
var clockwise_ids := PackedInt32Array()


static func compose(ids: PackedInt32Array, recipient: int, portrait_phone: bool) -> GuiSeatRows:
	var result := GuiSeatRows.new()
	if ids.size() < 2 or ids.size() > 9 or not ids.has(recipient):
		return result
	var seen: Dictionary[int, bool] = {}
	for id: int in ids:
		if id < 0 or seen.has(id):
			return result
		seen[id] = true
	var start: int = ids.find(recipient)
	for offset: int in range(1, ids.size()):
		result.clockwise_ids.append(ids[(start + offset) % ids.size()])
	result.clockwise_ids.append(recipient)
	var opponents: int = ids.size() - 1
	# Portrait odd counts have a centered apex; wide uses the same symmetric
	# ring topology with complete left/right rows around its reserved center.
	var apex_count: int = 1 if opponents % 2 == 1 else 2
	if not portrait_phone and opponents >= 3 and opponents % 2 == 1:
		apex_count = 3
	var side_rows: int = (opponents - apex_count) / 2
	result.rows.append(PackedInt32Array())
	for index: int in side_rows:
		result.rows.append(PackedInt32Array([-1, -1]))
	var cursor: int = 0
	for index: int in range(side_rows, 0, -1):
		result.rows[index][0] = result.clockwise_ids[cursor]
		cursor += 1
	for index: int in apex_count:
		result.rows[0].append(result.clockwise_ids[cursor])
		cursor += 1
	for index: int in range(1, side_rows + 1):
		result.rows[index][1] = result.clockwise_ids[cursor]
		cursor += 1
	result.rows.append(PackedInt32Array([recipient]))
	result.valid = true
	return result
