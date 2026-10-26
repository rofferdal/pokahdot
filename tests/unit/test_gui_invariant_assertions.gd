extends "res://tests/support/poker_gut_test.gd"

const GuiInvariantAssertionsScript := preload("res://tests/support/gui_invariant_assertions.gd")
const GuiSceneHarnessScript := preload("res://tests/support/gui_scene_harness.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")

const PASSING_VIEWPORT := Vector2i(1920, 1080)
const PLAYER_COUNT: int = 6


func test_real_table_fixture_satisfies_all_invariants() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	assert_eq(GuiInvariantAssertionsScript.validate(rendered), PackedStringArray())


func test_scene_harness_mounts_real_startup_table_and_explicit_overlays() -> void:
	var startup: Dictionary = await _render(&"startup", 2)
	assert_eq(startup.root.name, "Main")
	assert_null(startup.table)

	var table: Dictionary = await _render(&"wager-entry")
	assert_eq(table.root.name, "PokerTable")
	assert_same(table.root, table.table)

	var quit: Dictionary = await _render(&"quit-confirmation")
	assert_eq(quit.overlay.name, "QuitConfirmation")
	assert_true(quit.overlay.visible)
	assert_eq(quit.intentional_overlap_controls, [&"QuitConfirmation"])

	var keypad: Dictionary = await _render(&"keypad-open", 2)
	assert_eq(keypad.overlay.name, "StartupNumberKeypad")
	assert_true(keypad.overlay.visible)
	assert_eq(keypad.intentional_overlap_controls, [&"StartupNumberKeypad"])


func test_containment_failure_is_reported() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var quit_button := rendered.table.get_node("%QuitButton") as Button
	quit_button.position = Vector2(-300.0, -300.0)
	_assert_failure(rendered, "containment:")


func test_intersection_failure_is_reported() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var seats := rendered.table.get_node("TableMargin/Felt/TableSurface/Seats") as Control
	var seat_zero := seats.get_node("Seat0") as Control
	var seat_one := seats.get_node("Seat1") as Control
	seat_one.position = seat_zero.position
	_assert_failure(rendered, "intersection:")


func test_auxiliary_clearance_failure_is_reported() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var seats := rendered.table.get_node("TableMargin/Felt/TableSurface/Seats") as Control
	var seat_zero := seats.get_node("Seat0") as Control
	var action_zero := seats.get_node("Seat0Status") as Control
	action_zero.position = seat_zero.position
	action_zero.visible = true
	_assert_failure(rendered, "auxiliary-clearance:")


func test_single_line_text_clipping_failure_is_reported() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var wager_input := rendered.table.get_node("%WagerInput") as LineEdit
	wager_input.text = "This wager entry is deliberately much too wide for its control"
	_assert_failure(rendered, "text-clipping:")


func test_wrapped_text_clipping_failure_is_reported() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var label := Label.new()
	label.name = "DeliberatelyClippedWrap"
	label.position = Vector2(8.0, 8.0)
	label.size = Vector2(110.0, 20.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 20)
	label.text = "Several wrapped lines are deliberately hidden by this short label."
	rendered.table.add_child(label)
	await get_tree().process_frame
	_assert_failure(rendered, "text-clipping:", "hides wrapped lines")


func test_ellipsized_required_content_clipping_is_reported() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var seat := rendered.table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1") as Control
	var name_label := seat.find_child("Name", true, false) as Label
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.text = "Required player name is deliberately too long ".repeat(8)
	_assert_failure(rendered, "text-clipping:", "/Name")
	var stack_label := seat.find_child("Stack", true, false) as Label
	stack_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack_label.text = "99999999999999999999999999999999999999999999999999999999"
	_assert_failure(rendered, "text-clipping:", "/Stack")


func test_wrapped_ellipsis_line_limit_is_reported_even_with_spare_height() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var label := Label.new()
	label.name = "LimitedRequiredContent"
	label.add_theme_font_size_override("font_size", 20)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = 1
	label.text = "Required summary content has several complete wrapped lines."
	rendered.table.add_child(label)
	label.size = Vector2(150.0, 200.0)
	_assert_failure(rendered, "text-clipping:", "limit 1")


func test_popup_overlay_required_content_clipping_is_reported() -> void:
	var rendered: Dictionary = await _render(&"keypad-open", 2)
	var title := rendered.overlay.get_node("Content/Title") as Label
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.text = "Required keypad title deliberately overflows the entire popup width ".repeat(8)
	_assert_failure(rendered, "text-clipping:", "overlay/")


func test_popup_position_uses_the_embedding_viewport_coordinates() -> void:
	var rendered: Dictionary = await _render(&"keypad-open", 2)
	assert_eq(GuiInvariantAssertionsScript.validate(rendered), PackedStringArray())
	var popup := rendered.overlay as Window
	popup.position = Vector2i(-20, -20)
	_assert_failure(rendered, "containment:", "popup overlay")


func test_phone_showdown_table_and_summary_have_distinct_fixtures() -> void:
	var harness: Node = GuiSceneHarnessScript.new()
	add_child_autofree(harness)
	var bare: Dictionary = harness.render(
		GuiVisualStateFixturesScript.by_id(&"showdown-long", 6), Vector2i(390, 844)
	)
	assert_true(await harness.settle_layout())
	assert_null(bare.overlay)
	assert_eq(bare.intentional_overlap_controls, [])
	assert_false((bare.table.get_node("%PhoneShowdownOverlay") as Control).visible)

	var summary: Dictionary = harness.rerender(
		GuiVisualStateFixturesScript.by_id(&"showdown-overlay", 6)
	)
	assert_true(await harness.settle_layout())
	assert_eq(summary.overlay.name, &"PhoneShowdownOverlay")
	assert_eq(summary.intentional_overlap_controls, [&"PhoneShowdownOverlay"])
	assert_eq(GuiInvariantAssertionsScript.validate(summary), PackedStringArray())
	bare = harness.rerender(GuiVisualStateFixturesScript.by_id(&"showdown-long", 6))
	assert_true(await harness.settle_layout())
	assert_null(bare.overlay)
	assert_false((bare.table.get_node("%PhoneShowdownOverlay") as Control).visible)


func test_compact_tablet_keeps_complete_showdown_content_visible() -> void:
	for viewport_size: Vector2i in [Vector2i(768, 1024), Vector2i(1024, 768)]:
		var harness: Node = GuiSceneHarnessScript.new()
		add_child_autofree(harness)
		var rendered: Dictionary = harness.render(
			GuiVisualStateFixturesScript.by_id(&"showdown-long", 6), viewport_size
		)
		assert_true(await harness.settle_layout())
		var label := (
			rendered.table.get_node("TableMargin/Felt/TableSurface/Seats/Seat4Status") as Label
		)
		assert_eq(
			label.text,
			"Full house\nAces / Kings" if viewport_size.y > viewport_size.x else "Full house: A / K"
		)
		assert_eq(GuiInvariantAssertionsScript.validate(rendered), PackedStringArray())


func test_font_floor_failure_is_reported() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var label := Label.new()
	label.name = "DeliberatelySmallFont"
	label.position = Vector2(8.0, 8.0)
	label.size = Vector2(100.0, 30.0)
	label.add_theme_font_size_override("font_size", 19)
	label.text = "Small"
	rendered.table.add_child(label)
	_assert_failure(rendered, "font-floor:")


func test_touch_target_failure_is_reported() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var button := Button.new()
	button.name = "DeliberatelySmallTarget"
	button.position = Vector2(8.0, 8.0)
	button.size = Vector2(47.0, 48.0)
	button.add_theme_font_size_override("font_size", 20)
	button.text = "X"
	rendered.table.add_child(button)
	_assert_failure(rendered, "touch-target:")


func test_community_card_failure_is_reported() -> void:
	var rendered: Dictionary = await _render(&"human-turn-river")
	var wager_input := rendered.table.get_node("%WagerInput") as LineEdit
	wager_input.text = "75"
	var card := rendered.table.get_node("%CardSlots").get_child(0) as Control
	card.visible = false
	_assert_failure(rendered, "community-cards:")


func test_legal_action_failure_is_reported() -> void:
	var rendered: Dictionary = await _render(&"wager-entry")
	var fold_button := rendered.table.get_node("%FoldButton") as Button
	fold_button.disabled = true
	_assert_failure(rendered, "legal-action:")


func test_overlay_exceptions_are_state_specific() -> void:
	var ordinary: Dictionary = await _render(&"wager-entry")
	ordinary.intentional_overlap_controls = [&"UnexpectedOverlay"]
	_assert_failure(ordinary, "overlay-exception:")

	var quit: Dictionary = await _render(&"quit-confirmation")
	quit.intentional_overlap_controls = []
	_assert_failure(quit, "overlay-exception:")


func _render(state_id: StringName, player_count: int = PLAYER_COUNT) -> Dictionary:
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(state_id, player_count)
	var harness: Node = GuiSceneHarnessScript.new()
	add_child_autofree(harness)
	var rendered: Dictionary = harness.render(descriptor, PASSING_VIEWPORT)
	assert_true(await harness.settle_layout(), "%s must reach stable geometry" % state_id)
	return rendered


func _assert_failure(rendered: Dictionary, prefix: String, detail: String = "") -> void:
	var failures: PackedStringArray = GuiInvariantAssertionsScript.validate(rendered)
	for failure: String in failures:
		if failure.begins_with(prefix) and (detail.is_empty() or detail in failure):
			assert_true(true)
			return
	assert_true(false, "Expected %s%s in %s" % [prefix, detail, failures])
