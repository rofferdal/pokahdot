class_name GuiInvariantAssertions
extends RefCounted

## Reusable invariant validator for deterministic GUI scene fixtures.

const MINIMUM_FONT_SIZE: int = 20
const MINIMUM_TOUCH_SIZE := Vector2(48.0, 48.0)
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")


static func validate(rendered: Dictionary) -> PackedStringArray:
	var failures := PackedStringArray()
	_validate_explicit_overlay(rendered, failures)
	var table: PokerTableController = rendered.table
	if table != null:
		_validate_table(rendered, failures)
	else:
		_validate_control_tree(rendered.root, rendered.root.get_global_rect(), failures)
		_validate_overlay_controls(rendered, failures)
	return failures


static func _validate_table(rendered: Dictionary, failures: PackedStringArray) -> void:
	var table: PokerTableController = rendered.table
	if GuiLayoutProfileScript.is_phone(rendered.layout_profile):
		_validate_phone_table(rendered, failures)
		return
	var surface := table.get_node("TableMargin/Felt/TableSurface") as Control
	var surface_rect := Rect2(Vector2.ZERO, surface.size)
	var regions: Dictionary[StringName, Rect2] = table.get_resolved_region_rects()
	for region_name: StringName in regions:
		var region: Rect2 = regions[region_name]
		if region.size == Vector2.ZERO:
			continue
		_require(
			surface_rect.encloses(region),
			"containment: %s %s is outside %s" % [region_name, region, surface_rect],
			failures,
		)

	var seat_rects: Dictionary[int, Rect2] = table.get_seat_rects()
	var quit_button := table.get_node("%QuitButton") as Button
	var quit_rect := Rect2(
		quit_button.global_position - surface.global_position,
		quit_button.size,
	)
	for major_name: StringName in [&"center", &"action", &"event"]:
		_require(
			not quit_rect.intersects(regions[major_name]),
			"intersection: quit intersects %s" % major_name,
			failures,
		)
	var placed_seats: Array[Rect2] = []
	for seat: int in seat_rects:
		var seat_rect: Rect2 = seat_rects[seat]
		for placed: Rect2 in placed_seats:
			_require(
				not seat_rect.intersects(placed),
				"intersection: seat_%d %s intersects seat %s" % [seat, seat_rect, placed],
				failures,
			)
		placed_seats.append(seat_rect)
		_require(
			not quit_rect.intersects(seat_rect),
			"intersection: quit intersects seat_%d" % seat,
			failures,
		)
		for major_name: StringName in [&"center", &"action", &"event"]:
			_require(
				not seat_rect.intersects(regions[major_name]),
				"intersection: seat_%d intersects %s" % [seat, major_name],
				failures,
			)
		_validate_auxiliary_clearance(seat, seat_rect, seat_rects, regions, failures)
		_validate_compact_seat_content(table, seat, failures)
		_require(
			not quit_rect.intersects(regions[StringName("status_%d" % seat)]),
			"auxiliary-clearance: quit intersects status_%d" % seat,
			failures,
		)

	for first_name: StringName in [&"center", &"action", &"event"]:
		for second_name: StringName in [&"center", &"action", &"event"]:
			if String(first_name) >= String(second_name):
				continue
			_require(
				not regions[first_name].intersects(regions[second_name]),
				"intersection: %s intersects %s" % [first_name, second_name],
				failures,
			)

	_validate_control_tree(table, table.get_global_rect(), failures)
	_validate_community_cards(table, failures)
	_validate_legal_actions(table, rendered.descriptor.view, failures)
	_validate_overlay_controls(rendered, failures)


static func _validate_phone_table(rendered: Dictionary, failures: PackedStringArray) -> void:
	var table: PokerTableController = rendered.table
	var surface := table.get_node("TableMargin/Felt/TableSurface") as Control
	var surface_rect := Rect2(surface.global_position, surface.size)
	var regions: Dictionary[StringName, Rect2] = table.get_resolved_region_rects()
	for region_name: StringName in [&"center", &"action"]:
		var region_global := Rect2(
			regions[region_name].position + surface.global_position, regions[region_name].size
		)
		_require(
			surface_rect.encloses(region_global),
			"containment: %s %s is outside %s" % [region_name, region_global, surface_rect],
			failures,
		)
	var visible_seats: Array[Rect2] = []
	var more_button := table.get_node("%PhoneMoreButton") as Button
	var more_rect: Rect2 = more_button.get_global_rect()
	_require(
		(
			(table.get_node("TableMargin/Felt/TableSurface/ActionPanel") as Control)
			. get_global_rect()
			. encloses(more_rect)
		),
		"containment: More is outside the reserved action region",
		failures,
	)
	for seat: int in table.get_seat_rects():
		var panel := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as Control
		if not panel.visible:
			continue
		var seat_rect := panel.get_global_rect()
		_require(surface_rect.encloses(seat_rect), "containment: seat_%d" % seat, failures)
		for placed: Rect2 in visible_seats:
			_require(not seat_rect.intersects(placed), "intersection: seat_%d" % seat, failures)
		visible_seats.append(seat_rect)
		_require(
			not seat_rect.intersects(more_rect),
			"intersection: More intersects seat_%d" % seat,
			failures,
		)
		_validate_phone_token_content(panel, seat, failures)
		for major_name: StringName in [&"center", &"action"]:
			var major_global := Rect2(
				regions[major_name].position + surface.global_position, regions[major_name].size
			)
			_require(
				not seat_rect.intersects(major_global),
				(
					"intersection: seat_%d %s intersects %s %s"
					% [seat, seat_rect, major_name, major_global]
				),
				failures,
			)
	var center_global := Rect2(
		regions.center.position + surface.global_position, regions.center.size
	)
	var action_global := Rect2(
		regions.action.position + surface.global_position, regions.action.size
	)
	_require(
		not center_global.intersects(action_global),
		"intersection: action intersects center",
		failures
	)
	var center_control := table.get_node("TableMargin/Felt/TableSurface/CenterZone") as Control
	for child_name: String in ["BoardZone", "PotZone", "WagerZone"]:
		var child := center_control.get_node(child_name) as Control
		_require(
			center_control.get_global_rect().encloses(child.get_global_rect()),
			"containment: center does not enclose %s" % child_name,
			failures,
		)
	_validate_control_tree(table, table.get_global_rect(), failures)
	_validate_community_cards(table, failures)
	_validate_legal_actions(table, rendered.descriptor.view, failures)
	_validate_overlay_controls(rendered, failures)


static func _validate_phone_token_content(
	panel: Control, seat: int, failures: PackedStringArray
) -> void:
	var name_label := panel.find_child("Name", true, false) as Label
	var stack_label := panel.find_child("Stack", true, false) as Label
	var badge := panel.find_child("Badge", true, false) as Label
	var cards := panel.find_child("HoleCards", true, false) as Control
	if name_label == null or stack_label == null or badge == null or cards == null:
		return
	_require(
		not name_label.get_global_rect().intersects(badge.get_global_rect()),
		"seat-content: seat_%d name intersects state/position badge" % seat,
		failures,
	)
	_require(
		not stack_label.get_global_rect().intersects(cards.get_global_rect()),
		"seat-content: seat_%d stack intersects cards" % seat,
		failures,
	)
	_validate_phone_showdown_cards(panel, cards, seat, failures)


static func _validate_phone_showdown_cards(
	panel: Control, cards: Control, seat: int, failures: PackedStringArray
) -> void:
	var previous_card: Control
	for index: int in range(2):
		var card := panel.find_child("ShowdownCard%d" % (index + 1), true, false) as Control
		if card == null:
			continue
		var context := "seat-content: seat_%d card_%d" % [seat, index + 1]
		var rank := card.get_node("Content/Rank") as Label
		var suit := card.get_node("Content/Suit") as TextureRect
		_require(cards.get_global_rect().encloses(card.get_global_rect()), context, failures)
		_require(panel.get_global_rect().encloses(card.get_global_rect()), context, failures)
		_require(card.get_global_rect().encloses(rank.get_global_rect()), context, failures)
		_require(card.get_global_rect().encloses(suit.get_global_rect()), context, failures)
		_require(
			rank.get_global_rect().end.x <= suit.get_global_rect().position.x,
			"%s rank intersects suit" % context,
			failures,
		)
		var rank_size: Vector2 = (
			rank
			. get_theme_font("font")
			. get_string_size(
				rank.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				rank.get_theme_font_size("font_size"),
			)
		)
		_require(rank_size.x <= rank.size.x, "%s rank is clipped" % context, failures)
		_require(
			suit.size.x >= 18.0 and suit.size.y >= 18.0,
			"%s suit is too small" % context,
			failures,
		)
		if previous_card != null:
			_require(
				not previous_card.get_global_rect().intersects(card.get_global_rect()),
				"%s intersects the other revealed card" % context,
				failures,
			)
		previous_card = card


static func _validate_compact_seat_content(
	table: PokerTableController, seat: int, failures: PackedStringArray
) -> void:
	var panel := (
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as PanelContainer
	)
	var avatar_region := panel.find_child("AvatarRegion", true, false) as Control
	var identity := panel.find_child("Identity", true, false) as VBoxContainer
	var marker := panel.find_child("Marker", true, false) as Label
	if (
		avatar_region == null
		or identity == null
		or marker == null
		or marker.get_parent() != avatar_region
	):
		return
	_require(
		avatar_region.get_global_rect().encloses(marker.get_global_rect()),
		(
			"seat-content: seat_%d marker %s escapes compact avatar %s"
			% [seat, marker.get_global_rect(), avatar_region.get_global_rect()]
		),
		failures,
	)
	_require(
		not marker.get_global_rect().intersects(identity.get_global_rect()),
		(
			"seat-content: seat_%d marker %s intersects identity %s"
			% [seat, marker.get_global_rect(), identity.get_global_rect()]
		),
		failures,
	)


static func _validate_auxiliary_clearance(
	seat: int,
	seat_rect: Rect2,
	seat_rects: Dictionary[int, Rect2],
	regions: Dictionary[StringName, Rect2],
	failures: PackedStringArray,
) -> void:
	var status_name := StringName("status_%d" % seat)
	var status: Rect2 = regions[status_name]
	_require(
		status.position.y >= seat_rect.end.y,
		"auxiliary-clearance: %s is not below seat_%d" % [status_name, seat],
		failures,
	)
	for other_seat: int in seat_rects:
		_require(
			not status.intersects(seat_rects[other_seat]),
			"auxiliary-clearance: %s intersects seat_%d" % [status_name, other_seat],
			failures,
		)
	for major_name: StringName in [&"center", &"action", &"event"]:
		_require(
			not status.intersects(regions[major_name]),
			"auxiliary-clearance: %s intersects %s" % [status_name, major_name],
			failures,
		)


static func _validate_control_tree(
	root: Control, usable_rect: Rect2, failures: PackedStringArray
) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var path: String = str(root.get_path_to(control))
		_require(
			usable_rect.encloses(control.get_global_rect()),
			"containment: %s %s is outside %s" % [path, control.get_global_rect(), usable_rect],
			failures,
		)
		_validate_font(control, path, failures)
		if control is BaseButton or control is LineEdit:
			_require(
				control.size.x >= MINIMUM_TOUCH_SIZE.x and control.size.y >= MINIMUM_TOUCH_SIZE.y,
				"touch-target: %s has size %s" % [path, control.size],
				failures,
			)
		_validate_text_fit(control, path, failures)


static func _validate_font(control: Control, path: String, failures: PackedStringArray) -> void:
	var font_size: int = 0
	if control is RichTextLabel:
		font_size = control.get_theme_font_size("normal_font_size")
	elif control is Label or control is Button or control is LineEdit or control is CheckBox:
		font_size = control.get_theme_font_size("font_size")
	if font_size > 0:
		_require(
			font_size >= MINIMUM_FONT_SIZE,
			"font-floor: %s uses %d px" % [path, font_size],
			failures,
		)


static func _validate_text_fit(control: Control, path: String, failures: PackedStringArray) -> void:
	var text: String = ""
	var font_size: int = 0
	if control is Label:
		text = control.text
		font_size = control.get_theme_font_size("font_size")
		if control.autowrap_mode != TextServer.AUTOWRAP_OFF:
			_require(
				control.get_visible_line_count() >= control.get_line_count(),
				"text-clipping: %s hides wrapped lines" % path,
				failures,
			)
			return
	elif control is Button or control is CheckBox:
		text = control.text
		font_size = control.get_theme_font_size("font_size")
	elif control is LineEdit:
		text = control.text if not control.text.is_empty() else control.placeholder_text
		font_size = control.get_theme_font_size("font_size")
	else:
		return
	if text.is_empty() or font_size <= 0:
		return
	if control is Label and control.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		return
	var rendered_width: float = (
		control
		. get_theme_font("font")
		. get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		. x
	)
	_require(
		rendered_width <= control.size.x,
		"text-clipping: %s needs %.1f px but has %.1f px" % [path, rendered_width, control.size.x],
		failures,
	)


static func _validate_community_cards(
	table: PokerTableController, failures: PackedStringArray
) -> void:
	var board := table.get_node("TableMargin/Felt/TableSurface/CenterZone/BoardZone") as Control
	var slots := table.get_node("%CardSlots") as HBoxContainer
	_require(slots.get_child_count() == 5, "community-cards: expected five slots", failures)
	for index: int in range(table.board_card_count):
		var card := slots.get_child(index) as Control
		_require(card.is_visible_in_tree(), "community-cards: slot %d is hidden" % index, failures)
		_require(
			board.get_global_rect().encloses(card.get_global_rect()),
			"community-cards: slot %d is outside the board" % index,
			failures,
		)
		_require(card.modulate.a >= 0.99, "community-cards: slot %d is faded" % index, failures)


static func _validate_legal_actions(
	table: PokerTableController, view: GameView, failures: PackedStringArray
) -> void:
	var reported_rects: Dictionary[StringName, Rect2] = table.get_action_control_rects()
	var controls_by_action: Dictionary = {
		PlayerAction.Kind.FOLD: [table.get_node("%FoldButton")],
		PlayerAction.Kind.CHECK: [table.get_node("%CheckCallButton")],
		PlayerAction.Kind.CALL: [table.get_node("%CheckCallButton")],
		PlayerAction.Kind.BET: [table.get_node("%MinWagerButton"), table.get_node("%WagerButton")],
		PlayerAction.Kind.RAISE:
		[table.get_node("%MinWagerButton"), table.get_node("%WagerButton")],
		PlayerAction.Kind.ALL_IN: [table.get_node("%AllInButton")],
	}
	var action_panel := table.get_node("TableMargin/Felt/TableSurface/ActionPanel") as Control
	for action: PlayerAction.Kind in view.legal_actions:
		var reachable: bool = false
		for control: Control in controls_by_action[action]:
			var control_rect: Rect2 = reported_rects.get(
				StringName(control.name), control.get_global_rect()
			)
			if (
				control.is_visible_in_tree()
				and not control.disabled
				and action_panel.get_global_rect().encloses(control_rect)
			):
				reachable = true
		_require(reachable, "legal-action: %s is not reachable" % action, failures)


static func _validate_explicit_overlay(rendered: Dictionary, failures: PackedStringArray) -> void:
	var allowed: Array = rendered.intentional_overlap_controls
	var expected: Array = []
	match rendered.descriptor.id:
		&"quit-confirmation":
			expected = (
				[&"PhoneQuitConfirmation"]
				if GuiLayoutProfileScript.is_phone(rendered.layout_profile)
				else [&"QuitConfirmation"]
			)
		&"keypad-open":
			expected = [&"StartupNumberKeypad"]
		&"wager-entry":
			if GuiLayoutProfileScript.is_phone(rendered.layout_profile):
				expected = [&"WagerKeypad"]
		&"showdown-long":
			if GuiLayoutProfileScript.is_phone(rendered.layout_profile):
				expected = [&"PhoneShowdownOverlay"]
	_require(
		allowed == expected,
		"overlay-exception: expected %s, got %s" % [expected, allowed],
		failures
	)
	if not expected.is_empty():
		_require(
			rendered.overlay != null and rendered.overlay.visible,
			"overlay-exception: named overlay is not visible",
			failures,
		)


static func _validate_overlay_controls(rendered: Dictionary, failures: PackedStringArray) -> void:
	var overlay: Node = rendered.overlay
	if overlay == null or not overlay.visible:
		return
	for node: Node in overlay.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		_validate_font(control, str(control.get_path()), failures)
		if control is BaseButton or control is LineEdit:
			_require(
				control.size.x >= MINIMUM_TOUCH_SIZE.x and control.size.y >= MINIMUM_TOUCH_SIZE.y,
				"touch-target: overlay %s has size %s" % [control.name, control.size],
				failures,
			)
		if overlay is Control:
			_require(
				(overlay as Control).get_global_rect().encloses(control.get_global_rect()),
				"containment: overlay does not enclose %s" % control.name,
				failures,
			)


static func _require(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
