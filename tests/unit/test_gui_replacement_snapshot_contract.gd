extends GutTest

const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const Modes := preload("res://scripts/gui/layout/gui_size_class.gd")


func test_schema2_accepts_native_more_navigation_with_optional_hidden_history() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	assert_false(snapshot.elements.has(&"quit"), "Quit is reached through More")
	var event: GuiLayoutElement = snapshot.elements[&"event"]
	event.visible = false
	event.rect = snapshot.elements[&"center"].rect
	assert_eq(
		Invariants.validate_snapshot(snapshot),
		PackedStringArray(),
		"Hidden history is not an obstacle"
	)


func test_schema1_dispatch_keeps_legacy_required_region_contract() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.schema_version = 1
	assert_true(_contains(Invariants.validate_snapshot(snapshot), "missing region quit"))
	assert_true(_contains(Invariants.validate_snapshot(null), "layout-readiness:"))


func test_replacement_readiness_and_actual_root_surface_bounds_are_required() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.pending = true
	_assert_failure(snapshot, "layout-readiness:")
	snapshot = _fixture()
	snapshot.ready = false
	_assert_failure(snapshot, "layout-readiness:")
	snapshot = _fixture()
	snapshot.surface_rect.position = Vector2(-1, 20)
	_assert_failure(snapshot, "containment:")
	snapshot = _fixture()
	snapshot.elements[&"action/fold"].rect.position = Vector2(-10, 780)
	_assert_failure(snapshot, "containment:")


func test_complete_seat_footprints_must_clear_regions_and_contain_the_status_band() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.seats[1].footprint.position = snapshot.elements[&"center"].rect.position
	_assert_failure(snapshot, "intersection:")
	snapshot = _fixture()
	snapshot.seats[1].footprint.size.y = 100
	_assert_failure(snapshot, "omits panel/status footprint")
	snapshot = _fixture()
	snapshot.elements[&"event"].rect = snapshot.seats[1].footprint
	_assert_failure(snapshot, "intersection:")


func test_explicit_rows_cover_every_id_once_and_cap_each_row_including_hero() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.seats[2] = _seat(2, Vector2(400, 100))
	snapshot.seats[3] = _seat(3, Vector2(700, 100))
	snapshot.seat_rows = [PackedInt32Array([1, 2, 3, 0])]
	_assert_failure(snapshot, "row-cap:")
	snapshot = _fixture()
	snapshot.seat_rows = [PackedInt32Array([1]), PackedInt32Array([1, 0])]
	_assert_failure(snapshot, "duplicate or unknown")
	snapshot = _fixture()
	snapshot.seat_rows = [PackedInt32Array([1])]
	_assert_failure(snapshot, "cover every seat")


func test_phone_portrait_limits_opponents_to_two_and_keeps_hero_in_its_own_row() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.layout_mode = Modes.LayoutMode.PHONE
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	snapshot.seat_rows = [PackedInt32Array([1, 0])]
	_assert_failure(snapshot, "portrait requires")
	snapshot = _fixture()
	snapshot.layout_mode = Modes.LayoutMode.PHONE
	snapshot.seats[2] = _seat(2, Vector2(400, 100))
	snapshot.seats[3] = _seat(3, Vector2(700, 100))
	snapshot.seat_rows = [PackedInt32Array([1, 2, 3]), PackedInt32Array([0])]
	_assert_failure(snapshot, "portrait requires")


func test_actual_horizontal_bands_cannot_be_hidden_by_declared_rows_or_staggering() -> void:
	for mode: int in [Modes.LayoutMode.WIDE, Modes.LayoutMode.PHONE_LANDSCAPE]:
		var snapshot: GuiLayoutSnapshot = _fixture()
		snapshot.layout_mode = mode
		snapshot.root_rect.size.x = 1600
		snapshot.viewport_rect = snapshot.root_rect
		snapshot.usable_rect.size.x = 1580
		snapshot.surface_rect.size.x = 1560
		snapshot.surface_size = snapshot.surface_rect.size
		snapshot.elements[&"event"].visible = false
		snapshot.seats = {
			1: _seat(1, Vector2(100, 100)),
			2: _seat(2, Vector2(400, 101)),
			3: _seat(3, Vector2(700, 102)),
			0: _seat(0, Vector2(1000, 103), true)
		}
		snapshot.seat_rows = [
			PackedInt32Array([1, 2]), PackedInt32Array([3]), PackedInt32Array([0])
		]
		var failures: PackedStringArray = Invariants.validate_snapshot(snapshot)
		assert_true(_contains(failures, "actual horizontal band"))
		for failure: String in failures:
			assert_string_contains(failure, "row-cap:")
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.layout_mode = Modes.LayoutMode.PHONE
	snapshot.elements[&"event"].visible = false
	snapshot.seats[2] = _seat(2, Vector2(400, 101))
	snapshot.seats[3] = _seat(3, Vector2(700, 102))
	snapshot.seat_rows = [PackedInt32Array([1, 2]), PackedInt32Array([3]), PackedInt32Array([0])]
	_assert_failure(snapshot, "actual portrait band")
	snapshot.layout_mode = Modes.LayoutMode.PHONE_LANDSCAPE
	assert_eq(
		Invariants.validate_snapshot(snapshot),
		PackedStringArray(),
		"Three opponents without the hero in that band remain valid"
	)


func test_phone_roster_limit_preserves_all_two_to_seven_counts_and_rejects_eight_nine() -> void:
	for count: int in range(2, 10):
		var snapshot: GuiLayoutSnapshot = _roster_fixture(count)
		assert_eq(
			Invariants.validate_snapshot(snapshot),
			PackedStringArray(),
			"Wide remains valid through nine seats"
		)
		for mode: int in [Modes.LayoutMode.PHONE, Modes.LayoutMode.PHONE_LANDSCAPE]:
			snapshot.layout_mode = mode
			if count <= 7:
				assert_eq(
					Invariants.validate_snapshot(snapshot),
					PackedStringArray(),
					"%d/%d" % [count, mode]
				)
			else:
				_assert_failure(snapshot, "invalid phone roster")


func test_menu_routes_must_point_to_a_real_enabled_more_control_in_action_region() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.menu_routes.erase(&"quit")
	_assert_failure(snapshot, "navigation:")
	snapshot = _fixture()
	snapshot.menu_routes[&"event"] = &"fold"
	_assert_failure(snapshot, "navigation:")
	snapshot = _fixture()
	snapshot.elements[&"action/more"].enabled = false
	_assert_failure(snapshot, "navigation:")
	snapshot = _fixture()
	snapshot.elements[&"action/more"].rect.position = Vector2(50, 780)
	_assert_failure(snapshot, "navigation:")


func test_legal_actions_require_visible_enabled_native_targets_with_full_size() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.elements[&"action/wager"].enabled = false
	snapshot.elements[&"action/pot"].visible = false
	_assert_failure(snapshot, "legal-action:")
	snapshot = _fixture()
	snapshot.elements[&"action/fold"].interactive = false
	_assert_failure(snapshot, "legal-action:")
	snapshot = _fixture()
	snapshot.elements[&"action/wager"].allocated_size.y = 20
	_assert_failure(snapshot, "touch-target:")


func test_full_text_and_role_font_floors_are_checked_in_known_controls_and_seat_fields() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.seats[1].fields[&"name"].required_size.x = 500
	_assert_failure(snapshot, "text-clipping:")
	snapshot = _fixture()
	snapshot.seats[1].fields[&"stack"].font_size = 17
	_assert_failure(snapshot, "font-floor:")
	snapshot = _fixture()
	snapshot.elements[&"event"].font_size = 18
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	snapshot.elements[&"event"].font_size = 17
	_assert_failure(snapshot, "font-floor:")


func test_board_has_five_public_slots_with_exact_dealt_faces_and_safe_aspect() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.board_cards.pop_back()
	_assert_failure(snapshot, "community-cards:")
	snapshot = _fixture()
	snapshot.expected_board_card_count = 5
	_assert_failure(snapshot, "community-cards:")
	snapshot = _fixture()
	snapshot.board_cards[0].element.rect.size.x = 5
	_assert_failure(snapshot, "card-content:")
	snapshot = _fixture()
	snapshot.board_cards[0].suit.rect = snapshot.board_cards[0].rank.rect
	_assert_failure(snapshot, "rank intersects suit")
	snapshot = _fixture()
	snapshot.board_cards[4].kind = GuiCardSnapshot.Kind.UNKNOWN
	_assert_failure(snapshot, "unknown card kind")
	snapshot = _fixture()
	snapshot.board_cards[0].rank.text = ""
	_assert_failure(snapshot, "missing authorized face copy")


func test_hole_card_faces_require_authorization_and_hidden_copy_is_redacted() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	var seat: GuiSeatSnapshot = snapshot.seats[1]
	seat.cards[0] = _card(seat.cards[0].element.rect.position, &"seat/1/cards/0", true)
	seat.cards[0].authorized = false
	_assert_failure(snapshot, "privacy:")
	assert_true(_contains(Invariants.validate_snapshot(snapshot), "not redacted"))
	seat.cards[0].rank.privacy_redacted = true
	seat.cards[0].suit.privacy_redacted = true
	seat.cards[0].rank.text = ""
	seat.cards[0].rank.value_text = ""
	seat.cards[0].suit.text = ""
	seat.cards[0].suit.value_text = ""
	assert_true(_contains(Invariants.validate_snapshot(snapshot), "unauthorized face"))
	assert_false(_contains(Invariants.validate_snapshot(snapshot), "not redacted"))
	snapshot = _fixture()
	snapshot.seats[1].cards[0].rank.text = "A"
	_assert_failure(snapshot, "hidden card retained identity")


func test_malformed_missing_and_hidden_required_values_fail_without_runtime_errors() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.seats[1].fields.erase(&"stack")
	_assert_failure(snapshot, "seat-content:")
	snapshot = _fixture()
	snapshot.seats[1].fields[&"name"].visible = false
	_assert_failure(snapshot, "seat-content:")
	snapshot = _fixture()
	snapshot.seats[1].cards[0] = null
	_assert_failure(snapshot, "card-content:")
	snapshot = _fixture()
	snapshot.seats[1].cards[0].element.visible = false
	_assert_failure(snapshot, "hidden hole-card slot")
	snapshot = _fixture()
	snapshot.seats[1].status = null
	_assert_failure(snapshot, "seat-content:")
	snapshot = _fixture()
	snapshot.measured.append(null)
	_assert_failure(snapshot, "missing observation")


func test_only_declared_modal_overlap_is_accepted_and_overlay_children_stay_inside() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	var overlay := GuiOverlaySnapshot.new()
	overlay.kind = &"summary"
	overlay.element = _element(&"overlay/summary", Rect2(400, 250, 400, 350))
	overlay.measured.append(_element(&"overlay/summary/text", Rect2(410, 260, 380, 30), "Summary"))
	snapshot.overlays.append(overlay)
	_assert_failure(snapshot, "overlay-exception:")
	assert_eq(Invariants.validate_snapshot(snapshot, [&"summary"]), PackedStringArray())
	overlay.measured[0].rect.position.x = 399
	assert_true(_contains(Invariants.validate_snapshot(snapshot, [&"summary"]), "containment:"))
	overlay.measured[0].rect.position.x = 410
	overlay.element.rect.position.x = -10
	assert_true(_contains(Invariants.validate_snapshot(snapshot, [&"summary"]), "containment:"))


func test_modal_cards_use_the_same_authorization_and_content_checks() -> void:
	var snapshot: GuiLayoutSnapshot = _fixture()
	var overlay := GuiOverlaySnapshot.new()
	overlay.kind = &"seat"
	overlay.element = _element(&"overlay/seat", Rect2(400, 250, 400, 350))
	var card: GuiCardSnapshot = _card(Vector2(420, 280), &"overlay/seat/cards/0", true)
	card.authorized = false
	overlay.cards.append(card)
	snapshot.overlays.append(overlay)
	assert_true(_contains(Invariants.validate_snapshot(snapshot, [&"seat"]), "privacy:"))


func test_explicit_fit_guidance_is_valid_without_pretending_the_table_fits() -> void:
	var snapshot: GuiLayoutSnapshot = _guidance_fixture()
	assert_false(snapshot.ready)
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	snapshot.elements[&"guidance"].text = "Different explanation"
	_assert_failure(snapshot, "guidance:")
	snapshot = _guidance_fixture()
	snapshot.elements[&"guidance"].visible = false
	_assert_failure(snapshot, "guidance:")
	snapshot = _guidance_fixture()
	snapshot.seats[1] = _seat(1, Vector2(100, 100))
	_assert_failure(snapshot, "stale visible seat")
	snapshot.seats[1].panel.visible = false
	snapshot.seats[1].status.visible = false
	_assert_failure(snapshot, "stale visible seat field")
	for value: GuiLayoutElement in snapshot.seats[1].fields.values():
		value.visible = false
	for card: GuiCardSnapshot in snapshot.seats[1].cards:
		card.element.visible = false
	snapshot.seats[1].cards[0] = _card(Vector2(240, 140), &"seat/1/cards/0", true)
	var private_card: GuiCardSnapshot = snapshot.seats[1].cards[0]
	private_card.authorized = false
	private_card.element.visible = false
	private_card.rank.visible = false
	private_card.suit.visible = false
	_assert_failure(snapshot, "privacy:")
	snapshot = _guidance_fixture()
	snapshot.elements[&"center"].visible = true
	_assert_failure(snapshot, "stale visible center")


func _fixture() -> GuiLayoutSnapshot:
	var snapshot := GuiLayoutSnapshot.new()
	snapshot.schema_version = 2
	snapshot.layout_mode = Modes.LayoutMode.WIDE
	snapshot.ready = true
	snapshot.root_rect = Rect2(0, 0, 1200, 900)
	snapshot.viewport_rect = snapshot.root_rect
	snapshot.usable_rect = Rect2(10, 10, 1180, 880)
	snapshot.surface_rect = Rect2(20, 20, 1160, 860)
	snapshot.surface_size = snapshot.surface_rect.size
	snapshot.elements = {
		&"center": _element(&"center", Rect2(400, 280, 400, 180)),
		&"board": _element(&"board", Rect2(420, 300, 350, 100)),
		&"pot": _element(&"pot", Rect2(420, 410, 120, 28), "Pot 100"),
		&"wager": _element(&"wager", Rect2(560, 410, 120, 28), "Wager 10"),
		&"action": _element(&"action", Rect2(350, 700, 600, 150)),
		&"action/fold": _element(&"action/fold", Rect2(360, 780, 80, 48), "Fold", true),
		&"action/check_call":
		_element(&"action/check_call", Rect2(445, 780, 110, 48), "Call 10", true),
		&"action/wager": _element(&"action/wager", Rect2(560, 780, 90, 48), "Raise", true),
		&"action/pot": _element(&"action/pot", Rect2(750, 780, 95, 48), "Pot 50", true),
		&"action/more": _element(&"action/more", Rect2(850, 780, 100, 48), "More / Pots", true),
		&"event": _element(&"event", Rect2(990, 100, 180, 550), "Public history", true)
	}
	snapshot.elements[&"event"].text_kind = &"rich_text"
	snapshot.elements[&"event"].font_size = 18
	for value: GuiLayoutElement in snapshot.elements.values():
		snapshot.measured.append(value)
	snapshot.seats = {1: _seat(1, Vector2(100, 100)), 0: _seat(0, Vector2(500, 500), true)}
	snapshot.seat_rows = [PackedInt32Array([1]), PackedInt32Array([0])]
	snapshot.menu_routes = {&"quit": &"more", &"event": &"more"}
	snapshot.actions = {0: [&"fold"], 1: [&"check_call"], 2: [&"wager", &"pot"]}
	snapshot.legal_actions = [0, 1, 2]
	for index: int in 5:
		snapshot.board_cards.append(
			_card(Vector2(420 + index * 53, 300), StringName("board/%d" % index), index < 3)
		)
	snapshot.expected_board_card_count = 3
	return snapshot


func _roster_fixture(count: int) -> GuiLayoutSnapshot:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.root_rect = Rect2(0, 0, 3000, 2000)
	snapshot.viewport_rect = snapshot.root_rect
	snapshot.usable_rect = Rect2(10, 10, 2980, 1980)
	snapshot.surface_rect = Rect2(20, 20, 2960, 1960)
	snapshot.surface_size = snapshot.surface_rect.size
	snapshot.elements[&"event"].visible = false
	for value: GuiLayoutElement in snapshot.elements.values():
		value.rect.position += Vector2(1000, 500)
		value.content_rect.position += Vector2(1000, 500)
	for card: GuiCardSnapshot in snapshot.board_cards:
		for value: GuiLayoutElement in [card.element, card.rank, card.suit]:
			if value.present:
				value.rect.position += Vector2(1000, 500)
				value.content_rect.position += Vector2(1000, 500)
	snapshot.seats.clear()
	snapshot.seat_rows.clear()
	for index: int in range(count - 1):
		var row: int = floori(index / 2.0)
		if index % 2 == 0:
			snapshot.seat_rows.append(PackedInt32Array())
		snapshot.seat_rows[-1].append(index + 1)
		snapshot.seats[index + 1] = _seat(
			index + 1, Vector2(100 + (index % 2) * 300, 100 + row * 180)
		)
	snapshot.seats[0] = _seat(0, Vector2(250, 100 + snapshot.seat_rows.size() * 180), true)
	snapshot.seat_rows.append(PackedInt32Array([0]))
	return snapshot


func _guidance_fixture() -> GuiLayoutSnapshot:
	var snapshot: GuiLayoutSnapshot = _fixture()
	snapshot.ready = false
	snapshot.fit_guidance = "More space needed."
	for value: GuiLayoutElement in snapshot.elements.values():
		value.visible = false
	snapshot.seats.clear()
	snapshot.board_cards.clear()
	snapshot.seat_rows.clear()
	snapshot.legal_actions.clear()
	var guide: GuiLayoutElement = _element(
		&"guidance", Rect2(100, 100, 1000, 200), snapshot.fit_guidance
	)
	snapshot.elements[&"guidance"] = guide
	snapshot.measured.append(guide)
	return snapshot


func _seat(id: int, origin: Vector2, hero: bool = false) -> GuiSeatSnapshot:
	var seat := GuiSeatSnapshot.new()
	seat.seat_id = id
	seat.hero = hero
	seat.visual_slot = 1 if hero else 0
	seat.panel = _element(StringName("seat/%d" % id), Rect2(origin, Vector2(280, 100)))
	seat.status = _element(
		StringName("status/%d" % id), Rect2(origin + Vector2(0, 110), Vector2(280, 50))
	)
	seat.footprint = Rect2(origin, Vector2(280, 160))
	seat.fields = {
		&"name":
		_element(
			StringName("seat/%d/name" % id),
			Rect2(origin + Vector2(10, 10), Vector2(100, 26)),
			"Player"
		),
		&"stack":
		_element(
			StringName("seat/%d/stack" % id),
			Rect2(origin + Vector2(10, 40), Vector2(100, 26)),
			"1000000"
		),
		&"action":
		_element(
			StringName("seat/%d/action" % id),
			Rect2(origin + Vector2(10, 70), Vector2(120, 26)),
			"Bet 10"
		),
		&"cards":
		_element(
			StringName("seat/%d/cards" % id), Rect2(origin + Vector2(140, 40), Vector2(94, 60))
		)
	}
	for role: StringName in [&"name", &"stack", &"action"]:
		seat.fields[role].font_size = 18
	for index: int in 2:
		seat.cards.append(
			_card(
				origin + Vector2(140 + index * 48, 40),
				StringName("seat/%d/cards/%d" % [id, index]),
				false
			)
		)
		seat.cards[index].kind = GuiCardSnapshot.Kind.BACK
	return seat


func _card(origin: Vector2, role: StringName, face: bool) -> GuiCardSnapshot:
	var card := GuiCardSnapshot.new()
	card.kind = GuiCardSnapshot.Kind.FACE if face else GuiCardSnapshot.Kind.EMPTY
	card.authorized = face
	card.element = _element(role, Rect2(origin, Vector2(45, 60)))
	card.rank = GuiLayoutElement.new()
	card.suit = GuiLayoutElement.new()
	if face:
		card.rank = _element(
			StringName(str(role) + "/rank"), Rect2(origin + Vector2(5, 3), Vector2(25, 24)), "A"
		)
		card.suit = _element(
			StringName(str(role) + "/suit"), Rect2(origin + Vector2(5, 31), Vector2(20, 20)), "♠"
		)
		card.rank.required_size = Vector2(20, 22)
		card.suit.required_size = Vector2(18, 18)
	return card


func _element(
	role: StringName, rect: Rect2, copy: String = "", interactive: bool = false
) -> GuiLayoutElement:
	var value := GuiLayoutElement.new()
	value.role = role
	value.present = true
	value.visible = true
	value.enabled = true
	value.rect = rect
	value.content_rect = rect
	value.allocated_size = rect.size
	value.local_content_size = rect.size
	value.interactive = interactive
	value.text = copy
	value.value_text = copy
	if not copy.is_empty():
		value.font_size = 20
		value.text_kind = &"button" if interactive else &"label"
		value.line_count = 1
		value.required_size = Vector2(minf(80, rect.size.x), minf(24, rect.size.y))
	return value


func _assert_failure(snapshot: GuiLayoutSnapshot, fragment: String) -> void:
	var failures: PackedStringArray = Invariants.validate_snapshot(snapshot)
	assert_true(_contains(failures, fragment), "%s not found in %s" % [fragment, failures])


func _contains(failures: PackedStringArray, fragment: String) -> bool:
	for failure: String in failures:
		if fragment in failure:
			return true
	return false
