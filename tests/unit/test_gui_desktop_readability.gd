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
	var opponent_action: Label = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action")
	assert_eq(opponent_action.get_theme_font_size("font_size"), 30)


func test_desktop_action_and_quit_fonts_match_community_cards_without_resizing_board() -> void:
	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1920, 1080)
	table.bind_view(_hero_table_view(2), _avatar_assignments(2))
	await get_tree().process_frame
	await get_tree().process_frame

	var community_zone: PanelContainer = table.get_node(
		"TableMargin/Felt/TableSurface/CenterZone/BoardZone"
	)
	var community_label: Label = table.get_node("%BoardLabel")
	var community_font_size: int = community_label.get_theme_font_size("font_size")
	assert_eq(community_font_size, 32)
	assert_eq(community_zone.size, Vector2(520, 147))

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


func test_startup_form_collapses_empty_errors_and_uses_visible_input_controls() -> void:
	var main := MainScene.instantiate()
	add_child_autofree(main)
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame

	var form := main.get_node("Center/Panel/Margin/Form") as VBoxContainer
	var panel := main.get_node("Center/Panel") as PanelContainer
	assert_true(Rect2(Vector2.ZERO, main.size).encloses(panel.get_rect()))
	assert_eq(form.get_theme_constant("separation"), 6)
	for error_path: NodePath in [
		^"Center/Panel/Margin/Form/PlayerCountError",
		^"Center/Panel/Margin/Form/StartingStackError",
		^"Center/Panel/Margin/Form/SmallBlindError",
		^"Center/Panel/Margin/Form/BigBlindError",
	]:
		assert_false((main.get_node(error_path) as Label).visible, str(error_path))
	for input_path: NodePath in [
		^"Center/Panel/Margin/Form/PlayerCountInput",
		^"Center/Panel/Margin/Form/StartingStackInput",
		^"Center/Panel/Margin/Form/SmallBlindInput",
		^"Center/Panel/Margin/Form/BigBlindInput",
	]:
		var input := main.get_node(input_path) as LineEdit
		assert_gte(input.get_theme_stylebox("normal").border_width_left, 2, str(input_path))
	assert_not_null(
		(
			(main.get_node("Center/Panel/Margin/Form/AllowExperimentalModelsCheckBox") as CheckBox)
			. get_theme_icon("unchecked")
		)
	)


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
