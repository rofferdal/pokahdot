class_name GuiLayoutSceneSweep
extends RefCounted

## Bounded rendered characterization; failures are observations, not exemptions.
const Harness := preload("res://tests/support/gui_scene_harness.gd")
const ReferenceDriver := preload("res://tests/support/gui_reference_fixture_driver.gd")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")
const Assertions := preload("res://tests/support/gui_invariant_assertions.gd")
const PhoneContract := preload("res://tests/support/gui_phone_matrix_contract.gd")
const Profiles := preload("res://scripts/gui/gui_layout_profile.gd")


static func run(host: Node) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var cases: Array[Dictionary] = []
	for definition: Dictionary in definitions():
		cases.append(await run_case(host, definition))
	for count: int in [2, 6, 7, 9]:
		cases.append_array(await _resize_stream(host, count))
	return {"cases": cases, "elapsed_ms": Time.get_ticks_msec() - started}


static func definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for count: int in range(2, 10):
		for size: Vector2i in [Vector2i(650, 900), Vector2i(1250, 700)]:
			for state: StringName in [&"human-turn-preflop", &"showdown-long"]:
				result.append(_definition(size, count, state))
	for size: Vector2i in [Vector2i(390, 844), Vector2i(768, 1024), Vector2i(1920, 1080)]:
		for count: int in [2, 6, 9]:
			for state: StringName in [&"human-turn-preflop", &"showdown-long"]:
				result.append(_definition(size, count, state))
	for state: StringName in [&"human-turn-preflop", &"showdown-long"]:
		result.append(_definition(Vector2i(1920, 1080), 8, state))
	for size: Vector2i in [Vector2i(390, 844), Vector2i(1250, 700), Vector2i(1920, 1080)]:
		for state: StringName in [&"startup", &"keypad-open", &"quit-confirmation"]:
			result.append(_definition(size, 6, state))
	for state: StringName in [&"showdown-overlay", &"menu", &"seat-detail"]:
		result.append(_definition(Vector2i(390, 844), 7, state))
	for size: Vector2i in [
		Vector2i(390, 844), Vector2i(650, 900), Vector2i(1250, 700), Vector2i(1920, 1080)
	]:
		for state: StringName in [&"human-turn-preflop", &"showdown-long"]:
			result.append(_definition(size, 7, state, &"large"))
	for count: int in [2, 7]:
		result.append(_definition(Vector2i(320, 320), count, &"human-turn-preflop"))
	return result


static func run_case(host: Node, definition: Dictionary) -> Dictionary:
	var descriptor: Dictionary = _descriptor(
		definition.state, definition.player_count, definition.variant
	)
	var signature: String = _view_signature(descriptor.view)
	var harness: Node = Harness.new()
	harness.set_fixture_driver(SweepFixtureDriver.new())
	host.add_child(harness)
	var rendered: Dictionary = harness.render(descriptor, definition.size)
	var settled: bool = await harness.settle_layout()
	var snapshot: GuiLayoutSnapshot = rendered.root.get_layout_snapshot()
	var raw: PackedStringArray = _observe(rendered, snapshot, settled, signature)
	var record: Dictionary = _record(definition, &"scene", snapshot, raw, rendered.root)
	harness.free()
	return record


static func _resize_stream(host: Node, count: int) -> Array[Dictionary]:
	var sizes: Array[Vector2i] = [
		Vector2i(390, 844),
		Vector2i(650, 900),
		Vector2i(768, 1024),
		Vector2i(1099, 600),
		Vector2i(1101, 600),
		Vector2i(1250, 700),
		Vector2i(1920, 1080),
		Vector2i(844, 390),
		Vector2i(390, 844),
	]
	var descriptor: Dictionary = _descriptor(&"human-turn-preflop", count, &"ordinary")
	var signature: String = _view_signature(descriptor.view)
	var harness: Node = Harness.new()
	harness.set_fixture_driver(SweepFixtureDriver.new())
	host.add_child(harness)
	var rendered: Dictionary = harness.render(descriptor, sizes[0])
	var root_id: int = rendered.root.get_instance_id()
	var result: Array[Dictionary] = []
	for index: int in range(sizes.size()):
		if index > 0:
			harness.resize_viewport(sizes[index])
		var settled: bool = await harness.settle_layout()
		var snapshot: GuiLayoutSnapshot = rendered.root.get_layout_snapshot()
		var raw: PackedStringArray = _observe(rendered, snapshot, settled, signature)
		if rendered.root.get_instance_id() != root_id:
			raw.append("resize-identity: root was reconstructed")
		var definition: Dictionary = _definition(sizes[index], count, &"human-turn-preflop")
		definition.stage = index
		result.append(_record(definition, &"resize", snapshot, raw, rendered.root))
	harness.free()
	return result


static func _observe(
	rendered: Dictionary, snapshot: GuiLayoutSnapshot, settled: bool, signature: String
) -> PackedStringArray:
	var raw: PackedStringArray = Assertions.validate_snapshot(
		snapshot, rendered.intentional_overlap_roles
	)
	if not settled:
		raw.append("layout-readiness: bounded settling timed out")
	var view: GameView = rendered.descriptor.view
	if _view_signature(view) != signature:
		raw.append("view-mutation: presentation changed recipient-safe GameView")
	if view == null:
		return raw
	var expected: Array[int] = []
	var actual: Array[int] = snapshot.seats.keys()
	for player: PlayerView in view.seats:
		expected.append(player.seat)
		if snapshot.seats.has(player.seat):
			var seat: GuiSeatSnapshot = snapshot.seats[player.seat]
			if seat.seat_id != player.seat or seat.hero != (player.seat == view.hero_seat):
				raw.append("seat-identity: seat/%d changed core identity" % player.seat)
	expected.sort()
	actual.sort()
	if expected != actual:
		raw.append("seat-identity: recipient seat set changed")
	if Profiles.is_phone(snapshot.profile):
		PhoneContract.validate(rendered, "phone", raw)
	return raw


static func _record(
	definition: Dictionary,
	probe: StringName,
	snapshot: GuiLayoutSnapshot,
	raw: PackedStringArray,
	root: Control,
) -> Dictionary:
	var failures := PackedStringArray()
	for failure: String in raw:
		var normalized: String = normalize_failure(failure)
		if normalized not in failures:
			failures.append(normalized)
	failures.sort()
	var size: Vector2i = definition.size
	var input: Dictionary = {
		"width": size.x,
		"height": size.y,
		"player_count": definition.player_count,
		"state": String(definition.state),
		"variant": String(definition.variant),
		"override": -1,
	}
	var id := (
		"%s/%dx%d/p%d/%s/%s"
		% [probe, size.x, size.y, definition.player_count, definition.state, definition.variant]
	)
	if definition.has("stage"):
		input.stage = definition.stage
		id += "/stage-%d" % definition.stage
	var minimum: Vector2 = root.get_combined_minimum_size()
	return {
		"id": id,
		"probe": String(probe),
		"scope": _scope(size, definition.player_count),
		"input": input,
		"failures": failures,
		"observations":
		{
			"profile": snapshot.profile,
			"root_minimum": [minimum.x, minimum.y],
			"orientation": "portrait" if size.y >= size.x else "landscape",
			"phone_count_supported": definition.player_count <= 7,
		},
		"details":
		{
			"raw_failures": raw,
			"profile": snapshot.profile,
			"root_minimum": [minimum.x, minimum.y],
			"generation": snapshot.generation
		},
	}


## Remove measured numeric geometry without discarding semantic role/seat IDs.
static func normalize_failure(failure: String) -> String:
	var result: String = failure.trim_prefix("phone: ")
	for marker: String in [" [P:", " needs ", " has size ", " uses "]:
		var index: int = result.find(marker)
		if index >= 0:
			result = result.left(index)
	var wrapped_limit: int = result.find(" hides wrapped lines (")
	if wrapped_limit >= 0:
		result = result.left(wrapped_limit) + " hides wrapped lines"
	return result


static func _scope(size: Vector2i, count: int) -> String:
	var profile: int = Profiles.classify(Vector2(size))
	if Profiles.is_phone(profile) and count > 7:
		return "unsupported_phone_count"
	if profile == Profiles.Kind.PHONE_LANDSCAPE:
		return "deferred_phone_landscape"
	if profile == Profiles.Kind.PHONE_PORTRAIT:
		return "candidate_phone_portrait" if count <= 7 else "unsupported_phone_count"
	if size.x <= 320 or size.y <= 320:
		return "insufficient_space"
	return "candidate_wide"


static func _definition(
	size: Vector2i, count: int, state: StringName, variant: StringName = &"ordinary"
) -> Dictionary:
	return {"size": size, "player_count": count, "state": state, "variant": variant}


static func _descriptor(state: StringName, count: int, variant: StringName) -> Dictionary:
	if state in [&"startup", &"keypad-open"]:
		return States.by_id(state, 6)
	var view: GameView = (
		States._showdown_view(count)
		if state in [&"showdown-long", &"showdown-overlay"]
		else States._human_turn_view(count, &"preflop")
	)
	if variant == &"large":
		# Synthetic safe presentation values, not a simulated betting history.
		view.pot_amount = count * 500_000
		view.maximum_wager_total = count * 500_000 - (count - 1) * 1000 + 10
		for player: PlayerView in view._seats:
			player.stack = (
				count * 500_000 - (count - 1) * 1000 if player.seat == view.hero_seat else 1000
			)
		view._action_history.append(
			PublicActionRecord.new(count - 1, PlayerAction.Kind.RAISE, 1_234_567)
		)
	var kind: StringName = (
		States.KIND_TABLE_MODAL if state == &"quit-confirmation" else States.KIND_TABLE
	)
	var result: Dictionary = States._table_descriptor(state, view, {}, [], kind)
	result.ui.sweep_variant = variant
	if state in [&"menu", &"seat-detail"]:
		result.ui.sweep_overlay = state
	return result


## Fingerprint every safe-view field, including card identities, wagers and
## public action content, rather than checking only collection counts.
static func _view_signature(view: GameView) -> String:
	return JSON.stringify(_safe_value(view))


static func _safe_value(value: Variant) -> Variant:
	if value is RefCounted:
		var fields: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				fields[property.name] = _safe_value(value.get(property.name))
		return fields
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_safe_value(item))
		return items
	if value is Dictionary:
		var fields: Dictionary = {}
		for key: Variant in value:
			fields[str(key)] = _safe_value(value[key])
		return fields
	return value


class SweepFixtureDriver:
	extends ReferenceDriver

	func _name_assignments(count: int) -> Dictionary[int, String]:
		var result: Dictionary[int, String] = {}
		var names: Array[String] = [
			"Human",
			"Aleksiej",
			"Priyanka",
			"Santiago",
			"Leilani",
			"Youssef",
			"Saoirse",
			"Natsuki",
			"Kwame"
		]
		for seat: int in range(count):
			result[seat] = names[seat]
		return result

	func render(
		viewport: SubViewport, descriptor: Dictionary, size: Vector2i, profile: int
	) -> Dictionary:
		var rendered: Dictionary = super.render(viewport, descriptor, size, profile)
		# This fixture's long live public action needs a third token row; the
		# completed-hand fixture clears action badges and fits its revealed cards
		# in the regular two-row token. The oracle never reads observed height.
		var expected_height: float = (
			86.0
			if (
				descriptor.ui.get("sweep_variant", &"ordinary") == &"large"
				and descriptor.id == &"human-turn-preflop"
			)
			else 60.0
		)
		rendered.reference_geometry_check = validate_fixture_geometry.bind(expected_height)
		match descriptor.ui.get("sweep_overlay", &""):
			&"menu":
				rendered.table.call("_open_phone_overflow_menu")
				rendered.intentional_overlap_roles = [&"menu"] as Array[StringName]
			&"seat-detail":
				rendered.table.call("_open_phone_seat_detail", 1)
				rendered.intentional_overlap_roles = [&"seat_detail"] as Array[StringName]
		return rendered

	static func validate_fixture_geometry(
		snapshot: GuiLayoutSnapshot,
		context: String,
		failures: PackedStringArray,
		expected_portrait_height: float,
	) -> void:
		if snapshot.surface_size.y > snapshot.surface_size.x:
			ReferenceDriver.validate_phone_geometry(snapshot, context, failures)
			return
		var expected_rects: Dictionary[int, Rect2] = GuiPhoneSeatLayout.seat_rects(
			snapshot.surface_size, snapshot.seats.size(), expected_portrait_height
		)
		for seat: GuiSeatSnapshot in snapshot.seats.values():
			if seat.hero:
				continue
			var expected: Rect2 = snapshot.surface_transform * expected_rects[seat.visual_slot]
			if not seat.panel.rect.is_equal_approx(expected):
				failures.append(
					(
						"%s: density-tier rectangle mismatch for seat %d: %s != %s"
						% [context, seat.seat_id, seat.panel.rect, expected]
					)
				)
