extends "res://tests/support/poker_gut_test.gd"

const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")

const DESKTOP_VIEWPORT := Vector2(1920, 1080)
# Diagnostic coverage only: this is the supplied screenshot raster, not a
# measured CSS viewport. Keep the evidence task open until browser metrics exist.
const OBSERVED_DESKTOP_RASTER := Vector2(1853, 916)
const IPAD_LANDSCAPE_VIEWPORT := Vector2(2388, 1450)
const SMALL_DESKTOP_VIEWPORT := Vector2(950, 532)
const MIN_WIDENED_SEAT_WIDTH: float = 416.0


func test_observed_desktop_raster_keeps_quit_clear_of_human_identity() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = OBSERVED_DESKTOP_RASTER
	add_child_autofree(table)
	table.bind_view(_view(6), _avatar_assignments(6), {0: "Human"})
	table.show()
	await _settle_layout()

	var quit_rect := (table.get_node("%QuitButton") as Button).get_global_rect()
	var hero := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0") as PanelContainer
	var hero_status := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Status") as Label
	assert_false(
		quit_rect.intersects(hero.get_global_rect()),
		(
			"Quit %s must clear human panel %s and center %s"
			% [quit_rect, hero.get_global_rect(), table.get_resolved_region_rects()[&"center"]]
		),
	)
	assert_false(
		quit_rect.intersects(hero_status.get_global_rect()), "Quit must clear human status"
	)
	for child_name: String in ["Name", "Stack", "Marker", "HeroCards"]:
		var child := hero.find_child(child_name, true, false) as Control
		assert_not_null(child, "Human %s must exist" % child_name)
		assert_false(
			quit_rect.intersects(child.get_global_rect()),
			"Quit %s must clear human %s %s" % [quit_rect, child_name, child.get_global_rect()],
		)


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
					seat_rect.intersects(previous_rect),
					(
						context
						+ " overlaps another seat: "
						+ str(seat_rect)
						+ " / "
						+ str(previous_rect)
					),
				)
			seat_rects.append(seat_rect)


func test_six_player_lowest_bot_status_band_is_visible_above_action_panel() -> void:
	var table := _table_for(6)
	await _settle_layout()
	var action_label := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat5Status") as Label
	assert_eq(action_label.text, "Big blind 10")
	assert_true(action_label.visible)
	var action_label_rect := action_label.get_global_rect()
	var action_panel := table.get_node("TableMargin/Felt/TableSurface/ActionPanel") as Control
	var event_log := table.get_node("%EventLog") as Control
	assert_false(
		action_label_rect.intersects(action_panel.get_global_rect()),
		"Player 6 status must not be covered by the action area",
	)
	assert_false(
		action_label_rect.intersects(event_log.get_global_rect()),
		"Player 6 status must not be covered by the event log",
	)
	assert_true(
		action_label_rect.end.y <= action_panel.get_global_rect().position.y,
		"Player 6 status must remain above the action area",
	)


func test_pot_and_wager_status_fields_remain_visible_after_layout() -> void:
	for viewport: Vector2 in [DESKTOP_VIEWPORT, SMALL_DESKTOP_VIEWPORT, IPAD_LANDSCAPE_VIEWPORT]:
		var table := PokerTableScene.instantiate() as PokerTableController
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = viewport
		add_child_autofree(table)
		table.bind_view(_view(6), _avatar_assignments(6))
		await _settle_layout()
		var pot_label := table.get_node("%PotLabel") as Label
		var wager_label := table.get_node("%WagerLabel") as Label
		assert_string_contains(pot_label.text, "Pot:")
		assert_string_contains(pot_label.text, "SB")
		assert_string_contains(pot_label.text, "BB")
		assert_string_contains(pot_label.text, "L")
		assert_false("layers" in pot_label.text)
		assert_false("/" in pot_label.text)
		assert_string_contains(wager_label.text, "Wagers")
		for label: Label in [pot_label, wager_label]:
			var label_rect: Rect2 = label.get_global_rect()
			var zone := label.get_parent() as Control
			var context := "%s at %s" % [label.name, viewport]
			assert_true(label.is_visible_in_tree(), context)
			assert_true(label.clip_text, context + " must stay inside the central footprint")
			assert_gt(label.get_theme_color("font_color").a, 0.0, context)
			assert_true(zone.get_global_rect().encloses(label_rect), context)
			# PanelContainer styling reserves an inner margin, but clipped text must
			# still receive almost all usable panel width rather than a zero-width box.
			assert_gte(label_rect.size.x, zone.get_global_rect().size.x * 0.9, context)
			assert_gte(label_rect.size.y, float(label.get_theme_font_size("font_size")), context)


func test_seven_player_ipad_landscape_reserves_action_and_showdown_clearance() -> void:
	var view: GameView = _view(7)
	view._action_history = [
		PublicActionRecord.new(1, PlayerAction.Kind.FOLD, 0),
		PublicActionRecord.new(6, PlayerAction.Kind.CALL, 44),
	]
	view._showdown_results = {
		3: _showdown_result(3, HandRank.Category.ONE_PAIR, [14, 13, 12, 9]),
		4: _showdown_result(4, HandRank.Category.FULL_HOUSE, [13, 10]),
	}
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = IPAD_LANDSCAPE_VIEWPORT
	add_child_autofree(table)
	table.bind_view(view, _avatar_assignments(7))
	await _settle_layout()

	var surface_rect := Rect2(Vector2.ZERO, _surface(table).size)
	var event_rect := (table.get_node("%EventLog") as Control).get_global_rect()
	var action_rect := (
		(table.get_node("TableMargin/Felt/TableSurface/ActionPanel") as Control).get_global_rect()
	)
	for seat: int in [1, 6]:
		var panel := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as Control
		var label := (
			table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%dStatus" % seat) as Label
		)
		assert_true(label.visible)
		assert_true(surface_rect.encloses(Rect2(panel.position, panel.size)))
		assert_false(panel.get_global_rect().intersects(event_rect))
		assert_false(panel.get_global_rect().intersects(action_rect))
		assert_gte(
			label.get_global_rect().position.y,
			panel.get_global_rect().end.y,
			"Player %d action must be below its seat" % (seat + 1),
		)
		assert_false(label.get_global_rect().intersects(event_rect))
		assert_false(label.get_global_rect().intersects(action_rect))

	for seat: int in [3, 4]:
		var panel := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as Control
		var label := (
			table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%dStatus" % seat) as Label
		)
		assert_true(label.visible)
		assert_gte(
			label.get_global_rect().position.y,
			panel.get_global_rect().end.y,
			"Player %d showdown result must be below its seat" % (seat + 1),
		)
		assert_true(surface_rect.encloses(Rect2(panel.position, panel.size)))
		assert_true(surface_rect.encloses(Rect2(label.position, label.size)))


func test_seven_player_ipad_details_remain_visible_with_or_without_latest_actions() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = IPAD_LANDSCAPE_VIEWPORT
	add_child_autofree(table)
	var without_actions := _view(7)
	without_actions._action_history.clear()
	table.bind_view(without_actions, _avatar_assignments(7))
	await _settle_layout()
	var player_one_rect: Rect2 = table.get_seat_rects()[0]
	var empty_action_rect: Rect2 = table.get_resolved_region_rects()[&"status_1"]
	assert_gt(empty_action_rect.size.y, 0.0)
	assert_gt(table.get_resolved_region_rects()[&"status_6"].size.y, 0.0)

	var with_actions := _view(7)
	with_actions._action_history = [
		PublicActionRecord.new(1, PlayerAction.Kind.CALL, 44),
		PublicActionRecord.new(6, PlayerAction.Kind.RAISE, 88),
	]
	table.bind_view(with_actions, _avatar_assignments(7))
	await _settle_layout()
	var regions := table.get_resolved_region_rects()
	var surface_rect := Rect2(Vector2.ZERO, _surface(table).size)
	for seat: int in [1, 6]:
		var seat_rect: Rect2 = regions[StringName("seat_%d" % seat)]
		var action_rect: Rect2 = regions[StringName("status_%d" % seat)]
		assert_true(surface_rect.encloses(seat_rect))
		assert_true(surface_rect.encloses(action_rect))
		assert_gte(action_rect.position.y, seat_rect.end.y)
		assert_false(action_rect.intersects(regions[&"event"]))
		assert_false(action_rect.intersects(regions[&"action"]))
	assert_eq(player_one_rect, table.get_seat_rects()[0])

	var player_two_action := (
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label
	)
	player_two_action.text = "Raise to 999999 • long status text remains in its reserved line"
	table._queue_layout()
	await _settle_layout()
	assert_true(surface_rect.encloses(player_two_action.get_global_rect()))
	assert_false(player_two_action.get_global_rect().intersects(regions[&"event"]))
	assert_eq(player_one_rect, table.get_seat_rects()[0])


func test_seven_player_ipad_showdown_summaries_have_dedicated_clearance() -> void:
	var view := _view(7)
	view._showdown_results = {
		3: _showdown_result(3, HandRank.Category.ONE_PAIR, [14, 13, 12, 9]),
		4: _showdown_result(4, HandRank.Category.FULL_HOUSE, [13, 10]),
	}
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = IPAD_LANDSCAPE_VIEWPORT
	add_child_autofree(table)
	table.bind_view(view, _avatar_assignments(7))
	await _settle_layout()
	var surface_rect := Rect2(Vector2.ZERO, _surface(table).size)
	var regions := table.get_resolved_region_rects()
	for seat: int in [3, 4]:
		var panel_rect: Rect2 = regions[StringName("seat_%d" % seat)]
		var summary_rect: Rect2 = regions[StringName("status_%d" % seat)]
		assert_true(surface_rect.encloses(summary_rect))
		assert_gte(summary_rect.position.y, panel_rect.end.y)
		assert_false(summary_rect.intersects(regions[&"center"]))
		assert_false(summary_rect.intersects(regions[&"event"]))
		assert_false(summary_rect.intersects(regions[&"action"]))
	var player_one_rect: Rect2 = regions[&"seat_0"]
	table._queue_layout()
	await _settle_layout()
	assert_eq(player_one_rect, table.get_seat_rects()[0])


func test_seven_player_ipad_central_zone_has_stable_bounded_equal_widths() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = IPAD_LANDSCAPE_VIEWPORT
	add_child_autofree(table)
	table.bind_view(_view(7), _avatar_assignments(7))
	await _settle_layout()
	for status_text: String in [
		"POT 15\nSB 5 BB 10 • L1 0/12",
		"POT 999999 • 4 layers\nSB 123456 BB 246912 • L12 99/120",
	]:
		(table.get_node("%PotLabel") as Label).text = status_text
		table._queue_layout()
		await _settle_layout()
		var regions := table.get_resolved_region_rects()
		assert_lte(regions[&"center"].size.x, 520.0)
		assert_almost_eq(regions[&"board"].size.x, regions[&"pot"].size.x, 0.01)
		assert_almost_eq(regions[&"pot"].size.x, regions[&"wager"].size.x, 0.01)
		assert_false(regions[&"center"].intersects(regions[&"event"]))
		assert_false(regions[&"center"].intersects(regions[&"action"]))
		for seat: int in range(7):
			assert_false(regions[StringName("seat_%d" % seat)].intersects(regions[&"center"]))


func test_reported_desktop_center_width_is_stable_after_repeated_refreshes() -> void:
	for viewport: Vector2 in [Vector2(950, 532), Vector2(1024, 600), DESKTOP_VIEWPORT]:
		var table := PokerTableScene.instantiate() as PokerTableController
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = viewport
		add_child_autofree(table)
		table.bind_view(_view(6), _avatar_assignments(6))
		await _settle_layout()
		var initial := table.get_resolved_region_rects()
		assert_almost_eq(
			initial[&"center"].get_center().x,
			_surface(table).size.x * 0.5,
			0.01,
			"initial center midpoint at %s" % viewport,
		)
		for status_text: String in [
			"Pot: 15 | SB 5 BB 10 | L1",
			"Pot: 999999999 | SB 123456 BB 246912 | L12 with long progress text",
		]:
			(table.get_node("%PotLabel") as Label).text = status_text
			var long_wager_status := "Wagers • 999999 active players with a long status"
			(table.get_node("%WagerLabel") as Label).text = long_wager_status
			for refresh: int in range(3):
				table._queue_layout()
				await _settle_layout()
			var regions := table.get_resolved_region_rects()
			assert_almost_eq(regions[&"center"].size.x, initial[&"center"].size.x, 0.01)
			assert_almost_eq(regions[&"board"].size.x, regions[&"pot"].size.x, 0.01)
			assert_almost_eq(regions[&"pot"].size.x, regions[&"wager"].size.x, 0.01)
			assert_almost_eq(
				regions[&"center"].get_center().x,
				_surface(table).size.x * 0.5,
				0.01,
				"settled center midpoint at %s" % viewport,
			)
			assert_true(Rect2(Vector2.ZERO, _surface(table).size).encloses(regions[&"center"]))
			assert_false(regions[&"center"].intersects(regions[&"event"]))
			assert_false(regions[&"center"].intersects(regions[&"action"]))


func test_center_stack_has_one_owner_and_ignores_late_child_minimum_width() -> void:
	for viewport: Vector2 in [Vector2(950, 532), DESKTOP_VIEWPORT, IPAD_LANDSCAPE_VIEWPORT]:
		var table := PokerTableScene.instantiate() as PokerTableController
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = viewport
		add_child_autofree(table)
		table.bind_view(_view(7), _avatar_assignments(7))
		await _settle_layout()
		var center := table.get_node("TableMargin/Felt/TableSurface/CenterZone") as Control
		assert_false(center is Container, "the manually sized center must not be a Container")
		var initial := table.get_resolved_region_rects()
		(table.get_node("%BoardLabel") as Label).custom_minimum_size.x = (
			initial[&"center"].size.x * 2.0
		)
		(table.get_node("%PotLabel") as Label).text = "Pot status " + "1234567890 ".repeat(20)
		(table.get_node("%WagerLabel") as Label).text = "Wager status " + "active ".repeat(20)
		for frame: int in range(4):
			await get_tree().process_frame
			var regions := table.get_resolved_region_rects()
			assert_almost_eq(
				regions[&"center"].size.x,
				initial[&"center"].size.x,
				0.01,
				"center width frame %d at %s" % [frame, viewport],
			)
			assert_almost_eq(regions[&"board"].size.x, regions[&"center"].size.x, 0.01)
			assert_almost_eq(regions[&"pot"].size.x, regions[&"center"].size.x, 0.01)
			assert_almost_eq(regions[&"wager"].size.x, regions[&"center"].size.x, 0.01)
			assert_almost_eq(
				regions[&"center"].get_center().x,
				_surface(table).size.x * 0.5,
				0.01,
				"center midpoint frame %d at %s" % [frame, viewport],
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
	# Compact previews also align both edges with the hero and clear curved felt.
	for viewport: Vector2 in [Vector2(1280, 720), Vector2(1369, 724), Vector2(1440, 900)]:
		var table := PokerTableScene.instantiate() as PokerTableController
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = viewport
		add_child_autofree(table)
		table.bind_view(_view(6), _avatar_assignments(6))
		await _settle_layout()
		var regions := table.get_resolved_region_rects()
		for role: StringName in [&"event", &"action"]:
			assert_almost_eq(regions[role].position.y, regions[&"hero"].position.y, 0.01)
			assert_almost_eq(regions[role].end.y, regions[&"hero"].end.y, 0.01)
		var felt := table.get_node("TableMargin/Felt") as Panel
		var style := felt.get_theme_stylebox("panel") as StyleBoxFlat
		for seat: int in [2, 4]:
			var upper: Rect2 = regions[StringName("seat_%d" % seat)].merge(
				regions[StringName("status_%d" % seat)]
			)
			assert_gte(
				upper.position.y + _surface(table).position.y,
				float(style.corner_radius_top_left) + 8.0,
				"complete upper seat must clear the felt's curved border at %s" % viewport
			)
		var event_log := table.get_node("%EventLog") as RichTextLabel
		assert_eq(event_log.get_theme_font_size("normal_font_size"), 18)
		assert_gte((table.get_node("%BoardLabel") as Label).get_theme_font_size("font_size"), 20)
		# The smaller log font must fit more history in the same reserved panel.
		event_log.text = "Public action\n".repeat(20)
		await _settle_layout()
		var compact_height: int = event_log.get_content_height()
		event_log.add_theme_font_size_override("normal_font_size", 20)
		await _settle_layout()
		assert_gt(event_log.get_content_height(), compact_height)


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


func test_desktop_regions_are_reserved_and_cannot_cover_the_center_or_side_panels() -> void:
	for player_count: int in [2, 6]:
		var table := _table_for(player_count)
		await _settle_layout()
		var surface := _surface(table)
		var surface_rect := Rect2(Vector2.ZERO, surface.size)
		var regions := table.get_resolved_region_rects()
		for region_name: StringName in [
			&"center", &"board", &"pot", &"wager", &"action", &"event", &"hero"
		]:
			assert_true(
				surface_rect.encloses(regions[region_name]),
				(
					"%d-player %s region must remain in the table surface"
					% [player_count, region_name]
				),
			)
		assert_false(regions[&"center"].intersects(regions[&"action"]))
		assert_false(regions[&"center"].intersects(regions[&"event"]))
		assert_almost_eq(
			regions[&"action"].end.y,
			regions[&"hero"].end.y,
			0.01,
			"action panel must share the human seat bottom edge",
		)
		assert_almost_eq(
			regions[&"event"].end.y,
			regions[&"hero"].end.y,
			0.01,
			"event feed must share the human seat bottom edge",
		)
		for seat: int in range(player_count):
			var seat_rect: Rect2 = regions[StringName("seat_%d" % seat)]
			assert_true(surface_rect.encloses(seat_rect))
			assert_false(
				seat_rect.intersects(regions[&"action"]),
				"%d seat %d action %s / %s" % [player_count, seat, seat_rect, regions[&"action"]]
			)
			assert_false(
				seat_rect.intersects(regions[&"event"]),
				"%d seat %d event %s / %s" % [player_count, seat, seat_rect, regions[&"event"]]
			)
			assert_false(
				seat_rect.intersects(regions[&"center"]),
				"%d seat %d center %s / %s" % [player_count, seat, seat_rect, regions[&"center"]]
			)
			var action_rect: Rect2 = regions[StringName("status_%d" % seat)]
			if action_rect.size.y > 0.0:
				assert_true(
					surface_rect.encloses(action_rect),
					(
						"%d seat %d action label %s / %s"
						% [player_count, seat, action_rect, surface_rect]
					)
				)
				assert_false(action_rect.intersects(regions[&"center"]))


func test_six_player_action_labels_are_owned_by_their_seats() -> void:
	var view: GameView = _view(6)
	view._action_history = [
		PublicActionRecord.blind(1, 5, true),
		PublicActionRecord.blind(5, 10, false),
		PublicActionRecord.new(2, PlayerAction.Kind.CALL, 10),
		PublicActionRecord.new(3, PlayerAction.Kind.RAISE, 30),
	]
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = DESKTOP_VIEWPORT
	add_child_autofree(table)
	table.bind_view(view, _avatar_assignments(6))
	await _settle_layout()
	for seat: int in range(6):
		var label := table.find_child("Seat%dStatus" % seat, true, false) as Label
		if not label.visible:
			continue
		var panel := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as Control
		var label_rect := label.get_global_rect()
		assert_eq(
			label.text,
			["", "Small blind 5", "Call to 10", "Raise to 30", "", "Big blind 10"][seat],
		)
		assert_almost_eq(label_rect.get_center().x, panel.get_global_rect().get_center().x, 0.01)
		assert_gte(label_rect.position.y, panel.get_global_rect().end.y)


func test_visible_action_controls_use_two_non_intersecting_rows() -> void:
	var table := _table_for(6)
	await _settle_layout()
	var primary := (
		table.get_node(
			"TableMargin/Felt/TableSurface/ActionPanel/Margin/Content/ActionRows/PrimaryButtons"
		)
		as HBoxContainer
	)
	var wager := (
		table.get_node(
			"TableMargin/Felt/TableSurface/ActionPanel/Margin/Content/ActionRows/WagerControls"
		)
		as HBoxContainer
	)
	assert_true(table.get_node("%MinWagerButton").visible)
	assert_eq(table.get_node("%MinWagerButton").text, "Min Raise 20")
	assert_eq(primary.get_child_count(), 4)
	assert_eq(wager.get_child_count(), 3)
	assert_eq(primary.get_node("FoldButton").visible, true)
	assert_eq(primary.get_node("CheckCallButton").visible, true)
	assert_eq(primary.get_node("PotRaiseButton").visible, true)
	var action_rect: Rect2 = (
		table.get_node("TableMargin/Felt/TableSurface/ActionPanel").get_global_rect()
	)
	var controls := table.get_action_control_rects()
	var placed: Array[Rect2] = []
	for control_name: StringName in controls:
		var control_rect: Rect2 = controls[control_name]
		assert_true(action_rect.encloses(control_rect), str(control_name))
		assert_gt(control_rect.size.x, 0.0, str(control_name))
		for previous: Rect2 in placed:
			assert_false(control_rect.intersects(previous), str(control_name))
		placed.append(control_rect)


func test_small_desktop_seven_player_regions_do_not_occlude_each_other() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = SMALL_DESKTOP_VIEWPORT
	add_child_autofree(table)
	var view := _view(7)
	view._showdown_results = {
		3: _showdown_result(3, HandRank.Category.ONE_PAIR, [14, 13, 12, 9]),
		4: _showdown_result(4, HandRank.Category.FULL_HOUSE, [13, 10]),
	}
	table.bind_view(view, _avatar_assignments(7))
	await _settle_layout()
	var surface := _surface(table)
	var surface_rect := Rect2(Vector2.ZERO, surface.size)
	var regions := table.get_resolved_region_rects()
	for region_name: StringName in [&"center", &"action", &"event", &"hero"]:
		assert_true(surface_rect.encloses(regions[region_name]), str(region_name))
	for seat: int in range(7):
		var seat_rect: Rect2 = regions[StringName("seat_%d" % seat)]
		assert_true(surface_rect.encloses(seat_rect), "seat %d" % seat)
		assert_false(seat_rect.intersects(regions[&"center"]), "seat %d center" % seat)
		assert_false(seat_rect.intersects(regions[&"action"]), "seat %d action" % seat)
		assert_false(seat_rect.intersects(regions[&"event"]), "seat %d event" % seat)
		for auxiliary_name: StringName in [StringName("status_%d" % seat)]:
			var auxiliary_rect: Rect2 = regions[auxiliary_name]
			if auxiliary_rect.size.y <= 0.0:
				continue
			assert_true(surface_rect.encloses(auxiliary_rect), str(auxiliary_name))
			assert_false(auxiliary_rect.intersects(regions[&"center"]), str(auxiliary_name))
			assert_false(auxiliary_rect.intersects(regions[&"action"]), str(auxiliary_name))
			assert_false(auxiliary_rect.intersects(regions[&"event"]), str(auxiliary_name))
	assert_false(regions[&"center"].intersects(regions[&"action"]))
	assert_false(regions[&"center"].intersects(regions[&"event"]))


func test_desktop_browser_keeps_active_betting_actions_visible_after_refresh() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = SMALL_DESKTOP_VIEWPORT
	add_child_autofree(table)
	var view := _view(6)
	view._action_history = [
		PublicActionRecord.blind(1, 5, true),
		PublicActionRecord.blind(5, 10, false),
		PublicActionRecord.new(2, PlayerAction.Kind.CALL, 10),
	]
	table.bind_view(view, _avatar_assignments(6))
	await _settle_layout()
	for refresh: int in range(3):
		table._queue_layout()
		await _settle_layout()
	var regions := table.get_resolved_region_rects()
	var surface_rect := Rect2(Vector2.ZERO, _surface(table).size)
	var expected_text: Dictionary[int, String] = {
		1: "Small blind 5",
		2: "Call to 10",
		5: "Big blind 10",
	}
	for seat: int in [1, 2, 5]:
		var label := (
			table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%dStatus" % seat) as Label
		)
		var label_rect := label.get_global_rect()
		assert_true(label.visible, "seat %d action must be visible" % seat)
		assert_eq(label.text, expected_text[seat], "seat %d action text" % seat)
		assert_gte(label.z_index, 100, "seat %d action must render in the foreground" % seat)
		assert_false(
			label.has_theme_stylebox_override("normal"),
			"seat actions must remain plain text like the approved iPad reference",
		)
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_OFF)
		assert_true(surface_rect.encloses(regions[StringName("status_%d" % seat)]))
		assert_true(
			(
				label_rect.position.y
				>= (
					(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat) as Control)
					. get_global_rect()
					. end
					. y
				)
			)
		)
		assert_false(
			label_rect.intersects((table.get_node("%EventLog") as Control).get_global_rect())
		)
		assert_false(
			label_rect.intersects(
				(
					(table.get_node("TableMargin/Felt/TableSurface/ActionPanel") as Control)
					. get_global_rect()
				)
			)
		)


func test_real_match_binding_keeps_blind_action_visible_after_table_show() -> void:
	var config := ResolvedTournamentConfig.new(
		2, 100, 5, 10, 7123, &"single_table", {0: &"human", 1: &"scripted"}
	)
	var match_instance := (
		TournamentMatch
		. new(
			config,
			{0: HumanAgent.new(), 1: ScriptedAgent.new([])},
		)
	)
	assert_eq(match_instance.start(1).status, StepResult.Status.YIELDED)
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = SMALL_DESKTOP_VIEWPORT
	table.hide()
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _avatar_assignments(2))
	table.show()
	await _settle_layout()
	var big_blind_label := (
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Status") as Label
	)
	assert_false(big_blind_label.text.is_empty())
	assert_true(big_blind_label.visible)
	assert_gte(big_blind_label.z_index, 100)


func test_event_action_matching_keeps_latest_action_on_its_owning_seat() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var view := _view(6)
	view._action_history = [
		PublicActionRecord.blind(1, 5, true),
		PublicActionRecord.blind(5, 10, false),
		PublicActionRecord.new(2, PlayerAction.Kind.CALL, 10),
	]
	table.bind_view(view, _avatar_assignments(6))
	(
		table
		. _render_events(
			[
				DomainEvent.new(DomainEvent.Kind.HAND_STARTED),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 2, 10),
			]
		)
	)
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status") as Label).text,
		"Call to 10",
	)
	assert_true(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status") as Label).visible
	)


func test_action_labels_are_rebuilt_from_recipient_history_during_refresh() -> void:
	var table := PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	var view := _view(6)
	view._action_history = [
		PublicActionRecord.blind(1, 5, true),
		PublicActionRecord.blind(5, 10, false),
		PublicActionRecord.new(2, PlayerAction.Kind.CALL, 10),
	]
	table.bind_view(view, _avatar_assignments(6))
	table._refresh_seat_status_labels()
	assert_eq(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status") as Label).text,
		"Call to 10",
	)
	assert_true(
		(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Status") as Label).visible
	)


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
	view.minimum_wager_total = 20
	view.maximum_wager_total = 100
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


func _showdown_result(
	seat: int,
	category: HandRank.Category,
	tie_break_values: Array[int],
) -> ShowdownResult:
	var cards: Array[CardData] = [
		CardData.new(14, CardData.Suit.SPADES),
		CardData.new(13, CardData.Suit.HEARTS),
		CardData.new(12, CardData.Suit.DIAMONDS),
		CardData.new(11, CardData.Suit.CLUBS),
		CardData.new(10, CardData.Suit.SPADES),
	]
	var rank := HandRank.new(category, tie_break_values, cards)
	return ShowdownResult.new(seat, [cards[0], cards[1]], rank)
