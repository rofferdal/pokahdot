extends "res://tests/support/poker_gut_test.gd"

const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")

const DESKTOP_VIEWPORT := Vector2(1920, 1080)
const MIN_WIDENED_SEAT_WIDTH: float = 416.0


func test_desktop_seats_are_widened_and_non_overlapping_for_two_to_nine_players() -> void:
	for player_count: int in range(2, 10):
		var table := _table_for(player_count)
		await _settle_layout()
		var surface_rect := Rect2(Vector2.ZERO, _surface(table).size)
		var seat_rects: Array[Rect2] = []
		for seat: int in range(player_count):
			var panel := (
				table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat)
				as PanelContainer
			)
			var seat_rect := panel.get_rect()
			var context := "%d-player desktop seat %d" % [player_count, seat]
			assert_gte(
				panel.size.x, MIN_WIDENED_SEAT_WIDTH, context + " must include avatar clearance"
			)
			assert_true(surface_rect.encloses(seat_rect), context + " must remain in bounds")
			for previous_rect: Rect2 in seat_rects:
				assert_false(
					seat_rect.intersects(previous_rect), context + " overlaps another seat"
				)
			seat_rects.append(seat_rect)


func test_six_player_lowest_bot_action_label_is_visible_above_action_panel() -> void:
	var table := _table_for(6)
	await _settle_layout()
	var action_label := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat5Action") as Label
	assert_eq(action_label.text, "Big blind 10")
	assert_true(action_label.visible)
	var action_label_rect := action_label.get_global_rect()
	var action_panel := table.get_node("TableMargin/Felt/TableSurface/ActionPanel") as Control
	var event_log := table.get_node("%EventLog") as Control
	assert_false(
		action_label_rect.intersects(action_panel.get_global_rect()),
		"Player 6 latest action must not be covered by the action area",
	)
	assert_false(
		action_label_rect.intersects(event_log.get_global_rect()),
		"Player 6 latest action must not be covered by the event log",
	)
	assert_true(
		action_label_rect.end.y <= action_panel.get_global_rect().position.y,
		"Player 6 latest action must remain above the action area",
	)


func test_event_log_and_action_panel_have_equal_size_and_symmetric_desktop_placement() -> void:
	for player_count: int in range(2, 10):
		var table := _table_for(player_count)
		await _settle_layout()
		var surface := _surface(table)
		var hero := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0") as Control
		var action_panel := table.get_node("TableMargin/Felt/TableSurface/ActionPanel") as Control
		var event_log := table.get_node("%EventLog") as Control
		var context := "%d-player desktop side panels" % player_count
		assert_almost_eq(action_panel.size.x, event_log.size.x, 0.01, context + " width")
		assert_almost_eq(action_panel.size.y, event_log.size.y, 0.01, context + " height")
		assert_almost_eq(
			action_panel.get_global_rect().position.y,
			event_log.get_global_rect().position.y,
			0.01,
			context + " vertical alignment",
		)
		assert_lt(event_log.get_global_rect().end.x, hero.get_global_rect().position.x, context)
		assert_gt(action_panel.get_global_rect().position.x, hero.get_global_rect().end.x, context)
		var left_gap := hero.get_global_rect().position.x - event_log.get_global_rect().end.x
		var right_gap := action_panel.get_global_rect().position.x - hero.get_global_rect().end.x
		assert_almost_eq(left_gap, right_gap, 0.01, context + " horizontal symmetry")
		assert_true(
			Rect2(Vector2.ZERO, surface.size).encloses(event_log.get_rect()),
			context + " event log must remain in the felt",
		)
		assert_true(
			Rect2(Vector2.ZERO, surface.size).encloses(action_panel.get_rect()),
			context + " action panel must remain in the felt",
		)


func test_desktop_player_facing_nodes_use_source_font_without_post_render_scaling() -> void:
	var table := _table_for(6)
	await _settle_layout()
	assert_not_null(table.theme.default_font, "desktop table must configure a source font face")
	for node: Node in table.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.visible:
			continue
		assert_eq(
			control.scale,
			Vector2.ONE,
			"%s must not post-scale desktop artwork" % control.get_path()
		)
	for seat: int in range(6):
		var panel := (
			table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as PanelContainer
		)
		var frame := panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert_not_null(frame, "seat %d must have a source border style" % seat)
		assert_eq(frame.border_width_left, frame.border_width_right, "seat %d border width" % seat)
		assert_eq(frame.border_width_top, frame.border_width_bottom, "seat %d border width" % seat)
		assert_gte(frame.border_width_left, 1, "seat %d border must remain visible" % seat)


func _table_for(player_count: int) -> PokerTableController:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = DESKTOP_VIEWPORT
	add_child_autofree(table)
	table.bind_view(_view(player_count), _avatar_assignments(player_count))
	table.show()
	return table


func _settle_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _surface(table: PokerTableController) -> Control:
	return table.get_node("TableMargin/Felt/TableSurface") as Control


func _view(player_count: int) -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	view.button_seat = 0
	view.small_blind_seat = 1 % player_count
	view.big_blind_seat = player_count - 1
	view.big_blind = 10
	view.small_blind = 5
	view.acting_seat = 0
	for seat: int in range(player_count):
		var agent: Agent = (
			HumanAgent.new() if seat == 0 else RandomAgent.new(RandomNumberGenerator.new())
		)
		var player := Player.new(&"followup_%d" % seat, "Player %d" % (seat + 1), seat, 100, agent)
		view._seats.append(PlayerView.new(player))
	view._action_history = [PublicActionRecord.blind(1 % player_count, 5, true)]
	view._action_history.append(PublicActionRecord.blind(player_count - 1, 10, false))
	return view


func _avatar_assignments(player_count: int) -> Dictionary[int, String]:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = paths[seat]
	return assignments
