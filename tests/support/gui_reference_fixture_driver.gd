class_name GuiReferenceFixtureDriver
extends RefCounted

## Reference-only scene bootstrap. Replacement scenes provide a different driver
## while retaining the generic harness, semantic invariants and ordered cases.

const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const MainScene := preload("res://scenes/main.tscn")
const PokerTableScene := preload("res://scenes/poker_table.tscn")

var _viewport: SubViewport
var _profile_override: int = GuiLayoutProfileScript.AUTOMATIC


func render(
	viewport: SubViewport,
	descriptor: Dictionary,
	viewport_size: Vector2i,
	profile_override: int,
) -> Dictionary:
	_viewport = viewport
	_profile_override = profile_override
	if (
		descriptor.kind
		in [
			GuiVisualStateFixturesScript.KIND_STARTUP,
			GuiVisualStateFixturesScript.KIND_UI_ONLY,
		]
	):
		return _render_startup_state(descriptor, viewport_size, profile_override)
	return _render_table_state(descriptor, viewport_size, profile_override)


func resize(rendered: Dictionary, viewport_size: Vector2i) -> void:
	var root: Control = rendered.root
	root.size = Vector2(viewport_size)
	if rendered.table == null:
		root.call("_refresh_startup_layout")


func rerender(rendered: Dictionary, descriptor: Dictionary) -> Dictionary:
	assert(rendered.table != null, "Only a rendered table can bind a new visual state.")
	assert(descriptor.view != null, "A table rerender requires a GameView snapshot.")
	var table: PokerTableController = rendered.table
	_close_overlay(rendered.overlay)
	(
		table
		. bind_view(
			descriptor.view,
			_avatar_assignments(descriptor.player_count),
			_name_assignments(descriptor.player_count),
		)
	)
	table._render_events(descriptor.events)
	if descriptor.id == &"wager-entry":
		(table.get_node("%WagerInput") as LineEdit).text = descriptor.ui.wager_input_text
	var overlay: Node = null
	if descriptor.id == &"quit-confirmation":
		overlay = _open_quit_fixture_overlay(table)
	elif GuiLayoutProfileScript.is_phone(table.get_layout_profile()):
		overlay = _open_phone_fixture_overlay(table, descriptor.id)
	return _result(descriptor, table, table, overlay)


func _render_startup_state(
	descriptor: Dictionary, viewport_size: Vector2i, profile_override: int
) -> Dictionary:
	var main := MainScene.instantiate() as Control
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(viewport_size)
	_viewport.add_child(main)
	main.set_layout_profile_override(profile_override)
	main._refresh_startup_layout()
	var overlay: Node = null
	if descriptor.id == &"keypad-open":
		main.show_numeric_keypad(main.get_node("%PlayerCountInput") as LineEdit)
		overlay = main.get_node("StartupNumberKeypad")
	return _result(descriptor, main, null, overlay)


func _render_table_state(
	descriptor: Dictionary, viewport_size: Vector2i, profile_override: int
) -> Dictionary:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(viewport_size)
	_viewport.add_child(table)
	table.set_layout_profile_override(profile_override)
	(
		table
		. bind_view(
			descriptor.view,
			_avatar_assignments(descriptor.player_count),
			_name_assignments(descriptor.player_count),
		)
	)
	if not descriptor.events.is_empty():
		table._render_events(descriptor.events)
	if descriptor.id == &"wager-entry":
		(table.get_node("%WagerInput") as LineEdit).text = descriptor.ui.wager_input_text
	var overlay: Node = null
	if descriptor.id == &"quit-confirmation":
		overlay = _open_quit_fixture_overlay(table)
	elif GuiLayoutProfileScript.is_phone(table.get_layout_profile()):
		overlay = _open_phone_fixture_overlay(table, descriptor.id)
	return _result(descriptor, table, table, overlay)


func _open_quit_fixture_overlay(table: PokerTableController) -> Node:
	if GuiLayoutProfileScript.is_phone(table.get_layout_profile()):
		var phone_confirmation := table.get_node("%PhoneQuitConfirmation") as Control
		phone_confirmation.show()
		table.call("_layout_phone_overlays")
		return phone_confirmation
	var confirmation := table.get_node("%QuitConfirmation") as ConfirmationDialog
	confirmation.popup_centered()
	return confirmation


func _open_phone_fixture_overlay(table: PokerTableController, state_id: StringName) -> Node:
	match state_id:
		&"wager-entry":
			table.show_wager_keypad()
			return table.get_node("WagerKeypad")
		&"showdown-overlay":
			table.call("_open_phone_showdown")
			return table.get_node("%PhoneShowdownOverlay")
	return null


func _result(
	descriptor: Dictionary, root: Control, table: PokerTableController, overlay: Node
) -> Dictionary:
	var overlap_controls: Array = descriptor.ui.get("intentional_overlap_controls", []).duplicate()
	if overlay != null and overlay.name == &"PhoneQuitConfirmation":
		overlap_controls.erase(&"QuitConfirmation")
	if overlay != null and overlay.visible and overlay.name not in overlap_controls:
		overlap_controls.append(StringName(overlay.name))
	return {
		"descriptor": descriptor,
		"viewport": _viewport,
		"root": root,
		"table": table,
		"overlay": overlay,
		"intentional_overlap_controls": overlap_controls,
		"intentional_overlap_roles": _expected_overlay_roles(descriptor, table),
		"reference_geometry_check": validate_phone_geometry,
		"layout_profile":
		(
			table.get_layout_profile()
			if table != null
			else GuiLayoutProfileScript.classify(root.size, _profile_override)
		),
	}


func _avatar_assignments(player_count: int) -> Dictionary[int, String]:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = paths[seat]
	return assignments


func _name_assignments(player_count: int) -> Dictionary[int, String]:
	var names: Array[String] = [
		"Human",
		"Youssef",
		"Leilani",
		"Aleksiej",
		"Santiago",
		"Priyanka",
		"Kwame",
		"Saoirse",
		"Natsuki"
	]
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = names[seat]
	return assignments


func _close_overlay(overlay: Node) -> void:
	if overlay != null and overlay.has_method("hide"):
		overlay.call("hide")


func _expected_overlay_roles(
	descriptor: Dictionary, table: PokerTableController
) -> Array[StringName]:
	var roles: Array[StringName] = []
	match descriptor.id:
		&"quit-confirmation":
			roles.append(&"quit")
		&"keypad-open":
			roles.append(&"keypad")
		&"showdown-overlay":
			if table != null and GuiLayoutProfileScript.is_phone(table.get_layout_profile()):
				roles.append(&"summary")
		&"wager-entry":
			if table != null and GuiLayoutProfileScript.is_phone(table.get_layout_profile()):
				roles.append(&"keypad")
	return roles


## Portrait review checks semantic geometry rather than frozen token pixels.
## Landscape retains its independent legacy characterization until redesigned.
static func validate_phone_geometry(
	snapshot: GuiLayoutSnapshot, context: String, failures: PackedStringArray
) -> void:
	if snapshot.surface_size.y > snapshot.surface_size.x:
		_validate_portrait_geometry(snapshot, context, failures)
		return
	var expected_rects: Dictionary[int, Rect2] = GuiPhoneSeatLayout.seat_rects(
		snapshot.surface_size, snapshot.seats.size()
	)
	for seat_id: int in snapshot.seats:
		var seat: GuiSeatSnapshot = snapshot.seats[seat_id]
		if seat.hero:
			continue
		var expected: Rect2 = snapshot.surface_transform * expected_rects[seat.visual_slot]
		if not seat.panel.rect.is_equal_approx(expected):
			failures.append(
				(
					"%s: density-tier rectangle mismatch for seat %d: %s != %s"
					% [context, seat_id, seat.panel.rect, expected]
				)
			)


static func _validate_portrait_geometry(
	snapshot: GuiLayoutSnapshot, context: String, failures: PackedStringArray
) -> void:
	var opponents: Array[GuiSeatSnapshot] = []
	var hero_id: int = -1
	for seat: GuiSeatSnapshot in snapshot.seats.values():
		if seat.hero:
			hero_id = seat.seat_id
		elif seat.panel.visible:
			opponents.append(seat)
	var footprints: Array[Rect2] = []
	for seat: GuiSeatSnapshot in opponents:
		var bands: Array[GuiLayoutElement] = []
		if seat.status != null:
			bands.append(seat.status)
		if seat.fields.has(&"action"):
			bands.append(seat.fields[&"action"])
		for band: GuiLayoutElement in bands:
			if band.visible and band.line_count > 2:
				failures.append(
					(
						"%s: portrait-status-lines: seat %d %s requires more than two lines"
						% [context, seat.seat_id, band.role]
					)
				)
			if band.visible and not seat.footprint.grow(0.01).encloses(band.rect):
				failures.append(
					(
						"%s: portrait-footprint: seat %d omits visible %s"
						% [context, seat.seat_id, band.role]
					)
				)
		if not snapshot.surface_rect.grow(0.01).encloses(seat.footprint):
			failures.append(
				"%s: portrait-footprint: seat %d escapes usable surface" % [context, seat.seat_id]
			)
		for other: GuiSeatSnapshot in opponents:
			if other.seat_id < seat.seat_id and seat.footprint.intersects(other.footprint):
				failures.append(
					(
						"%s: portrait-footprint: seat %d intersects seat %d"
						% [context, seat.seat_id, other.seat_id]
					)
				)
		for role: StringName in [&"center", &"action"]:
			if (
				snapshot.elements.has(role)
				and seat.footprint.intersects(snapshot.elements[role].rect)
			):
				failures.append(
					"%s: portrait-footprint: seat %d intersects %s" % [context, seat.seat_id, role]
				)
		footprints.append(seat.footprint)
		if seat.visual_slot != posmod(seat.seat_id - hero_id, snapshot.seats.size()):
			failures.append(
				"%s: portrait-identity: seat %d has wrong relative slot" % [context, seat.seat_id]
			)
	if _maximum_band_population(footprints) > 2:
		(
			failures
			. append(
				(
					"%s: portrait-row-cap: more than two complete seat footprints share a horizontal band"
					% context
				)
			)
		)
	_validate_portrait_rows(snapshot, opponents, context, failures)
	_validate_portrait_order(opponents, context, failures)


static func _validate_portrait_rows(
	snapshot: GuiLayoutSnapshot,
	opponents: Array[GuiSeatSnapshot],
	context: String,
	failures: PackedStringArray
) -> void:
	if opponents.is_empty():
		return
	var ordered: Array[GuiSeatSnapshot] = opponents.duplicate()
	ordered.sort_custom(
		func(a: GuiSeatSnapshot, b: GuiSeatSnapshot) -> bool:
			return a.panel.rect.position.y < b.panel.rect.position.y
	)
	var rows: Array[Array] = []
	for seat: GuiSeatSnapshot in ordered:
		if (
			rows.is_empty()
			or not is_equal_approx(seat.panel.rect.position.y, rows[-1][0].panel.rect.position.y)
		):
			rows.append([])
		rows[-1].append(seat)
	var odd: bool = opponents.size() % 2 == 1
	for index: int in range(rows.size()):
		var expected: int = 1 if odd and index == 0 else 2
		if rows[index].size() != expected:
			failures.append(
				"%s: portrait-apex: expected one odd apex followed by paired rows" % context
			)
	if not odd:
		return
	var apex: GuiSeatSnapshot = rows[0][0]
	if not is_equal_approx(apex.panel.rect.get_center().x, snapshot.surface_rect.get_center().x):
		failures.append("%s: portrait-apex: top seat is not centered" % context)
	if apex.panel.rect.size.x > snapshot.surface_rect.size.x * 0.5 + 0.01:
		failures.append("%s: portrait-apex: top seat is wider than a paired column" % context)
	for seat: GuiSeatSnapshot in opponents:
		if not is_equal_approx(seat.panel.rect.size.x, apex.panel.rect.size.x):
			failures.append("%s: portrait-apex: top seat width differs from paired seats" % context)


static func _maximum_band_population(footprints: Array[Rect2]) -> int:
	var edges: Array[float] = []
	for footprint: Rect2 in footprints:
		edges.append(footprint.position.y)
		edges.append(footprint.end.y)
	edges.sort()
	var maximum: int = 0
	for index: int in range(edges.size() - 1):
		var y: float = (edges[index] + edges[index + 1]) * 0.5
		var population: int = 0
		for footprint: Rect2 in footprints:
			if footprint.position.y < y and footprint.end.y > y:
				population += 1
		maximum = maxi(maximum, population)
	return maximum


static func _validate_portrait_order(
	opponents: Array[GuiSeatSnapshot], context: String, failures: PackedStringArray
) -> void:
	if opponents.size() < 2:
		return
	var lower := Vector2(INF, INF)
	var upper := Vector2(-INF, -INF)
	for seat: GuiSeatSnapshot in opponents:
		lower = lower.min(seat.panel.rect.get_center())
		upper = upper.max(seat.panel.rect.get_center())
	opponents.sort_custom(
		func(a: GuiSeatSnapshot, b: GuiSeatSnapshot) -> bool: return a.visual_slot < b.visual_slot
	)
	var previous: float = -1.0
	var height: float = upper.y - lower.y
	var width: float = upper.x - lower.x
	for seat: GuiSeatSnapshot in opponents:
		var center: Vector2 = seat.panel.rect.get_center()
		var distance: float
		if is_equal_approx(center.x, lower.x):
			distance = upper.y - center.y
		elif is_equal_approx(center.y, lower.y):
			distance = height + center.x - lower.x
		elif is_equal_approx(center.x, upper.x):
			distance = height + width + center.y - lower.y
		elif is_equal_approx(center.y, upper.y):
			distance = height * 2.0 + width + upper.x - center.x
		else:
			failures.append(
				(
					"%s: portrait-order: seat %d is inside the opponent perimeter"
					% [context, seat.seat_id]
				)
			)
			continue
		if distance <= previous:
			failures.append(
				(
					"%s: portrait-order: seat %d breaks clockwise source order"
					% [context, seat.seat_id]
				)
			)
		previous = distance
