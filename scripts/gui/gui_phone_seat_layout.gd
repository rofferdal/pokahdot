class_name GuiPhoneSeatLayout
extends RefCounted

## Pure presentation geometry for prototyping compact phone seat tokens.
##
## Seat 0 is the human-facing bottom position. The remaining seats are selected
## from eight stable clockwise perimeter slots. This class does not create
## controls or interpret poker state, so the later phone-token implementation
## can consume the same rectangles without entering the core layer.

enum Density {
	STANDARD,
	COMPACT,
	MINIMAL,
}

const MIN_PLAYER_COUNT: int = 2
const MAX_SUPPORTED_PLAYER_COUNT: int = 7
# Keep geometry for a larger match that began on a supported non-phone profile.
# This is a state-preservation fallback, not a phone startup capability.
const MAX_EMERGENCY_PLAYER_COUNT: int = 9
const RECOMMENDED_PHONE_PLAYER_COUNT: int = 4
const EDGE_MARGIN: float = 8.0
const SLOT_GAP: float = 8.0
const PORTRAIT_ROW_GAP: float = 8.0
const PORTRAIT_TOKEN_HEIGHT: float = 60.0


static func density_for(player_count: int) -> Density:
	if player_count <= 4:
		return Density.STANDARD
	if player_count <= 6:
		return Density.COMPACT
	return Density.MINIMAL


static func seat_rects(usable_size: Vector2, player_count: int) -> Dictionary[int, Rect2]:
	var rects: Dictionary[int, Rect2] = {}
	if not _has_valid_inputs(usable_size, player_count):
		return rects

	var token_size: Vector2 = _token_size(usable_size, density_for(player_count), player_count)
	var opponent_slots: Array[Rect2] = _opponent_slots(usable_size, token_size, player_count)
	var opponent_count: int = player_count - 1
	for opponent_index: int in range(opponent_count):
		var slot_index: int = floori(
			float(opponent_index) * float(opponent_slots.size()) / float(opponent_count)
		)
		rects[opponent_index + 1] = opponent_slots[slot_index]

	var hero_position := Vector2(
		(usable_size.x - token_size.x) * 0.5,
		usable_size.y - EDGE_MARGIN - token_size.y,
	)
	rects[0] = Rect2(hero_position, token_size)
	return rects


static func center_rect(
	usable_size: Vector2, player_count: int = MAX_SUPPORTED_PLAYER_COUNT
) -> Rect2:
	if usable_size.x <= 0.0 or usable_size.y <= 0.0:
		return Rect2()
	var portrait: bool = usable_size.y > usable_size.x
	var center_size := Vector2(
		minf(220.0, usable_size.x * (0.56 if portrait else 0.38)),
		minf(112.0, usable_size.y * (0.16 if portrait else 0.24)),
	)
	var center_position := Vector2(
		(usable_size.x - center_size.x) * 0.5,
		usable_size.y * (0.38 if portrait else 0.36),
	)
	if portrait and _has_valid_inputs(usable_size, player_count):
		var token_size: Vector2 = _token_size(usable_size, density_for(player_count), player_count)
		var opponent_slots: Array[Rect2] = _opponent_slots(usable_size, token_size, player_count)
		var opponent_bottom: float = 0.0
		var opponent_count: int = player_count - 1
		for opponent_index: int in range(opponent_count):
			var slot_index: int = floori(
				float(opponent_index) * float(opponent_slots.size()) / float(opponent_count)
			)
			opponent_bottom = maxf(opponent_bottom, opponent_slots[slot_index].end.y)
		center_position.y = maxf(center_position.y, opponent_bottom + 4.0)
	return Rect2(center_position, center_size)


static func _has_valid_inputs(usable_size: Vector2, player_count: int) -> bool:
	return (
		usable_size.x > 0.0
		and usable_size.y > 0.0
		and player_count >= MIN_PLAYER_COUNT
		and player_count <= MAX_EMERGENCY_PLAYER_COUNT
	)


static func _token_size(usable_size: Vector2, density: Density, player_count: int) -> Vector2:
	var portrait: bool = usable_size.y > usable_size.x
	var preferred_width: float = 168.0 if portrait else 160.0
	var height: float
	match density:
		Density.STANDARD:
			height = 60.0
		Density.COMPACT:
			height = 60.0
		_:
			height = 60.0
	if portrait and player_count <= MAX_SUPPORTED_PLAYER_COUNT:
		height = PORTRAIT_TOKEN_HEIGHT
	if player_count > MAX_SUPPORTED_PLAYER_COUNT:
		preferred_width = 78.0 if portrait else 88.0
		height = 48.0
	var top_column_count: float = 4.0 if player_count > MAX_SUPPORTED_PLAYER_COUNT else 2.0
	if not portrait and player_count <= MAX_SUPPORTED_PLAYER_COUNT:
		top_column_count = 3.0
	var top_row_width: float = (
		(usable_size.x - EDGE_MARGIN * 2.0 - SLOT_GAP * (top_column_count - 1.0)) / top_column_count
	)
	return Vector2(minf(preferred_width, top_row_width), height)


static func _opponent_slots(
	usable_size: Vector2, token_size: Vector2, player_count: int
) -> Array[Rect2]:
	var available_width: float = usable_size.x - EDGE_MARGIN * 2.0 - token_size.x
	var top_y: float = EDGE_MARGIN if usable_size.y > usable_size.x else 0.0
	if player_count <= MAX_SUPPORTED_PLAYER_COUNT:
		if usable_size.y > usable_size.x:
			return _supported_portrait_slots(usable_size, token_size, player_count)
		return _supported_opponent_slots(usable_size, token_size, top_y)
	var top_positions: Array[float] = [
		EDGE_MARGIN,
		EDGE_MARGIN + available_width / 3.0,
		EDGE_MARGIN + available_width * 2.0 / 3.0,
		EDGE_MARGIN + available_width,
	]
	var side_step: float = token_size.y + (4.0 if usable_size.x > usable_size.y else SLOT_GAP)
	var upper_side_y: float = EDGE_MARGIN + side_step
	var lower_side_y: float = EDGE_MARGIN + side_step * 2.0
	var right_x: float = usable_size.x - EDGE_MARGIN - token_size.x
	return [
		Rect2(Vector2(top_positions[0], top_y), token_size),
		Rect2(Vector2(top_positions[1], top_y), token_size),
		Rect2(Vector2(top_positions[2], top_y), token_size),
		Rect2(Vector2(top_positions[3], top_y), token_size),
		Rect2(Vector2(right_x, upper_side_y), token_size),
		Rect2(Vector2(right_x, lower_side_y), token_size),
		Rect2(Vector2(EDGE_MARGIN, lower_side_y), token_size),
		Rect2(Vector2(EDGE_MARGIN, upper_side_y), token_size),
	]


static func _supported_opponent_slots(
	usable_size: Vector2, token_size: Vector2, top_y: float
) -> Array[Rect2]:
	var left_x: float = 0.0
	var right_x: float = usable_size.x - token_size.x
	var side_step: float = token_size.y + (4.0 if usable_size.x > usable_size.y else SLOT_GAP)
	var upper_side_y: float = side_step
	var lower_side_y: float = side_step * 2.0
	return [
		Rect2(Vector2(left_x, top_y), token_size),
		Rect2(Vector2(right_x, top_y), token_size),
		Rect2(Vector2(right_x, upper_side_y), token_size),
		Rect2(Vector2(right_x, lower_side_y), token_size),
		Rect2(Vector2(left_x, lower_side_y), token_size),
		Rect2(Vector2(left_x, upper_side_y), token_size),
	]


static func _supported_portrait_slots(
	usable_size: Vector2, token_size: Vector2, player_count: int
) -> Array[Rect2]:
	var slots: Array[Rect2] = []
	var opponent_count: int = player_count - 1
	var right_x: float = usable_size.x - EDGE_MARGIN - token_size.x
	var center_x: float = (usable_size.x - token_size.x) * 0.5
	var row_step: float = token_size.y + PORTRAIT_ROW_GAP
	var top_y: float = EDGE_MARGIN
	var side_count: int = floori(float(opponent_count) / 2.0)
	var lowest_level: int = side_count if opponent_count % 2 == 1 else side_count - 1
	for level: int in range(lowest_level, 0 if opponent_count % 2 == 1 else -1, -1):
		slots.append(Rect2(Vector2(EDGE_MARGIN, top_y + row_step * level), token_size))
	if opponent_count % 2 == 1:
		slots.append(Rect2(Vector2(center_x, top_y), token_size))
	var first_right_level: int = 1 if opponent_count % 2 == 1 else 0
	for level: int in range(first_right_level, lowest_level + 1):
		slots.append(Rect2(Vector2(right_x, top_y + row_step * level), token_size))
	return slots
