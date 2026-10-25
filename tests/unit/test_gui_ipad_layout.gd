extends "res://tests/support/poker_gut_test.gd"

const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")

const IPAD_CHROME_LANDSCAPE_VIEWPORT := Vector2(1194, 696)
const IPAD_LANDSCAPE_VIEWPORT := Vector2(1024, 768)
const IPAD_PORTRAIT_VIEWPORT := Vector2(768, 1024)
const IPAD_OBSERVED_BACKING_VIEWPORT := Vector2(2388, 1450)
const CENTER_TOLERANCE: float = 1.0


func test_ipad_chrome_logical_viewport_selects_tablet_profile() -> void:
	assert_eq(
		GuiLayoutProfileScript.classify(IPAD_CHROME_LANDSCAPE_VIEWPORT),
		GuiLayoutProfileScript.Kind.TABLET,
	)


func test_ipad_board_is_centered_and_bot_seats_form_a_symmetric_arc() -> void:
	for viewport: Vector2 in [
		IPAD_CHROME_LANDSCAPE_VIEWPORT,
		IPAD_LANDSCAPE_VIEWPORT,
		IPAD_PORTRAIT_VIEWPORT,
		IPAD_OBSERVED_BACKING_VIEWPORT,
	]:
		for player_count: int in [2, 4, 6, 7, 9]:
			var table := _table_for(viewport, player_count)
			await _settle_layout()
			var surface := _surface(table)
			var regions := table.get_resolved_region_rects()
			var context := "%d players at %s" % [player_count, viewport]
			assert_almost_eq(
				regions[&"center"].get_center().x,
				surface.size.x * 0.5,
				CENTER_TOLERANCE,
				context + " center x",
			)
			assert_almost_eq(
				regions[&"center"].get_center().y,
				surface.size.y * 0.5,
				CENTER_TOLERANCE,
				context + " center y",
			)
			assert_almost_eq(
				regions[&"hero"].get_center().x,
				surface.size.x * 0.5,
				CENTER_TOLERANCE,
				context + " hero x",
			)
			_assert_bot_arc(regions, surface.size, player_count, context)


func test_compact_ipad_regions_are_owned_and_non_overlapping() -> void:
	for viewport: Vector2 in [IPAD_CHROME_LANDSCAPE_VIEWPORT, IPAD_PORTRAIT_VIEWPORT]:
		var table := _table_for(viewport, 6)
		await _settle_layout()
		var regions := table.get_resolved_region_rects()
		var surface_rect := Rect2(Vector2.ZERO, _surface(table).size)
		var context := "at %s" % viewport
		for region_name: StringName in [&"center", &"hero", &"event", &"action"]:
			assert_true(
				surface_rect.encloses(regions[region_name]), "%s %s" % [region_name, context]
			)
		assert_false(regions[&"center"].intersects(regions[&"event"]), "event " + context)
		assert_false(regions[&"center"].intersects(regions[&"action"]), "action " + context)
		assert_almost_eq(regions[&"event"].size.x, regions[&"action"].size.x, 0.01)
		assert_almost_eq(regions[&"event"].size.y, regions[&"action"].size.y, 0.01)
		assert_almost_eq(regions[&"event"].position.y, regions[&"action"].position.y, 0.01)
		for seat: int in range(6):
			var seat_rect: Rect2 = regions[StringName("seat_%d" % seat)]
			var status_rect: Rect2 = regions[StringName("status_%d" % seat)]
			assert_true(surface_rect.encloses(seat_rect), "seat %d" % seat)
			assert_true(surface_rect.encloses(status_rect), "status %d" % seat)
			assert_false(
				seat_rect.intersects(regions[&"center"]), "seat %d center %s" % [seat, context]
			)
			assert_false(
				status_rect.intersects(regions[&"center"]), "status %d center %s" % [seat, context]
			)
			if seat == 0:
				continue
			assert_false(seat_rect.intersects(regions[&"event"]), "seat %d event" % seat)
			assert_false(seat_rect.intersects(regions[&"action"]), "seat %d action" % seat)


func test_compact_ipad_position_markers_do_not_cover_avatars() -> void:
	var table := _table_for(IPAD_CHROME_LANDSCAPE_VIEWPORT, 6)
	await _settle_layout()
	for seat: int in range(6):
		var panel := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat)
		var avatar := panel.find_child("AvatarRegion", true, false) as Control
		var marker := panel.find_child("Marker", true, false) as Label
		assert_not_null(avatar, "seat %d avatar" % seat)
		assert_not_null(marker, "seat %d marker" % seat)
		assert_eq(marker.get_parent().name, &"Header", "seat %d marker owner" % seat)
		assert_false(
			marker.get_global_rect().intersects(avatar.get_global_rect()),
			"seat %d marker must not cover its avatar" % seat,
		)


func _assert_bot_arc(
	regions: Dictionary[StringName, Rect2],
	surface_size: Vector2,
	player_count: int,
	context: String,
) -> void:
	var pair_count: int = (player_count - 1) / 2
	var previous_y: float = INF
	for seat: int in range(1, pair_count + 1):
		var mirrored_seat: int = player_count - seat
		var left_center: Vector2 = regions[StringName("seat_%d" % seat)].get_center()
		var right_center: Vector2 = regions[StringName("seat_%d" % mirrored_seat)].get_center()
		assert_almost_eq(
			left_center.x + right_center.x,
			surface_size.x,
			CENTER_TOLERANCE,
			context + " mirrored x for seats %d/%d" % [seat, mirrored_seat],
		)
		assert_almost_eq(
			left_center.y,
			right_center.y,
			CENTER_TOLERANCE,
			context + " mirrored y for seats %d/%d" % [seat, mirrored_seat],
		)
		assert_lte(
			left_center.y,
			previous_y + CENTER_TOLERANCE,
			context + " arc must rise toward its upper center",
		)
		previous_y = left_center.y
	if player_count % 2 == 0:
		var apex_seat: int = player_count / 2
		var apex_center: Vector2 = regions[StringName("seat_%d" % apex_seat)].get_center()
		assert_almost_eq(
			apex_center.x,
			surface_size.x * 0.5,
			CENTER_TOLERANCE,
			context + " apex x",
		)
		assert_lt(apex_center.y, previous_y, context + " apex must be highest")


func _table_for(viewport: Vector2, player_count: int) -> PokerTableController:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = viewport
	table.set_layout_profile_override(GuiLayoutProfileScript.Kind.TABLET)
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
	view.button_seat = player_count - 1
	view.small_blind_seat = 0
	view.big_blind_seat = 1 % player_count
	view.big_blind = 10
	view.small_blind = 5
	view.minimum_wager_total = 20
	view.maximum_wager_total = 100
	view.acting_seat = 0
	for seat: int in range(player_count):
		var agent: Agent = (
			HumanAgent.new() if seat == 0 else RandomAgent.new(RandomNumberGenerator.new())
		)
		var player := Player.new(&"ipad_%d" % seat, "Player %d" % (seat + 1), seat, 100, agent)
		view._seats.append(PlayerView.new(player))
	view._action_history = [
		PublicActionRecord.blind(0, 5, true),
		PublicActionRecord.blind(1 % player_count, 10, false),
	]
	return view


func _avatar_assignments(player_count: int) -> Dictionary[int, String]:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = paths[seat]
	return assignments
