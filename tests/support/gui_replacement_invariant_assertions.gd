class_name GuiReplacementInvariantAssertions
extends RefCounted

## Schema2 validates actual replacement geometry and explicit navigation routes.
## It does not infer regions from legacy profile-specific node placement.
const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")
const Modes := preload("res://scripts/gui/layout/gui_size_class.gd")


static func validate(
	snapshot: GuiLayoutSnapshot, expected_overlays: Array[StringName] = []
) -> PackedStringArray:
	var failures := PackedStringArray()
	if snapshot == null:
		failures.append("layout-readiness: snapshot is missing")
		return failures
	var guidance: bool = not snapshot.fit_guidance.is_empty()
	_require(
		not snapshot.pending and (snapshot.ready or guidance),
		"layout-readiness: snapshot is not settled",
		failures
	)
	if snapshot.pending or (not snapshot.ready and not guidance):
		return failures
	_require(snapshot.schema_version == 2, "layout-contract: expected schema2", failures)
	_require(
		(
			snapshot.layout_mode >= Modes.LayoutMode.PHONE
			and snapshot.layout_mode <= Modes.LayoutMode.WIDE
		),
		"layout-contract: invalid replacement mode",
		failures
	)
	if not _root_bounds(snapshot, failures):
		return failures
	for value: GuiLayoutElement in snapshot.measured:
		_known(value, snapshot.root_rect, failures)
	for value: GuiLayoutElement in snapshot.elements.values():
		_known(value, snapshot.root_rect, failures)
	if guidance:
		_guidance(snapshot, failures)
	else:
		_regions(snapshot, failures)
		_seats(snapshot, failures)
		_rows(snapshot, failures)
		_board(snapshot, failures)
		_actions_and_routes(snapshot, failures)
	_overlays(snapshot, expected_overlays, failures)
	return failures


static func _root_bounds(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> bool:
	var valid: bool = _positive_rect(snapshot.root_rect) and _positive_rect(snapshot.viewport_rect)
	_require(valid, "containment: root/viewport must be finite positive rectangles", failures)
	if not valid:
		return false
	_require(
		snapshot.viewport_rect.encloses(snapshot.root_rect),
		"containment: root escapes viewport",
		failures
	)
	_require(
		(
			_positive_rect(snapshot.surface_rect)
			and snapshot.root_rect.encloses(snapshot.surface_rect)
		),
		"containment: surface escapes root",
		failures
	)
	_require(
		_positive_rect(snapshot.usable_rect) and snapshot.root_rect.encloses(snapshot.usable_rect),
		"containment: usable rectangle escapes root",
		failures
	)
	return true


static func _known(value: GuiLayoutElement, bounds: Rect2, failures: PackedStringArray) -> void:
	if value == null:
		failures.append("layout-contract: missing observation")
		return
	if value.present and value.visible:
		_require(
			(
				value.rect.is_finite()
				and value.rect.size.x >= 0
				and value.rect.size.y >= 0
				and bounds.encloses(value.rect)
			),
			"containment: %s escapes its actual bounds" % value.role,
			failures
		)
	Content.validate_element(value, failures)


static func _guidance(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> void:
	var guide: GuiLayoutElement = snapshot.elements.get(&"guidance")
	_require(
		not snapshot.fit_guidance.strip_edges().is_empty(),
		"guidance: missing explanation",
		failures
	)
	_require(_active(guide), "guidance: explanation is not visibly rendered", failures)
	if guide != null:
		_require(
			guide.text == snapshot.fit_guidance,
			"guidance: rendered explanation differs from fit guidance",
			failures
		)
	for role: StringName in [&"center", &"board", &"action", &"event"]:
		_require(
			not _active(snapshot.elements.get(role)),
			"guidance: stale visible %s placement" % role,
			failures
		)
	for seat: GuiSeatSnapshot in snapshot.seats.values():
		_require(
			seat != null and not _active(seat.panel) and not _active(seat.status),
			"guidance: stale visible seat placement",
			failures
		)

		if seat != null:
			for value: GuiLayoutElement in seat.fields.values():
				_require(not _active(value), "guidance: stale visible seat field", failures)
			for card: GuiCardSnapshot in seat.cards:
				if card != null:
					_require(
						(
							not _active(card.element)
							and not _active(card.rank)
							and not _active(card.suit)
						),
						"guidance: stale visible seat card",
						failures
					)

					if card.kind == GuiCardSnapshot.Kind.FACE and not card.authorized:
						failures.append("privacy: unauthorized face retained during guidance")
						_require(
							(
								card.rank != null
								and card.suit != null
								and card.rank.privacy_redacted
								and card.suit.privacy_redacted
								and card.rank.text.is_empty()
								and card.suit.text.is_empty()
							),
							"privacy: hidden unauthorized face copy was not redacted",
							failures
						)
					elif card.kind != GuiCardSnapshot.Kind.FACE:
						for value: GuiLayoutElement in [card.rank, card.suit]:
							if value != null:
								_require(
									value.text.is_empty() and value.value_text.is_empty(),
									"privacy: hidden card retained identity during guidance",
									failures
								)


static func _regions(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> void:
	for role: StringName in [&"center", &"board", &"pot", &"wager", &"action"]:
		var value: GuiLayoutElement = snapshot.elements.get(role)
		_require(_active(value), "layout-contract: missing visible region %s" % role, failures)
		if _active(value):
			_require(
				_positive_rect(value.rect) and snapshot.surface_rect.encloses(value.rect),
				"containment: %s escapes surface" % role,
				failures
			)
	var center: GuiLayoutElement = snapshot.elements.get(&"center")
	if _active(center):
		for role: StringName in [&"board", &"pot", &"wager"]:
			var value: GuiLayoutElement = snapshot.elements.get(role)
			if _active(value):
				_require(
					center.rect.encloses(value.rect),
					"containment: center does not enclose %s" % role,
					failures
				)
	var major: Array[GuiLayoutElement] = []
	for role: StringName in [&"center", &"action", &"event"]:
		var value: GuiLayoutElement = snapshot.elements.get(role)
		if _active(value):
			_require(
				snapshot.surface_rect.encloses(value.rect),
				"containment: %s escapes surface" % role,
				failures
			)
			major.append(value)
	for index: int in major.size():
		for other: int in range(index + 1, major.size()):
			_require(
				not major[index].rect.intersects(major[other].rect),
				"intersection: %s overlaps %s" % [major[index].role, major[other].role],
				failures
			)


static func _seats(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> void:
	var phone: bool = (
		snapshot.layout_mode in [Modes.LayoutMode.PHONE, Modes.LayoutMode.PHONE_LANDSCAPE]
	)
	_require(
		snapshot.seats.size() >= 2 and snapshot.seats.size() <= (7 if phone else 9),
		(
			"seat-content: invalid phone roster (requires two to seven seats)"
			if phone
			else "seat-content: invalid roster size"
		),
		failures
	)
	var placed: Array[Rect2] = []
	for id: int in snapshot.seats:
		var seat: GuiSeatSnapshot = snapshot.seats[id]
		if seat == null:
			failures.append("seat-content: missing seat_%d" % id)
			continue
		_require(id >= 0 and id == seat.seat_id, "seat-content: seat identity mismatch", failures)
		_require(
			_active(seat.panel) and _active(seat.status),
			"seat-content: hidden seat_%d footprint" % id,
			failures
		)
		_require(
			_positive_rect(seat.footprint) and snapshot.surface_rect.encloses(seat.footprint),
			"containment: seat_%d complete footprint escapes surface" % id,
			failures
		)
		for value: GuiLayoutElement in [seat.panel, seat.status]:
			_known(value, snapshot.root_rect, failures)
			if value != null:
				_require(
					seat.footprint.encloses(value.rect),
					"seat-content: seat_%d omits panel/status footprint" % id,
					failures
				)
		if seat.panel != null and seat.status != null:
			_require(
				not seat.panel.rect.intersects(seat.status.rect),
				"intersection: seat_%d status overlaps its panel" % id,
				failures
			)
		for previous: Rect2 in placed:
			_require(
				not seat.footprint.intersects(previous),
				"intersection: complete seat footprints overlap",
				failures
			)
		placed.append(seat.footprint)
		for role: StringName in [&"center", &"action", &"event"]:
			var value: GuiLayoutElement = snapshot.elements.get(role)
			if _active(value):
				_require(
					not seat.footprint.intersects(value.rect),
					"intersection: seat_%d overlaps %s" % [id, role],
					failures
				)
		_seat_content(seat, snapshot.root_rect, failures)


static func _seat_content(
	seat: GuiSeatSnapshot, bounds: Rect2, failures: PackedStringArray
) -> void:
	for role: StringName in [&"name", &"stack", &"action", &"cards"]:
		_require(
			seat.fields.has(role) and _active(seat.fields[role]),
			"seat-content: seat_%d missing %s" % [seat.seat_id, role],
			failures
		)
	for value: GuiLayoutElement in seat.fields.values():
		_known(value, bounds, failures)
		if _active(value) and seat.panel != null:
			_require(
				seat.panel.rect.encloses(value.rect),
				"seat-content: seat_%d field escapes panel" % seat.seat_id,
				failures
			)
	_require(
		seat.cards.size() == 2,
		"seat-content: seat_%d needs two hole-card slots" % seat.seat_id,
		failures
	)
	var previous: Array[Rect2] = []
	for card: GuiCardSnapshot in seat.cards:
		_card(card, bounds, "seat_%d" % seat.seat_id, failures)
		if card == null or card.element == null:
			continue
		_require(_active(card.element), "seat-content: hidden hole-card slot", failures)
		if _active(card.element):
			if seat.panel != null:
				_require(
					seat.panel.rect.encloses(card.element.rect),
					"seat-content: card escapes seat_%d" % seat.seat_id,
					failures
				)
			var group: GuiLayoutElement = seat.fields.get(&"cards")
			if group != null:
				_require(
					group.rect.encloses(card.element.rect),
					"seat-content: card escapes hole-card group",
					failures
				)
			for rect: Rect2 in previous:
				_require(
					not rect.intersects(card.element.rect),
					"intersection: hole cards overlap",
					failures
				)
			previous.append(card.element.rect)
		if card.kind == GuiCardSnapshot.Kind.FACE:
			_require(
				seat.face_authorized,
				"privacy: seat_%d has no face authorization" % seat.seat_id,
				failures
			)


static func _rows(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> void:
	var seen := PackedInt32Array()
	var heroes: int = 0
	for row: PackedInt32Array in snapshot.seat_rows:
		_require(
			(
				not row.is_empty()
				and (
					row.size() <= 2
					or (
						snapshot.layout_mode == Modes.LayoutMode.PHONE_LANDSCAPE
						and row == snapshot.seat_rows[0]
						and row.size() == 3
					)
				)
			),
			"row-cap: each row has at most two seats except the phone landscape top triple",
			failures
		)
		var row_heroes: int = 0
		for id: int in row:
			_require(
				snapshot.seats.has(id) and not seen.has(id),
				"row-cap: duplicate or unknown seat ID",
				failures
			)
			seen.append(id)
			var seat: GuiSeatSnapshot = snapshot.seats.get(id)
			if seat != null and seat.hero:
				row_heroes += 1
				heroes += 1
		_require(
			row_heroes == 0 or row.size() == 1, "row-cap: human requires a separate row", failures
		)
	_require(
		seen.size() == snapshot.seats.size() and heroes == 1,
		"row-cap: rows must cover every seat and one hero exactly once",
		failures
	)

	_actual_bands(snapshot, failures)


static func _actual_bands(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> void:
	var boundaries: Array[float] = []
	var visible: Array[GuiSeatSnapshot] = []
	for seat: GuiSeatSnapshot in snapshot.seats.values():
		if (
			seat != null
			and (_active(seat.panel) or _active(seat.status))
			and _positive_rect(seat.footprint)
		):
			visible.append(seat)
			boundaries.append(seat.footprint.position.y)
			boundaries.append(seat.footprint.end.y)
	boundaries.sort()
	var maximum: int = 0
	var maximum_opponents: int = 0
	for index: int in range(boundaries.size() - 1):
		if boundaries[index] == boundaries[index + 1]:
			continue
		var y: float = (boundaries[index] + boundaries[index + 1]) * 0.5
		var population: int = 0
		var opponents: int = 0
		for seat: GuiSeatSnapshot in visible:
			if seat.footprint.position.y < y and seat.footprint.end.y > y:
				population += 1
				if not seat.hero:
					opponents += 1
		var top_end: float = 0.0
		for seat: GuiSeatSnapshot in visible:
			if seat.footprint.position.y == boundaries[0]:
				top_end = maxf(top_end, seat.footprint.end.y)
		var allowed: int = (
			3 if snapshot.layout_mode == Modes.LayoutMode.PHONE_LANDSCAPE and y < top_end else 2
		)
		_require(
			population <= allowed, "row-cap: only phone landscape top band permits three", failures
		)
		_require(
			population == opponents or population == 1, "row-cap: human shares a band", failures
		)
		maximum = maxi(maximum, population)
		maximum_opponents = maxi(maximum_opponents, opponents)
	_require(
		maximum <= 3,
		"row-cap: actual horizontal band exceeds three seats including the hero",
		failures
	)
	if snapshot.layout_mode == Modes.LayoutMode.PHONE:
		_require(
			maximum_opponents <= 2, "row-cap: actual portrait band exceeds two opponents", failures
		)


static func _board(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> void:
	_require(snapshot.board_cards.size() == 5, "community-cards: expected five slots", failures)
	_require(
		snapshot.expected_board_card_count >= 0 and snapshot.expected_board_card_count <= 5,
		"community-cards: invalid expected face count",
		failures
	)
	var board: GuiLayoutElement = snapshot.elements.get(&"board")
	var faces: int = 0
	var previous: Array[Rect2] = []
	for index: int in snapshot.board_cards.size():
		var card: GuiCardSnapshot = snapshot.board_cards[index]
		_card(card, snapshot.root_rect, "board/%d" % index, failures)
		if card == null or card.element == null:
			continue
		_require(_active(card.element), "community-cards: hidden slot %d" % index, failures)
		if board != null:
			_require(
				board.rect.encloses(card.element.rect),
				"community-cards: card escapes board",
				failures
			)
		_require(
			(
				(card.kind == GuiCardSnapshot.Kind.FACE)
				== (index < snapshot.expected_board_card_count)
			),
			"community-cards: face/slot order differs from expected board",
			failures
		)
		if card.kind == GuiCardSnapshot.Kind.FACE:
			faces += 1
		for rect: Rect2 in previous:
			_require(
				not rect.intersects(card.element.rect),
				"intersection: board cards overlap",
				failures
			)
		previous.append(card.element.rect)
	_require(
		faces == snapshot.expected_board_card_count,
		"community-cards: unexpected face count",
		failures
	)


static func _card(
	card: GuiCardSnapshot, bounds: Rect2, context: String, failures: PackedStringArray
) -> void:
	if card == null or card.element == null:
		failures.append("card-content: missing %s observation" % context)
		return
	_known(card.element, bounds, failures)
	_require(
		(
			card.kind
			in [GuiCardSnapshot.Kind.EMPTY, GuiCardSnapshot.Kind.BACK, GuiCardSnapshot.Kind.FACE]
		),
		"card-content: unknown card kind %s" % context,
		failures
	)
	if _active(card.element):
		_require(
			(
				_positive_rect(card.element.rect)
				and (
					card.element.rect.size.x / maxf(0.001, card.element.rect.size.y)
					>= 5.0 / 7.0 - 0.001
				)
			),
			"card-content: narrow or invalid card %s" % context,
			failures
		)
	if card.kind == GuiCardSnapshot.Kind.FACE:
		_require(card.authorized, "privacy: unauthorized face %s" % context, failures)
		if card.rank == null or card.suit == null:
			failures.append("card-content: missing face glyphs %s" % context)
			return
		_known(card.rank, bounds, failures)
		_known(card.suit, bounds, failures)
		if not card.authorized:
			_require(
				(
					card.rank.privacy_redacted
					and card.suit.privacy_redacted
					and card.rank.text.is_empty()
					and card.suit.text.is_empty()
				),
				"privacy: unauthorized face copy was not redacted",
				failures
			)
		if card.authorized:
			_require(
				(
					not card.rank.text.strip_edges().is_empty()
					and not card.suit.text.strip_edges().is_empty()
				),
				"card-content: missing authorized face copy %s" % context,
				failures
			)
		Content.validate_card(card, context, failures)
	else:
		for value: GuiLayoutElement in [card.rank, card.suit]:
			if value != null:
				_require(
					value.text.is_empty() and value.value_text.is_empty(),
					"privacy: hidden card retained identity %s" % context,
					failures
				)


static func _actions_and_routes(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> void:
	var action: GuiLayoutElement = snapshot.elements.get(&"action")
	var more: GuiLayoutElement = _action(snapshot, &"more")
	_require(
		_reachable(more, action),
		"navigation: More must remain enabled inside the action region",
		failures
	)
	for route: StringName in [&"quit", &"event"]:
		var via: StringName = snapshot.menu_routes.get(route, &"")
		_require(
			via in [&"more", &"action/more"] and _reachable(_action(snapshot, via), action),
			"navigation: %s has no reachable More route" % route,
			failures
		)
	for kind: int in snapshot.legal_actions:
		var reachable: bool = false
		for value: Variant in snapshot.actions.get(kind, []):
			if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
				reachable = reachable or _reachable(_action(snapshot, StringName(value)), action)
		_require(reachable, "legal-action: %d is not reachable" % kind, failures)


static func _overlays(
	snapshot: GuiLayoutSnapshot, expected: Array[StringName], failures: PackedStringArray
) -> void:
	var visible: Array[StringName] = []
	for overlay: GuiOverlaySnapshot in snapshot.overlays:
		if overlay == null or overlay.element == null:
			failures.append("overlay-exception: missing overlay observation")
			continue
		if not _active(overlay.element):
			continue
		visible.append(overlay.kind)
		_known(overlay.element, snapshot.viewport_rect, failures)
		for value: GuiLayoutElement in overlay.measured:
			_known(value, overlay.element.rect, failures)
		for value: GuiLayoutElement in overlay.elements.values():
			_known(value, overlay.element.rect, failures)
		for card: GuiCardSnapshot in overlay.cards:
			_card(card, overlay.element.rect, "overlay/%s" % overlay.kind, failures)
	_require(
		visible == expected,
		"overlay-exception: visible overlays differ from declared overlap kinds",
		failures
	)


static func _action(snapshot: GuiLayoutSnapshot, role: StringName) -> GuiLayoutElement:
	var qualified: StringName = (
		role if str(role).begins_with("action/") else StringName("action/" + str(role))
	)
	return snapshot.elements.get(qualified, snapshot.elements.get(role))


static func _reachable(value: GuiLayoutElement, action: GuiLayoutElement) -> bool:
	return (
		_active(value)
		and value.enabled
		and value.interactive
		and _active(action)
		and action.rect.encloses(value.rect)
	)


static func _active(value: GuiLayoutElement) -> bool:
	return value != null and value.present and value.visible and value.opacity > 0.0


static func _positive_rect(value: Rect2) -> bool:
	return value.is_finite() and value.size.x > 0 and value.size.y > 0


static func _require(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
