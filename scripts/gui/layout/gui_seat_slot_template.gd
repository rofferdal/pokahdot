class_name GuiSeatSlotTemplate
extends Resource

## Indexed by clockwise visual slot. Columns are left/center/right (0/1/2).
## The recipient maps to floor(seat_count/2) at bottom center.
@export var seat_count: int = 0
@export var slots: Array[Vector2i] = []


static func load_for_count(count: int) -> GuiSeatSlotTemplate:
	if count < 2 or count > 9:
		return null
	var path: String = "res://resources/gui_seat_slots/seats_%d.tres" % count
	return load(path) as GuiSeatSlotTemplate if ResourceLoader.exists(path) else null


func validation_error() -> String:
	if seat_count < 2 or seat_count > 9 or slots.size() != seat_count:
		return "template-count"
	var hero_slot: int = floori(seat_count / 2.0)
	var bottom: int = slots[hero_slot].y
	if bottom < 1 or bottom >= seat_count or slots[hero_slot].x != 1:
		return "template-hero"
	var schema_error: String = _slot_schema_error(hero_slot, bottom)
	return schema_error if not schema_error.is_empty() else _clockwise_error(hero_slot)


func _slot_schema_error(hero_slot: int, bottom: int) -> String:
	var seen: Dictionary[Vector2i, bool] = {}
	var populations: Dictionary[int, int] = {}
	for index: int in slots.size():
		var slot: Vector2i = slots[index]
		if slot.x < 0 or slot.x > 2 or slot.y < 0 or slot.y > bottom or seen.has(slot):
			return "template-slot"
		seen[slot] = true
		populations[slot.y] = populations.get(slot.y, 0) + 1
		if populations[slot.y] > 2 or (slot.y == bottom and index != hero_slot):
			return "template-row-cap"
		var reflected: Vector2i = slots[posmod(2 * hero_slot - index, seat_count)]
		if reflected != Vector2i(2 - slot.x, slot.y):
			return "template-mirror"
	for row: int in range(bottom + 1):
		if not populations.has(row):
			return "template-empty-row"
		if row > 0 and row < bottom:
			if not seen.has(Vector2i(0, row)) or not seen.has(Vector2i(2, row)):
				return "template-side-row"
	return ""


func _clockwise_error(hero_slot: int) -> String:
	for index: int in slots.size():
		var slot: Vector2i = slots[index]
		if index != hero_slot:
			if slot.x == 1 and (index != 0 or slot.y != 0):
				return "template-center"
			if index < hero_slot and slot.x == 0:
				return "template-clockwise"
			if index > hero_slot and slot.x != 0:
				return "template-clockwise"
		if index > 0 and index <= hero_slot and slot.y < slots[index - 1].y:
			return "template-clockwise"
		if index > hero_slot + 1 and slot.y > slots[index - 1].y:
			return "template-clockwise"
	return ""
