class_name TableSeatLayout
extends RefCounted

## Owns the presentation-only normalized placements for supported table sizes.


static func symmetric_positions(seat_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	match seat_count:
		2:
			positions = [Vector2(0.5, 0.08), Vector2(0.5, 0.91)]
		3:
			positions = [Vector2(0.85, 0.32), Vector2(0.5, 0.91), Vector2(0.15, 0.32)]
		4:
			positions = [
				Vector2(0.5, 0.06), Vector2(0.88, 0.36), Vector2(0.5, 0.91), Vector2(0.12, 0.36)
			]
		5:
			positions = [
				Vector2(0.72, 0.12),
				Vector2(0.86, 0.55),
				Vector2(0.5, 0.91),
				Vector2(0.14, 0.55),
				Vector2(0.28, 0.12)
			]
		6:
			positions = [
				Vector2(0.5, 0.08),
				Vector2(0.88, 0.30),
				Vector2(0.80, 0.60),
				Vector2(0.5, 0.91),
				Vector2(0.20, 0.60),
				Vector2(0.12, 0.30)
			]
		7:
			positions = [
				Vector2(0.70, 0.06),
				Vector2(0.88, 0.40),
				Vector2(0.78, 0.72),
				Vector2(0.5, 0.91),
				Vector2(0.22, 0.72),
				Vector2(0.12, 0.40),
				Vector2(0.30, 0.06)
			]
		8:
			positions = [
				Vector2(0.5, 0.05),
				Vector2(0.82, 0.19),
				Vector2(0.90, 0.48),
				Vector2(0.74, 0.72),
				Vector2(0.5, 0.91),
				Vector2(0.26, 0.72),
				Vector2(0.10, 0.48),
				Vector2(0.18, 0.19)
			]
		9:
			positions = [
				Vector2(0.80, 0.05),
				Vector2(0.90, 0.30),
				Vector2(0.90, 0.52),
				Vector2(0.75, 0.72),
				Vector2(0.5, 0.91),
				Vector2(0.25, 0.72),
				Vector2(0.10, 0.52),
				Vector2(0.10, 0.30),
				Vector2(0.20, 0.05)
			]
		_:
			push_error("TableSeatLayout does not support %d seats." % seat_count)
	return positions


static func compact_desktop_positions(seat_count: int) -> Array[Vector2]:
	if seat_count == 9:
		# Nine source-sized seat panels cannot fit the regular five-row desktop
		# ring on a short 1140x632 surface. Use three side-column levels and two
		# centered upper seats while keeping the human at the bottom center.
		return [
			Vector2(0.5, 0.05),
			Vector2(0.88, 0.05),
			Vector2(0.88, 0.40),
			Vector2(0.88, 0.80),
			Vector2(0.5, 0.91),
			Vector2(0.12, 0.80),
			Vector2(0.12, 0.40),
			Vector2(0.12, 0.05),
			Vector2(0.5, 0.40),
		]
	return symmetric_positions(seat_count)


static func landscape_tablet_positions(seat_count: int) -> Array[Vector2]:
	if seat_count == 7:
		# Keep the side seats outside the event/action columns. The upper pair
		# also has a dedicated summary band above it for showdown text.
		return [
			Vector2(0.70, 0.20),
			Vector2(0.88, 0.38),
			Vector2(0.78, 0.64),
			Vector2(0.5, 0.91),
			Vector2(0.22, 0.64),
			Vector2(0.12, 0.38),
			Vector2(0.30, 0.20),
		]
	return symmetric_positions(seat_count)


static func compact_tablet_positions(seat_count: int) -> Array[Vector2]:
	# Compact logical iPad canvases need the same table-shaped ordering as the
	# full layout, but side seats must stay outside the centered board. Values
	# are mirrored around x=0.5 and rise toward the upper center.
	match seat_count:
		2:
			return [Vector2(0.5, 0.05), Vector2(0.5, 0.91)]
		3:
			return [Vector2(0.87, 0.28), Vector2(0.5, 0.91), Vector2(0.13, 0.28)]
		4:
			return [
				Vector2(0.5, 0.05),
				Vector2(0.87, 0.34),
				Vector2(0.5, 0.91),
				Vector2(0.13, 0.34),
			]
		5:
			return [
				Vector2(0.68, 0.06),
				Vector2(0.87, 0.40),
				Vector2(0.5, 0.91),
				Vector2(0.13, 0.40),
				Vector2(0.32, 0.06),
			]
		6:
			return [
				Vector2(0.5, 0.04),
				Vector2(0.87, 0.27),
				Vector2(0.87, 0.58),
				Vector2(0.5, 0.91),
				Vector2(0.13, 0.58),
				Vector2(0.13, 0.27),
			]
		7:
			return [
				Vector2(0.68, 0.06),
				Vector2(0.87, 0.32),
				Vector2(0.87, 0.59),
				Vector2(0.5, 0.91),
				Vector2(0.13, 0.59),
				Vector2(0.13, 0.32),
				Vector2(0.32, 0.06),
			]
		8:
			return [
				Vector2(0.5, 0.04),
				Vector2(0.72, 0.16),
				Vector2(0.87, 0.38),
				Vector2(0.87, 0.61),
				Vector2(0.5, 0.91),
				Vector2(0.13, 0.61),
				Vector2(0.13, 0.38),
				Vector2(0.28, 0.16),
			]
		9:
			return [
				Vector2(0.625, 0.04),
				Vector2(0.875, 0.04),
				Vector2(0.875, 0.32),
				Vector2(0.875, 0.58),
				Vector2(0.5, 0.91),
				Vector2(0.125, 0.58),
				Vector2(0.125, 0.32),
				Vector2(0.125, 0.04),
				Vector2(0.375, 0.04),
			]
		_:
			push_error("TableSeatLayout does not support %d compact tablet seats." % seat_count)
			return []


static func compact_tablet_portrait_positions(seat_count: int) -> Array[Vector2]:
	if seat_count == 9:
		# Portrait has enough vertical room for four mirrored arc levels. Avoid
		# shrinking four panels into one top row as required on short landscape.
		return [
			Vector2(0.87, 0.05),
			Vector2(0.87, 0.23),
			Vector2(0.87, 0.41),
			Vector2(0.87, 0.59),
			Vector2(0.5, 0.91),
			Vector2(0.13, 0.59),
			Vector2(0.13, 0.41),
			Vector2(0.13, 0.23),
			Vector2(0.13, 0.05),
		]
	return compact_tablet_positions(seat_count)


static func small_desktop_positions(seat_count: int) -> Array[Vector2]:
	if seat_count == 7:
		# Short desktop surfaces need the upper pair and side seats outside the
		# fixed central zone while leaving the bottom center for the human seat.
		return [
			Vector2(0.82, 0.24),
			Vector2(0.94, 0.24),
			Vector2(0.88, 0.90),
			Vector2(0.5, 0.96),
			Vector2(0.12, 0.90),
			Vector2(0.06, 0.24),
			Vector2(0.18, 0.24),
		]
	return compact_desktop_positions(seat_count)


static func small_desktop_opponent_positions(
	seat_count: int, surface_size: Vector2, center_rect: Rect2, cell_size: Vector2
) -> Array[Vector2]:
	# Preserve the occupied grid cells, then assign their perimeter order to
	# relative core seats. Authored cell sizes keep folds/reveals from changing
	# ownership; neither player insertion order nor optional content is an input.
	if seat_count < 2 or seat_count > 9:
		push_error("TableSeatLayout does not support %d small desktop seats." % seat_count)
		return []
	var occupancy: Array[int] = [1, 2, 0, 3, 5, 6, 4, 7]
	var columns: Array[float] = [
		0.0, center_rect.position.x - cell_size.x, center_rect.end.x, surface_size.x - cell_size.x
	]
	var cells: Array[int] = []
	var positions: Dictionary[int, Vector2] = {}
	var angles: Dictionary[int, float] = {}
	for index: int in range(seat_count - 1):
		var cell: int = occupancy[index]
		var position := Vector2(columns[cell % 4], (cell / 4) * 172.0)
		var delta: Vector2 = position + cell_size * 0.5 - surface_size * 0.5
		cells.append(cell)
		positions[cell] = position
		angles[cell] = fposmod(atan2(delta.x, -delta.y) - PI, TAU)
	cells.sort_custom(
		func(first: int, second: int) -> bool:
			if angles[first] == angles[second]:
				return first < second
			return angles[first] < angles[second]
	)
	var ordered: Array[Vector2] = []
	for cell: int in cells:
		ordered.append(positions[cell])
	return ordered
