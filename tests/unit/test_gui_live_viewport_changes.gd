extends "res://tests/support/poker_gut_test.gd"

const GuiSceneHarnessScript := preload("res://tests/support/gui_scene_harness.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")


func test_phone_rotation_replaces_geometry_with_the_current_orientation() -> void:
	var fixture: Dictionary = await _render(&"human-turn-preflop", Vector2i(360, 640), 4)
	var harness = fixture.harness
	var table: PokerTableController = fixture.rendered.table
	var portrait_generation: int = table.get_layout_generation()
	_assert_current_region_owners(table, 4)

	harness.resize_viewport(Vector2i(640, 360))
	assert_true(await harness.settle_layout())
	assert_gt(table.get_layout_generation(), portrait_generation)
	assert_false(table.is_layout_pending())
	assert_eq(table.size, Vector2(640, 360))
	_assert_current_region_owners(table, 4)

	var landscape_generation: int = table.get_layout_generation()
	harness.resize_viewport(Vector2i(360, 640))
	assert_true(await harness.settle_layout())
	assert_gt(table.get_layout_generation(), landscape_generation)
	assert_eq(table.size, Vector2(360, 640))
	_assert_current_region_owners(table, 4)


func test_reduced_browser_heights_settle_to_the_latest_surface() -> void:
	var fixture: Dictionary = await _render(&"wager-entry", Vector2i(390, 844), 6)
	var harness = fixture.harness
	var table: PokerTableController = fixture.rendered.table
	for viewport_size: Vector2i in [
		Vector2i(390, 744),
		Vector2i(844, 390),
		Vector2i(844, 330),
	]:
		var previous_generation: int = table.get_layout_generation()
		harness.resize_viewport(viewport_size)
		assert_true(await harness.settle_layout(), str(viewport_size))
		assert_gt(table.get_layout_generation(), previous_generation, str(viewport_size))
		assert_false(table.is_layout_pending(), str(viewport_size))
		assert_eq(table.size, Vector2(viewport_size), str(viewport_size))
		_assert_current_region_owners(table, 6)


func test_burst_resizes_coalesce_and_reject_stale_deferred_center_bounds() -> void:
	var fixture: Dictionary = await _render(&"wager-entry", Vector2i(1920, 1080), 6)
	var harness = fixture.harness
	var table: PokerTableController = fixture.rendered.table
	var stale_generation: int = table.get_layout_generation()

	for viewport_size: Vector2i in [
		Vector2i(1280, 720),
		Vector2i(950, 532),
		Vector2i(1024, 768),
		Vector2i(844, 390),
	]:
		harness.resize_viewport(viewport_size)
	table._queue_layout()
	table._queue_layout()
	assert_true(table.is_layout_pending())
	assert_gt(table.get_layout_generation(), stale_generation)
	assert_true(await harness.settle_layout())
	assert_eq(table.size, Vector2(844, 390))
	assert_false(table.is_layout_pending())
	_assert_current_region_owners(table, 6)

	var current_center: Rect2 = table.get_resolved_region_rects()[&"center"]
	table._apply_center_zone_bounds_if_current(Vector2.ONE, Vector2(-10.0, -10.0), stale_generation)
	assert_eq(table.get_resolved_region_rects()[&"center"], current_center)

	var current_generation: int = table.get_layout_generation()
	for _request: int in range(8):
		table._queue_layout()
	assert_eq(table.get_layout_generation(), current_generation + 8)
	assert_true(await harness.settle_layout())
	assert_false(table.is_layout_pending())
	assert_eq(table.get_resolved_region_rects()[&"center"], current_center)


func test_phone_burst_resizes_preserve_safe_open_ui_and_reject_stale_plan() -> void:
	var fixture: Dictionary = await _render(&"showdown-long", Vector2i(390, 844), 6)
	var harness = fixture.harness
	var table: PokerTableController = fixture.rendered.table
	var original_view: GameView = table._bound_view
	var stale_plan: RefCounted = table._applied_phone_layout_plan
	var stale_generation: int = table.get_layout_generation()

	table.get_node("%PhoneMoreButton").emit_signal("pressed")
	await _burst_phone_resize(harness, table)
	assert_true((table.get_node("%PhoneOverflowMenu") as Control).visible)
	_assert_phone_plan_applied(table, 6)

	table.get_node("%PhoneMenuShowdownButton").emit_signal("pressed")
	await _burst_phone_resize(harness, table)
	assert_true((table.get_node("%PhoneShowdownOverlay") as Control).visible)
	_assert_phone_plan_applied(table, 6)

	table.get_node("%PhoneShowdownCloseButton").emit_signal("pressed")
	var opponent := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1") as Control
	(opponent.find_child("DetailsButton", true, false) as Button).emit_signal("pressed")
	await _burst_phone_resize(harness, table)
	var detail := table.get_node("TableMargin/Felt/TableSurface/SeatDetailOverlay") as Control
	assert_true(detail.visible)
	_assert_phone_plan_applied(table, 6)

	var current_regions: Dictionary[StringName, Rect2] = table.get_resolved_region_rects()
	table._apply_phone_layout_if_current(stale_plan, stale_generation)
	assert_eq(table.get_resolved_region_rects(), current_regions)
	assert_same(table._bound_view, original_view)


func test_phone_wager_draft_survives_rotation_and_is_cancelled_on_desktop_exit() -> void:
	var fixture: Dictionary = await _render(&"wager-entry", Vector2i(390, 844), 6)
	var harness = fixture.harness
	var table: PokerTableController = fixture.rendered.table
	var keypad := table.get_node("WagerKeypad") as WagerKeypad
	var original_input: String = (table.get_node("%WagerInput") as LineEdit).text

	table.show_wager_keypad()
	keypad.get_node("Content/Keys/Key2").emit_signal("pressed")
	var draft_value: String = keypad.get_node("Content/Value").text
	await _burst_phone_resize(harness, table)
	assert_true(keypad.visible)
	assert_true(keypad.is_bottom_sheet())
	assert_eq(keypad.get_node("Content/Value").text, draft_value)
	assert_eq((table.get_node("%WagerInput") as LineEdit).text, original_input)
	_assert_bottom_sheet(fixture.rendered.viewport, keypad)

	harness.resize_viewport(Vector2i(1280, 720))
	assert_true(await harness.settle_layout())
	assert_false(keypad.visible)
	assert_eq((table.get_node("%WagerInput") as LineEdit).text, original_input)
	assert_not_null(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1") as Control).find_child(
			"Avatar", true, false
		)
	)


func test_compact_seat_styling_is_restored_after_returning_to_desktop() -> void:
	var fixture: Dictionary = await _render(&"human-turn-preflop", Vector2i(1920, 1080), 6)
	var harness = fixture.harness
	var table: PokerTableController = fixture.rendered.table
	var desktop_seat_rects: Dictionary[int, Rect2] = table.get_seat_rects().duplicate()
	var desktop_marker_text: Dictionary[int, String] = {}
	for seat: int in range(6):
		desktop_marker_text[seat] = _seat_marker(table, seat).text
	_assert_standard_seat_spacing(table, 6)

	for compact_size: Vector2i in [Vector2i(950, 532), Vector2i(768, 1024)]:
		harness.resize_viewport(compact_size)
		assert_true(await harness.settle_layout(), str(compact_size))
		for seat: int in range(6):
			var compact_marker := _seat_marker(table, seat)
			var tablet_compact: bool = compact_size == Vector2i(768, 1024)
			assert_eq(
				compact_marker.get_parent().name,
				&"Header" if tablet_compact else &"AvatarRegion",
			)
			assert_false("SB" in compact_marker.text)
			assert_false("BB" in compact_marker.text)
			var compact_style := compact_marker.get_theme_stylebox("normal") as StyleBoxFlat
			if tablet_compact:
				var avatar := (
					table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat).find_child(
						"AvatarRegion", true, false
					)
					as Control
				)
				assert_false(compact_marker.get_global_rect().intersects(avatar.get_global_rect()))
			else:
				assert_eq(compact_style.bg_color, Color.TRANSPARENT)
		harness.resize_viewport(Vector2i(1920, 1080))
		assert_true(await harness.settle_layout(), "desktop after %s" % compact_size)
		assert_eq(table.get_seat_rects(), desktop_seat_rects, str(compact_size))
		for seat: int in range(6):
			assert_eq(_seat_marker(table, seat).text, desktop_marker_text[seat])
		_assert_standard_seat_spacing(table, 6)


func test_larger_match_is_preserved_with_guidance_when_resized_to_phone() -> void:
	var fixture: Dictionary = await _render(&"human-turn-preflop", Vector2i(1280, 720), 9)
	var harness = fixture.harness
	var table: PokerTableController = fixture.rendered.table
	var original_view: GameView = table._bound_view
	var notice := table.get_node("%PhonePlayerCountNotice") as Label
	assert_false(notice.visible)

	harness.resize_viewport(Vector2i(390, 844))
	assert_true(await harness.settle_layout())
	assert_same(table._bound_view, original_view)
	assert_eq(table._bound_view.seats.size(), 9)
	assert_true(notice.visible)
	assert_string_contains(notice.text, "larger layout")
	assert_eq(table.get_seat_rects().size(), 9)

	harness.resize_viewport(Vector2i(1280, 720))
	assert_true(await harness.settle_layout())
	assert_same(table._bound_view, original_view)
	assert_false(notice.visible)


func _seat_marker(table: PokerTableController, seat: int) -> Label:
	var panel := (
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as PanelContainer
	)
	return panel.find_child("Marker", true, false) as Label


func test_real_keypads_and_dialogs_survive_resize_open_close_cycles() -> void:
	var startup_fixture: Dictionary = await _render(&"startup", Vector2i(390, 844), 2)
	var startup_harness = startup_fixture.harness
	var main: Control = startup_fixture.rendered.root
	var startup_keypad := main.get_node("StartupNumberKeypad") as PopupPanel
	main.call("show_numeric_keypad", main.get_node("%PlayerCountInput"))
	assert_true(startup_keypad.visible)
	var startup_value: String = startup_keypad.get_node("Content/Value").text
	startup_harness.resize_viewport(Vector2i(844, 390))
	assert_true(await startup_harness.settle_layout())
	assert_true(startup_keypad.visible)
	assert_eq(startup_keypad.get_node("Content/Value").text, startup_value)
	_assert_embedded_popup(startup_fixture.rendered.viewport, startup_keypad)
	startup_keypad.get_node("Content/Keys/Key2").emit_signal("pressed")
	assert_eq((main.get_node("%PlayerCountInput") as LineEdit).text, "6")
	assert_eq(startup_keypad.get_node("Content/Value").text, "6")
	startup_keypad.hide()
	assert_false(startup_keypad.visible)

	var table_fixture: Dictionary = await _render(&"wager-entry", Vector2i(390, 844), 6)
	var table_harness = table_fixture.harness
	var table: PokerTableController = table_fixture.rendered.table
	var wager_keypad := table.get_node("WagerKeypad") as PopupPanel
	table.show_wager_keypad()
	assert_true(wager_keypad.visible)
	var wager_value: String = wager_keypad.get_node("Content/Value").text
	var wager_range: String = wager_keypad.get_node("Content/Range").text
	table_harness.resize_viewport(Vector2i(640, 360))
	assert_true(await table_harness.settle_layout())
	assert_true(wager_keypad.visible)
	assert_eq(wager_keypad.get_node("Content/Value").text, wager_value)
	assert_eq(wager_keypad.get_node("Content/Range").text, wager_range)
	_assert_embedded_popup(table_fixture.rendered.viewport, wager_keypad)
	wager_keypad.get_node("Content/Keys/Key2").emit_signal("pressed")
	assert_eq((table.get_node("%WagerInput") as LineEdit).text, "75")
	assert_eq(wager_keypad.get_node("Content/Value").text, "752")
	wager_keypad.hide()
	assert_false(wager_keypad.visible)

	var confirmation := table.get_node("%QuitConfirmation") as ConfirmationDialog
	confirmation.popup_centered()
	assert_true(confirmation.visible)
	table_harness.resize_viewport(Vector2i(844, 390))
	assert_true(await table_harness.settle_layout())
	assert_true(confirmation.visible)
	_assert_embedded_popup(table_fixture.rendered.viewport, confirmation)
	confirmation.hide()
	assert_false(confirmation.visible)

	table.show_wager_keypad()
	assert_true(wager_keypad.visible)
	var bot_turn := GuiVisualStateFixturesScript.by_id(&"bot-turn", 6)
	table_harness.rerender(bot_turn)
	assert_true(await table_harness.settle_layout())
	assert_false(wager_keypad.visible)
	assert_false(table.is_layout_pending())
	_assert_current_region_owners(table, 6)


func test_rerender_after_state_changes_uses_only_the_new_snapshot_geometry() -> void:
	var fixture: Dictionary = await _render(&"human-turn-preflop", Vector2i(1280, 720), 6)
	var harness = fixture.harness
	var table: PokerTableController = fixture.rendered.table
	var preflop_generation: int = table.get_layout_generation()
	assert_eq(table.board_card_count, 0)

	var river := GuiVisualStateFixturesScript.by_id(&"human-turn-river", 6)
	var river_rendered: Dictionary = harness.rerender(river)
	assert_true(await harness.settle_layout())
	assert_gt(table.get_layout_generation(), preflop_generation)
	assert_eq(river_rendered.descriptor.id, &"human-turn-river")
	assert_eq(table.board_card_count, 5)
	_assert_current_region_owners(table, 6)

	var river_generation: int = table.get_layout_generation()
	var showdown := GuiVisualStateFixturesScript.by_id(&"showdown-long", 6)
	var showdown_rendered: Dictionary = harness.rerender(showdown)
	assert_true(await harness.settle_layout())
	assert_gt(table.get_layout_generation(), river_generation)
	assert_eq(showdown_rendered.descriptor.id, &"showdown-long")
	assert_true(_has_visible_showdown_region(table))
	assert_false(table.is_layout_pending())
	_assert_current_region_owners(table, 6)


func _render(state_id: StringName, viewport_size: Vector2i, player_count: int) -> Dictionary:
	var harness: Node = GuiSceneHarnessScript.new()
	add_child_autofree(harness)
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(state_id, player_count)
	var rendered: Dictionary = harness.render(descriptor, viewport_size)
	assert_true(await harness.settle_layout(), "%s at %s" % [state_id, viewport_size])
	return {"harness": harness, "rendered": rendered}


func _assert_current_region_owners(table: PokerTableController, player_count: int) -> void:
	var surface := table.get_node("TableMargin/Felt/TableSurface") as Control
	var regions: Dictionary[StringName, Rect2] = table.get_resolved_region_rects()
	var owners: Dictionary[StringName, Control] = {
		&"center": surface.get_node("CenterZone"),
		&"board": surface.get_node("CenterZone/BoardZone"),
		&"pot": surface.get_node("CenterZone/PotZone"),
		&"wager": surface.get_node("CenterZone/WagerZone"),
		&"action": surface.get_node("ActionPanel"),
		&"event": surface.get_node("EventLog"),
		&"quit": surface.get_node("QuitButton"),
	}
	for region_name: StringName in owners:
		assert_eq(regions[region_name], _surface_local_rect(surface, owners[region_name]))
		assert_true(surface.is_ancestor_of(owners[region_name]))
	assert_eq(regions.size(), 8 + player_count * 2)
	assert_eq(regions[&"hero"], regions[&"seat_0"])
	for seat: int in range(player_count):
		var seat_name := StringName("seat_%d" % seat)
		var seat_owner := surface.get_node("Seats/Seat%d" % seat) as Control
		assert_eq(regions[seat_name], _surface_local_rect(surface, seat_owner))
		assert_true(surface.is_ancestor_of(seat_owner))
		var status_name := StringName("status_%d" % seat)
		var status_owner := surface.get_node("Seats/Seat%dStatus" % seat) as Control
		assert_eq(regions[status_name], _surface_local_rect(surface, status_owner))
		assert_true(surface.is_ancestor_of(status_owner))


func _burst_phone_resize(harness: Node, table: PokerTableController) -> void:
	var previous_generation: int = table.get_layout_generation()
	for viewport_size: Vector2i in [
		Vector2i(844, 390),
		Vector2i(844, 330),
		Vector2i(360, 640),
	]:
		harness.resize_viewport(viewport_size)
	assert_true(table.is_layout_pending())
	assert_true(await harness.settle_layout())
	assert_gt(table.get_layout_generation(), previous_generation)
	assert_eq(table.size, Vector2(360, 640))
	assert_false(table.is_layout_pending())


func _assert_phone_plan_applied(table: PokerTableController, player_count: int) -> void:
	var plan: RefCounted = table._applied_phone_layout_plan
	assert_not_null(plan)
	var surface := table.get_node("TableMargin/Felt/TableSurface") as Control
	assert_eq(plan.usable_rect, Rect2(Vector2.ZERO, surface.size))
	_assert_rect_almost_eq(
		_surface_local_rect(surface, surface.get_node("CenterZone")), plan.center_rect
	)
	_assert_rect_almost_eq(
		_surface_local_rect(surface, surface.get_node("ActionPanel")), plan.action_rect
	)
	var more_rect: Rect2 = _surface_local_rect(surface, table.get_node("%PhoneMoreButton"))
	assert_true(plan.action_rect.encloses(more_rect))
	assert_eq(
		_surface_local_rect(surface, table.get_node("%PhoneShowdownOverlay")), plan.overlay_rect
	)
	assert_eq(_surface_local_rect(surface, table.get_node("%PhoneOverflowMenu")), plan.menu_rect)
	if table.has_node("TableMargin/Felt/TableSurface/SeatDetailOverlay"):
		var detail := table.get_node("TableMargin/Felt/TableSurface/SeatDetailOverlay") as Control
		if detail.visible:
			assert_eq(_surface_local_rect(surface, detail), plan.seat_detail_rect)
	for seat: int in range(player_count):
		if seat == table._bound_view.hero_seat:
			continue
		var visual_seat: int = posmod(seat - table._bound_view.hero_seat, player_count)
		var seat_control := surface.get_node("Seats/Seat%d" % seat) as Control
		assert_eq(seat_control.get_rect(), plan.seat_rects[visual_seat])


func _assert_standard_seat_spacing(table: PokerTableController, player_count: int) -> void:
	var seats := table.get_node("TableMargin/Felt/TableSurface/Seats") as Control
	for seat: int in range(player_count):
		var panel := seats.get_node("Seat%d" % seat) as PanelContainer
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(style.content_margin_left, 8.0, "seat %d left" % seat)
		assert_eq(style.content_margin_top, 5.0, "seat %d top" % seat)
		assert_eq(style.content_margin_right, 8.0, "seat %d right" % seat)
		assert_eq(style.content_margin_bottom, 5.0, "seat %d bottom" % seat)
		var header := panel.get_node("Content/Header") as HBoxContainer
		assert_eq(header.get_theme_constant("separation"), 7 if seat == 0 else 5)


func _surface_local_rect(surface: Control, control: Control) -> Rect2:
	var global_rect: Rect2 = control.get_global_rect()
	return Rect2(global_rect.position - surface.global_position, global_rect.size)


func _assert_embedded_popup(viewport: SubViewport, popup: Window) -> void:
	var viewport_rect := Rect2i(Vector2i.ZERO, viewport.size)
	var popup_rect := Rect2i(popup.position, popup.size)
	assert_true(viewport_rect.encloses(popup_rect), "%s inside %s" % [popup_rect, viewport_rect])
	var expected_position: Vector2 = (Vector2(viewport.size) - Vector2(popup.size)) * 0.5
	assert_almost_eq(float(popup.position.x), expected_position.x, 1.0)
	assert_almost_eq(float(popup.position.y), expected_position.y, 1.0)


func _assert_bottom_sheet(viewport: SubViewport, popup: Window) -> void:
	var viewport_rect := Rect2i(Vector2i.ZERO, viewport.size)
	var popup_rect := Rect2i(popup.position, popup.size)
	assert_true(viewport_rect.encloses(popup_rect), "%s inside %s" % [popup_rect, viewport_rect])
	assert_eq(popup.position.x, 0)
	assert_eq(popup.size.x, viewport.size.x)
	assert_eq(popup.position.y + popup.size.y, viewport.size.y)


func _assert_rect_almost_eq(actual: Rect2, expected: Rect2) -> void:
	assert_almost_eq(actual.position.x, expected.position.x, 0.01)
	assert_almost_eq(actual.position.y, expected.position.y, 0.01)
	assert_almost_eq(actual.size.x, expected.size.x, 0.01)
	assert_almost_eq(actual.size.y, expected.size.y, 0.01)


func _has_visible_showdown_region(table: PokerTableController) -> bool:
	for node: Node in table.get_node("TableMargin/Felt/TableSurface/Seats").get_children():
		var label := node as Label
		if (
			label != null
			and String(label.name).ends_with("Status")
			and label.max_lines_visible == 2
		):
			return not label.text.is_empty()
	return false
