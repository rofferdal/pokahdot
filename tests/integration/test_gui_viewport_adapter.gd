extends "res://tests/support/poker_gut_test.gd"

const Geometry := preload("res://scripts/gui/platform/gui_viewport_geometry.gd")
const MainScene := preload("res://scenes/main.tscn")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")
const Setup := preload("res://tests/web/reference_fixture_setup.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")


func test_direct_headless_main_preserves_explicit_control_geometry_and_host_window() -> void:
	var window: Window = get_window()
	var original_base: Vector2i = window.content_scale_size
	var original_size: Vector2i = window.size
	var main := MainScene.instantiate() as StartupConfigController
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(360, 780)
	add_child_autofree(main)
	assert_true(await _settle(main))
	assert_eq(main.size, Vector2(360, 780))
	assert_eq(main.get_viewport_adapter().get_geometry().logical_size, Vector2i(360, 780))
	assert_eq(window.content_scale_size, original_base)
	assert_eq(window.size, original_size)


func test_startup_and_full_bleed_phone_table_share_injected_safe_geometry() -> void:
	var main: StartupConfigController = await _main(Vector2i(390, 844))
	var usable := Rect2(11, 23, 362, 792)
	main.get_viewport_adapter().inject_geometry(Geometry.injected(Vector2(390, 844), usable))
	assert_true(await _settle(main))
	var startup: GuiLayoutSnapshot = main.get_layout_snapshot()
	assert_eq(startup.usable_rect, usable)
	assert_not_null(startup.startup)
	main._on_start_pressed()
	assert_true(await _settle(main))
	var table: GuiLayoutSnapshot = main.get_layout_snapshot()
	assert_eq(table.usable_rect, usable)
	assert_eq(table.surface_rect, table.usable_rect)
	assert_eq(table.seats.size(), 6)
	assert_eq(main.get_viewport_adapter().get_geometry().usable_rect, usable)


func test_wide_table_felt_remains_distinct_from_injected_usable_geometry() -> void:
	var main: StartupConfigController = await _main(Vector2i(1280, 720))
	var usable := Rect2(11, 23, 1250, 680)
	main.get_viewport_adapter().inject_geometry(Geometry.injected(Vector2(1280, 720), usable))
	assert_true(await _settle(main))
	var table: PokerTableController = Setup.table(main, true)
	table.bind_view(States.by_id(&"human-turn-preflop", 6).view, {}, {})
	assert_true(await _settle(main))
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_eq(snapshot.usable_rect, usable)
	assert_ne(snapshot.surface_rect, snapshot.usable_rect)
	assert_true(snapshot.usable_rect.encloses(snapshot.surface_rect))


func test_subviewport_injection_never_normalizes_the_host_window() -> void:
	var window: Window = get_window()
	var original_base: Vector2i = window.content_scale_size
	var original_size: Vector2i = window.size
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	viewport.gui_embed_subwindows = true
	add_child_autofree(viewport)
	var main := MainScene.instantiate() as StartupConfigController
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(390, 844)
	viewport.add_child(main)
	main.get_viewport_adapter().inject_geometry(
		Geometry.injected(Vector2(390, 844), Rect2(7, 31, 370, 780))
	)
	assert_true(await _settle(main))
	assert_eq(main.get_layout_snapshot().usable_rect, Rect2(7, 31, 370, 780))
	assert_eq(window.content_scale_size, original_base)
	assert_eq(window.size, original_size)
	assert_eq(viewport.size, Vector2i(390, 844))


func test_inset_updates_keep_open_keypad_draft_focus_and_committed_field_value() -> void:
	var main: StartupConfigController = await _main(Vector2i(390, 844))
	var adapter: GuiViewportAdapter = main.get_viewport_adapter()
	adapter.inject_geometry(Geometry.injected(Vector2(390, 844), Rect2(11, 23, 362, 792)))
	var table: PokerTableController = Setup.table(main, true)
	table.bind_view(States.by_id(&"human-turn-preflop", 6).view, {}, {})
	assert_true(await _settle(main))
	Setup.set_wager_input(table, "  ")
	table.show_wager_keypad()
	var keypad := table.get_node("WagerKeypad") as WagerKeypad
	assert_true(keypad.visible)
	var key := keypad.get_action_control(&"2")
	key.grab_focus()
	key.pressed.emit()
	var draft: String = _keypad(main.get_layout_snapshot()).elements[&"value"].text
	var seat_ids: Array[int] = main.get_layout_snapshot().seats.keys()
	for usable: Rect2 in [Rect2(9, 31, 370, 776), Rect2(9, 41, 370, 760)]:
		adapter.inject_geometry(Geometry.injected(Vector2(390, 844), usable))
		assert_true(await _settle(main))
		assert_true(keypad.visible)
		assert_eq(_keypad(main.get_layout_snapshot()).elements[&"value"].text, draft)
		assert_eq((table.get_node("%WagerInput") as LineEdit).text, "  ")
		assert_eq(main.get_layout_snapshot().seats.keys(), seat_ids)
		var focus: Control = keypad.gui_get_focus_owner()
		assert_not_null(focus)
		if focus != null:
			assert_true(keypad.is_ancestor_of(focus))
		var overlay: GuiOverlaySnapshot = _keypad(main.get_layout_snapshot())
		assert_not_null(overlay)
		if overlay != null:
			assert_true(
				usable.encloses(overlay.element.rect),
				"%s must enclose keypad %s" % [usable, overlay.element.rect]
			)
	keypad.cancel()
	assert_eq((table.get_node("%WagerInput") as LineEdit).text, "  ")


func test_burst_injections_keep_latest_immutable_geometry() -> void:
	var main: StartupConfigController = await _main(Vector2i(390, 844))
	var table: PokerTableController = Setup.table(main, true)
	table.bind_view(States.by_id(&"human-turn-preflop", 6).view, {}, {})
	assert_true(await _settle(main))
	var adapter: GuiViewportAdapter = main.get_viewport_adapter()
	var first: GuiViewportGeometry = Geometry.injected(Vector2(390, 844), Rect2(1, 2, 380, 820))
	var last: GuiViewportGeometry = Geometry.injected(Vector2(390, 844), Rect2(13, 37, 360, 770))
	adapter.inject_geometry(first)
	assert_true(table.get_layout_snapshot().pending)
	assert_false(table.get_layout_snapshot().ready)
	adapter.inject_geometry(last)
	assert_true(await _settle(main))
	assert_eq(adapter.get_geometry().usable_rect, last.usable_rect)
	assert_eq(main.get_layout_snapshot().usable_rect, last.usable_rect)
	assert_eq(first.usable_rect, Rect2(1, 2, 380, 820))
	assert_eq(first.generation, 0, "Publishing new generations must not mutate injected values")


func test_invalid_geometry_reports_nonready_without_losing_active_view_then_recovers() -> void:
	var main: StartupConfigController = await _main(Vector2i(390, 844))
	var table: PokerTableController = Setup.table(main, true)
	table.bind_view(States.by_id(&"human-turn-preflop", 6).view, {}, {})
	assert_true(await _settle(main))
	var before: GuiLayoutSnapshot = main.get_layout_snapshot()
	var original_stack: String = before.seats[1].fields[&"stack"].text
	var original_base: Vector2i = get_window().content_scale_size
	main.get_viewport_adapter().inject_geometry(Geometry.injected(Vector2.ZERO))
	for _frame: int in range(4):
		await get_tree().process_frame
	assert_false(main.get_layout_snapshot().ready)
	assert_false(main.get_viewport_adapter().get_geometry().valid)
	assert_eq(get_window().content_scale_size, original_base)
	main.get_viewport_adapter().inject_geometry(Geometry.injected(Vector2(390, 844)))
	assert_true(await _settle(main))
	var recovered: GuiLayoutSnapshot = main.get_layout_snapshot()
	assert_eq(recovered.seats.keys(), before.seats.keys())
	assert_eq(recovered.seats[1].fields[&"stack"].text, original_stack)


func test_translated_scaled_main_converts_nonzero_usable_origin_through_current_transform() -> void:
	var main: StartupConfigController = await _main(Vector2i(390, 844))
	var usable := Rect2(11, 23, 362, 792)
	main.get_viewport_adapter().inject_geometry(Geometry.injected(Vector2(390, 844), usable))
	assert_true(await _settle(main))
	main.position = Vector2(31, 47)
	main.scale = Vector2(0.75, 0.5)
	assert_true(await _settle(main))
	var expected: Rect2 = main.get_global_transform_with_canvas() * usable
	assert_true(main.get_layout_snapshot().usable_rect.is_equal_approx(expected))
	var table: PokerTableController = Setup.table(main, true)
	table.bind_view(States.by_id(&"human-turn-preflop", 6).view, {}, {})
	assert_true(await _settle(main))
	assert_true(table.get_layout_snapshot().usable_rect.is_equal_approx(expected))
	assert_true(table.get_layout_snapshot().surface_rect.is_equal_approx(expected))
	main.position += Vector2(19, 13)
	assert_true(await _settle(main))
	expected = main.get_global_transform_with_canvas() * usable
	assert_true(table.get_layout_snapshot().usable_rect.is_equal_approx(expected))
	assert_true(table.get_layout_snapshot().surface_rect.is_equal_approx(expected))


func test_compact_landscape_keypad_keeps_complete_content_inside_three_hundred_two_units() -> void:
	var main: StartupConfigController = await _main(Vector2i(640, 360))
	var table: PokerTableController = Setup.table(main, true)
	table.bind_view(States.by_id(&"human-turn-preflop", 6).view, {}, {})
	assert_true(await _settle(main))
	Setup.set_wager_input(table, "75")
	table.show_wager_keypad()
	assert_true(await _settle(main))
	var keypad := table.get_node("WagerKeypad") as WagerKeypad
	var key := keypad.get_action_control(&"2")
	key.grab_focus()
	key.pressed.emit()
	var draft: String = _keypad(main.get_layout_snapshot()).elements[&"value"].text
	var usable := Rect2(11, 24, 618, 302)
	main.get_viewport_adapter().inject_geometry(Geometry.injected(Vector2(640, 360), usable))
	assert_true(await _settle(main))
	assert_true(keypad.visible)
	assert_eq(_keypad(main.get_layout_snapshot()).elements[&"value"].text, draft)
	assert_eq((table.get_node("%WagerInput") as LineEdit).text, "75")
	var focus: Control = keypad.gui_get_focus_owner()
	assert_not_null(focus)
	if focus != null:
		assert_true(keypad.is_ancestor_of(focus))
	var overlay: GuiOverlaySnapshot = _keypad(main.get_layout_snapshot())
	assert_not_null(overlay)
	if overlay == null:
		return
	assert_true(usable.grow(0.0001).encloses(overlay.element.rect), str(overlay.element.rect))
	var failures := PackedStringArray()
	for element: GuiLayoutElement in overlay.measured:
		if not element.visible:
			continue
		assert_true(
			overlay.element.rect.grow(0.0001).encloses(element.rect),
			"%s escapes compact keypad: %s" % [element.role, element.rect]
		)
		Invariants.validate_element(element, failures)
	assert_eq(failures, PackedStringArray())


func _main(size: Vector2i) -> StartupConfigController:
	var main := MainScene.instantiate() as StartupConfigController
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(size)
	add_child_autofree(main)
	assert_true(await _settle(main))
	return main


func _settle(main: StartupConfigController) -> bool:
	var previous: String = ""
	var stable: int = 0
	for _frame: int in range(20):
		await get_tree().process_frame
		var snapshot: GuiLayoutSnapshot = main.get_layout_snapshot()
		var signature: String = snapshot.geometry_signature()
		if snapshot.ready and not snapshot.pending and signature == previous:
			stable += 1
		else:
			stable = 0
		previous = signature
		if stable >= 2:
			return true
	return false


func _keypad(snapshot: GuiLayoutSnapshot) -> GuiOverlaySnapshot:
	for overlay: GuiOverlaySnapshot in snapshot.overlays:
		if overlay.kind == &"keypad" and overlay.element.visible:
			return overlay
	return null
