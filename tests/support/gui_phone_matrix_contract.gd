class_name GuiPhoneMatrixContract
extends RefCounted

## Phone-specific semantic content and privacy checks, independent of node trees.
const OPPONENT_ACTION_PADDING: float = 12.0
const HERO_ACTION_PADDING: float = 4.0
const MAX_SUPPORTED_PLAYER_COUNT: int = 7


static func validate(rendered: Dictionary, context: String, failures: PackedStringArray) -> void:
	var snapshot: GuiLayoutSnapshot = rendered.root.get_layout_snapshot()
	if snapshot.seats.is_empty():
		return
	var reference_check: Callable = rendered.get("reference_geometry_check", Callable())
	if reference_check.is_valid():
		reference_check.call(snapshot, context, failures)
	var found_long_name: bool = false
	for seat_id: int in snapshot.seats:
		var seat: GuiSeatSnapshot = snapshot.seats[seat_id]
		if seat.hero:
			continue
		var name: GuiLayoutElement = seat.fields[&"name"]
		if not name.present or name.text.is_empty():
			failures.append("%s: seat %d has no assigned display name" % [context, seat_id])
			continue
		found_long_name = found_long_name or name.text.length() >= 8
		if name.required_size.x > name.allocated_size.x:
			failures.append("%s: seat %d display name is clipped" % [context, seat_id])
		var stack: GuiLayoutElement = seat.fields[&"stack"]
		if not stack.present or not stack.text.is_valid_int():
			failures.append("%s: seat %d has no numeric stack" % [context, seat_id])
		elif stack.required_size.x > stack.allocated_size.x:
			failures.append("%s: seat %d stack is clipped" % [context, seat_id])
		var details: GuiLayoutElement = seat.fields[&"details"]
		if not details.present or name.text not in details.tooltip:
			failures.append("%s: seat %d detail does not retain its full name" % [context, seat_id])
		if not seat.fields[&"cards"].present or seat.cards.size() != 2:
			failures.append("%s: seat %d does not show two hole-card fields" % [context, seat_id])
			# Do not skip privacy checks: an injected third face is itself a defect.
		_validate_action_content(seat, context, failures)
		_validate_cards(seat, context, failures)
	if snapshot.seats.size() == MAX_SUPPORTED_PLAYER_COUNT and not found_long_name:
		failures.append(
			"%s: seven-player fixture does not exercise an eight-character name" % context
		)
	var hero_action: GuiLayoutElement = snapshot.elements[&"hero_action"]
	if hero_action.visible:
		if hero_action.required_size.x + HERO_ACTION_PADDING > hero_action.allocated_size.x:
			failures.append("%s: hero action content lacks padding" % context)
		for role: StringName in [&"hero_cards", &"hero_stack"]:
			if hero_action.rect.intersects(snapshot.elements[role].rect):
				failures.append("%s: hero action covers %s" % [context, role])
	var more: GuiLayoutElement = snapshot.elements[&"more"]
	if more.rect.size.x < 48.0 or more.rect.size.y < 48.0:
		failures.append("%s: More touch target is below 48 x 48" % context)


static func _validate_action_content(
	seat: GuiSeatSnapshot, context: String, failures: PackedStringArray
) -> void:
	var action: GuiLayoutElement = seat.fields[&"action"]
	if not action.visible:
		return
	if action.required_size.x + OPPONENT_ACTION_PADDING > action.allocated_size.x:
		failures.append("%s: seat %d action content lacks padding" % [context, seat.seat_id])
	for role: StringName in [&"name", &"stack", &"badge", &"cards"]:
		var required: GuiLayoutElement = seat.fields[role]
		if required.present and action.rect.intersects(required.rect):
			failures.append("%s: seat %d action badge covers %s" % [context, seat.seat_id, role])


static func _validate_cards(
	seat: GuiSeatSnapshot, context: String, failures: PackedStringArray
) -> void:
	var expected: GuiCardSnapshot.Kind = GuiCardSnapshot.Kind.BACK
	if seat.folded or seat.busted:
		expected = GuiCardSnapshot.Kind.EMPTY
	elif seat.face_authorized:
		expected = GuiCardSnapshot.Kind.FACE
	var correct: bool = seat.cards.size() == 2
	for card: GuiCardSnapshot in seat.cards:
		if (
			card.element.visible
			and (
				not card.element.rect.has_area()
				or not seat.fields[&"cards"].rect.encloses(card.element.rect)
				or not seat.panel.rect.encloses(card.element.rect)
			)
		):
			failures.append(
				(
					"%s: seat %d card field %s escapes its container or panel"
					% [context, seat.seat_id, card.element.role]
				)
			)
		correct = (
			correct and card.kind == expected and card.element.present and card.element.visible
		)
	if correct:
		return
	var problem: String = "exposes or omits private cards"
	if expected == GuiCardSnapshot.Kind.EMPTY:
		problem = "omits empty card fields"
	elif expected == GuiCardSnapshot.Kind.FACE:
		problem = "revealed-card presentation is incorrect"
	failures.append("%s: seat %d %s" % [context, seat.seat_id, problem])


static func view_signature(view: GameView) -> String:
	if view == null:
		return "startup"
	var seats: Array[Dictionary] = []
	for player_view: PlayerView in view.seats:
		(
			seats
			. append(
				{
					"seat": player_view.seat,
					"stack": player_view.stack,
					"folded": player_view.folded,
					"all_in": player_view.all_in,
					"busted": player_view.busted,
				}
			)
		)
	return (
		JSON
		. stringify(
			{
				"street": String(view.street),
				"acting_seat": view.acting_seat,
				"pot": view.pot_amount,
				"call": view.call_amount,
				"minimum": view.minimum_wager_total,
				"maximum": view.maximum_wager_total,
				"legal_actions": Array(view.legal_actions),
				"active_seats": Array(view.active_seats),
				"eliminated_seats": Array(view.eliminated_seats),
				"seats": seats,
				"showdown_count": view.showdown_results.size(),
				"revealed_count": view.revealed_hole_cards.size(),
			}
		)
	)
