class_name GuiSnapshotRegionAssertions
extends RefCounted

const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")


static func validate(snapshot: GuiLayoutSnapshot, phone: bool, failures: PackedStringArray) -> void:
	var major_roles: Array[StringName] = [&"center", &"action"]
	if not phone:
		major_roles.append(&"event")
	for role: StringName in major_roles:
		var value: GuiLayoutElement = snapshot.elements[role]
		_require(snapshot.surface_rect.encloses(value.rect), "containment: %s" % role, failures)
	for first: int in range(major_roles.size()):
		for second: int in range(first + 1, major_roles.size()):
			_no_overlap(
				snapshot.elements[major_roles[first]],
				snapshot.elements[major_roles[second]],
				failures
			)
	if phone:
		_require(
			snapshot.elements[&"action"].rect.encloses(snapshot.elements[&"more"].rect),
			"containment: More is outside the reserved action region",
			failures
		)
		for role: StringName in [&"board", &"pot", &"wager"]:
			_require(
				snapshot.elements[&"center"].rect.encloses(snapshot.elements[role].rect),
				"containment: center does not enclose %s" % role,
				failures
			)
	else:
		for role: StringName in [&"board", &"pot", &"wager", &"quit"]:
			var value: GuiLayoutElement = snapshot.elements[role]
			if value.rect.size != Vector2.ZERO:
				_require(
					snapshot.surface_rect.encloses(value.rect), "containment: %s" % role, failures
				)
		for role: StringName in major_roles:
			_no_overlap(snapshot.elements[&"quit"], snapshot.elements[role], failures)
	var placed: Array[GuiLayoutElement] = []
	for seat: GuiSeatSnapshot in snapshot.seats.values():
		if phone and not seat.panel.visible:
			continue
		_require(
			snapshot.surface_rect.encloses(seat.panel.rect),
			"containment: seat_%d" % seat.seat_id,
			failures
		)
		for other: GuiLayoutElement in placed:
			_no_overlap(seat.panel, other, failures)
		placed.append(seat.panel)
		for role: StringName in major_roles:
			_no_overlap(seat.panel, snapshot.elements[role], failures)
		_no_overlap(seat.panel, snapshot.elements[&"more" if phone else &"quit"], failures)
		if phone:
			Content.validate_phone_seat(
				seat, snapshot.surface_size.y >= snapshot.surface_size.x, failures
			)
		else:
			_validate_status(snapshot, seat, major_roles, failures)
			Content.validate_compact_marker(seat, failures)


static func _validate_status(
	snapshot: GuiLayoutSnapshot,
	seat: GuiSeatSnapshot,
	major_roles: Array[StringName],
	failures: PackedStringArray
) -> void:
	var status: GuiLayoutElement = seat.status
	if not status.present:
		return
	_require(
		snapshot.surface_rect.encloses(status.rect),
		"containment: status_%d" % seat.seat_id,
		failures
	)
	if status.parent_role == seat.panel.role:
		_require(
			seat.panel.rect.encloses(status.rect),
			"auxiliary-clearance: integrated status_%d escapes seat" % seat.seat_id,
			failures
		)
		return
	_require(
		status.rect.position.y >= seat.panel.rect.end.y,
		"auxiliary-clearance: status_%d is not below seat" % seat.seat_id,
		failures
	)
	for other: GuiSeatSnapshot in snapshot.seats.values():
		_require(
			not status.rect.intersects(other.panel.rect),
			"auxiliary-clearance: status_%d intersects seat_%d" % [seat.seat_id, other.seat_id],
			failures
		)
	var obstacles: Array[StringName] = major_roles.duplicate()
	obstacles.append(&"quit")
	for role: StringName in obstacles:
		_require(
			not status.rect.intersects(snapshot.elements[role].rect),
			"auxiliary-clearance: status_%d intersects %s" % [seat.seat_id, role],
			failures
		)


static func _no_overlap(
	first: GuiLayoutElement, second: GuiLayoutElement, failures: PackedStringArray
) -> void:
	_require(
		not first.rect.intersects(second.rect),
		"intersection: %s intersects %s" % [first.role, second.role],
		failures
	)


static func _require(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
