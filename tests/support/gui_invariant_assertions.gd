class_name GuiInvariantAssertions
extends RefCounted

## Shared invariants consume only public semantic snapshots and fixture metadata.
const MINIMUM_FONT_SIZE: int = 20
const MINIMUM_TOUCH_SIZE := Vector2(48.0, 48.0)
const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")
const Regions := preload("res://tests/support/gui_snapshot_region_assertions.gd")
const Replacement := preload("res://tests/support/gui_replacement_invariant_assertions.gd")


static func validate(rendered: Dictionary) -> PackedStringArray:
	var snapshot: GuiLayoutSnapshot = rendered.root.get_layout_snapshot()
	var expected: Array[StringName] = []
	match rendered.descriptor.id:
		&"quit-confirmation":
			expected.append(&"quit")
		&"keypad-open":
			expected.append(&"keypad")
		&"wager-entry":
			if _is_phone(snapshot.profile):
				expected.append(&"keypad")
		&"showdown-overlay":
			if _is_phone(snapshot.profile):
				expected.append(&"summary")
	var failures: PackedStringArray = validate_snapshot(snapshot, expected)
	var declared: Array = rendered.get("intentional_overlap_roles", [])
	_require(
		declared == expected,
		"overlay-exception: expected %s, got %s" % [expected, declared],
		failures
	)
	return failures


static func validate_snapshot(
	snapshot: GuiLayoutSnapshot, expected_overlays: Array[StringName] = []
) -> PackedStringArray:
	if snapshot != null and snapshot.schema_version == 2:
		return Replacement.validate(snapshot, expected_overlays)
	var failures := PackedStringArray()
	if snapshot == null:
		failures.append("layout-readiness: snapshot is missing")
		return failures
	_require(
		snapshot.ready and not snapshot.pending,
		"layout-readiness: snapshot is not settled",
		failures
	)
	if not snapshot.ready:
		return failures
	if snapshot.startup == null:
		var required_roles: Array[StringName] = [&"center", &"action", &"board", &"pot", &"wager"]
		if _is_phone(snapshot.profile):
			required_roles.append(&"more")
		else:
			required_roles.append_array([&"event", &"quit"])
		for role: StringName in required_roles:
			if not snapshot.elements.has(role) or not snapshot.elements[role].present:
				failures.append("layout-contract: missing region %s" % role)
		if not failures.is_empty():
			return failures
		Regions.validate(snapshot, _is_phone(snapshot.profile), failures)
		_validate_board(snapshot, failures)
		_validate_actions(snapshot, failures)
	for value: GuiLayoutElement in snapshot.measured:
		_validate_containment(value, snapshot.root_rect, failures)
		validate_element(value, failures)
	# Semantic fields keep stable diagnostic roles independent of descendant indices.
	for value: GuiLayoutElement in snapshot.elements.values():
		validate_element(value, failures)
	for seat: GuiSeatSnapshot in snapshot.seats.values():
		for value: GuiLayoutElement in seat.fields.values():
			validate_element(value, failures)
		validate_element(seat.status, failures)
		for card: GuiCardSnapshot in seat.cards:
			_require(
				card.kind != GuiCardSnapshot.Kind.FACE or card.authorized,
				"privacy: seat_%d exposes private cards" % seat.seat_id,
				failures
			)
	var visible_overlays: Array[StringName] = []
	for overlay: GuiOverlaySnapshot in snapshot.overlays:
		if not overlay.element.visible:
			continue
		visible_overlays.append(overlay.kind)
		_require(
			snapshot.viewport_rect.encloses(overlay.element.rect),
			"containment: popup overlay %s is outside its viewport" % overlay.kind,
			failures
		)
		for value: GuiLayoutElement in overlay.measured:
			_validate_containment(value, overlay.element.rect, failures)
			validate_element(value, failures)
	_require(
		visible_overlays == expected_overlays,
		"overlay-exception: expected visible %s, got %s" % [expected_overlays, visible_overlays],
		failures
	)
	return failures


static func validate_element(value: GuiLayoutElement, failures: PackedStringArray) -> void:
	Content.validate_element(value, failures)


static func _validate_containment(
	value: GuiLayoutElement, bounds: Rect2, failures: PackedStringArray
) -> void:
	if value.visible:
		_require(
			bounds.encloses(value.rect),
			"containment: %s %s is outside %s" % [value.role, value.rect, bounds],
			failures
		)


static func _validate_board(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> void:
	_require(snapshot.board_cards.size() == 5, "community-cards: expected five slots", failures)
	for index: int in range(snapshot.expected_board_card_count):
		if index >= snapshot.board_cards.size():
			failures.append("community-cards: slot %d is missing" % index)
			continue
		var card: GuiLayoutElement = snapshot.board_cards[index].element
		_require(card.visible, "community-cards: slot %d is hidden" % index, failures)
		_require(
			snapshot.elements[&"board"].rect.encloses(card.rect),
			"community-cards: slot %d is outside the board" % index,
			failures
		)
		_require(card.opacity >= 0.99, "community-cards: slot %d is faded" % index, failures)


static func _validate_actions(snapshot: GuiLayoutSnapshot, failures: PackedStringArray) -> void:
	for action: int in snapshot.legal_actions:
		var reachable: bool = false
		for role: StringName in snapshot.actions.get(action, []):
			if not snapshot.elements.has(role):
				continue
			var value: GuiLayoutElement = snapshot.elements[role]
			reachable = (
				reachable
				or (
					value.present
					and value.visible
					and value.enabled
					and snapshot.elements[&"action"].rect.encloses(value.rect)
				)
			)
		_require(reachable, "legal-action: %s is not reachable" % action, failures)


static func _require(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)


static func _is_phone(profile: int) -> bool:
	return (
		profile
		in [
			GuiLayoutSnapshot.Profile.PHONE_PORTRAIT,
			GuiLayoutSnapshot.Profile.PHONE_LANDSCAPE,
		]
	)
