class_name GuiLayoutSweepGeometry
extends RefCounted

## Pure production-plan probes. These are primitive allocations, never a
## substitute for rendered child minima or the final wide controller layout.
const PhonePlan := preload("res://scripts/gui/gui_phone_layout_plan.gd")
const SixSeatPlan := preload("res://scripts/gui/gui_six_seat_desktop_plan.gd")
const PhoneSeats := preload("res://scripts/gui/gui_phone_seat_layout.gd")
const SeatLayout := preload("res://scripts/gui/gui_table_seat_layout.gd")
const Positions := preload("res://scripts/gui/table_seat_layout.gd")
const Mobile := preload("res://scripts/gui/gui_mobile_table_layout.gd")


static func rectangles(bounds: Rect2, regions: Dictionary[StringName, Rect2]) -> PackedStringArray:
	var failures := PackedStringArray()
	var roles: Array[StringName] = []
	roles.assign(regions.keys())
	roles.sort_custom(
		func(first: StringName, second: StringName) -> bool: return String(first) < String(second)
	)
	for role: StringName in roles:
		var value: Rect2 = regions[role]
		if not value.position.is_finite() or not value.size.is_finite():
			failures.append("nonfinite:%s" % role)
		elif value.size.x <= 0.0 or value.size.y <= 0.0:
			failures.append("nonpositive:%s" % role)
		elif not bounds.encloses(value):
			failures.append("containment:%s" % role)
	for first: int in range(roles.size()):
		for second: int in range(first + 1, roles.size()):
			var a: Rect2 = regions[roles[first]]
			var b: Rect2 = regions[roles[second]]
			if a.size.x > 0.0 and a.size.y > 0.0 and b.size.x > 0.0 and b.size.y > 0.0:
				if a.intersects(b):
					failures.append("intersection:%s:%s" % [roles[first], roles[second]])
	return failures


static func phone(size: Vector2, count: int, large: bool) -> PackedStringArray:
	var plan := PhonePlan.new()
	var token_height: float = 86.0 if large else PhoneSeats.PORTRAIT_TOKEN_HEIGHT
	var action_minimum := Vector2(280, 128)
	if not plan.configure(
		size, count, action_minimum, Vector2(280, 316), Vector2(280, 188), token_height
	):
		return PackedStringArray(["infeasible:phone/configure-rejected"])
	var regions: Dictionary[StringName, Rect2] = {
		&"phone/center": plan.center_rect,
		&"phone/action": plan.action_rect,
	}
	for seat: int in range(1, count):
		if plan.seat_rects.has(seat):
			regions[StringName("phone/seat/%d" % seat)] = plan.seat_rects[seat]
	var failures: PackedStringArray = rectangles(Rect2(Vector2.ZERO, size), regions)
	if plan.seat_rects.size() != count:
		failures.append("seat-count:phone")
	if not plan.action_rect.encloses(plan.more_rect):
		failures.append("containment:phone/action/more")
	if plan.more_rect.size.x < 48.0 or plan.more_rect.size.y < 48.0:
		failures.append("target:phone/more")
	if plan.action_rect.size.y < action_minimum.y:
		failures.append("infeasible:phone/action-minimum")
	for role: StringName in [&"overlay", &"menu", &"seat_detail", &"phone_quit"]:
		var overlay_rect: Rect2 = plan.get("%s_rect" % role)
		if not Rect2(Vector2.ZERO, size).encloses(overlay_rect):
			failures.append("containment:phone/%s" % role)
	if plan.menu_rect.size.x < 280.0 or plan.menu_rect.size.y < 316.0:
		failures.append("infeasible:phone/menu-minimum")
	if plan.seat_detail_rect.size.x < 280.0 or plan.seat_detail_rect.size.y < 188.0:
		failures.append("infeasible:phone/detail-minimum")
	return failures


static func wide(layout: GuiTableLayoutPass, large: bool) -> PackedStringArray:
	var failures: PackedStringArray = ring(layout)
	# Exercise actual multi-count grid cell geometry, with explicit primitive
	# inputs rather than duplicating the impure controller's minimum-size work.
	var size: Vector2 = layout.surface_size
	var center := Rect2(Vector2((size.x - 280.0) * 0.5, 0.0), Vector2(280, 184))
	var cell := Vector2(((size.x - center.size.x) * 0.5 - 6.0) * 0.5, 88.0)
	var positions: Array[Vector2] = Positions.small_desktop_opponent_positions(
		layout.seat_count, size, center, cell
	)
	var regions: Dictionary[StringName, Rect2] = {&"wide-grid/center": center}
	for index: int in range(positions.size()):
		regions[StringName("wide-grid/seat/%d" % (index + 1))] = Rect2(positions[index], cell)
	if positions.size() != layout.seat_count - 1:
		failures.append("seat-count:wide-grid")
	failures.append_array(rectangles(Rect2(Vector2.ZERO, size), regions))
	if (
		layout.layout_profile == GuiLayoutProfile.Kind.DESKTOP
		and layout.seat_count == 6
		and size.x < SixSeatPlan.FULL_DENSITY_WIDTH
	):
		var plan := SixSeatPlan.new()
		if not plan.configure(
			size,
			Vector2(minf(520.0, size.x * 0.48), 226.0 if large else 198.0),
			Vector2(200, 150),
			Vector2(306, 150),
			Vector2(72, 48)
		):
			failures.append("infeasible:wide/six-seat-desktop")
		else:
			var footprints: Dictionary[StringName, Rect2] = {
				&"wide-six/center": plan.center_rect,
				&"wide-six/action": plan.action_rect,
				&"wide-six/event": plan.event_rect,
				&"wide-six/quit": plan.quit_rect,
			}
			for seat: int in plan.seat_rects:
				footprints[StringName("wide-six/seat/%d" % seat)] = (plan.seat_rects[seat].merge(
					plan.status_rects[seat]
				))
			failures.append_array(rectangles(Rect2(Vector2.ZERO, size), footprints))
	return failures


static func ring(layout: GuiTableLayoutPass) -> PackedStringArray:
	var failures := PackedStringArray()
	var count: int = layout.seat_count
	for hero: int in range(count):
		var used_slots: Dictionary[int, bool] = {}
		var previous_angle: float = 0.0
		for relative: int in range(count):
			var seat: int = posmod(hero + relative, count)
			var slot: int = SeatLayout.visual_slot_for_seat(seat, count, hero)
			if used_slots.has(slot):
				failures.append("seat-identity:wide-ring/duplicate-slot")
			used_slots[slot] = true
			var point: Vector2 = layout.normalized_seat_position(slot, relative == 0)
			point = Mobile.opponent_position(
				point, layout.mobile_portrait_layout and relative != 0, layout.seat_content_scale
			)
			if not point.is_finite():
				failures.append("nonfinite:wide-ring/anchor")
			if point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0:
				failures.append("containment:wide-ring/anchor")
			if relative == 0:
				if not point.is_equal_approx(Vector2(0.5, 0.91)):
					failures.append("seat-identity:wide-ring/hero-bottom")
				continue
			var delta: Vector2 = point - Vector2(0.5, 0.5)
			var angle: float = fposmod(atan2(delta.x, -delta.y) - PI, TAU)
			if angle <= previous_angle:
				failures.append("seat-order:wide-ring/clockwise")
			previous_angle = angle
	return failures
