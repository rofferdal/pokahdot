extends "res://tests/support/poker_gut_test.gd"

const GuiSceneHarnessScript := preload("res://tests/support/gui_scene_harness.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const ShowdownHandFormatterScript := preload("res://scripts/gui/showdown_hand_formatter.gd")

const REFERENCE_VIEWPORT := Vector2i(950, 532)
const DESKTOP_VIEWPORT := Vector2i(1920, 1080)
const FIRST_PLAYER_COUNT: int = 2
const LAST_PLAYER_COUNT: int = 9


func test_unified_status_band_content_contract_across_two_to_nine_players() -> void:
	for player_count: int in range(FIRST_PLAYER_COUNT, LAST_PLAYER_COUNT + 1):
		var fixtures: Dictionary = await _render_status_states(player_count)
		var summary_seat: int = player_count - 1
		var expected_summary: String = ShowdownHandFormatterScript.format_compact(
			fixtures.showdown_result
		)
		for seat: int in range(player_count):
			var context := "p%d seat %d" % [player_count, seat]
			var blank_label: Label = _status_label(fixtures.blank.table, seat)
			var action_label: Label = _status_label(fixtures.action.table, seat)
			var retained_fold_label: Label = _status_label(fixtures.retained_fold.table, seat)
			var showdown_label: Label = _status_label(fixtures.showdown.table, seat)

			assert_eq(blank_label.text, "", "%s blank text" % context)
			assert_false(action_label.text.is_empty(), "%s action text" % context)
			assert_eq(
				action_label.autowrap_mode,
				TextServer.AUTOWRAP_OFF,
				"%s action wrapping" % context,
			)
			assert_lte(action_label.get_line_count(), 1, "%s action line count" % context)
			assert_eq(retained_fold_label.text, "Fold", "%s retained Fold" % context)
			assert_lte(
				retained_fold_label.get_line_count(), 1, "%s retained Fold line count" % context
			)
			assert_eq(
				showdown_label.text,
				expected_summary if seat == summary_seat else "Fold",
				"%s showdown summary precedence" % context,
			)
			assert_lte(showdown_label.get_line_count(), 2, "%s showdown line count" % context)
			assert_gte(
				showdown_label.get_visible_line_count(),
				showdown_label.get_line_count(),
				"%s showdown text is not vertically clipped" % context,
			)
			for label: Label in [blank_label, action_label, retained_fold_label, showdown_label]:
				assert_gte(
					label.get_theme_font_size("font_size"), 18, "%s seat-copy font floor" % context
				)


func test_unified_status_and_lower_table_rectangles_stay_fixed_across_states() -> void:
	for player_count: int in range(FIRST_PLAYER_COUNT, LAST_PLAYER_COUNT + 1):
		var fixtures: Dictionary = await _render_status_states(player_count)
		var baseline: Dictionary[StringName, Rect2] = fixtures.blank.regions
		for state_name: StringName in [&"action", &"retained_fold", &"showdown"]:
			var regions: Dictionary[StringName, Rect2] = fixtures[state_name].regions
			var state_context := "p%d %s" % [player_count, state_name]
			for stable_name: StringName in [&"event", &"hero", &"action"]:
				assert_eq(
					regions[stable_name],
					baseline[stable_name],
					"%s %s" % [state_context, stable_name]
				)
			for seat: int in range(player_count):
				for prefix: String in ["seat", "status"]:
					var region_name := StringName("%s_%d" % [prefix, seat])
					assert_eq(
						regions[region_name],
						baseline[region_name],
						"%s %s" % [state_context, region_name],
					)
					if prefix == "status":
						assert_gt(
							regions[region_name].size.x, 0.0, "%s reserved width" % state_context
						)
						assert_gt(
							regions[region_name].size.y, 0.0, "%s reserved height" % state_context
						)


func test_unified_status_footprints_are_contained_and_non_intersecting() -> void:
	for player_count: int in range(FIRST_PLAYER_COUNT, LAST_PLAYER_COUNT + 1):
		var fixtures: Dictionary = await _render_status_states(player_count)
		for state_name: StringName in [&"blank", &"action", &"retained_fold", &"showdown"]:
			var table: PokerTableController = fixtures[state_name].table
			var regions: Dictionary[StringName, Rect2] = fixtures[state_name].regions
			var surface := table.get_node("TableMargin/Felt/TableSurface") as Control
			var surface_bounds := Rect2(Vector2.ZERO, surface.size)
			var footprint_regions: Array[Rect2] = []
			var footprint_names: Array[StringName] = []
			for seat: int in range(player_count):
				var seat_name := StringName("seat_%d" % seat)
				var status_name := StringName("status_%d" % seat)
				var seat_rect: Rect2 = regions[seat_name]
				var status_rect: Rect2 = regions[status_name]
				var context := "p%d %s seat %d" % [player_count, state_name, seat]
				assert_true(surface_bounds.encloses(seat_rect), "%s seat containment" % context)
				assert_true(surface_bounds.encloses(status_rect), "%s status containment" % context)
				assert_gte(status_rect.position.y, seat_rect.end.y, "%s below-seat band" % context)
				footprint_regions.append(seat_rect)
				footprint_names.append(seat_name)
				footprint_regions.append(status_rect)
				footprint_names.append(status_name)
			for first: int in range(footprint_regions.size()):
				for second: int in range(first + 1, footprint_regions.size()):
					assert_false(
						footprint_regions[first].intersects(footprint_regions[second]),
						(
							"p%d %s %s must not intersect %s"
							% [
								player_count,
								state_name,
								footprint_names[first],
								footprint_names[second]
							]
						),
					)
			for lower_name: StringName in [&"event", &"action"]:
				for index: int in range(footprint_regions.size()):
					assert_false(
						regions[lower_name].intersects(footprint_regions[index]),
						(
							"p%d %s %s must not intersect %s"
							% [player_count, state_name, lower_name, footprint_names[index]]
						),
					)


func test_six_and_seven_player_seat_slots_stay_fixed_when_content_changes() -> void:
	var cases: Array[Dictionary] = [
		{"player_count": 7, "viewport": DESKTOP_VIEWPORT, "name": "desktop"},
		{"player_count": 6, "viewport": Vector2i(2388, 1450), "name": "landscape tablet"},
		{"player_count": 7, "viewport": Vector2i(2388, 1450), "name": "landscape tablet"},
	]
	for test_case: Dictionary in cases:
		var player_count: int = test_case.player_count
		var viewport: Vector2i = test_case.viewport
		var context: String = "p%d %s" % [player_count, test_case.name]
		var winner_seat: int = player_count - 1
		var baseline := await _render_at(_descriptor(player_count), viewport)

		var folded_descriptor := _descriptor(player_count)
		folded_descriptor.view._seats[winner_seat].folded = true
		var fold_actions: Array[PublicActionRecord] = [
			PublicActionRecord.new(winner_seat, PlayerAction.Kind.FOLD, 0),
		]
		folded_descriptor.view._action_history = fold_actions
		var folded := await _render_at(folded_descriptor, viewport)

		var showdown_descriptor := _showdown_descriptor(player_count)
		var revealed_hole_cards: Dictionary[int, Array] = {
			winner_seat:
			[
				CardData.new(14, CardData.Suit.SPADES),
				CardData.new(13, CardData.Suit.HEARTS),
			]
		}
		showdown_descriptor.view._revealed_hole_cards = revealed_hole_cards
		var showdown_results: Dictionary[int, ShowdownResult] = {
			winner_seat: _long_showdown_result(winner_seat)
		}
		showdown_descriptor.view._showdown_results = showdown_results
		var pot_awards: Array[PotAward] = [
			PotAward.new(0, 70, [winner_seat], {winner_seat: 70}),
		]
		showdown_descriptor.view._pot_awards = pot_awards
		var showdown := await _render_at(showdown_descriptor, viewport)

		for rendered: Dictionary in [folded, showdown]:
			var stable_regions: Array[StringName] = [&"center", &"hero"]
			for seat: int in range(player_count):
				stable_regions.append(StringName("seat_%d" % seat))
				stable_regions.append(StringName("status_%d" % seat))
			for region_name: StringName in stable_regions:
				assert_eq(
					rendered.regions[region_name],
					baseline.regions[region_name],
					"%s %s" % [context, region_name],
				)
		assert_false(
			folded.table.has_node(
				(
					(
						"TableMargin/Felt/TableSurface/Seats/Seat%d/Content/"
						+ "Footer/HoleCards/CardBack1"
					)
					% winner_seat
				)
			)
		)
		assert_true(
			showdown.table.has_node(
				(
					(
						"TableMargin/Felt/TableSurface/Seats/Seat%d/Content/Header/"
						+ "AvatarRegion/MainPotWinnerStar"
					)
					% winner_seat
				)
			)
		)


func _render_status_states(player_count: int) -> Dictionary:
	var states: Dictionary = {}
	var blank := _descriptor(player_count)
	blank.view._action_history = [] as Array[PublicActionRecord]
	states[&"blank"] = await _render(blank)

	var action := _descriptor(player_count)
	action.view._action_history = _actions_for_every_seat(player_count, PlayerAction.Kind.CALL)
	states[&"action"] = await _render(action)

	var retained_fold := _showdown_descriptor(player_count)
	retained_fold.view._action_history = _actions_for_every_seat(
		player_count, PlayerAction.Kind.FOLD
	)
	states[&"retained_fold"] = await _render(retained_fold)

	var showdown := _showdown_descriptor(player_count)
	showdown.view._action_history = _actions_for_every_seat(player_count, PlayerAction.Kind.FOLD)
	var summary_seat: int = player_count - 1
	var showdown_result := _long_showdown_result(summary_seat)
	var showdown_results: Dictionary[int, ShowdownResult] = {summary_seat: showdown_result}
	showdown.view._showdown_results = showdown_results
	states[&"showdown"] = await _render(showdown)
	states[&"showdown_result"] = showdown_result
	return states


func _descriptor(player_count: int) -> Dictionary:
	var view: GameView = GuiVisualStateFixturesScript._human_turn_view(player_count, &"preflop")
	return GuiVisualStateFixturesScript._table_descriptor(&"unified-status", view)


func _showdown_descriptor(player_count: int) -> Dictionary:
	var descriptor := _descriptor(player_count)
	descriptor.view.street = &"hand_end"
	descriptor.view.hand_complete = true
	descriptor.view.acting_seat = Table.NO_SEAT
	return descriptor


func _actions_for_every_seat(
	player_count: int, action_kind: PlayerAction.Kind
) -> Array[PublicActionRecord]:
	var actions: Array[PublicActionRecord] = []
	for seat: int in range(player_count):
		actions.append(PublicActionRecord.new(seat, action_kind, 10))
	return actions


func _long_showdown_result(seat: int) -> ShowdownResult:
	var hole_cards: Array[CardData] = [
		CardData.new(14, CardData.Suit.SPADES), CardData.new(13, CardData.Suit.HEARTS)
	]
	var selected_cards: Array[CardData] = [
		hole_cards[0],
		hole_cards[1],
		CardData.new(14, CardData.Suit.DIAMONDS),
		CardData.new(14, CardData.Suit.CLUBS),
		CardData.new(13, CardData.Suit.SPADES),
	]
	return ShowdownResult.new(
		seat, hole_cards, HandRank.new(HandRank.Category.FULL_HOUSE, [14, 13], selected_cards)
	)


func _status_label(table: PokerTableController, seat: int) -> Label:
	return table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%dStatus" % seat) as Label


func _render(descriptor: Dictionary) -> Dictionary:
	return await _render_at(descriptor, REFERENCE_VIEWPORT)


func _render_at(descriptor: Dictionary, viewport: Vector2i) -> Dictionary:
	var harness: Node = GuiSceneHarnessScript.new()
	add_child_autofree(harness)
	var rendered: Dictionary = harness.render(descriptor, viewport)
	assert_true(await harness.settle_layout())
	var table: PokerTableController = rendered.table
	return {
		"harness": harness,
		"table": table,
		"regions": table.get_resolved_region_rects(),
	}
