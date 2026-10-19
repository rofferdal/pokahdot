extends "res://tests/support/poker_gut_test.gd"

const PokerTableScene := preload("res://scenes/poker_table.tscn")


func test_action_controls_follow_recipient_legal_actions_and_submit_wagers() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	var view: GameView = match_instance.get_view_for(0)
	assert_true(view.acting_seat == 0)
	assert_false(table.get_node("%FoldButton").disabled)
	assert_false(table.get_node("%CheckCallButton").disabled)
	assert_string_contains(table.get_node("%CheckCallButton").text, "Call")
	assert_false(table.get_node("%MinWagerButton").disabled)
	assert_false(table.get_node("%WagerButton").disabled)
	assert_false(table.get_node("%AllInButton").disabled)
	assert_string_contains(table.get_node("%MinWagerButton").text, "Min Raise")
	assert_string_contains(table.get_node("%HalfWagerButton").text, "Preset Raise")
	assert_eq(table.get_node("%WagerButton").text, "Raise")
	assert_eq(table.get_node("%AllInButton").text, "All-in")

	table.submit_wager_total(view.minimum_wager_total)

	assert_gt(match_instance.get_view_for(0).pot_amount, 15)
	assert_true(table.get_event_texts().any(func(text: String) -> bool: return "action" in text))


func test_rejected_free_wager_keeps_human_turn_and_displays_core_error() -> void:
	var match_instance := _waiting_match([PlayerAction.call_action()])
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	var input: LineEdit = table.get_node("%WagerInput")
	input.text = "1"
	table.get_node("%WagerButton").emit_signal("pressed")

	assert_eq(match_instance.get_view_for(0).acting_seat, 0)
	assert_false(table.get_node("%ActionStatus").text.is_empty())
	assert_true(table.get_event_texts()[-1].contains("rejected"))


func test_event_log_preserves_domain_event_order_and_fold_settlement() -> void:
	var match_instance := _waiting_match([PlayerAction.fold_action()])
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())
	table.get_node("%FoldButton").emit_signal("pressed")

	var event_texts: Array[String] = table.get_event_texts()
	assert_eq(event_texts[0], "Hand")
	assert_string_contains(event_texts[1], "blind")
	assert_string_contains(event_texts[2], "blind")
	assert_eq(event_texts[3], "Deal")
	assert_string_contains(event_texts[-2], "wins")
	assert_eq(event_texts[-1], "Complete")
	assert_eq(match_instance.get_view_for(0).hand_winner_seat, 1)


func test_gui_actions_complete_a_checked_down_showdown_and_render_its_events() -> void:
	var match_instance := _waiting_match(
		[
			PlayerAction.call_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
		]
	)
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	table.bind_match(match_instance, 0, _empty_assignments())

	table.get_node("%CheckCallButton").emit_signal("pressed")
	for _street: int in range(3):
		table.get_node("%CheckCallButton").emit_signal("pressed")

	var view: GameView = match_instance.get_view_for(0)
	assert_true(view.hand_complete)
	assert_eq(view.community_cards.size(), 5)
	assert_true(table.get_event_texts().has("Showdown"))
	assert_eq(table.get_event_texts()[-1], "Complete")


func test_human_adjacent_panels_do_not_overlap_desktop_seats() -> void:
	for player_count: int in [6, 9]:
		var table = PokerTableScene.instantiate()
		table.hide()
		add_child_autofree(table)
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = Vector2(1920, 1080)
		table.bind_view(_action_view(player_count), _empty_assignments())
		table.show()
		await get_tree().process_frame
		await get_tree().process_frame

		var action_rect: Rect2 = table.get_action_panel_rect()
		var event_rect: Rect2 = table.get_event_log_rect()
		var hero_rect: Rect2 = table.get_seat_rects()[0]
		assert_gte(
			action_rect.position.x,
			hero_rect.end.x + 12.0,
			"%d-player action position" % player_count
		)
		assert_lte(
			event_rect.end.x, hero_rect.position.x - 12.0, "%d-player event position" % player_count
		)
		assert_lte(action_rect.size.y, 140.0, "%d-player two-row action height" % player_count)
		assert_gte(event_rect.size.x, 380.0, "%d-player event width" % player_count)
		assert_lte(event_rect.size.y, 140.0, "%d-player event height" % player_count)
		assert_eq(table.get_node("%FoldButton").get_theme_font_size("font_size"), 21)
		assert_eq(table.get_node("%FoldButton").get_theme_stylebox("normal").border_width_left, 1)
		assert_eq(table.get_node("%FoldButton").get_theme_stylebox("hover").border_width_left, 2)
		assert_eq(table.get_node("%WagerInput").get_theme_stylebox("normal").border_width_left, 1)
		assert_gte(table.get_node("%FoldButton").get_theme_font_size("font_size"), 20)
		var event_log: RichTextLabel = table.get_node("%EventLog")
		assert_false(event_log.fit_content)
		assert_true(event_log.scroll_active)
		assert_eq(event_log.get_theme_color("default_color"), Color("111111"))
		assert_eq(event_log.get_theme_stylebox("normal").bg_color, Color("dedede"))
		assert_true(
			(
				(
					table
					. get_node(
						"TableMargin/Felt/TableSurface/ActionPanel/Margin/Content/ActionRows/PrimaryButtons"
					)
				)
				is HBoxContainer
			)
		)
		assert_true(
			(
				(
					table
					. get_node(
						"TableMargin/Felt/TableSurface/ActionPanel/Margin/Content/ActionRows/WagerControls"
					)
				)
				is HBoxContainer
			)
		)
		assert_false(
			action_rect.intersects(event_rect),
			"%d-player action/event panels %s / %s" % [player_count, action_rect, event_rect]
		)
		for seat_rect: Rect2 in table.get_seat_rects().values():
			assert_false(
				action_rect.intersects(seat_rect),
				"%d-player action panel %s / %s" % [player_count, action_rect, seat_rect]
			)
			assert_false(
				event_rect.intersects(seat_rect),
				"%d-player event panel %s / %s" % [player_count, event_rect, seat_rect]
			)


func test_each_seat_displays_its_latest_public_action_below_its_panel() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(3)
	view._action_history = [
		PublicActionRecord.blind(0, 5, true),
		PublicActionRecord.blind(1, 10, false),
		PublicActionRecord.new(2, PlayerAction.Kind.RAISE, 30),
	]
	table.bind_view(view, _empty_assignments())

	assert_eq(
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Action").text, "Small blind 5"
	)
	assert_eq(
		table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action").text, "Big blind 10"
	)
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Action").text, "Raise 30")
	assert_eq(
		(
			table
			. get_node("TableMargin/Felt/TableSurface/Seats/Seat2/Content/Header/Identity/Stack")
			. text
		),
		"100 chips"
	)


func test_folded_seat_stays_visible_grayscale_and_hides_hole_cards() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(3)
	view._seats[1].folded = true
	view._action_history = [PublicActionRecord.new(1, PlayerAction.Kind.FOLD, 0)]
	table.bind_view(view, _empty_assignments())

	var folded_seat: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1")
	var hole_cards: HBoxContainer = folded_seat.get_node("Content/Footer/HoleCards")
	assert_true(folded_seat.visible)
	assert_true(folded_seat.material is ShaderMaterial)
	assert_true(folded_seat.get_node("Content/Header/Avatar").use_parent_material)
	assert_eq(hole_cards.get_child_count(), 0)
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action").text, "Fold")


func test_seat_identity_keeps_stack_below_name_and_all_in_outside_the_panel() -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(2)
	view._seats[1].all_in = true
	view._action_history = [PublicActionRecord.new(1, PlayerAction.Kind.ALL_IN, 100)]
	table.bind_view(view, _empty_assignments())

	var identity: VBoxContainer = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/Identity"
	)
	var stack_label: Label = identity.get_node("Stack")
	var marker: Label = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/Marker"
	)
	assert_eq(identity.get_child(0).name, "Name")
	assert_eq(identity.get_child(1).name, "Stack")
	assert_eq(stack_label.text, "100 chips")
	assert_false(stack_label.text.contains("ALL-IN"))
	assert_eq(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1Action").text, "All-in 100")
	assert_eq(marker.custom_minimum_size.x, 48.0)


func test_showdown_summaries_use_recipient_safe_results_above_revealed_seats() -> void:
	var table = PokerTableScene.instantiate()
	table.hide()
	add_child_autofree(table)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1920, 1080)
	var view := _action_view(3)
	view._showdown_results = {
		0: _showdown_result(0, HandRank.Category.ONE_PAIR, [13, 14, 12, 7]),
		1: _showdown_result(1, HandRank.Category.FULL_HOUSE, [14, 10]),
	}
	table.bind_view(view, _empty_assignments())
	table.show()
	await get_tree().process_frame
	await get_tree().process_frame

	var pair_label: Label = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0Showdown")
	var full_house_label: Label = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1Showdown"
	)
	var hero_panel: PanelContainer = table.get_node("TableMargin/Felt/TableSurface/Seats/Seat0")
	assert_eq(pair_label.text, "Pair of Kings")
	assert_eq(full_house_label.text, "Full house: Aces full of Tens")
	assert_true(pair_label.visible)
	assert_false(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat2Showdown").visible)
	assert_lte(pair_label.position.y + pair_label.size.y, hero_panel.position.y)


func test_main_pot_showdown_winner_has_a_yellow_half_avatar_star_without_marking_side_pot_winners(
) -> void:
	var table = PokerTableScene.instantiate()
	add_child_autofree(table)
	var view := _action_view(3)
	view._showdown_results = {
		0: _showdown_result(0, HandRank.Category.ONE_PAIR, [13, 14, 12, 7]),
		1: _showdown_result(1, HandRank.Category.FULL_HOUSE, [14, 10]),
	}
	view._pot_awards = [
		PotAward.new(0, 120, [1], {1: 120}),
		PotAward.new(1, 40, [0], {0: 40}),
	]
	table.bind_view(view, _empty_assignments())

	var winner_star: Label = table.get_node(
		"TableMargin/Felt/TableSurface/Seats/Seat1/Content/Header/MainPotWinnerStar"
	)
	assert_eq(winner_star.text, "★")
	assert_eq(winner_star.get_theme_color("font_color"), Color("ffd429"))
	assert_eq(winner_star.custom_minimum_size, Vector2(28, 28))
	assert_eq(winner_star.get_parent().name, "Header")
	assert_false(
		table.has_node("TableMargin/Felt/TableSurface/Seats/Seat0/Content/Header/MainPotWinnerStar")
	)


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


func _waiting_match(bot_actions: Array[PlayerAction]) -> TournamentMatch:
	var config := (
		ResolvedTournamentConfig
		. new(
			2,
			100,
			5,
			10,
			9123,
			&"single_table",
			{0: &"human", 1: &"scripted"},
		)
	)
	var match_instance := (
		TournamentMatch
		. new(
			config,
			{0: HumanAgent.new(), 1: ScriptedAgent.new(bot_actions)},
		)
	)
	assert_eq(match_instance.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	return match_instance


func _empty_assignments() -> Dictionary[int, String]:
	return {}


func _action_view(player_count: int) -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	for seat: int in range(player_count):
		var agent: Agent = (
			HumanAgent.new() if seat == 0 else RandomAgent.new(RandomNumberGenerator.new())
		)
		var player := Player.new(&"action_%d" % seat, "Player %d" % (seat + 1), seat, 100, agent)
		view._seats.append(PlayerView.new(player))
	return view
