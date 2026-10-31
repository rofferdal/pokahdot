extends GutTest

const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")
const Invariants := preload("res://tests/support/gui_replacement_invariant_assertions.gd")


func test_default_phone_game_is_playable_instead_of_guidance() -> void:
	for count: int in [6, 7]:
		var table: GuiReplacementTableController = await _table(Vector2i(389, 743), count, true)
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		assert_true(
			snapshot.ready,
			"Default phone game must show playable content (%d): " % count + snapshot.fit_guidance
		)
		assert_eq(Invariants.validate(snapshot), PackedStringArray())
		if snapshot.ready:
			assert_true(table.get_composition().get_control(&"fold").is_visible_in_tree())
			assert_true(table.get_composition().get_control(&"wager").is_visible_in_tree())
		table.get_parent().free()


func test_narrow_phone_targets_keep_six_player_game_and_menu_reachable() -> void:
	for allocation: Vector2i in [Vector2i(360, 780), Vector2i(360, 720), Vector2i(780, 360)]:
		var table: GuiReplacementTableController = await _table(allocation, 6, true)
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		assert_true(snapshot.ready, "%s: %s" % [allocation, snapshot.fit_guidance])
		assert_eq(Invariants.validate(snapshot), PackedStringArray())
		if snapshot.ready:
			var more: Control = table.get_composition().get_control(&"more")
			assert_eq(more.accessibility_name, "More / Pots")
			assert_gte(more.size.x, 48.0)
			assert_gte(more.size.y, 48.0)
		table.get_parent().free()


func test_narrow_phone_keeps_late_default_tournament_wagers_readable() -> void:
	var view: GameView = GuiBrowserCaptureFixture.descriptor(6).view
	view._seats[0].stack = 1000
	view._seats[0].bet_this_round = 0
	view._seats[1].stack = 0
	view._seats[1].bet_this_round = 5000
	view._seats[1].all_in = true
	for id: int in range(2, 6):
		view._seats[id].stack = 0
		view._seats[id].bet_this_round = 0
		view._seats[id].folded = true
		view._seats[id].busted = true
	view.button_seat = 1
	view.small_blind_seat = 1
	view.big_blind_seat = 0
	view.active_seats = [0, 1]
	view.eliminated_seats = [2, 3, 4, 5]
	view.pot_amount = 5000
	view.call_amount = 1000
	view.maximum_wager_total = 1000
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL, PlayerAction.Kind.ALL_IN]
	var table: GuiReplacementTableController = await _table(
		Vector2i(360, 780), 6, true, &"human-turn-flop", false, view
	)
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_true(snapshot.ready, snapshot.fit_guidance)
	assert_eq(Invariants.validate(snapshot), PackedStringArray())
	if snapshot.ready:
		assert_eq(snapshot.seats[1].fields[&"action"].text, "Bet 5000")
	table.get_parent().free()


func test_six_and_seven_players_fit_phone_landscape() -> void:
	for count: int in [6, 7]:
		var allocation := Vector2i(844, 390) if count == 6 else Vector2i(932, 430)
		var table: GuiReplacementTableController = await _table(allocation, count, true)
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		assert_true(snapshot.ready, "%d: %s" % [count, snapshot.fit_guidance])
		assert_eq(Invariants.validate(snapshot), PackedStringArray())
		table.get_parent().free()


func test_ipad_keeps_avatars_and_inline_wager_shortcuts() -> void:
	for allocation: Vector2i in [Vector2i(1194, 676), Vector2i(834, 1030)]:
		for count: int in [2, 6, 9]:
			var table: GuiReplacementTableController = await _table(allocation, count)
			var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
			assert_true(snapshot.ready, "%s/%d: %s" % [allocation, count, snapshot.fit_guidance])
			assert_eq(Invariants.validate(snapshot), PackedStringArray())
			if snapshot.ready:
				for seat: Control in table.get_composition().get_seat_controls().values():
					var avatar := seat.get_field(&"avatar") as TextureRect
					assert_not_null(avatar)
					if avatar != null:
						assert_true(avatar.is_visible_in_tree())
						assert_not_null(avatar.texture)
				for role: StringName in [&"minimum", &"pot"]:
					assert_true(table.get_composition().get_control(role).is_visible_in_tree())
			table.get_parent().free()


func test_tablet_pointer_controls_keep_avatars_in_reduced_safe_area() -> void:
	var table: GuiReplacementTableController = await _table(Vector2i(996, 716), 6, true)
	table.use_keypad(false)
	await _settle(table)
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_true(snapshot.ready)
	assert_eq(snapshot.layout_mode, GuiSizeClass.LayoutMode.WIDE_COMPACT)
	assert_eq(Invariants.validate(snapshot), PackedStringArray())
	if snapshot.ready:
		for token: Control in table.get_composition().get_seat_controls().values():
			assert_not_null(token.get_field(&"avatar"))
	table.get_parent().free()


func test_reviewed_ipad_seats_stay_fixed_while_board_and_buttons_align() -> void:
	var table: GuiReplacementTableController = await _table(Vector2i(1194, 676), 6, true)
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_true(snapshot.ready)
	assert_eq(Invariants.validate(snapshot), PackedStringArray())
	if snapshot.ready:
		var human: Rect2 = snapshot.seats[0].panel.rect
		var expected: Dictionary[int, Vector2] = {
			0: Vector2(435.81, 518.4),
			1: Vector2(0, 319.2),
			2: Vector2(0, 159.6),
			3: Vector2(435.81, 0),
			4: Vector2(871.62, 159.6),
			5: Vector2(871.62, 319.2)
		}
		for id: int in expected:
			var rect: Rect2 = snapshot.seats[id].panel.rect
			assert_almost_eq(rect.position.x, expected[id].x, 1.0)
			assert_almost_eq(rect.position.y, expected[id].y, 1.0)
			assert_almost_eq(rect.size.x, 322.0, 1.0)
			assert_almost_eq(rect.size.y, 108.0, 1.0)
			var token := table.get_composition().get_seat_controls()[id] as GuiSeatToken
			var pair: Rect2 = token.get_field(&"cards").get_global_rect()
			assert_almost_eq(pair.end.x, rect.end.x - 3.0, 1.0)
			assert_almost_eq(pair.end.y, rect.end.y - 3.0, 1.0)
			assert_gte(pair.size.y, rect.size.y * 0.6)
			assert_lte(pair.size.y, rect.size.y * 2.0 / 3.0 + 1.0)
		var center := table.get_composition().get_control(&"center") as GuiCenterBoard
		var cards: Rect2 = center.get_cards().get_global_rect()
		assert_almost_eq(cards.size.x, human.size.x, 1.0)
		assert_almost_eq(cards.get_center().x, human.get_center().x, 1.0)
		assert_almost_eq(cards.get_center().x, 597.0, 1.0)
		assert_almost_eq(cards.get_center().y, 338.0, 1.0)
		var totals: Rect2 = (center.get_node("Totals") as Control).get_global_rect()
		assert_almost_eq(totals.position.y - cards.end.y, 2.0, 1.0)
		var blinds: Rect2 = (center.get_node("BlindLevel") as Control).get_global_rect()
		assert_almost_eq(blinds.position.y - totals.end.y, 2.0, 1.0)
		var actions: Control = table.get_composition().get_control(&"actions")
		assert_almost_eq(actions.get_global_rect().end.y, human.end.y, 1.0)
	table.get_parent().free()


func test_tablet_resize_grows_seats_and_cards_and_keeps_identity_and_draft() -> void:
	var table: GuiReplacementTableController = await _table(Vector2i(1194, 676), 6)
	table.set_layout_mode_override(GuiSizeClass.LayoutMode.WIDE_COMPACT)
	await _settle(table)
	var composition: GuiTableComposition = table.get_composition()
	var seats: Dictionary[int, Control] = composition.get_seat_controls()
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	var width: float = snapshot.seats[1].panel.rect.size.x
	var card_height: float = snapshot.board_cards[0].element.rect.size.y
	var human_width: float = snapshot.seats[0].panel.rect.size.x
	var texture: Texture2D = (seats[1].get_field(&"avatar") as TextureRect).texture
	var initial_avatar_height: float = (seats[1].get_field(&"avatar") as Control).size.y
	table.set_wager_draft("00075")
	for allocation: Vector2i in [Vector2i(1280, 1000), Vector2i(834, 1030), Vector2i(1194, 676)]:
		(table.get_parent() as SubViewport).size = allocation
		table.size = Vector2(allocation)
		table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(allocation)))
		await _settle(table)
		await wait_process_frames(8)
		snapshot = table.get_layout_snapshot()
		assert_true(snapshot.ready, str(allocation))
		assert_eq(Invariants.validate(snapshot), PackedStringArray())
		assert_eq(table.get_wager_draft(), "00075")
		assert_same(table.get_composition(), composition)
		assert_same(composition.get_seat_controls()[1], seats[1])
		assert_same((seats[1].get_field(&"avatar") as TextureRect).texture, texture)
		for seat: Control in seats.values():
			var panel := seat.get_node("Panel") as Control
			var avatar := seat.get_field(&"avatar") as TextureRect
			var padding: StyleBox = panel.get_theme_stylebox("panel")
			assert_almost_eq(avatar.size.y, panel.size.y * 0.5, 1.0)
			assert_almost_eq(avatar.size.x, avatar.size.y, 1.0)
			assert_almost_eq(
				avatar.global_position.x,
				panel.global_position.x + padding.get_margin(SIDE_LEFT),
				0.1
			)
			assert_almost_eq(
				avatar.global_position.y,
				panel.global_position.y + padding.get_margin(SIDE_TOP),
				0.1
			)
		if allocation == Vector2i(1194, 676):
			assert_almost_eq(
				(seats[1].get_field(&"avatar") as Control).size.y, initial_avatar_height, 1.0
			)
		if allocation.x == 1280:
			assert_gt(snapshot.seats[1].panel.rect.size.x, width)
			assert_gt(snapshot.seats[0].panel.rect.size.x, human_width)
			assert_gt(snapshot.board_cards[0].element.rect.size.y, card_height)
	table.get_parent().free()


func test_phone_inline_shortcuts_follow_measured_spare_space() -> void:
	var table: GuiReplacementTableController = await _table(Vector2i(390, 1000), 6)
	assert_true(table.get_layout_snapshot().ready)
	for role: StringName in [&"minimum", &"pot"]:
		assert_true(table.get_composition().get_control(role).is_visible_in_tree(), str(role))
	(table.get_parent() as SubViewport).size = Vector2i(390, 744)
	table.size = Vector2(390, 744)
	table.set_viewport_geometry(GuiViewportGeometry.injected(table.size))
	await _settle(table)
	assert_true(table.get_layout_snapshot().ready)
	for role: StringName in [&"minimum", &"pot"]:
		assert_false(table.get_composition().get_control(role).is_visible_in_tree(), str(role))
	assert_eq(Invariants.validate(table.get_layout_snapshot()), PackedStringArray())
	table.get_parent().free()


func test_tablet_stress_states_and_large_values_keep_complete_content() -> void:
	for allocation: Vector2i in [Vector2i(1194, 676), Vector2i(834, 1030)]:
		for state: StringName in [
			&"showdown-long", &"elimination", &"tournament-winner", &"human-turn-flop"
		]:
			var table: GuiReplacementTableController = await _table(
				allocation, 9, false, state, state == &"human-turn-flop"
			)
			var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
			assert_true(snapshot.ready, "%s/%s: %s" % [allocation, state, snapshot.fit_guidance])
			assert_eq(Invariants.validate(snapshot), PackedStringArray(), str(state))
			if snapshot.ready:
				for seat: Control in table.get_composition().get_seat_controls().values():
					var avatar := seat.get_field(&"avatar") as TextureRect
					assert_not_null(avatar.texture)
					if (seat.get_seat_snapshot(table) as GuiSeatSnapshot).busted:
						assert_not_null(seat.material, "Eliminated seats retain grayscale avatars")
			table.get_parent().free()


func test_tablet_pairs_centered_human_and_upper_right_role_markers() -> void:
	for allocation: Vector2i in [Vector2i(1194, 676), Vector2i(834, 1030)]:
		var table: GuiReplacementTableController = await _table(allocation, 6, true)
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		assert_true(snapshot.ready)
		assert_eq(snapshot.seat_rows[0].size(), 1)
		assert_eq(snapshot.seat_rows[-1], PackedInt32Array([0]))
		var human: Rect2 = snapshot.seats[0].panel.rect
		assert_almost_eq(human.get_center().x, allocation.x * 0.5, 1.0)
		for id: int in snapshot.seats:
			var seat: GuiSeatSnapshot = snapshot.seats[id]
			assert_almost_eq(
				seat.panel.rect.size.x / seat.panel.rect.size.y, human.size.x / human.size.y, 0.05
			)
			var token := table.get_composition().get_seat_controls()[id] as GuiSeatToken
			var cards: Control = token.get_field(&"cards")
			for role: StringName in [&"marker", &"badge", &"badge_row_2"]:
				var badge: Control = token.get_field(role)
				if badge.is_visible_in_tree():
					assert_lte(
						badge.get_global_rect().end.y, cards.get_global_rect().position.y + 1
					)
					assert_gt(
						badge.get_global_rect().get_center().x, seat.panel.rect.get_center().x
					)
		table.get_parent().free()


func test_community_center_uses_nearest_clear_band_when_exact_center_is_blocked() -> void:
	var plan := GuiPhoneLandscapePlan.new()
	plan.feasible = true
	plan.center = Rect2(400, 140, 200, 150)
	plan.actions = Rect2(700, 420, 250, 80)
	plan.seats = {0: Rect2(400, 350, 200, 120), 1: Rect2(0, 0, 200, 120)}
	GuiTabletTablePlan.center_board(plan, Vector2(1000, 500), 80.0, 2.0)
	assert_almost_eq(plan.center.position.y, 198.0, 0.01)
	assert_false(plan.center.intersects(plan.seats[0]))
	assert_false(plan.center.intersects(plan.actions))
	assert_true(Rect2(0, 0, 1000, 500).encloses(plan.center))


func test_tablet_measurements_reject_invalid_geometry() -> void:
	var ids := PackedInt32Array([0, 1])
	var minima: Dictionary[int, Vector2] = {0: Vector2(200, 120), 1: Vector2(200, 120)}
	for invalid: Vector2 in [Vector2.ZERO, Vector2(-1, 80), Vector2(NAN, 80), Vector2(40, INF)]:
		assert_false(
			(
				GuiTabletTablePlan
				. resolve(ids, 0, minima, invalid, Vector2(300, 130), Vector2(1000, 1000), 2)
				. valid
			)
		)
	for invalid: float in [-1.0, NAN, INF]:
		assert_false(
			(
				GuiTabletTablePlan
				. resolve(
					ids,
					0,
					minima,
					Vector2(236, 123),
					Vector2(300, 130),
					Vector2(1000, 1000),
					invalid
				)
				. valid
			)
		)


func test_phone_remains_playable_while_waiting_for_a_bot() -> void:
	var view: GameView = GuiBrowserCaptureFixture.descriptor(6).view
	view.acting_seat = 1
	view.hands_until_next_level = 12
	var table: GuiReplacementTableController = await _table(
		Vector2i(360, 744), 6, true, &"human-turn-flop", false, view
	)
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_true(snapshot.ready, snapshot.fit_guidance)
	assert_eq(Invariants.validate(snapshot), PackedStringArray())
	table.get_parent().free()


func test_landscape_hole_cards_stay_bottom_right_and_board_cards_are_taller() -> void:
	for allocation: Vector2i in [Vector2i(780, 360), Vector2i(844, 390)]:
		var table: GuiReplacementTableController = await _table(allocation, 6, true)
		assert_true(table.get_layout_snapshot().ready)
		for seat: GuiSeatToken in table.get_composition().get_seat_controls().values():
			var panel: Rect2 = (seat.get_node("Panel") as Control).get_global_rect()
			var cards: Rect2 = seat.get_field(&"cards").get_global_rect()
			assert_almost_eq(cards.end.x, panel.end.x - 3.0, 1.0)
			assert_almost_eq(cards.end.y, panel.end.y - 3.0, 1.0)
			var markers: Rect2 = (seat.get_node("%Markers") as Control).get_global_rect()
			assert_lte(markers.end.y, cards.position.y + 1.0)
		var center := table.get_composition().get_control(&"center") as GuiCenterBoard
		for card: GuiPlayingCard in center.get_cards().cards:
			var rect: Rect2 = card.get_card_snapshot(table, &"board-card").element.rect
			assert_gt(rect.size.y, rect.size.x)
		table.get_parent().free()


func _settle(table: GuiReplacementTableController) -> void:
	for frame: int in 180:
		await get_tree().process_frame
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		if (
			not snapshot.pending
			and (snapshot.ready or snapshot.fit_guidance.begins_with("More space"))
		):
			return
	fail_test("Browser correction fixture failed to settle.")


func _table(
	allocation: Vector2i,
	count: int,
	browser_state: bool = false,
	state: StringName = &"human-turn-flop",
	large_values: bool = false,
	view_override: GameView = null
) -> GuiReplacementTableController:
	var viewport := SubViewport.new()
	viewport.size = allocation
	viewport.gui_embed_subwindows = true
	add_child(viewport)
	var table := TableScene.instantiate() as GuiReplacementTableController
	table.touch_entry = true
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(allocation)
	viewport.add_child(table)
	table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(allocation)))
	var fixture: Dictionary = (
		GuiBrowserCaptureFixture.descriptor(count)
		if browser_state
		else GuiVisualStateFixtures.by_id(state, count)
	)
	if view_override != null:
		fixture.view = view_override
	if large_values:
		var view: GameView = fixture.view
		for player: PlayerView in view.seats:
			player.stack = 9000000
			player.bet_this_round = 1000000
		view.pot_amount = 6000000
		view.small_blind = 500000
		view.big_blind = 1000000
		view.call_amount = 1000000
		view.minimum_wager_total = 2000000
		view.maximum_wager_total = 9000000
	var names: Dictionary[int, String] = {}
	for id: int in count:
		names[id] = "Emiliano"
	var avatars: Dictionary[int, String] = {}
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	for id: int in count:
		avatars[id] = paths[id]
	assert_true(table.bind_view(fixture.view, avatars, names))
	await _settle(table)
	return table
