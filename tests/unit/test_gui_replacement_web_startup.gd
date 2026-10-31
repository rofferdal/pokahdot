extends "res://tests/support/poker_gut_test.gd"

const MainScene := preload("res://scenes/main.tscn")


func test_real_phone_startup_to_table_transition_keeps_phone_composition() -> void:
	var main := MainScene.instantiate() as StartupConfigController
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(390, 844)
	add_child_autofree(main)
	await get_tree().process_frame
	(main.get_table_controller() as GuiReplacementTableController).use_keypad(true)
	main._on_start_pressed()
	var table := main.get_table_controller() as GuiReplacementTableController
	assert_not_null(table)
	for _frame: int in 180:
		await get_tree().process_frame
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		if not snapshot.pending and (snapshot.ready or not snapshot.fit_guidance.is_empty()):
			break
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_eq(table.size, Vector2(390, 844))
	assert_eq(snapshot.schema_version, 2)
	assert_true(snapshot.ready, "The default phone game must render playable content.")
	assert_true(snapshot.fit_guidance.is_empty())
	assert_eq(table.get_table_view_model().seats.size(), 6)
	assert_not_null(main.startup_adapter.match_instance)
