class_name GuiPhoneLayoutPlan
extends RefCounted

## Immutable geometry snapshot for one phone-table layout pass.
##
## Every rectangle is derived from the same usable surface size. Callers build a
## new plan after a resize instead of letting individual controls read live
## viewport geometry at different points in the frame.

const GuiPhoneSeatLayoutScript := preload("res://scripts/gui/gui_phone_seat_layout.gd")
const OVERLAY_MARGIN: float = 12.0
const PORTRAIT_NUMERIC_CENTER_HEIGHT: float = 92.0
const MORE_BUTTON_SIZE := Vector2(72.0, 48.0)
const SEAT_DETAIL_SIZE := Vector2(280.0, 188.0)
const PHONE_QUIT_SIZE := Vector2(320.0, 180.0)

var compact_numeric_center: bool = false
var usable_rect: Rect2
var seat_rects: Dictionary[int, Rect2]
var center_rect: Rect2
var action_rect: Rect2
var more_rect: Rect2
var overlay_rect: Rect2
var menu_rect: Rect2
var seat_detail_rect: Rect2
var phone_quit_rect: Rect2


func configure(
	usable_size: Vector2,
	player_count: int,
	action_minimum_size: Vector2,
	menu_minimum_size: Vector2 = Vector2.ZERO,
	seat_detail_minimum_size: Vector2 = Vector2.ZERO,
	portrait_token_height: float = GuiPhoneSeatLayoutScript.PORTRAIT_TOKEN_HEIGHT,
	portrait_columns: int = 0,
) -> bool:
	var resolved_seats: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(
		usable_size, player_count, portrait_token_height, portrait_columns
	)
	if resolved_seats.is_empty():
		return false

	usable_rect = Rect2(Vector2.ZERO, usable_size)
	seat_rects = resolved_seats
	center_rect = GuiPhoneSeatLayoutScript.center_rect(
		usable_size, player_count, portrait_token_height
	)
	var landscape: bool = usable_size.x > usable_size.y
	var rendered_center_width: float = minf(usable_size.x, maxf(center_rect.size.x, 280.0))
	if landscape:
		# The shortest supported landscape fixture cannot fit two full-name
		# opponent tokens beside the authored 280 px center. Keep an 8 px gutter
		# on both sides and narrow only the center; five compact community cards
		# still fit without reducing any required seat information.
		var opponent_width: float = resolved_seats[1].size.x
		var width_between_opponents: float = usable_size.x - opponent_width * 2.0 - 16.0
		rendered_center_width = minf(rendered_center_width, width_between_opponents)
	center_rect.position.x = (usable_size.x - rendered_center_width) * 0.5
	center_rect.size.x = rendered_center_width

	var resolved_action_height: float = minf(
		usable_size.y,
		maxf(
			112.0 if landscape else (0.0 if portrait_columns > 0 else 128.0), action_minimum_size.y
		),
	)
	var action_side_inset: float = 0.0
	if landscape:
		# Keep the action rail centered and at least 440 px wide. The rail begins
		# below the side tokens, so it can use their horizontal columns without
		# obscuring required opponent information.
		var opponent_width: float = resolved_seats[1].size.x
		action_side_inset = minf(opponent_width + 8.0, maxf(0.0, (usable_size.x - 440.0) * 0.5))
	action_rect = Rect2(
		Vector2(action_side_inset, usable_size.y - resolved_action_height),
		Vector2(usable_size.x - action_side_inset * 2.0, resolved_action_height),
	)
	compact_numeric_center = (
		not landscape and (portrait_token_height > 60.0 or portrait_columns > 0)
	)
	var center_height: float = (
		108.0
		if landscape
		else (
			(PORTRAIT_NUMERIC_CENTER_HEIGHT if portrait_columns > 0 else 96.0)
			if compact_numeric_center
			else 174.0
		)
	)
	center_rect.size.y = minf(center_height, maxf(0.0, action_rect.position.y - 4.0))
	center_rect.position.y = minf(
		maxf(64.0 if landscape else center_rect.position.y, center_rect.position.y),
		maxf(0.0, action_rect.position.y - center_rect.size.y - 4.0),
	)
	if not landscape and portrait_columns > 0:
		center_rect.size.x = usable_size.x - 16.0
		center_rect.position.x = 8.0
		center_rect.position.y = action_rect.position.y - center_rect.size.y - 4.0
	# More is rendered inside the reserved action rail; it never consumes a
	# perimeter seat slot.
	more_rect = Rect2(
		Vector2(action_rect.end.x - MORE_BUTTON_SIZE.x - 4.0, action_rect.position.y + 4.0),
		MORE_BUTTON_SIZE,
	)

	var overlay_size := Vector2(
		maxf(0.0, usable_size.x - OVERLAY_MARGIN * 2.0),
		maxf(0.0, usable_size.y - OVERLAY_MARGIN * 2.0),
	)
	overlay_rect = Rect2(Vector2.ONE * OVERLAY_MARGIN, overlay_size)
	var menu_size := Vector2(
		minf(overlay_size.x, maxf(280.0, menu_minimum_size.x)),
		minf(overlay_size.y, maxf(316.0, menu_minimum_size.y)),
	)
	menu_rect = Rect2(
		Vector2(usable_size.x - menu_size.x - OVERLAY_MARGIN, OVERLAY_MARGIN), menu_size
	)

	var detail_size := Vector2(
		minf(
			maxf(SEAT_DETAIL_SIZE.x, seat_detail_minimum_size.x),
			maxf(0.0, usable_size.x - 32.0),
		),
		minf(
			maxf(SEAT_DETAIL_SIZE.y, seat_detail_minimum_size.y),
			maxf(0.0, usable_size.y - 32.0),
		),
	)
	seat_detail_rect = Rect2((usable_size - detail_size) * 0.5, detail_size)
	var quit_size := Vector2(
		minf(PHONE_QUIT_SIZE.x, maxf(0.0, usable_size.x - 24.0)),
		minf(PHONE_QUIT_SIZE.y, maxf(0.0, usable_size.y - 24.0)),
	)
	phone_quit_rect = Rect2((usable_size - quit_size) * 0.5, quit_size)
	return true
