class_name GuiPhoneSnapshotCapture
extends RefCounted


# Value inputs for a single phone snapshot; controls remain owned by the composition.
class Data:
	var mode: GuiSizeClass.LayoutMode
	var surface: Control
	var generation: int
	var pending: bool
	var ready: bool
	var guidance: String
	var rows: Array[PackedInt32Array] = []
	var board_count: int
	var legal_actions: Array[int] = []
	var action_roles: Dictionary[int, Array] = {}


static func capture(root: Control, layout: GuiPhoneTableLayout, data: Data) -> GuiLayoutSnapshot:
	var snapshot := GuiLayoutSnapshot.new()
	snapshot.schema_version = 2
	snapshot.layout_mode = data.mode
	snapshot.profile = GuiSnapshotMeasurement.profile_for_mode(data.mode)
	snapshot.root_rect = Rect2(Vector2.ZERO, root.size)
	snapshot.viewport_rect = snapshot.root_rect
	snapshot.usable_rect = GuiSnapshotMeasurement.rect(layout, root)
	snapshot.surface_rect = GuiSnapshotMeasurement.rect(data.surface, root)
	snapshot.surface_size = data.surface.size
	snapshot.surface_transform = (data.surface.get_global_transform_with_canvas())
	snapshot.generation = data.generation
	snapshot.pending = data.pending
	snapshot.ready = data.ready
	snapshot.fit_guidance = data.guidance
	snapshot.seat_rows = data.rows.duplicate()
	snapshot.menu_routes = {&"quit": &"more", &"event": &"more"}
	var center := layout.get_control(&"center") as GuiCenterBoard
	var actions := layout.get_control(&"actions") as GuiActionBar
	var seats: Dictionary[int, Control] = layout.get_seat_controls()
	var roles: Dictionary[StringName, Control] = {
		&"center": center,
		&"board": center.get_node("Cards"),
		&"pot": center.get_node("Totals/Pot"),
		&"wager": center.get_node("Totals/Wager"),
		&"action": actions,
		&"logo": layout.get_control(&"logo"),
		&"guidance": layout.get_control(&"guidance").get_node("Center/Message")
	}
	for role: StringName in [
		&"fold",
		&"check_call",
		&"minimum",
		&"pot",
		&"wager",
		&"all_in",
		&"continue",
		&"more",
		&"total",
		&"status"
	]:
		roles[StringName("action/" + str(role))] = actions.get_control(role)
	for role: StringName in roles:
		var element: GuiLayoutElement = GuiSnapshotMeasurement.element(roles[role], root, role)
		snapshot.elements[role] = element
		snapshot.measured.append(element)
	var event := GuiLayoutElement.new()
	event.role = &"event"
	snapshot.elements[&"event"] = event
	for id: int in seats:
		snapshot.seats[id] = (seats[id] as GuiSeatToken).get_seat_snapshot(root)
	var cards := center.get_node("Cards") as GuiCardRow
	for index: int in cards.cards.size():
		snapshot.board_cards.append(
			cards.cards[index].get_card_snapshot(root, StringName("board/%d" % index), true)
		)
	snapshot.expected_board_card_count = data.board_count
	snapshot.legal_actions = data.legal_actions.duplicate()
	snapshot.actions = data.action_roles.duplicate(true)
	return snapshot
