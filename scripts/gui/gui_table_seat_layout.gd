class_name GuiTableSeatLayout
extends RefCounted

## Applies one desktop/tablet pass to complete seat and public-status footprints.
## Inputs are recipient-safe player snapshots and typed widget ownership maps.
const GuiMobileTableLayoutScript := preload("res://scripts/gui/gui_mobile_table_layout.gd")
const TableSeatLayoutScript := preload("res://scripts/gui/table_seat_layout.gd")
const OPPONENT_AVATAR_SIZE := GuiTableSeatFactory.OPPONENT_AVATAR_SIZE
const HERO_AVATAR_SIZE := GuiTableSeatFactory.HERO_AVATAR_SIZE


static func apply(
	layout: GuiTableLayoutPass,
	player_views: Array[PlayerView],
	hero_seat: int,
	seats: Dictionary[int, PanelContainer],
	statuses: Dictionary[int, Label],
	action_minimum: Vector2
) -> void:
	var players: Dictionary[int, PlayerView] = {}
	for player: PlayerView in player_views:
		players[player.seat] = player
	var seat_width: float = (
		clampf(
			layout.surface_size.x * 0.32,
			104.0 * layout.seat_content_scale,
			280.0 * layout.seat_content_scale,
		)
		if layout.mobile_portrait_layout
		else (
			clampf(
				layout.surface_size.x * 0.27,
				104.0 * layout.seat_content_scale,
				140.0 * layout.seat_content_scale
			)
			if layout.compact_layout
			else maxf(
				360.0 * layout.seat_content_scale,
				clampf(
					layout.surface_size.x * 0.23,
					250.0 * layout.seat_content_scale,
					360.0 * layout.seat_content_scale
				),
			)
		)
	)
	# The avatar is the dominant visual element in a seat. Reserve roughly half
	# of its displayed width as additional horizontal breathing room so names,
	# stacks, markers, and card backs do not crowd the avatar at desktop sizes.
	if not layout.mobile_portrait_layout:
		seat_width += (
			maxf(OPPONENT_AVATAR_SIZE.x, HERO_AVATAR_SIZE.x) * 0.5 * layout.seat_visual_scale
		)
	var compact_tablet_seat_width: float = maxf(
		160.0, (layout.surface_size.x - layout.center_width) * 0.5 - 8.0
	)
	if layout.compact_tablet_layout:
		seat_width = compact_tablet_seat_width
	if (
		layout.compact_tablet_layout
		and not layout.portrait_tablet_layout
		and layout.seat_count == 9
	):
		compact_tablet_seat_width = minf(
			compact_tablet_seat_width, (layout.surface_size.x - 24.0) * 0.25
		)
		seat_width = compact_tablet_seat_width
	var small_desktop_side_width: float = (layout.surface_size.x - layout.center_width) * 0.5
	var small_desktop_column_gap: float = 6.0
	var small_desktop_column_width: float = (
		(small_desktop_side_width - small_desktop_column_gap) * 0.5
	)
	var small_desktop_opponent_positions: Array[Vector2] = []
	if layout.small_desktop_layout:
		small_desktop_opponent_positions = TableSeatLayoutScript.small_desktop_opponent_positions(
			layout.seat_count,
			layout.surface_size,
			Rect2(layout.center_position, layout.center_size),
			Vector2(small_desktop_column_width, 88.0)
		)
	for seat: int in seats:
		var is_hero: bool = seat == hero_seat
		var hero_minimum_height: float = maxf(96.0 * layout.seat_visual_scale, action_minimum.y)
		var seat_size := (
			Vector2(seat_width, hero_minimum_height)
			if is_hero
			else Vector2(seat_width, 70.0 * layout.seat_visual_scale)
		)
		if layout.compact_layout and is_hero:
			seat_size = Vector2(
				clampf(
					layout.surface_size.x * (0.76 if layout.mobile_portrait_layout else 0.56),
					190.0 * layout.seat_visual_scale,
					440.0 * layout.seat_visual_scale,
				),
				80.0 * layout.seat_visual_scale,
			)
		if layout.compact_tablet_layout:
			seat_size.x = layout.center_width if is_hero else compact_tablet_seat_width
		var visual_slot: int = visual_slot_for_seat(seat, layout.seat_count, hero_seat)
		var normalized_position: Vector2 = layout.normalized_seat_position(visual_slot, is_hero)
		normalized_position = (
			GuiMobileTableLayoutScript
			. opponent_position(
				normalized_position,
				layout.mobile_portrait_layout and not is_hero,
				layout.seat_content_scale,
			)
		)
		var panel := seats[seat] as GuiTableSeatView
		if not layout.small_desktop_layout and not layout.compact_tablet_layout:
			GuiMobileTableLayoutScript.restore_standard_seat_overlays(panel, is_hero)
		GuiMobileTableLayoutScript.apply_seat_geometry(panel, layout.seat_visual_scale, is_hero)
		if layout.small_desktop_layout:
			GuiMobileTableLayoutScript.apply_small_desktop_seat_footprint(panel)
		elif layout.compact_tablet_layout:
			GuiMobileTableLayoutScript.apply_compact_tablet_seat_footprint(panel)
		var stack_label := panel.stack_label
		var stack_value: int = players[seat].stack
		stack_label.text = (
			str(stack_value)
			if layout.small_desktop_layout or layout.portrait_tablet_layout or stack_value >= 100000
			else "%d chips" % stack_value
		)
		panel.reserve_full_name_width(layout.small_desktop_layout or layout.compact_tablet_layout)
		var minimum_size: Vector2 = panel.get_combined_minimum_size()
		var standard_desktop_layout: bool = (
			not layout.compact_layout and not layout.landscape_tablet_layout
		)
		var resolved_seat_size := (
			Vector2(
				seat_size.x,
				(220.0 if is_hero else 198.0) * layout.seat_visual_scale,
			)
			if standard_desktop_layout
			else Vector2(maxf(seat_size.x, minimum_size.x), maxf(seat_size.y, minimum_size.y))
		)
		if layout.landscape_tablet_layout and layout.seat_count in [6, 7]:
			# Reserve one stable footprint for every seat. This prevents a
			# showdown card/summary refresh or optional action text from changing
			# the seat's rectangle and moving neighboring presentation regions.
			resolved_seat_size.y = maxf(resolved_seat_size.y, 220.0 * layout.seat_visual_scale)
		if not layout.mobile_portrait_layout and layout.surface_size.x < 1200.0 and not is_hero:
			# Short desktop surfaces cannot fit nine full-height source panels in
			# the regular ring. Keep the panel footprint compact; its content is
			# still laid out by the same presentation controls and remains clipped
			# to the seat boundary instead of colliding with neighboring seats.
			resolved_seat_size.y = minf(resolved_seat_size.y, 170.0)
		if layout.small_desktop_layout and not is_hero:
			resolved_seat_size = Vector2(small_desktop_column_width, 88.0)
		elif layout.compact_tablet_layout and not is_hero:
			resolved_seat_size = Vector2(compact_tablet_seat_width, 102.0)
		elif layout.full_ring_desktop_layout and not is_hero:
			resolved_seat_size.y = layout.full_ring_opponent_height
		panel.size = resolved_seat_size
		var intended_position: Vector2 = (
			normalized_position * layout.surface_size - resolved_seat_size * 0.5
		)
		panel.position = Vector2(
			clampf(intended_position.x, 0.0, layout.surface_size.x - resolved_seat_size.x),
			clampf(intended_position.y, 0.0, layout.surface_size.y - resolved_seat_size.y),
		)
		if layout.full_ring_desktop_layout and not is_hero:
			var status_footprint_height: float = (
				resolved_seat_size.y
				+ GuiMobileTableLayoutScript.STATUS_BAND_GAP * layout.seat_visual_scale
				+ GuiMobileTableLayoutScript.STATUS_BAND_HEIGHT * layout.seat_visual_scale
				+ 5.0
			)
			var edge_margin: float = 0.5
			var column_gap: float = 4.0
			var outer_right_x: float = layout.surface_size.x - resolved_seat_size.x - edge_margin
			var inner_right_x: float = outer_right_x - resolved_seat_size.x - column_gap
			var outer_left_x: float = edge_margin
			var inner_left_x: float = outer_left_x + resolved_seat_size.x + column_gap
			var full_ring_positions: Dictionary[int, Vector2] = {
				0: Vector2(inner_right_x, 0.0),
				1: Vector2(outer_right_x, 0.0),
				2: Vector2(outer_right_x, status_footprint_height),
				3: Vector2(outer_right_x, status_footprint_height * 2.0),
				5: Vector2(outer_left_x, status_footprint_height * 2.0),
				6: Vector2(outer_left_x, status_footprint_height),
				7: Vector2(outer_left_x, 0.0),
				8: Vector2(inner_left_x, 0.0),
			}
			# Seven seats use the same non-overlapping side-column footprints,
			# omitting the two outer top seats while retaining clockwise order.
			var footprint_slot: int = visual_slot
			if layout.seat_count == 7:
				var seven_seat_slots: Dictionary[int, int] = {0: 0, 1: 2, 2: 3, 4: 5, 5: 6, 6: 8}
				footprint_slot = seven_seat_slots[visual_slot]
			panel.position = full_ring_positions[footprint_slot]
		if layout.small_desktop_layout:
			if is_hero:
				panel.position = Vector2(
					(layout.surface_size.x - panel.size.x) * 0.5,
					(
						layout.surface_size.y
						- panel.size.y
						- GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT
						- GuiMobileTableLayoutScript.STATUS_BAND_GAP
					),
				)
			else:
				var relative_seat: int = posmod(seat - hero_seat, layout.seat_count)
				panel.position = small_desktop_opponent_positions[relative_seat - 1]
		var status_label: Label = statuses.get(seat)
		var status_scale: float = (
			layout.tablet_status_scale()
			if layout.compact_tablet_layout
			else (1.0 if layout.small_desktop_layout else layout.seat_visual_scale)
		)
		GuiMobileTableLayoutScript.layout_seat_status_band(
			status_label, panel, layout.compact_layout, status_scale
		)
		var status_overflow: float = status_label.get_rect().end.y - layout.surface_size.y
		if status_overflow > 0.0:
			panel.position.y = maxf(0.0, panel.position.y - status_overflow)
			GuiMobileTableLayoutScript.layout_seat_status_band(
				status_label, panel, layout.compact_layout, status_scale
			)


static func visual_slot_for_seat(seat: int, seat_count: int, hero_seat: int) -> int:
	var bottom_slot: int = seat_count / 2
	var relative_seat: int = posmod(seat - hero_seat, seat_count)
	return posmod(bottom_slot + relative_seat, seat_count)
