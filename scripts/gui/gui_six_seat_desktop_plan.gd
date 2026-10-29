class_name GuiSixSeatDesktopPlan
extends RefCounted

## One geometry owner for the compact six-seat desktop composition.
## Complete status bands are reserved before any rectangle is applied.

const FULL_DENSITY_WIDTH: float = 1600.0
const GAP: float = 8.0
const STATUS_GAP: float = 2.0
const STATUS_HEIGHT: float = 64.0
const OPPONENT_HEIGHT: float = 102.0
const LOWER_RAIL_HEIGHT: float = 150.0

var seat_rects: Dictionary[int, Rect2] = {}
var status_rects: Dictionary[int, Rect2] = {}
var center_rect: Rect2
var hero_rect: Rect2
var event_rect: Rect2
var action_rect: Rect2
var quit_rect: Rect2


static func can_use(surface_size: Vector2, profile: int, player_count: int, large: bool) -> bool:
	if profile != GuiLayoutProfile.Kind.DESKTOP or player_count != 6:
		return false
	if surface_size.x >= FULL_DENSITY_WIDTH:
		return false
	var candidate := GuiSixSeatDesktopPlan.new()
	return (
		candidate
		. configure(
			surface_size,
			Vector2(minf(520.0, surface_size.x * 0.48), 226.0 if large else 198.0),
			Vector2(0.0, LOWER_RAIL_HEIGHT),
			Vector2(306.0, LOWER_RAIL_HEIGHT),
			Vector2(72.0, 48.0),
		)
	)


func configure(
	surface_size: Vector2,
	center_size: Vector2,
	hero_minimum: Vector2,
	side_minimum: Vector2,
	quit_minimum: Vector2,
	opponent_minimum: Vector2 = Vector2(160.0, OPPONENT_HEIGHT),
	upper_corner_clearance: float = 0.0,
) -> bool:
	seat_rects.clear()
	status_rects.clear()
	var lane_width: float = (surface_size.x - center_size.x) * 0.5 - GAP
	if lane_width < maxf(side_minimum.x, opponent_minimum.x):
		return false
	if center_size.x < maxf(hero_minimum.x, quit_minimum.x):
		return false
	var opponent_size := Vector2(lane_width, maxf(OPPONENT_HEIGHT, opponent_minimum.y))
	var footprint_height: float = opponent_size.y + STATUS_GAP + STATUS_HEIGHT
	# Keep the existing compact rail reservation even when folded cards or
	# unavailable actions reduce child minima during the same hand.
	var lower_height: float = maxf(LOWER_RAIL_HEIGHT, maxf(hero_minimum.y, side_minimum.y))
	var lower_y: float = surface_size.y - STATUS_HEIGHT - STATUS_GAP - lower_height
	var center_top_minimum: float = footprint_height + GAP + quit_minimum.y + GAP
	var center_top_maximum: float = lower_y - GAP - center_size.y
	var lower_opponent_y: float = lower_y - GAP - footprint_height
	if (
		center_top_maximum < center_top_minimum
		or lower_opponent_y < footprint_height + maxf(0.0, upper_corner_clearance) + GAP
	):
		return false
	center_rect = Rect2(
		Vector2(
			(surface_size.x - center_size.x) * 0.5,
			clampf((surface_size.y - center_size.y) * 0.5, center_top_minimum, center_top_maximum),
		),
		center_size,
	)
	quit_rect = Rect2(
		Vector2(
			(surface_size.x - quit_minimum.x) * 0.5,
			center_rect.position.y - GAP - quit_minimum.y,
		),
		quit_minimum,
	)
	hero_rect = Rect2(
		Vector2(center_rect.position.x, lower_y), Vector2(center_size.x, lower_height)
	)
	event_rect = Rect2(Vector2(0.0, lower_y), Vector2(lane_width, lower_height))
	action_rect = Rect2(
		Vector2(surface_size.x - lane_width, lower_y), Vector2(lane_width, lower_height)
	)
	# Keys are relative core seats: the human is zero, followed clockwise by
	# lower-left, upper-left, apex, upper-right and lower-right opponents.
	seat_rects = {
		0: hero_rect,
		1: Rect2(Vector2(0.0, lower_opponent_y), opponent_size),
		2: Rect2(Vector2(0.0, maxf(0.0, upper_corner_clearance)), opponent_size),
		3: Rect2(Vector2((surface_size.x - lane_width) * 0.5, 0.0), opponent_size),
		4:
		Rect2(
			Vector2(surface_size.x - lane_width, maxf(0.0, upper_corner_clearance)), opponent_size
		),
		5: Rect2(Vector2(surface_size.x - lane_width, lower_opponent_y), opponent_size),
	}
	for relative_seat: int in seat_rects:
		var panel: Rect2 = seat_rects[relative_seat]
		status_rects[relative_seat] = Rect2(
			Vector2(panel.position.x, panel.end.y + STATUS_GAP),
			Vector2(panel.size.x, STATUS_HEIGHT),
		)
	return true
