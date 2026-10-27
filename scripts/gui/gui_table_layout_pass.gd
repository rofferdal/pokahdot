class_name GuiTableLayoutPass
extends RefCounted

## One pass owns profile policy, scales and measured center bounds.
## Root geometry selects a profile; inset surface geometry sizes its contents.
## It retains no nodes, views, match state, or presentation callbacks.
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const GuiMobileTableLayoutScript := preload("res://scripts/gui/gui_mobile_table_layout.gd")
const GuiSixSeatDesktopPlanScript := preload("res://scripts/gui/gui_six_seat_desktop_plan.gd")

var surface_size: Vector2
var layout_profile: int
var phone_layout: bool
var compact_desktop: bool
var tablet_layout: bool
var mobile_portrait_layout: bool
var portrait_tablet_layout: bool
var landscape_tablet_layout: bool
var compact_tablet_layout: bool
var small_desktop_layout: bool
var short_desktop_center_layout: bool
var mobile_content_scale: float
var seat_content_scale: float
var seat_visual_scale: float
var compact_layout: bool
var seat_count: int
var full_ring_desktop_layout: bool
var full_ring_opponent_height: float
var full_ring_footprint_height: float
var center_width: float
var center_size: Vector2
var center_position: Vector2


func configure(
	root_size: Vector2,
	usable_size: Vector2,
	profile_override: int,
	player_count: int,
	large_values: bool
) -> void:
	surface_size = usable_size
	layout_profile = GuiLayoutProfileScript.classify(root_size, profile_override)
	phone_layout = GuiLayoutProfileScript.is_phone(layout_profile)
	compact_desktop = GuiSixSeatDesktopPlanScript.can_use(
		surface_size, layout_profile, player_count, large_values
	)
	tablet_layout = layout_profile == GuiLayoutProfileScript.Kind.TABLET
	mobile_portrait_layout = GuiMobileTableLayoutScript.is_mobile_portrait(surface_size)
	portrait_tablet_layout = tablet_layout and surface_size.y > surface_size.x
	landscape_tablet_layout = tablet_layout and surface_size.x >= surface_size.y
	compact_tablet_layout = (tablet_layout and surface_size.x < 1600.0) or compact_desktop
	small_desktop_layout = (
		GuiMobileTableLayoutScript.is_small_desktop(surface_size)
		and not tablet_layout
		and not compact_desktop
	)
	short_desktop_center_layout = (
		not tablet_layout
		and not small_desktop_layout
		and not compact_desktop
		and surface_size.y < 900.0
	)
	mobile_content_scale = GuiMobileTableLayoutScript.content_scale(surface_size)
	seat_content_scale = GuiMobileTableLayoutScript.seat_scale(surface_size)
	seat_visual_scale = seat_content_scale
	if player_count == 9 and not tablet_layout and not small_desktop_layout:
		# A full ring consumes three opponent/status rows above the side panels.
		# Scale that footprint from available height so intermediate short-wide
		# browser canvases retain a complete action/event row at the bottom.
		var source_ring_height: float = (
			3.0
			* (
				198.0
				+ GuiMobileTableLayoutScript.STATUS_BAND_GAP
				+ GuiMobileTableLayoutScript.STATUS_BAND_HEIGHT
			)
		)
		var available_ring_height: float = maxf(0.0, surface_size.y - 192.0)
		seat_visual_scale = minf(
			seat_visual_scale,
			clampf(available_ring_height / source_ring_height, 0.65, 1.0),
		)
	compact_layout = (
		surface_size.x < 600.0
		or mobile_portrait_layout
		or small_desktop_layout
		or compact_tablet_layout
	)
	seat_count = player_count
	full_ring_desktop_layout = (
		(seat_count == 9 or (seat_count == 7 and surface_size.y < 1200.0))
		and not compact_layout
		and not landscape_tablet_layout
	)
	full_ring_opponent_height = 198.0 * seat_visual_scale
	full_ring_footprint_height = (
		full_ring_opponent_height
		+ GuiMobileTableLayoutScript.STATUS_BAND_GAP * seat_visual_scale
		+ GuiMobileTableLayoutScript.STATUS_BAND_HEIGHT * seat_visual_scale
		+ 5.0
	)


static func compact_copy(profile: int, usable_size: Vector2, compact_desktop: bool) -> bool:
	return (
		compact_desktop
		or GuiLayoutProfileScript.is_phone(profile)
		or GuiMobileTableLayoutScript.is_small_desktop(usable_size)
		or GuiMobileTableLayoutScript.is_portrait_tablet(usable_size)
	)


static func numeric_keypad(
	profile: int, usable_size: Vector2, compact_desktop: bool, large_values: bool
) -> bool:
	return (
		large_values
		and (
			compact_desktop
			or GuiMobileTableLayoutScript.is_small_desktop(usable_size)
			or (profile == GuiLayoutProfileScript.Kind.TABLET and usable_size.x < 1600.0)
		)
	)


func tablet_status_scale() -> float:
	return resolve_tablet_status_scale(surface_size, compact_desktop)


static func resolve_tablet_status_scale(usable_size: Vector2, compact_desktop: bool) -> float:
	if compact_desktop:
		return 1.0
	if usable_size.y > usable_size.x:
		return GuiMobileTableLayoutScript.PORTRAIT_TABLET_STATUS_SCALE
	return GuiMobileTableLayoutScript.COMPACT_TABLET_STATUS_SCALE


func normalized_seat_position(visual_slot: int, is_hero: bool) -> Vector2:
	if is_hero:
		return Vector2(0.5, 0.91)
	var positions: Array[Vector2]
	if compact_tablet_layout:
		positions = (
			TableSeatLayout.compact_tablet_portrait_positions(seat_count)
			if portrait_tablet_layout
			else TableSeatLayout.compact_tablet_positions(seat_count)
		)
	elif landscape_tablet_layout:
		positions = TableSeatLayout.landscape_tablet_positions(seat_count)
	elif not mobile_portrait_layout and surface_size.x < 1200.0:
		positions = (
			TableSeatLayout.small_desktop_positions(seat_count)
			if small_desktop_layout
			else TableSeatLayout.compact_desktop_positions(seat_count)
		)
	else:
		positions = TableSeatLayout.symmetric_positions(seat_count)
	return positions[visual_slot]
