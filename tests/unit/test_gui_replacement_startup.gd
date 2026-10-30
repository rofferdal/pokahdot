extends GutTest

const MainScene := preload("res://scenes/main.tscn")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")


func test_replacement_is_default_and_startup_instantiates_one_table() -> void:
	var main := MainScene.instantiate() as StartupConfigController
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1920, 1200)
	add_child_autofree(main)
	await wait_process_frames(5)
	assert_true(main.get_table_controller() is GuiReplacementTableController)
	assert_eq(_direct_tables(main), 1)
	assert_true(main.get_layout_snapshot().ready)
	remove_child(main)
	add_child(main)
	await wait_process_frames(3)
	assert_eq(_direct_tables(main), 1, "Reentry must not instantiate another controller")


func test_startup_adopts_one_match_and_applies_safe_origin_once() -> void:
	var main := _main()
	await wait_process_frames(5)
	var table: Control = main.get_table_controller()
	assert_eq(table.get_script().get_global_name(), &"GuiReplacementTableController")
	assert_eq(_direct_tables(main), 1)
	var safe := Rect2(23, 31, 1850, 1120)
	main.get_viewport_adapter().inject_geometry(GuiViewportGeometry.injected(main.size, safe))
	await wait_process_frames(5)
	(main.get_node("%StartButton") as Button).pressed.emit()
	var adopted: TournamentMatch = main.startup_adapter.match_instance
	assert_not_null(adopted)
	assert_true(await _settle(main))
	assert_eq(table.position, Vector2.ZERO)
	assert_eq(table.size, main.size)
	var snapshot: GuiLayoutSnapshot = main.get_layout_snapshot()
	assert_eq(snapshot.schema_version, 2)
	assert_eq(snapshot.usable_rect, safe)
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	var composition: Object = table.call("get_composition")
	main.get_viewport_adapter().inject_geometry(
		GuiViewportGeometry.injected(main.size, Rect2(41, 53, 1800, 1100))
	)
	assert_true(await _settle(main))
	assert_same(main.startup_adapter.match_instance, adopted)
	assert_same(main.get_table_controller(), table)
	assert_same(table.call("get_composition"), composition)
	assert_eq(main.get_layout_snapshot().usable_rect, Rect2(41, 53, 1800, 1100))
	assert_eq(_direct_tables(main), 1)


func test_replacement_snapshot_values_survive_controller_free() -> void:
	var main := _main()
	await wait_process_frames(5)
	(main.get_node("%StartButton") as Button).pressed.emit()
	var table: GuiReplacementTableController = main.get_table_controller()
	assert_true(await _settle(main))
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	var name_before_free: String = snapshot.seats[1].fields[&"name"].text
	assert_false(name_before_free.is_empty())
	_assert_detached(snapshot)
	table.free()
	assert_eq(snapshot.seats[1].fields[&"name"].text, name_before_free)
	_assert_detached(snapshot)


func _main() -> StartupConfigController:
	var main := MainScene.instantiate() as StartupConfigController
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1920, 1200)
	add_child_autofree(main)
	return main


func _settle(main: StartupConfigController) -> bool:
	for frame: int in 180:
		await wait_process_frames(1)
		var snapshot: GuiLayoutSnapshot = main.get_layout_snapshot()
		if not snapshot.pending and snapshot.ready:
			return true
	return false


func _direct_tables(main: Node) -> int:
	var count: int = 0
	for child: Node in main.get_children():
		if child.has_method("bind_match") and child.has_method("get_layout_snapshot"):
			count += 1
	return count


func _touch_press() -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	return event


func _left_mouse_press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


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


func test_physical_mouse_input_is_not_emulated_as_touchscreen_input() -> void:
	assert_false(
		ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", true),
		"Desktop browser clicks must remain mouse input so LineEdit uses the physical keyboard.",
	)


func test_phone_explains_its_limit_without_changing_the_six_player_default() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var player_count_input := main.get_node("%PlayerCountInput") as LineEdit

	main.size = Vector2(390, 844)
	main._refresh_startup_layout()
	var snapshot: GuiLayoutSnapshot = main.get_layout_snapshot()
	assert_true(snapshot.startup.fields[&"guidance"].visible)
	assert_eq(
		snapshot.startup.fields[&"guidance"].text,
		"Phone supports 2–7 players; 4 recommended. Default: 6."
	)
	assert_eq(snapshot.startup.fields[&"player_count_label"].text, "Players (2–7)")
	assert_eq(player_count_input.text, "6")

	main.size = Vector2(1920, 1080)
	main._refresh_startup_layout()
	snapshot = main.get_layout_snapshot()
	assert_false(snapshot.startup.fields[&"guidance"].visible)
	assert_eq(player_count_input.text, "6")
	assert_eq(snapshot.startup.fields[&"player_count_label"].text, "Participants (2–9)")


func test_phone_rejects_eight_players_without_clamping_the_entered_value() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var input := main.get_node("%PlayerCountInput") as LineEdit

	main.size = Vector2(390, 844)
	main._refresh_startup_layout()
	input.text = "8"
	(main.get_node("%StartButton") as Button).pressed.emit()
	assert_eq(input.text, "8")
	assert_eq(
		main.get_layout_snapshot().startup.fields[&"player_count_error"].text,
		"Phone layouts support 2–7 players. Enlarge the window to start with 8 or 9.",
	)
	assert_true(main.get_layout_snapshot().startup.visible)

	main.size = Vector2(1920, 1080)
	main._refresh_startup_layout()
	assert_eq(input.text, "8")
	assert_eq(
		main.get_layout_snapshot().startup.fields[&"player_count_label"].text, "Participants (2–9)"
	)


func test_startup_numeric_inputs_use_the_same_in_canvas_number_keypad_as_the_table() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)

	for input_path: NodePath in [
		^"%PlayerCountInput",
		^"%StartingStackInput",
		^"%SmallBlindInput",
		^"%BigBlindInput",
	]:
		var input := main.get_node(input_path) as LineEdit
		assert_false(input.virtual_keyboard_enabled, str(input_path))
		assert_false(input.virtual_keyboard_show_on_focus, str(input_path))
		assert_eq(input.virtual_keyboard_type, LineEdit.KEYBOARD_TYPE_NUMBER, str(input_path))

	var player_count_input := main.get_node("%PlayerCountInput") as LineEdit
	main.show_numeric_keypad(player_count_input)
	var keypad := (main.get_node("StartupOverlay") as GuiOverlayHost).get_keypad()
	assert_true(keypad.is_active())
	assert_eq((keypad.get_control(&"title") as Label).text, "Enter number")
	assert_true(keypad.get_control(&"limits").visible)
	keypad.get_control(&"2").emit_signal("pressed")
	assert_eq(player_count_input.text, "6")
	assert_eq(keypad.get_draft(), "6")
	keypad.get_control(&"done").emit_signal("pressed")
	assert_eq(player_count_input.text, "6")


func test_startup_numeric_input_dispatch_depends_on_touch_not_layout_profile() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	var input := main.get_node("%PlayerCountInput") as LineEdit
	var keypad := (main.get_node("StartupOverlay") as GuiOverlayHost).get_keypad()
	var profiles: Array[int] = [
		GuiLayoutSnapshot.Profile.PHONE_PORTRAIT,
		GuiLayoutSnapshot.Profile.TABLET,
		GuiLayoutSnapshot.Profile.SMALL_DESKTOP,
		GuiLayoutSnapshot.Profile.DESKTOP,
	]

	for profile: int in profiles:
		main.set_layout_profile_override(profile)
		input.gui_input.emit(_left_mouse_press())
		assert_false(keypad.is_active(), "mouse profile %d" % profile)
		input.gui_input.emit(_touch_press())
		assert_true(keypad.is_active(), "touch profile %d" % profile)
		keypad.cancel()


func test_startup_touch_to_keyboard_transition_cancels_only_the_draft() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	var input := main.get_node("%PlayerCountInput") as LineEdit
	var keypad := (main.get_node("StartupOverlay") as GuiOverlayHost).get_keypad()
	main.set_layout_profile_override(GuiLayoutSnapshot.Profile.DESKTOP)

	input.gui_input.emit(_touch_press())
	keypad.get_control(&"2").emit_signal("pressed")
	assert_eq(input.text, "6")
	assert_eq(keypad.get_draft(), "6")

	input.gui_input.emit(_left_mouse_press())
	assert_false(keypad.is_active())
	assert_eq(input.text, "6")
	# Godot owns physical-keyboard editing once pointer focus is allowed through.
	input.text = "10"
	input.text_submitted.emit(input.text)
	assert_eq(
		(main.get_node("%PlayerCountError") as Label).text,
		"Player count must be between 2 and 9.",
	)
	input.text = "6"


func test_return_to_startup_reveals_the_completion_status() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main._return_to_startup("Tournament complete.")

	var snapshot: GuiLayoutSnapshot = main.get_layout_snapshot()
	assert_true(snapshot.startup.visible)
	assert_eq(snapshot.startup.fields[&"status"].text, "Tournament complete.")
	assert_true(snapshot.startup.fields[&"status"].visible)
