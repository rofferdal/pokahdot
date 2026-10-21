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
