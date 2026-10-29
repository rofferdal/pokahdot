class_name GuiSnapshotContentAssertions
extends RefCounted

## Pure assertions over detached presentation observations.
const MINIMUM_FONT_SIZE: int = 20
const EVENT_LOG_FONT_SIZE: int = 18
const MINIMUM_TOUCH_SIZE := Vector2(48.0, 48.0)


static func validate_element(
	value: GuiLayoutElement, failures: PackedStringArray, portrait_seat_copy: bool = false
) -> void:
	if value == null or not value.visible:
		return
	if value.font_size > 0:
		var minimum: int = minimum_font_size(value, portrait_seat_copy)
		_require(
			value.font_size >= minimum,
			"font-floor: %s uses %d px" % [value.role, value.font_size],
			failures
		)
	if value.interactive:
		_require(
			(
				value.allocated_size.x >= MINIMUM_TOUCH_SIZE.x
				and value.allocated_size.y >= MINIMUM_TOUCH_SIZE.y
			),
			"touch-target: %s has size %s" % [value.role, value.allocated_size],
			failures
		)
	if value.text_kind not in [&"label", &"button", &"input"] or value.line_count == 0:
		return
	var tolerance: float = 0.5 if value.text_kind == &"label" else 0.0
	_require(
		value.required_size.x <= value.allocated_size.x + tolerance,
		(
			"text-clipping: %s needs %.1f px but has %.1f px"
			% [value.role, value.required_size.x, value.allocated_size.x]
		),
		failures
	)
	if value.text_kind != &"label":
		return
	_require(
		value.required_size.y <= value.allocated_size.y + tolerance,
		(
			"text-clipping: %s hides wrapped lines or vertical content: needs %.1f px but has %.1f px"
			% [value.role, value.required_size.y, value.allocated_size.y]
		),
		failures
	)
	_require(
		value.max_lines < 0 or value.max_lines >= value.line_count,
		(
			"text-clipping: %s hides wrapped lines (%d required, limit %d)"
			% [value.role, value.line_count, value.max_lines]
		),
		failures
	)


static func minimum_font_size(value: GuiLayoutElement, portrait_seat_copy: bool = false) -> int:
	if value.role == &"event" and value.text_kind == &"rich_text":
		return EVENT_LOG_FONT_SIZE
	if not portrait_seat_copy or value.text_kind != &"label" or value.interactive:
		return MINIMUM_FONT_SIZE
	var parts: PackedStringArray = String(value.role).split("/")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return MINIMUM_FONT_SIZE
	if int(parts[1]) < 0 or str(int(parts[1])) != parts[1]:
		return MINIMUM_FONT_SIZE
	if parts.size() == 2 and parts[0] == "status":
		return 18
	if (
		parts.size() == 3
		and parts[0] == "seat"
		and parts[2] in ["name", "stack", "badge", "badge_row_2", "badge_row_3", "marker", "action"]
	):
		return 18
	return MINIMUM_FONT_SIZE


static func validate_phone_seat(
	seat: GuiSeatSnapshot, portrait: bool, failures: PackedStringArray
) -> void:
	var roles: Array[StringName] = [&"name", &"stack", &"badge", &"cards"]
	for role: StringName in roles:
		_require(
			seat.fields.has(role) and seat.fields[role].present,
			"seat-content: seat_%d is missing %s" % [seat.seat_id, role],
			failures
		)
	if not _has_fields(seat, roles):
		return
	_no_overlap(seat.fields[&"name"], seat.fields[&"badge"], seat.seat_id, failures)
	_no_overlap(seat.fields[&"stack"], seat.fields[&"cards"], seat.seat_id, failures)
	if portrait:
		var fields: Array[GuiLayoutElement] = [
			seat.fields[&"name"], seat.fields[&"stack"], seat.fields[&"cards"]
		]
		for role: StringName in [&"badge", &"badge_row_2", &"badge_row_3", &"action"]:
			if seat.fields.has(role) and seat.fields[role].visible:
				fields.append(seat.fields[role])
		for index: int in range(fields.size()):
			for other: int in range(index + 1, fields.size()):
				_no_overlap(fields[index], fields[other], seat.seat_id, failures)
	var badge_parts: String = ""
	for role: StringName in [&"badge", &"badge_row_2", &"badge_row_3"]:
		if seat.fields.has(role) and seat.fields[role].visible:
			badge_parts += seat.fields[role].text.replace(" ", "")
	_require(
		badge_parts == seat.required_badge_text.replace(" ", ""),
		"seat-content: seat_%d role/state components changed" % seat.seat_id,
		failures
	)
	var previous: GuiCardSnapshot
	for card: GuiCardSnapshot in seat.cards:
		if card.kind != GuiCardSnapshot.Kind.FACE:
			continue
		var context := "seat-content: seat_%d %s" % [seat.seat_id, card.element.role]
		_require(seat.fields[&"cards"].rect.encloses(card.element.rect), context, failures)
		_require(seat.panel.rect.encloses(card.element.rect), context, failures)
		_validate_face(card, context, failures)
		if previous != null:
			_require(
				not previous.element.rect.intersects(card.element.rect),
				"%s intersects the other revealed card" % context,
				failures
			)
		previous = card


static func validate_compact_marker(seat: GuiSeatSnapshot, failures: PackedStringArray) -> void:
	if not _has_fields(seat, [&"marker", &"avatar", &"identity"]):
		return
	var marker: GuiLayoutElement = seat.fields[&"marker"]
	var avatar: GuiLayoutElement = seat.fields[&"avatar"]
	if marker.parent_role != avatar.role:
		return
	_require(
		avatar.rect.encloses(marker.rect),
		"seat-content: seat_%d marker escapes compact avatar" % seat.seat_id,
		failures
	)
	_no_overlap(marker, seat.fields[&"identity"], seat.seat_id, failures)


static func _validate_face(
	card: GuiCardSnapshot, context: String, failures: PackedStringArray
) -> void:
	_require(card.rank.present and card.suit.present, "%s omits rank or suit" % context, failures)
	_require(
		card.rank.visible and card.suit.visible, "%s omits visible rank or suit" % context, failures
	)
	_require(
		card.element.opacity >= 0.99 and card.rank.opacity >= 0.99 and card.suit.opacity >= 0.99,
		"%s card content is faded" % context,
		failures
	)
	_require(card.element.rect.encloses(card.rank.rect), context, failures)
	_require(card.element.rect.encloses(card.suit.rect), context, failures)
	_require(
		card.rank.rect.end.x <= card.suit.rect.position.x,
		"%s rank intersects suit" % context,
		failures
	)
	_require(
		card.rank.required_size.x <= card.rank.allocated_size.x,
		"%s rank is clipped" % context,
		failures
	)
	_require(
		card.suit.allocated_size.x >= 18.0 and card.suit.allocated_size.y >= 18.0,
		"%s suit is too small" % context,
		failures
	)


static func _has_fields(seat: GuiSeatSnapshot, roles: Array[StringName]) -> bool:
	for role: StringName in roles:
		if not seat.fields.has(role) or not seat.fields[role].present:
			return false
	return true


static func _no_overlap(
	first: GuiLayoutElement, second: GuiLayoutElement, seat: int, failures: PackedStringArray
) -> void:
	_require(
		not first.rect.intersects(second.rect),
		"seat-content: seat_%d %s intersects %s" % [seat, first.role, second.role],
		failures
	)


static func _require(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
