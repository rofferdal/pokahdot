extends GutTest

const LogScene := preload("res://scenes/gui/components/EventLog.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")

var _viewport: SubViewport


func test_plain_public_copy_is_exact_detached_and_does_not_interpret_markup() -> void:
	var root: Control = _root()
	var log: GuiEventLog = LogScene.instantiate()
	var lines: Array[String] = [
		"[b]Raise 9000000[/b]", "[color=red]Player wins[/color]", "<literal> & text"
	]
	var model: EventLogViewModel = EventLogViewModel.from_lines(lines)
	var expected: String = model.text
	var reference: WeakRef = weakref(model)
	log.render(model)
	root.add_child(log)
	log.size = Vector2(360, 260)
	await wait_process_frames(6)
	lines[0] = "Changed caller line"
	model.text = "Changed model text"
	model.entries[0] = "Changed model entry"
	model = null
	assert_null(reference.get_ref())
	assert_eq(log.get_log_text(), expected)
	assert_eq(log.get_body().text, expected)
	assert_eq(log.get_body().get_parsed_text(), expected)
	assert_false(log.get_body().bbcode_enabled)
	_assert_geometry_and_roles(log, root)


func test_docked_and_overlay_instances_render_one_model_without_sharing_reader_state() -> void:
	var root: Control = _root()
	var docked: GuiEventLog = LogScene.instantiate()
	var overlay: GuiEventLog = LogScene.instantiate()
	root.add_child(docked)
	root.add_child(overlay)
	docked.size = Vector2(320, 230)
	overlay.size = Vector2(580, 420)
	overlay.position = Vector2(400, 0)
	var model: EventLogViewModel = _history(60)
	docked.render(model)
	overlay.render(model)
	await wait_process_frames(7)
	assert_eq(docked.get_log_text(), model.text)
	assert_eq(overlay.get_log_text(), model.text)
	assert_eq(docked.get_body().get_parsed_text(), overlay.get_body().get_parsed_text())
	var overlay_end: float = overlay.get_body().get_v_scroll_bar().value
	docked.get_body().get_v_scroll_bar().value = 20.0
	assert_eq(overlay.get_body().get_v_scroll_bar().value, overlay_end)
	docked.hide()
	model = _history(80)
	docked.render(model)
	overlay.render(model)
	await wait_process_frames(5)
	assert_eq(docked.get_log_text(), model.text)
	assert_eq(overlay.get_log_text(), model.text)
	docked.show()
	await wait_process_frames(5)
	assert_eq(docked.get_body().get_v_scroll_bar().value, 20.0)
	_assert_geometry_and_roles(docked, root)
	_assert_geometry_and_roles(overlay, root)


func test_empty_and_long_history_keep_a_constant_intrinsic_minimum() -> void:
	var root: Control = _root()
	var log: GuiEventLog = LogScene.instantiate()
	root.add_child(log)
	log.render(EventLogViewModel.from_lines([]))
	await wait_process_frames(5)
	var minimum: Vector2 = log.get_combined_minimum_size()
	log.size = minimum
	await wait_process_frames(4)
	assert_eq((log.get_node("Empty") as Label).text, "No events yet.")
	assert_eq(log.get_log_text(), "")
	_assert_geometry_and_roles(log, root)
	log.render(_history(200))
	await wait_process_frames(6)
	assert_eq(log.get_combined_minimum_size(), minimum)
	assert_eq((log.get_node("Empty") as Label).text, "")
	assert_true(log.get_body().scroll_active)
	assert_false(log.get_body().fit_content)
	assert_true(log.get_body().selection_enabled)
	assert_gt(log.get_body().get_v_scroll_bar().max_value, log.get_body().get_v_scroll_bar().page)
	assert_string_contains(log.get_log_text(), "Public event 199")
	_assert_geometry_and_roles(log, root)
	log.render(EventLogViewModel.from_lines([]))
	await wait_process_frames(5)
	assert_eq(log.get_combined_minimum_size(), minimum)
	assert_eq((log.get_node("Empty") as Label).text, "No events yet.")


func test_new_entries_follow_only_when_the_reader_was_at_the_end() -> void:
	var root: Control = _root()
	var log: GuiEventLog = LogScene.instantiate()
	root.add_child(log)
	log.size = Vector2(350, 240)
	log.render(_history(50))
	await wait_process_frames(7)
	var bar: VScrollBar = log.get_body().get_v_scroll_bar()
	assert_almost_eq(bar.value, _end(bar), 1.0)
	var previous_end: float = _end(bar)
	log.render(_history(70))
	await wait_process_frames(6)
	assert_gt(_end(bar), previous_end)
	assert_almost_eq(bar.value, _end(bar), 1.0)
	bar.value = _end(bar) * 0.3
	var reading: float = bar.value
	log.render(_history(100))
	await wait_process_frames(6)
	assert_almost_eq(bar.value, reading, 0.5)
	assert_lt(bar.value, _end(bar))
	log.render(EventLogViewModel.from_lines(["Short replacement"]))
	await wait_process_frames(6)
	assert_gte(bar.value, bar.min_value)
	assert_lte(bar.value, _end(bar))


func test_multiple_updates_before_layout_coalesce_without_losing_end_following() -> void:
	var root: Control = _root()
	var log: GuiEventLog = LogScene.instantiate()
	root.add_child(log)
	log.size = Vector2(330, 230)
	log.render(_history(40))
	await wait_process_frames(7)
	log.render(_history(45))
	log.render(_history(50))
	var final_model: EventLogViewModel = _history(55)
	log.render(final_model)
	await wait_process_frames(6)
	var bar: VScrollBar = log.get_body().get_v_scroll_bar()
	assert_eq(log.get_log_text(), final_model.text)
	assert_almost_eq(bar.value, _end(bar), 1.0)


func test_equal_text_render_preserves_selection_and_the_reader_offset() -> void:
	var root: Control = _root()
	var log: GuiEventLog = LogScene.instantiate()
	root.add_child(log)
	log.size = Vector2(350, 250)
	var model: EventLogViewModel = _history(40)
	log.render(model)
	await wait_process_frames(7)
	var body: RichTextLabel = log.get_body()
	body.select_all()
	var selected: String = body.get_selected_text()
	body.get_v_scroll_bar().value = 20.0
	var same_lines: Array[String] = []
	same_lines.assign(model.entries)
	log.render(EventLogViewModel.from_lines(same_lines))
	await wait_process_frames(5)
	assert_eq(body.get_selected_text(), selected)
	assert_eq(body.get_v_scroll_bar().value, 20.0)
	assert_eq(log.get_log_text(), model.text)


func test_native_mouse_wheel_and_keyboard_can_scroll_the_log_body() -> void:
	var root: Control = _input_root()
	var log: GuiEventLog = LogScene.instantiate()
	root.add_child(log)
	log.size = Vector2(360, 250)
	log.render(_history(80))
	await wait_process_frames(7)
	var body: RichTextLabel = log.get_body()
	var bar: VScrollBar = body.get_v_scroll_bar()
	bar.value = 0.0
	await _wheel(body.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	assert_gt(bar.value, 0.0)
	var before_key: float = bar.value
	body.grab_focus()
	await _key(KEY_PAGEDOWN)
	assert_gt(bar.value, before_key)
	_assert_geometry_and_roles(log, root)


func test_touch_drag_can_scroll_history_without_affecting_its_plain_copy() -> void:
	var root: Control = _input_root()
	var log: GuiEventLog = LogScene.instantiate()
	root.add_child(log)
	log.size = Vector2(360, 280)
	var model: EventLogViewModel = _history(80)
	log.render(model)
	await wait_process_frames(7)
	var body: RichTextLabel = log.get_body()
	var bar: VScrollBar = body.get_v_scroll_bar()
	bar.value = 0.0
	var origin: Vector2 = body.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.position = origin
	press.pressed = true
	_viewport.push_input(press)
	await get_tree().process_frame
	var drag := InputEventScreenDrag.new()
	drag.position = origin - Vector2(0, 50)
	drag.relative = Vector2(0, -50)
	_viewport.push_input(drag)
	await get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.position = drag.position
	release.pressed = false
	_viewport.push_input(release)
	await wait_process_frames(4)
	assert_gt(bar.value, 0.0)
	assert_eq(log.get_log_text(), model.text)


func test_hidden_updates_and_remove_reentry_keep_history_and_reader_context() -> void:
	var root: Control = _root()
	var log: GuiEventLog = LogScene.instantiate()
	var model: EventLogViewModel = _history(60)
	log.render(model)
	root.add_child(log)
	log.size = Vector2(340, 240)
	await wait_process_frames(7)
	log.get_body().get_v_scroll_bar().value = 35.0
	log.hide()
	model = _history(80)
	log.render(model)
	await wait_process_frames(5)
	assert_eq(log.get_log_text(), model.text)
	log.show()
	await wait_process_frames(5)
	assert_almost_eq(log.get_body().get_v_scroll_bar().value, 35.0, 0.5)
	root.remove_child(log)
	await wait_process_frames(4)
	root.add_child(log)
	await wait_process_frames(5)
	assert_eq(log.get_log_text(), model.text)
	assert_almost_eq(log.get_body().get_v_scroll_bar().value, 35.0, 0.5)
	_assert_geometry_and_roles(log, root)


func test_pending_restore_is_safe_when_removed_and_rebound_before_reentry() -> void:
	var root: Control = _root()
	var log: GuiEventLog = LogScene.instantiate()
	root.add_child(log)
	log.render(_history(30))
	root.remove_child(log)
	await wait_process_frames(4)
	var final_model: EventLogViewModel = _history(50)
	log.render(final_model)
	root.add_child(log)
	log.size = Vector2(330, 250)
	await wait_process_frames(7)
	assert_eq(log.get_log_text(), final_model.text)
	assert_push_error_count(0)
	_assert_geometry_and_roles(log, root)


func test_native_minimum_recovers_exactly_after_long_history_and_large_allocations() -> void:
	var root: Control = _root()
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		var host := VBoxContainer.new()
		host.theme = metrics
		root.add_child(host)
		var log: GuiEventLog = LogScene.instantiate()
		log.size_flags_vertical = Control.SIZE_EXPAND_FILL
		host.add_child(log)
		log.render(EventLogViewModel.from_lines([]))
		await wait_process_frames(6)
		var minimum: Vector2 = host.get_combined_minimum_size()
		host.size = minimum
		await wait_process_frames(5)
		log.render(_history(150))
		await wait_process_frames(6)
		assert_eq(host.get_combined_minimum_size(), minimum)
		host.size = Vector2(1200, 800)
		await wait_process_frames(6)
		assert_eq(host.get_combined_minimum_size(), minimum)
		host.size = minimum
		await wait_process_frames(7)
		assert_eq(host.size, minimum)
		assert_true(Rect2(host.global_position, minimum).encloses(log.get_global_rect()))
		_assert_geometry_and_roles(log, root)
		root.remove_child(host)
		host.free()


func test_authored_log_fills_and_recovers_parent_allocations_without_resizing_copy() -> void:
	var root: Control = _root()
	var host := VBoxContainer.new()
	root.add_child(host)
	var heading := Label.new()
	heading.text = "Table controls"
	host.add_child(heading)
	var log: GuiEventLog = LogScene.instantiate()
	host.add_child(log)
	var model: EventLogViewModel = _history(120)
	log.render(model)
	await wait_process_frames(6)
	var minimum: Vector2 = host.get_combined_minimum_size()
	for allocation: Vector2 in [Vector2(320, 240), Vector2(900, 700), Vector2(260, 210)]:
		host.size = allocation
		await wait_process_frames(6)
		assert_eq(host.size, allocation)
		assert_eq(log.size.x, allocation.x)
		assert_almost_eq(log.get_global_rect().end.y, host.get_global_rect().end.y, 0.1)
		assert_almost_eq(log.get_body().get_global_rect().end.y, log.get_global_rect().end.y, 0.1)
		assert_eq(host.get_combined_minimum_size(), minimum)
		assert_eq(log.get_log_text(), model.text)
		assert_gt(_end(log.get_body().get_v_scroll_bar()), 0.0)
		_assert_geometry_and_roles(log, root)
	host.size = minimum
	await wait_process_frames(6)
	assert_eq(host.size, minimum)
	assert_eq(host.get_combined_minimum_size(), minimum)
	_assert_geometry_and_roles(log, root)


func test_resize_keeps_end_following_or_an_earlier_reader_offset() -> void:
	var root: Control = _root()
	var log: GuiEventLog = LogScene.instantiate()
	root.add_child(log)
	log.size = Vector2(700, 350)
	var model: EventLogViewModel = _history(120)
	log.render(model)
	await wait_process_frames(7)
	var bar: VScrollBar = log.get_body().get_v_scroll_bar()
	assert_almost_eq(bar.value, _end(bar), 1.0)
	log.size = Vector2(260, 220)
	await wait_process_frames(7)
	assert_almost_eq(bar.value, _end(bar), 1.0)
	bar.value = 100.0
	log.size = Vector2(800, 500)
	await wait_process_frames(7)
	assert_almost_eq(bar.value, 100.0, 0.5)
	log.size = Vector2(280, 230)
	await wait_process_frames(7)
	assert_almost_eq(bar.value, 100.0, 0.5)
	assert_eq(log.get_log_text(), model.text)
	_assert_geometry_and_roles(log, root)


func test_null_binding_clears_old_history_with_one_explicit_error() -> void:
	var root: Control = _root()
	var log: GuiEventLog = LogScene.instantiate()
	root.add_child(log)
	log.render(_history(20))
	await wait_process_frames(5)
	log.render(null)
	assert_push_error_count(1)
	await wait_process_frames(5)
	assert_eq(log.get_log_text(), "")
	assert_eq(log.get_body().get_parsed_text(), "")
	assert_eq((log.get_node("Empty") as Label).text, "No events yet.")
	_assert_geometry_and_roles(log, root)


func _assert_geometry_and_roles(log: GuiEventLog, root: Control) -> void:
	var body: RichTextLabel = log.get_body()
	assert_true(log.get_global_rect().encloses(body.get_global_rect()))
	assert_gte(body.size.y, 96.0)
	assert_eq(body.get_theme_font_size("normal_font_size"), 18)
	var observed: GuiLayoutElement = log.get_observation(root)
	assert_eq(observed.role, &"event")
	assert_eq(observed.text_kind, &"rich_text")
	assert_eq(observed.text, log.get_log_text())
	assert_eq(observed.font_size, 18)
	var failures := PackedStringArray()
	Invariants.validate_element(observed, failures)
	assert_eq(failures, PackedStringArray())
	for name: String in ["Heading", "Empty"]:
		var label: Label = log.get_node(name)
		assert_gte(label.get_theme_font_size("font_size"), 20)
		var value: GuiLayoutElement = GuiSnapshotMeasurement.element(label, root, StringName(name))
		var label_failures := PackedStringArray()
		Invariants.validate_element(value, label_failures)
		assert_eq(label_failures, PackedStringArray())


func _history(count: int) -> EventLogViewModel:
	var lines: Array[String] = []
	for index: int in count:
		lines.append("Public event %d: player raised to 1000000 chips." % index)
	return EventLogViewModel.from_lines(lines)


func _end(bar: VScrollBar) -> float:
	return maxf(bar.min_value, bar.max_value - bar.page)


func _root() -> Control:
	var root := Control.new()
	root.size = Vector2(1800, 1300)
	root.theme = Palette
	add_child_autofree(root)
	return root


func _input_root() -> Control:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(900, 700)
	add_child_autofree(_viewport)
	var root := Control.new()
	root.size = Vector2(900, 700)
	root.theme = Palette
	_viewport.add_child(root)
	return root


func _wheel(position: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.pressed = true
	_viewport.push_input(event)
	await get_tree().process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame
