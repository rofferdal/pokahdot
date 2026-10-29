extends "res://tests/support/poker_gut_test.gd"

const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")


func test_high_resolution_mobile_portrait_uses_the_available_table_surface() -> void:
	var table = PokerTableScene.instantiate()
	table.hide()
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1080, 2340)
	table.bind_view(_hero_table_view(6), _avatar_assignments(6))
	table.show()
	await get_tree().process_frame
	await get_tree().process_frame

	var surface_size := _surface_size(table)
	var opponent_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1")
	var opponent_avatar: TextureRect = opponent_panel.find_child("Avatar", true, false)
	var opponent_avatar_region: Control = opponent_panel.find_child("AvatarRegion", true, false)
	var opponent_name: Label = opponent_panel.find_child("Name", true, false)
	var board_card: PanelContainer = table.get_node("%CardSlots/CardSlot1")
	var action_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/ActionPanel")
	var event_log: RichTextLabel = table.get_node("%EventLog")
	var hero_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0")

	assert_gte(opponent_panel.size.x, surface_size.x * 0.3)
	assert_gte(opponent_avatar_region.custom_minimum_size.x, 100.0)
	assert_eq(opponent_name.get_theme_font_size("font_size"), 22)
	assert_gte(board_card.custom_minimum_size.x, 55.0)
	assert_gte(action_panel.size.y, 260.0)
	assert_gte(event_log.size.y, 110.0)
	assert_true(
		action_panel.get_global_rect().encloses(table.get_node("%FoldButton").get_global_rect())
	)
	assert_false(action_panel.get_global_rect().intersects(hero_panel.get_global_rect()))
	assert_false(event_log.get_global_rect().intersects(action_panel.get_global_rect()))
	for seat: int in range(6):
		var seat_panel: PanelContainer = table.get_node(
			"TableMargin/Felt/TableSurface/Seats/Seat%d" % seat
		)
		assert_false(action_panel.get_global_rect().intersects(seat_panel.get_global_rect()))
		assert_false(event_log.get_global_rect().intersects(seat_panel.get_global_rect()))

	table.size = Vector2(2340, 1080)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(opponent_avatar_region.custom_minimum_size, Vector2(112, 112))
	assert_eq(opponent_avatar.custom_minimum_size, Vector2.ZERO)
	assert_eq(opponent_name.get_theme_font_size("font_size"), 22)
	assert_eq(board_card.custom_minimum_size, Vector2(68, 76))


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
