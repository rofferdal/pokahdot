extends "res://tests/support/poker_gut_test.gd"

const Harness := preload("res://tests/support/gui_scene_harness.gd")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")
const CardFactory := preload("res://scripts/gui/card_face_factory.gd")
const TableScene := preload("res://scenes/poker_table.tscn")
const MainScene := preload("res://scenes/main.tscn")
const WIDE := Vector2i(1920, 1080)
const PHONE := Vector2i(390, 844)
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")


func test_unmounted_and_unbound_scenes_report_nonready_values() -> void:
	var table := TableScene.instantiate() as PokerTableController
	assert_false(table.get_layout_snapshot().ready)
	add_child(table)
	await get_tree().process_frame
	assert_false(table.get_layout_snapshot().ready)
	table.free()
	var main := MainScene.instantiate() as StartupConfigController
	assert_false(main.get_layout_snapshot().ready)
	main.free()


func test_wide_snapshot_covers_regions_seats_and_every_action() -> void:
	var rendered: Dictionary = await _render(&"human-turn-river")
	var snapshot: GuiLayoutSnapshot = rendered.table.get_layout_snapshot()
	assert_true(snapshot.ready)
	assert_false(snapshot.pending)
	assert_eq(snapshot.schema_version, 1)
	assert_eq(snapshot.seats.size(), 6)
	assert_eq(snapshot.board_cards.size(), 5)
	for role: StringName in [
		&"center",
		&"board",
		&"pot",
		&"wager",
		&"action",
		&"event",
		&"quit",
		&"action/fold",
		&"action/check_call",
		&"action/min_wager",
		&"action/pot",
		&"action/wager_input",
		&"action/wager",
		&"action/all_in",
	]:
		assert_true(snapshot.elements.has(role), String(role))
	for seat_id: int in snapshot.seats:
		var seat: GuiSeatSnapshot = snapshot.seats[seat_id]
		assert_eq(seat.seat_id, seat_id)
		assert_true(seat.footprint.encloses(seat.panel.rect))
		if seat.status.visible:
			assert_true(seat.footprint.encloses(seat.status.rect))
		assert_true(seat.fields.has(&"name"))
		assert_true(seat.fields.has(&"stack"))
	assert_true(snapshot.elements[&"action/min_wager"].interactive)


func test_phone_snapshot_reports_hero_action_fields_and_actual_opponent_cards() -> void:
	var rendered: Dictionary = await _render(&"human-turn-preflop", PHONE)
	var snapshot: GuiLayoutSnapshot = rendered.table.get_layout_snapshot()
	assert_eq(snapshot.profile, GuiLayoutProfile.Kind.PHONE_PORTRAIT)
	for role: StringName in [&"more", &"hero_cards", &"hero_stack", &"hero_action"]:
		assert_true(snapshot.elements.has(role), String(role))
	assert_true(snapshot.elements[&"more"].visible)
	var seat: GuiSeatSnapshot = snapshot.seats[1]
	assert_eq(seat.cards.size(), 2)
	assert_false(seat.face_authorized)
	for card: GuiCardSnapshot in seat.cards:
		assert_eq(card.kind, GuiCardSnapshot.Kind.BACK)
		assert_true(card.element.visible)
	assert_true(seat.fields[&"details"].interactive)
	assert_string_contains(seat.fields[&"details"].tooltip, seat.fields[&"name"].text)


func test_startup_snapshot_has_input_validation_and_navigation_roles() -> void:
	var rendered: Dictionary = await _render(&"startup")
	var snapshot: GuiLayoutSnapshot = rendered.root.get_layout_snapshot()
	assert_true(snapshot.ready)
	assert_not_null(snapshot.startup)
	assert_true(snapshot.startup.visible)
	for role: StringName in [
		&"player_count",
		&"starting_stack",
		&"small_blind",
		&"big_blind",
		&"start",
		&"quit",
	]:
		assert_true(snapshot.startup.fields.has(role), String(role))
	assert_eq(snapshot.startup.fields[&"player_count"].text, "6")
	assert_true(snapshot.startup.fields[&"start"].interactive)


func test_startup_keypad_and_native_quit_have_common_coordinate_space() -> void:
	for state: StringName in [&"keypad-open", &"quit-confirmation"]:
		var rendered: Dictionary = await _render(state)
		var snapshot: GuiLayoutSnapshot = rendered.root.get_layout_snapshot()
		var kind: StringName = &"keypad" if state == &"keypad-open" else &"quit"
		var overlay: GuiOverlaySnapshot = _overlay(snapshot, kind)
		assert_not_null(overlay, String(state))
		if overlay == null:
			continue
		assert_true(overlay.element.visible)
		assert_false(overlay.native_window)
		assert_true(snapshot.viewport_rect.encloses(overlay.element.rect))
		assert_gt(overlay.measured.size(), 0)
		var popup := rendered.overlay as Window
		popup.position = Vector2i(37, 53)
		var moved: GuiOverlaySnapshot = _overlay(rendered.root.get_layout_snapshot(), kind)
		assert_eq(moved.element.rect.position, Vector2(37, 53))
		for element: GuiLayoutElement in moved.measured:
			if element.visible:
				assert_gte(element.rect.position.x, 37.0)
				assert_gte(element.rect.position.y, 53.0)


func test_phone_summary_quit_menu_and_detail_are_semantic_overlays() -> void:
	for state: StringName in [&"showdown-overlay", &"quit-confirmation"]:
		var rendered: Dictionary = await _render(state, PHONE)
		var kind: StringName = &"summary" if state == &"showdown-overlay" else &"quit"
		var overlay: GuiOverlaySnapshot = _overlay(rendered.table.get_layout_snapshot(), kind)
		assert_not_null(overlay)
		if overlay != null:
			assert_true(overlay.element.visible)
			assert_false(overlay.native_window)
	var ordinary: Dictionary = await _render(&"human-turn-preflop", PHONE)
	ordinary.table.call("_open_phone_overflow_menu")
	assert_not_null(_overlay(ordinary.table.get_layout_snapshot(), &"menu"))
	ordinary.table.call("_open_phone_seat_detail", 1)
	var detail: GuiOverlaySnapshot = _overlay(ordinary.table.get_layout_snapshot(), &"seat_detail")
	assert_not_null(detail)
	if detail != null:
		assert_eq(detail.selected_seat, 1)
		assert_eq(detail.cards.size(), 2)


func test_rectangles_and_effective_typography_include_root_transform() -> void:
	var rendered: Dictionary = await _render(&"human-turn-preflop")
	var table: PokerTableController = rendered.table
	var original: GuiLayoutSnapshot = table.get_layout_snapshot()
	var original_text: GuiLayoutElement = original.seats[1].fields[&"name"]
	table.position = Vector2(31, 47)
	table.scale = Vector2(0.75, 0.75)
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	var quit := table.get_node("%QuitButton") as Control
	var expected: Rect2 = quit.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, quit.size)
	assert_true(snapshot.elements[&"quit"].rect.is_equal_approx(expected))
	assert_almost_eq(
		snapshot.seats[1].fields[&"name"].required_size.x, original_text.required_size.x, 0.01
	)
	assert_almost_eq(snapshot.seats[1].fields[&"name"].logical_scale.x, 0.75, 0.01)
	assert_eq(snapshot.usable_rect, snapshot.root_rect)
	assert_true(snapshot.usable_rect.encloses(snapshot.surface_rect))
	assert_ne(snapshot.usable_rect.position, Vector2.ZERO)
	var label := Label.new()
	label.text = "Scaled text observation"
	label.add_theme_font_size_override("font_size", 24)
	table.add_child(label)
	var measured: GuiLayoutElement = _text(table.get_layout_snapshot(), label.text)
	assert_not_null(measured)
	if measured != null:
		assert_eq(measured.font_size, 24)
		assert_almost_eq(measured.effective_font_size, 18.0, 0.01)


func test_card_visibility_and_missing_fields_are_observed_from_actual_children() -> void:
	var rendered: Dictionary = await _render(&"human-turn-river", PHONE)
	var table: PokerTableController = rendered.table
	var board := table.get_node("%CardSlots").get_child(0) as Control
	board.hide()
	var cards: Control = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1").find_child(
		"HoleCards", true, false
	)
	cards.get_child(0).free()
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_false(snapshot.board_cards[0].element.visible)
	assert_eq(snapshot.seats[1].cards.size(), 1)


func test_public_card_content_geometry_and_legal_action_failures_remain_observable() -> void:
	var rendered: Dictionary = await _render(&"human-turn-river")
	var table: PokerTableController = rendered.table
	var card := table.get_node("%CardSlots").get_child(0) as Control
	var rank := card.get_node("Content/Rank") as Label
	var suit := card.get_node("Content/Suit") as TextureRect
	suit.set_anchors_preset(Control.PRESET_TOP_LEFT)
	suit.custom_minimum_size = Vector2.ZERO
	suit.position = rank.position
	suit.size = Vector2.ONE
	card.modulate.a = 0.2
	(table.get_node("%FoldButton") as Button).disabled = true
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_eq(snapshot.expected_board_card_count, 5)
	assert_true(PlayerAction.Kind.FOLD in snapshot.legal_actions)
	assert_false(snapshot.elements[&"action/fold"].enabled)
	var observed: GuiCardSnapshot = snapshot.board_cards[0]
	assert_eq(observed.kind, GuiCardSnapshot.Kind.FACE)
	assert_true(observed.authorized)
	assert_true(observed.suit.texture_present)
	assert_true(observed.rank.rect.intersects(observed.suit.rect))
	assert_eq(observed.suit.rect.size, Vector2.ONE)
	assert_lt(observed.element.opacity, 0.99)


func test_unauthorized_extra_face_is_detected_and_rank_text_is_redacted() -> void:
	var rendered: Dictionary = await _render(&"human-turn-preflop", PHONE)
	var table: PokerTableController = rendered.table
	var cards: Control = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1").find_child(
		"HoleCards", true, false
	)
	var face: Control = CardFactory.create_card_face(
		CardData.new(14, CardData.Suit.SPADES),
		"ShowdownCard1",
		Vector2(48, 48),
		20,
		Color.WHITE,
		Color.BLACK
	)
	(face.get_node("Content/Rank") as Label).text = "UNREVEALED_RANK_SECRET"
	face.tooltip_text = "UNREVEALED_RANK_SECRET"
	(face.get_node("Content/Rank") as Label).tooltip_text = "UNREVEALED_RANK_SECRET"
	cards.add_child(face)
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_eq(snapshot.seats[1].cards.size(), 3, "Injected sibling must not be ignored")
	var exposed_count: int = 0
	for card: GuiCardSnapshot in snapshot.seats[1].cards:
		if card.kind == GuiCardSnapshot.Kind.FACE:
			exposed_count += 1
			assert_false(card.authorized)
			assert_true(card.element.visible)
			assert_true(card.rank.privacy_redacted)
			assert_eq(card.rank.text, "")
	assert_eq(exposed_count, 1)
	for element: GuiLayoutElement in snapshot.measured:
		assert_false("UNREVEALED_RANK_SECRET" in element.text)
		assert_false("UNREVEALED_RANK_SECRET" in element.tooltip)
	_assert_detached(snapshot)


func test_clipped_text_line_limits_targets_and_unregistered_geometry_remain_observable() -> void:
	var rendered: Dictionary = await _render(&"human-turn-preflop")
	var table: PokerTableController = rendered.table
	var label := Label.new()
	label.text = "Required content wraps into several lines and must remain fully measurable."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 1
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 19)
	table.add_child(label)
	label.size = Vector2(100, 24)
	label.position = Vector2(-100, -100)
	var button := Button.new()
	button.text = "X"
	button.add_theme_font_size_override("font_size", 20)
	table.add_child(button)
	button.size = Vector2(47, 48)
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	var measured: GuiLayoutElement = _text(snapshot, label.text)
	assert_not_null(measured)
	if measured != null:
		assert_eq(measured.font_size, 19)
		assert_gt(measured.line_count, measured.max_lines)
		assert_gt(measured.required_size.y, measured.content_rect.size.y)
		assert_false(snapshot.viewport_rect.encloses(measured.rect))
	var target: GuiLayoutElement = _text(snapshot, "X")
	assert_not_null(target)
	if target != null:
		assert_true(target.interactive)
		assert_lt(target.rect.size.x, 48.0)


func test_unknown_surface_defects_keep_roles_when_felt_decoration_is_inserted() -> void:
	var rendered: Dictionary = await _render(&"human-turn-preflop")
	var table: PokerTableController = rendered.table
	var surface := table.get_node("TableMargin/Felt/TableSurface") as Control
	var probe := Control.new()
	surface.add_child(probe)
	probe.position = Vector2(-200, -200)
	probe.size = Vector2(30, 24)
	var label := Label.new()
	label.text = "Unknown surface defect remains measured"
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 19)
	probe.add_child(label)
	label.size = Vector2(30, 24)
	await get_tree().process_frame
	var before: GuiLayoutSnapshot = table.get_layout_snapshot()
	var original: GuiLayoutElement = _text(before, label.text)
	assert_not_null(original)
	if original == null:
		return
	assert_true(String(original.role).begins_with("surface/child/"))
	var decoration := Control.new()
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.get_parent().add_child(decoration)
	surface.get_parent().move_child(decoration, 0)
	await get_tree().process_frame
	var after: GuiLayoutSnapshot = table.get_layout_snapshot()
	var observed: GuiLayoutElement = _text(after, label.text)
	assert_not_null(observed)
	if observed == null:
		return
	assert_eq(observed.role, original.role)
	assert_eq(observed.parent_role, original.parent_role)
	for snapshot: GuiLayoutSnapshot in [before, after]:
		var failures: PackedStringArray = Invariants.validate_snapshot(snapshot)
		assert_true(
			"containment: %s " % original.parent_role in "\n".join(failures),
			"Unregistered control geometry must still be rejected"
		)
		assert_true(
			"font-floor: %s" % original.role in "\n".join(failures),
			"Unregistered text must still be rejected"
		)


func test_snapshot_values_survive_rerender_and_scene_free() -> void:
	var rendered: Dictionary = await _render(&"human-turn-preflop")
	var table: PokerTableController = rendered.table
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	var original: String = snapshot.seats[1].fields[&"name"].text
	var panel := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1") as Control
	(panel.find_child("Name", true, false) as Label).text = "Changed after observation"
	assert_eq(snapshot.seats[1].fields[&"name"].text, original)
	table.bind_view(States.by_id(&"showdown-long", 6).view, {})
	table.free()
	assert_eq(snapshot.seats[1].fields[&"name"].text, original)
	assert_gt(snapshot.measured.size(), 0)
	_assert_detached(snapshot)


func _render(state: StringName, size: Vector2i = WIDE) -> Dictionary:
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	var rendered: Dictionary = harness.render(States.by_id(state, 6), size)
	assert_true(await harness.settle_layout(), "%s layout must settle" % state)
	return rendered


func _overlay(snapshot: GuiLayoutSnapshot, kind: StringName) -> GuiOverlaySnapshot:
	for overlay: GuiOverlaySnapshot in snapshot.overlays:
		if overlay.kind == kind and overlay.element.visible:
			return overlay
	return null


func _text(snapshot: GuiLayoutSnapshot, text: String) -> GuiLayoutElement:
	for element: GuiLayoutElement in snapshot.measured:
		if element.text == text:
			return element
	return null


func _assert_detached(value: Variant) -> void:
	if value is Node or value is Resource:
		assert_true(false, "Snapshots must not retain scene nodes or resources")
	elif value is Array:
		for child: Variant in value:
			_assert_detached(child)
	elif value is Dictionary:
		for key: Variant in value:
			_assert_detached(key)
			_assert_detached(value[key])
	elif value is RefCounted:
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_assert_detached(value.get(property.name))
