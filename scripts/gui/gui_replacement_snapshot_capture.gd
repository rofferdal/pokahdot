class_name GuiReplacementSnapshotCapture
extends RefCounted


func guidance_snapshot(
	root: Control, host: GuiCompositionHost, geometry: GuiViewportGeometry, transform: Transform2D
) -> GuiLayoutSnapshot:
	var snapshot := GuiLayoutSnapshot.new()
	snapshot.schema_version = 2
	snapshot.root_rect = Rect2(Vector2.ZERO, root.size)
	snapshot.viewport_rect = snapshot.root_rect
	snapshot.usable_rect = (
		geometry.usable_rect if geometry != null and geometry.valid else snapshot.root_rect
	)
	snapshot.surface_rect = transform * snapshot.usable_rect
	snapshot.surface_size = snapshot.usable_rect.size
	var state: GuiCompositionState = host.state
	snapshot.layout_mode = (
		state.fit.size_class.mode
		if state != null and state.fit != null
		else GuiSizeClass.LayoutMode.WIDE
	)
	snapshot.profile = GuiSnapshotMeasurement.profile_for_mode(snapshot.layout_mode)
	snapshot.fit_guidance = (
		state.guidance
		if state != null and not state.guidance.is_empty()
		else "Waiting for table measurements."
	)
	var message: Control = host.get_node("LayoutSlot/SpaceGuidance/Center/Message")
	var observed: GuiLayoutElement = GuiSnapshotMeasurement.element(message, root, &"guidance")
	snapshot.elements[&"guidance"] = observed
	snapshot.measured.append(observed)
	var more: GuiLayoutElement = GuiSnapshotMeasurement.element(
		root.get_node("GuidanceRail/Row/More"), root, &"action/more"
	)
	snapshot.elements[&"action/more"] = more
	snapshot.measured.append(more)
	snapshot.menu_routes = {&"quit": &"more", &"event": &"more"}
	return snapshot


func capture_overlay(
	snapshot: GuiLayoutSnapshot,
	root: Control,
	overlay: GuiOverlayHost,
	detail_seat: int,
	authorization: Array[bool]
) -> void:
	if not overlay.is_active():
		return
	var active: Control = overlay.get_control(&"active")
	var kind: StringName = overlay.get_active_kind()
	kind = &"keypad" if kind == &"number" else &"seat_detail" if kind == &"seat" else kind
	var value := GuiOverlaySnapshot.new()
	value.kind = kind
	value.element = GuiSnapshotMeasurement.element(active, root, StringName("overlay/" + str(kind)))
	var redacted: Array[Node] = []
	if kind == &"seat_detail":
		value.selected_seat = detail_seat
		var pair := overlay.get_control(&"seat_cards") as GuiHoleCards
		for index: int in pair.cards.size():
			var authorized: bool = index < authorization.size() and authorization[index]
			if not authorized:
				redacted.append(pair.cards[index])
			value.cards.append(
				pair.cards[index].get_card_snapshot(
					root, StringName("overlay/seat_detail/cards/%d" % index), authorized
				)
			)
	var semantic: Dictionary[Node, StringName] = {overlay.get_log().get_body(): &"event"}
	GuiSnapshotMeasurement.descendants(
		active, root, value.element.role, value.measured, redacted, false, [], semantic
	)
	if kind == &"keypad":
		for role: StringName in [
			&"clear", &"back", &"done", &"cancel", &"value", &"title", &"limits", &"minimum", &"pot"
		]:
			value.elements[role] = GuiSnapshotMeasurement.element(
				overlay.get_keypad().get_control(role),
				root,
				StringName("overlay/keypad/" + str(role))
			)
		for digit: int in 10:
			var role := StringName("key/%d" % digit)
			value.elements[role] = GuiSnapshotMeasurement.element(
				overlay.get_keypad().get_control(StringName(str(digit))),
				root,
				StringName("overlay/keypad/" + str(role))
			)
	snapshot.overlays.append(value)
