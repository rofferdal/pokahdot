class_name GuiTableSnapshotProducer
extends RefCounted

## Legacy adaptation boundary. Consumers see roles and detached measurements,
## while the producer may inspect the reference implementation's current tree.
const Measure := preload("res://scripts/gui/gui_snapshot_measurement.gd")


static func capture(
	root: Control,
	surface: Control,
	view: GameView,
	controls: Dictionary[StringName, Control],
	panels: Dictionary[int, PanelContainer],
	statuses: Dictionary[int, Label],
	modal_nodes: Dictionary[StringName, Node],
	detail_seat: int,
) -> GuiLayoutSnapshot:
	var result := GuiLayoutSnapshot.new()
	result.root_rect = Measure.rect(root, root)
	result.viewport_rect = root.get_viewport().get_visible_rect()
	result.surface_rect = Measure.rect(surface, root)
	result.surface_size = surface.size
	result.surface_transform = surface.get_global_transform_with_canvas()
	result.usable_rect = result.root_rect
	var redacted_roots: Array[Node] = []
	for role: StringName in controls:
		result.elements[role] = Measure.element(controls[role], root, role)
	if view != null:
		result.expected_board_card_count = view.community_cards.size()
		for action: PlayerAction.Kind in view.legal_actions:
			result.legal_actions.append(action)
		for player: PlayerView in view.seats:
			if panels.has(player.seat):
				var seat := _seat(
					root, panels[player.seat], statuses.get(player.seat), player, view
				)
				result.seats[player.seat] = seat
				result.elements[StringName("seat/%d" % player.seat)] = seat.panel
				result.elements[StringName("status/%d" % player.seat)] = seat.status
				if not seat.face_authorized:
					var cards: Control = _find(panels[player.seat], "HoleCards")
					if cards != null:
						redacted_roots.append(cards)
				if seat.hero:
					result.elements[&"hero"] = seat.panel
		var hero_cards: Control = controls.get(&"hero_cards")
		if (
			hero_cards != null
			and hero_cards.is_visible_in_tree()
			and result.seats.has(view.hero_seat)
		):
			result.seats[view.hero_seat].cards = Measure.cards(
				hero_cards, root, &"hero/cards", true
			)
			result.seats[view.hero_seat].fields[&"cards"] = result.elements[&"hero_cards"]
			result.seats[view.hero_seat].fields[&"stack"] = result.elements[&"hero_stack"]
			result.seats[view.hero_seat].fields[&"action"] = result.elements[&"hero_action"]
	result.board_cards = Measure.cards(controls.get(&"cards"), root, &"board/cards", true)
	var detail: Node = modal_nodes.get(&"seat_detail")
	if detail != null and view != null and not _face_authorized(view, detail_seat):
		var detail_cards: Control = _find(detail, "DetailHoleCards")
		if detail_cards != null:
			redacted_roots.append(detail_cards)
	# Register exact seat-copy and log roles; card/unknown descendants retain the 20 px floor.
	var semantic_nodes: Dictionary[Node, StringName] = {}
	semantic_nodes[surface] = &"surface"
	for seat: int in panels:
		var panel := panels[seat] as GuiTableSeatView
		if panel == null:
			continue
		var copy_fields: Dictionary[StringName, Control] = {
			&"name": panel.name_label,
			&"stack": panel.stack_label,
			&"badge": panel.state_badge,
			&"action": panel.action_badge,
			&"marker": _find(panel, "Marker"),
			&"badge_row_2": _find(panel, "BadgeRow2"),
			&"badge_row_3": _find(panel, "BadgeRow3"),
		}
		for role: StringName in copy_fields:
			if copy_fields[role] != null:
				semantic_nodes[copy_fields[role]] = StringName("seat/%d/%s" % [seat, role])
		if statuses.has(seat):
			semantic_nodes[statuses[seat]] = StringName("status/%d" % seat)
	if controls.has(&"event") and controls[&"event"] != null:
		semantic_nodes[controls[&"event"]] = &"event"
	Measure.descendants(
		root, root, &"table", result.measured, redacted_roots, false, [], semantic_nodes
	)
	for kind: StringName in modal_nodes:
		var overlay := Measure.overlay(modal_nodes[kind], root, kind, redacted_roots)
		if kind == &"seat_detail":
			overlay.selected_seat = detail_seat
			if detail != null:
				overlay.cards = Measure.cards(
					_find(detail, "DetailHoleCards"),
					root,
					&"overlay/seat_detail/cards",
					view != null and _face_authorized(view, detail_seat)
				)
		result.overlays.append(overlay)
	_bind_actions(result)
	return result


static func _seat(
	root: Control, panel: Control, status: Label, player: PlayerView, view: GameView
) -> GuiSeatSnapshot:
	var result := GuiSeatSnapshot.new()
	result.seat_id = player.seat
	result.hero = player.seat == view.hero_seat
	result.folded = player.folded
	result.busted = player.busted
	result.visual_slot = posmod(player.seat - view.hero_seat, view.seats.size())
	result.face_authorized = _face_authorized(view, player.seat)
	var prefix := "seat/%d" % player.seat
	result.panel = Measure.element(panel, root, StringName(prefix))
	result.status = Measure.element(status, root, StringName("status/%d" % player.seat))
	result.status.parent_role = StringName(prefix) if panel.is_ancestor_of(status) else &"surface"
	result.footprint = result.panel.rect
	if result.status.visible:
		result.footprint = result.footprint.merge(result.status.rect)
	var names: Dictionary[StringName, String] = {
		&"name": "Name",
		&"stack": "Stack",
		&"badge": "Badge",
		&"badge_row_2": "BadgeRow2",
		&"badge_row_3": "BadgeRow3",
		&"action": "ActionBadge",
		&"cards": "HoleCards",
		&"avatar": "AvatarRegion",
		&"marker": "Marker",
		&"identity": "Identity",
		&"details": "DetailsButton",
	}
	for role: StringName in names:
		var control: Control = _find(panel, names[role])
		if role == &"action" and panel is GuiTableSeatView:
			control = (panel as GuiTableSeatView).action_badge
		if role == &"cards" and control == null:
			control = _find(panel, "HeroCards")
		result.fields[role] = Measure.element(control, root, StringName("%s/%s" % [prefix, role]))
		if role == &"action" and result.fields[role].visible:
			result.footprint = result.footprint.merge(result.fields[role].rect)
	var marker: Control = _find(panel, "Marker")
	var avatar: Control = _find(panel, "AvatarRegion")
	if marker != null and marker.get_parent() == avatar:
		result.fields[&"marker"].parent_role = result.fields[&"avatar"].role
	var badge := _find(panel, "Badge") as Label
	if badge != null:
		result.required_badge_text = String(badge.get_meta("full_text", badge.text))
	var container: Control = _find(panel, "HeroCards" if result.hero else "HoleCards")
	result.cards = Measure.cards(
		container, root, StringName(prefix + "/cards"), result.face_authorized
	)
	return result


static func _face_authorized(view: GameView, seat: int) -> bool:
	return seat == view.hero_seat or view.revealed_hole_cards.has(seat)


static func _find(root: Node, node_name: String) -> Control:
	return root.find_child(node_name, true, false) as Control


static func _bind_actions(snapshot: GuiLayoutSnapshot) -> void:
	snapshot.actions = {
		PlayerAction.Kind.FOLD: [&"action/fold"],
		PlayerAction.Kind.CHECK: [&"action/check_call"],
		PlayerAction.Kind.CALL: [&"action/check_call"],
		PlayerAction.Kind.BET: [&"action/min_wager", &"action/wager"],
		PlayerAction.Kind.RAISE: [&"action/min_wager", &"action/wager"],
		PlayerAction.Kind.ALL_IN: [&"action/all_in"],
	}
