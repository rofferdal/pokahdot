extends "res://tests/support/poker_gut_test.gd"

const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const MainScene := preload("res://scenes/main.tscn")
const PokerTableScene := preload("res://scenes/poker_table.tscn")


func test_desktop_seat_content_is_visible_and_non_overlapping_for_every_supported_count() -> void:
	for player_count: int in range(2, 10):
		var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = Vector2(1920, 1080)
		table.bind_view(_hero_table_view(player_count), _avatar_assignments(player_count))
		table.show()
		await get_tree().process_frame
		await get_tree().process_frame

		var surface_rect := Rect2(Vector2.ZERO, _surface_size(table))
		var placed_rects: Array[Rect2] = []
		for seat: int in range(player_count):
			var panel: PanelContainer = table.get_node(
				"TableMargin/Felt/TableSurface/Seats/Seat%d" % seat
			)
			var seat_rect: Rect2 = panel.get_rect()
			var context := "desktop seat %d at %d players" % [seat, player_count]
			assert_true(surface_rect.encloses(seat_rect), context)
			for placed_rect: Rect2 in placed_rects:
				assert_false(
					seat_rect.intersects(placed_rect), "%s overlaps another seat" % context
				)
			placed_rects.append(seat_rect)

			var content: Control = panel.get_node("Content")
			assert_true(
				Rect2(Vector2.ZERO, panel.size).encloses(Rect2(content.position, content.size)),
				"%s content must remain inside its seat panel" % context,
			)
			for child: Node in content.get_children():
				if child is Control:
					var child_control := child as Control
					assert_true(
						Rect2(Vector2.ZERO, content.size).encloses(
							Rect2(child_control.position, child_control.size)
						),
						"%s child %s must remain visible" % [context, child.name],
					)


func test_desktop_seat_typography_is_reduced_after_scale_correction() -> void:
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1920, 1080)
	table.bind_view(_hero_table_view(2), _avatar_assignments(2))
	await get_tree().process_frame

	var opponent: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1")
	var hero: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0")
	assert_eq(
		opponent.get_node("Content/Header/Identity/Name").get_theme_font_size("font_size"), 30
	)
	assert_eq(
		opponent.get_node("Content/Header/Identity/Stack").get_theme_font_size("font_size"), 33
	)
	assert_eq(hero.get_node("Content/Header/Identity/Name").get_theme_font_size("font_size"), 34)
	assert_eq(opponent.get_node("Content/Header/Marker").get_theme_font_size("font_size"), 30)
	var opponent_action: Label = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status")
	assert_eq(opponent_action.get_theme_font_size("font_size"), 26)


func test_desktop_action_and_quit_fonts_match_community_cards_without_resizing_board() -> void:
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1920, 1080)
	table.bind_view(_hero_table_view(2), _avatar_assignments(2))
	await get_tree().process_frame
	await get_tree().process_frame

	var community_zone: Panel = table.get_node("TableMargin/Felt/TableSurface/CenterZone/BoardZone")
	var community_label: Label = table.get_node("%BoardLabel")
	var community_font_size: int = community_label.get_theme_font_size("font_size")
	assert_eq(community_font_size, 32)
	assert_eq(community_zone.size, Vector2(520, 134))

	for control_path: NodePath in [
		^"%FoldButton",
		^"%CheckCallButton",
		^"%MinWagerButton",
		^"%PotRaiseButton",
		^"%AllInButton",
		^"%WagerInput",
		^"%WagerButton",
		^"%QuitButton",
	]:
		var control: Control = table.get_node(control_path)
		assert_gte(
			control.get_theme_font_size("font_size"),
			community_font_size,
			"%s must match Community cards typography" % control_path,
		)


func test_desktop_action_controls_have_distinct_focus_and_disabled_states() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1853, 916)
	table.bind_view(_hero_table_view(6), _avatar_assignments(6))
	await get_tree().process_frame
	await get_tree().process_frame

	for path: NodePath in [
		^"%FoldButton",
		^"%CheckCallButton",
		^"%MinWagerButton",
		^"%PotRaiseButton",
		^"%AllInButton",
		^"%WagerButton",
	]:
		var button := table.get_node(path) as Button
		var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
		var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
		var disabled := button.get_theme_stylebox("disabled") as StyleBoxFlat
		assert_not_null(focus, "%s needs an explicit keyboard focus ring" % path)
		assert_not_null(disabled, "%s needs an explicit disabled state" % path)
		assert_gt(focus.border_width_left, normal.border_width_left, str(path))
		assert_ne(_style_signature(focus), _style_signature(normal), str(path))
		assert_ne(_style_signature(disabled), _style_signature(normal), str(path))
	var wager_input := table.get_node("%WagerInput") as LineEdit
	assert_ne(
		_style_signature(wager_input.get_theme_stylebox("focus") as StyleBoxFlat),
		_style_signature(wager_input.get_theme_stylebox("normal") as StyleBoxFlat),
	)


func test_desktop_empty_board_slots_are_neutral_and_event_log_follows_latest_row() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1853, 916)
	table.bind_view(_hero_table_view(6), _avatar_assignments(6))
	await get_tree().process_frame
	await get_tree().process_frame

	for slot: PanelContainer in table.get_node("%CardSlots").get_children():
		assert_eq((slot.get_node("Content/Rank") as Label).text, "")
		assert_null((slot.get_node("Content/Suit") as TextureRect).texture)
		assert_eq(slot.modulate.a, 1.0)
		var slot_style := slot.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(slot_style.bg_color, Color("294c5c"))
		assert_eq(slot_style.border_color, Color("82968b"))
	var event_log := table.get_node("%EventLog") as RichTextLabel
	var event_style := event_log.get_theme_stylebox("normal") as StyleBoxFlat
	assert_true(event_log.scroll_active)
	assert_true(event_log.scroll_following)
	assert_gte(event_style.content_margin_left, 8.0)
	assert_gte(event_style.content_margin_bottom, 5.0)


func test_folded_desktop_status_retains_readable_contrast() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1853, 916)
	var view := _hero_table_view(2)
	view._seats[1].folded = true
	table.bind_view(view, _avatar_assignments(2))
	await get_tree().process_frame

	var status := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label
	var folded_color: Color = status.get_theme_color("font_color")
	assert_eq(folded_color, Color("d6d0be"))
	assert_gte(_color_difference(folded_color, Color("075c35")), 1.0)


func test_startup_form_collapses_empty_errors_and_uses_visible_input_controls() -> void:
	var main := MainScene.instantiate()
	add_child_autofree(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame

	var form := main.get_node("%Form") as VBoxContainer
	var fields := main.get_node("%Fields") as GridContainer
	var panel := main.get_node("Center/Panel") as PanelContainer
	assert_true(Rect2(Vector2.ZERO, main.size).encloses(panel.get_rect()))
	assert_eq(form.get_theme_constant("separation"), 18)
	assert_eq(fields.columns, 2)
	assert_eq(main.get_node("%Title").get_parent(), form)
	assert_eq(main.get_node("%Description").get_parent(), form)
	assert_eq(main.get_node("%Actions").get_parent(), form)
	assert_true(is_equal_approx(panel.custom_minimum_size.x, 883.2))
	assert_eq(main.get_node("%Title").get_theme_font_size("font_size"), 64)
	for error_path: NodePath in [
		^"%PlayerCountError",
		^"%StartingStackError",
		^"%SmallBlindError",
		^"%BigBlindError",
	]:
		assert_false((main.get_node(error_path) as Label).visible, str(error_path))
	for input_path: NodePath in [
		^"%PlayerCountInput",
		^"%StartingStackInput",
		^"%SmallBlindInput",
		^"%BigBlindInput",
	]:
		var input := main.get_node(input_path) as LineEdit
		assert_gte(input.get_theme_stylebox("normal").border_width_left, 2, str(input_path))
	var use_legacy_models := main.get_node("%UseLegacyModelsCheckBox") as CheckBox
	assert_eq(use_legacy_models.text, "Use legacy heuristic models")
	assert_false(use_legacy_models.button_pressed)
	assert_not_null(use_legacy_models.get_theme_icon("unchecked"))


func test_startup_actions_are_grouped_and_have_distinct_button_states() -> void:
	var main := MainScene.instantiate()
	add_child_autofree(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame

	var actions := main.get_node("%Actions") as HBoxContainer
	var start_button := main.get_node("%StartButton") as Button
	var quit_button := main.get_node("%QuitApplicationButton") as Button
	assert_eq(start_button.get_parent(), actions)
	assert_eq(quit_button.get_parent(), actions)
	assert_false(start_button.get_rect().intersects(quit_button.get_rect()))
	var action_bounds := Rect2(Vector2.ZERO, actions.size)
	assert_true(action_bounds.encloses(Rect2(start_button.position, start_button.size)))
	assert_true(action_bounds.encloses(Rect2(quit_button.position, quit_button.size)))
	assert_true(start_button.position.x < quit_button.position.x)
	assert_true(is_equal_approx(start_button.position.y, quit_button.position.y))

	for button: Button in [start_button, quit_button]:
		var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
		var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
		var pressed := button.get_theme_stylebox("pressed") as StyleBoxFlat
		var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
		assert_not_null(normal, button.name + " needs an explicit normal button style")
		assert_not_null(hover, button.name + " needs an explicit hover button style")
		assert_not_null(pressed, button.name + " needs an explicit pressed button style")
		assert_not_null(focus, button.name + " needs an explicit focus button style")
		for style: StyleBoxFlat in [normal, hover, pressed, focus]:
			assert_gte(style.border_width_left, 2, button.name)
			assert_gte(style.border_width_top, 2, button.name)
			assert_gte(style.border_width_right, 2, button.name)
			assert_gte(style.border_width_bottom, 2, button.name)
			assert_gte(
				_color_difference(style.bg_color, style.border_color),
				0.15,
				button.name + " needs visible border contrast",
			)
		assert_ne(_style_signature(normal), _style_signature(hover), button.name)
		assert_ne(_style_signature(hover), _style_signature(pressed), button.name)
		assert_ne(_style_signature(normal), _style_signature(focus), button.name)


func _style_signature(style: StyleBoxFlat) -> String:
	return (
		"%s|%s|%d|%d|%d|%d"
		% [
			style.bg_color.to_html(true),
			style.border_color.to_html(true),
			style.border_width_left,
			style.border_width_top,
			style.border_width_right,
			style.border_width_bottom,
		]
	)


func _color_difference(first: Color, second: Color) -> float:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)


func _hero_table_view(player_count: int) -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	view._hero_hole_cards = [
		CardData.new(14, CardData.Suit.HEARTS), CardData.new(10, CardData.Suit.CLUBS)
	]
	for seat: int in range(player_count):
		var agent: Agent = (
			HumanAgent.new() if seat == 0 else RandomAgent.new(RandomNumberGenerator.new())
		)
		var player := Player.new(&"display_%d" % seat, "Player %d" % (seat + 1), seat, 100, agent)
		view._seats.append(PlayerView.new(player))
	return view


func _avatar_assignments(player_count: int) -> Dictionary[int, String]:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = paths[seat]
	return assignments


func _surface_size(table: PokerTableController) -> Vector2:
	return table.get_node("TableMargin/Felt/TableSurface").size
