extends "res://tests/support/poker_gut_test.gd"

const Fixtures := preload("res://tests/support/gui_visual_state_fixtures.gd")
const Harness := preload("res://tests/support/gui_scene_harness.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const PHONE_COUNTS: Array[int] = [2, 4, 6, 7]
const HERO_SEEDS: Dictionary[int, int] = {2: 1, 4: 8, 6: 2, 7: 17}
const OPPONENT_SEEDS: Dictionary[int, int] = {2: 4, 4: 1, 6: 4, 7: 1}
const SPLIT_SEEDS: Dictionary[int, int] = {2: 47, 4: 41, 6: 1, 7: 6}
const SIDE_POT_SEEDS: Dictionary[int, int] = {4: 2, 6: 1, 7: 1}
const NAMES: Array[String] = ["Human", "Leilani", "Haruto", "Youssef", "Chidi", "Yael", "Wei"]


class CallingAgent:
	extends Agent
	var shove_hand: int = 99
	var fold_preflop: bool = false

	func choose_action(view: GameView) -> PlayerAction:
		if fold_preflop and view.street == &"preflop":
			return PlayerAction.fold_action()
		if view.hand_number >= shove_hand and PlayerAction.Kind.ALL_IN in view.legal_actions:
			return PlayerAction.all_in_action()
		return (
			PlayerAction.check_action()
			if PlayerAction.Kind.CHECK in view.legal_actions
			else PlayerAction.call_action()
		)


func test_real_hero_and_opponent_showdowns_name_the_winner_without_opening_a_menu() -> void:
	for count: int in PHONE_COUNTS:
		for hero_wins: bool in [true, false]:
			var seed_value: int = HERO_SEEDS[count] if hero_wins else OPPONENT_SEEDS[count]
			var match_instance: TournamentMatch = _match(count, seed_value)
			var before: GameView = _before_settlement(match_instance)
			assert_true(before.revealed_hole_cards.is_empty())
			var mounted: Dictionary = await _mount(match_instance, count)
			var table: PokerTableController = mounted.rendered.table
			table._advance_after_action_pause()
			assert_true(await mounted.harness.settle_layout())
			var view: GameView = table._bound_view
			assert_true(view.hand_complete)
			assert_eq(view.pot_awards.size(), 1)
			assert_eq(view.pot_awards[0].winner_seats.size(), 1)
			assert_eq(view.pot_awards[0].winner_seats[0] == 0, hero_wins)
			_assert_default_result(mounted)
			_assert_direct_pot_details(table)
			_dispose(mounted)


func test_real_split_pots_name_every_recipient_in_the_default_phone_result() -> void:
	for count: int in PHONE_COUNTS:
		var match_instance: TournamentMatch = _match(count, SPLIT_SEEDS[count])
		_before_settlement(match_instance)
		var mounted: Dictionary = await _mount(match_instance, count)
		var table: PokerTableController = mounted.rendered.table
		table._advance_after_action_pause()
		assert_true(await mounted.harness.settle_layout())
		assert_gt(table._bound_view.pot_awards[0].winner_seats.size(), 1)
		_assert_default_result(mounted)
		_assert_direct_pot_details(table)
		_dispose(mounted)


func test_real_side_pot_settlement_keeps_all_named_recipients_and_exact_shares_accessible() -> void:
	for count: int in SIDE_POT_SEEDS:
		var match_instance: TournamentMatch = _match(count, SIDE_POT_SEEDS[count], -1, 3)
		# Two legal check/call hands establish unequal stacks without editing core state.
		for completed_hand: int in range(2):
			_finish_hand(match_instance)
			match_instance.advance_one_action()
		_before_settlement(match_instance, true)
		var mounted: Dictionary = await _mount(match_instance, count)
		var table: PokerTableController = mounted.rendered.table
		table._advance_after_action_pause()
		assert_true(await mounted.harness.settle_layout())
		assert_gte(table._bound_view.pot_awards.size(), 2)
		_assert_default_result(mounted)
		_assert_direct_pot_details(table)
		_dispose(mounted)


func test_completed_hand_result_respects_the_pause_and_resets_for_the_next_hand() -> void:
	var match_instance: TournamentMatch = _match(4, HERO_SEEDS[4])
	_before_settlement(match_instance)
	var mounted: Dictionary = await _mount(match_instance, 4, 0.2)
	var table: PokerTableController = mounted.rendered.table
	table._advance_after_action_pause()
	assert_true(await mounted.harness.settle_layout())
	var hand_number: int = table._bound_view.hand_number
	var result_text: String = table._action_status.text
	assert_string_contains(result_text, "Human")
	await get_tree().create_timer(0.06).timeout
	assert_eq(table._bound_view.hand_number, hand_number)
	assert_eq(table._action_status.text, result_text)
	assert_eq(table._phone_more_button.text, "Pots")
	await get_tree().create_timer(0.2).timeout
	assert_eq(table._bound_view.hand_number, hand_number + 1)
	assert_false(table._action_status.text.begins_with("Winner"))
	assert_eq(table._phone_more_button.text, "More")
	_dispose(mounted)


func test_seven_long_named_recipients_fit_at_supported_numeric_boundaries() -> void:
	# Synthetic presentation stress only: real flow tests above establish legal
	# settlement. This supplemental view deliberately makes all seven seats
	# equal award recipients and retains legitimate public card reveals.
	var match_instance: TournamentMatch = _match(7, SPLIT_SEEDS[7])
	_finish_hand(match_instance)
	var view: GameView = match_instance.get_view_for(0)
	var names: Dictionary[int, String] = {
		0: "Human",
		1: "Santiago",
		2: "Priyanka",
		3: "Aleksiej",
		4: "Fernanda",
		5: "Leilanie",
		6: "Katarina",
	}
	var recipients: Array[int] = [0, 1, 2, 3, 4, 5, 6]
	var shares: Dictionary[int, int] = {}
	for player: PlayerView in view._seats:
		player.stack = 1000000
		player.all_in = false
		player.busted = false
		player.folded = false
		shares[player.seat] = 1000000
	view.pot_amount = 7000000
	view.big_blind = 1000000
	view.small_blind = 500000
	view._pot_awards = [PotAward.new(0, 7000000, recipients, shares)]
	var descriptor: Dictionary = Fixtures.by_id(&"showdown-long", 7)
	descriptor.view = view
	var harness: Node = Harness.new()
	add_child(harness)
	var rendered: Dictionary = harness.render(descriptor, Vector2i(360, 640))
	var table: PokerTableController = rendered.table
	table.bind_view(view, {}, names)
	assert_true(await harness.settle_layout())
	_stabilize_board_slot_names(table)
	var label: Label = table._action_status
	assert_true(label.is_visible_in_tree())
	assert_gte(label.get_theme_font_size("font_size"), 20)
	for seat: int in recipients:
		assert_lte(names[seat].length(), GuiNameCatalog.MAX_CODE_POINT_COUNT)
		assert_string_contains(label.text, names[seat])
	var text_failures := PackedStringArray()
	Invariants._validate_label_fit(label, "seven-recipient winner feedback", text_failures)
	assert_eq(text_failures, PackedStringArray())
	assert_eq(Invariants.validate(rendered), PackedStringArray(), "No boundary-layout exemptions")
	assert_false(table._phone_showdown_overlay.visible)
	table._phone_more_button.emit_signal("pressed")
	assert_true(table._phone_showdown_overlay.visible)
	for seat: int in recipients:
		assert_string_contains(table._phone_showdown_summary.text, "%s +1000000" % names[seat])
	table._close_phone_showdown()
	_dispose({"rendered": rendered, "harness": harness})


func test_long_names_with_combined_roles_keep_all_components_before_and_after_settlement() -> void:
	for count: int in PHONE_COUNTS:
		var descriptor: Dictionary = Fixtures.by_id(&"all-in-runout", count)
		var view: GameView = descriptor.view
		view.button_seat = 1 if count == 2 else 0
		view.small_blind_seat = 1
		view.big_blind_seat = 0 if count == 2 else 2
		view._seats[1].all_in = true
		view._seats[1].stack = 0
		var names: Dictionary[int, String] = {}
		for seat: int in range(count):
			names[seat] = "Human" if seat == 0 else "Santiago"
		var harness: Node = Harness.new()
		add_child(harness)
		var rendered: Dictionary = harness.render(descriptor, Vector2i(360, 640))
		var table: PokerTableController = rendered.table
		table.bind_view(view, {}, names)
		assert_true(await harness.settle_layout())
		assert_eq(Invariants.validate(rendered), PackedStringArray(), "Combined active roles")
		view.hand_complete = true
		view.hand_winner_seat = 1
		view._seats[1].stack = count * 1000000
		view._revealed_hole_cards = {1: [CardData.new(10, 0), CardData.new(10, 1)]}
		table.bind_view(view, {}, names)
		for dimensions: Vector2i in [Vector2i(360, 640), Vector2i(390, 744), Vector2i(360, 640)]:
			harness.resize_viewport(dimensions)
			assert_true(await harness.settle_layout())
			assert_eq(
				Invariants.validate(rendered),
				PackedStringArray(),
				"Positive awarded stack and ten cards"
			)
			var token: Control = table._seat_widgets[1]
			var parts: String = ""
			for badge_name: String in ["Badge", "BadgeRow2", "BadgeRow3"]:
				var badge := token.find_child(badge_name, true, false) as Label
				if badge != null and badge.visible:
					parts += badge.text
			assert_string_contains(parts, "SB")
			assert_string_contains(parts, "AI")
			if count == 2:
				assert_string_contains(parts, "D")
		_dispose({"rendered": rendered, "harness": harness})


func test_acting_heads_up_dealer_keeps_long_name_stack_roles_and_previous_action() -> void:
	for stack_value: int in [1000, 1000000]:
		var descriptor: Dictionary = Fixtures.by_id(&"bot-turn", 2)
		var view: GameView = descriptor.view
		view.button_seat = 1
		view.small_blind_seat = 1
		view.big_blind_seat = 0
		view.acting_seat = 1
		view._seats[1].stack = stack_value
		view._action_history = [PublicActionRecord.new(1, PlayerAction.Kind.RAISE, stack_value)]
		var harness: Node = Harness.new()
		add_child(harness)
		var rendered: Dictionary = harness.render(descriptor, Vector2i(360, 640))
		var table: PokerTableController = rendered.table
		table.bind_view(view, {}, {0: "Human", 1: "Santiago"})
		assert_true(await harness.settle_layout())
		assert_eq(
			Invariants.validate(rendered),
			PackedStringArray(),
			"Acting heads-up fields must all fit"
		)
		var panel: Control = table._seat_widgets[1]
		assert_eq((panel.find_child("Stack", true, false) as Label).text, str(stack_value))
		assert_eq((panel.find_child("ActionBadge", true, false) as Label).text, "R%d" % stack_value)
		_dispose({"rendered": rendered, "harness": harness})


func test_real_fold_wins_remain_named_without_revealing_opponents() -> void:
	for count: int in PHONE_COUNTS:
		var match_instance: TournamentMatch = _match(count, 1, -1, 99, true)
		_before_fold_settlement(match_instance)
		var mounted: Dictionary = await _mount(match_instance, count)
		var table: PokerTableController = mounted.rendered.table
		table._advance_after_action_pause()
		assert_true(await mounted.harness.settle_layout())
		assert_true(table._bound_view.hand_complete)
		assert_eq(table._bound_view.hand_winner_seat, 0)
		assert_true(table._bound_view.revealed_hole_cards.is_empty())
		assert_true(table._bound_view.showdown_results.is_empty())
		assert_string_contains(table._action_status.text, "Human")
		_assert_default_result(mounted)
		_assert_direct_pot_details(table)
		assert_string_contains(table._phone_showdown_summary.text, "Human")
		_dispose(mounted)


func test_showdown_winner_feedback_does_not_reveal_a_folded_opponents_cards() -> void:
	var match_instance: TournamentMatch = _match(4, 1, 3)
	_before_settlement(match_instance)
	var mounted: Dictionary = await _mount(match_instance, 4)
	var table: PokerTableController = mounted.rendered.table
	table._advance_after_action_pause()
	assert_true(await mounted.harness.settle_layout())
	assert_false(table._bound_view.revealed_hole_cards.has(3))
	assert_false(table._bound_view.showdown_results.has(3))
	_assert_default_result(mounted)
	var folded_cards := table._seat_widgets[3].find_child("HoleCards", true, false) as Control
	assert_eq(folded_cards.get_child_count(), 2)
	for field: Node in folded_cards.get_children():
		assert_true(str(field.name).begins_with("HoleCardField"))
		assert_true(field is Label)
		assert_eq((field as Label).text, "", "Folded card fields must contain no private card text")
	assert_null(folded_cards.find_child("ShowdownCard1", false, false))
	assert_null(folded_cards.find_child("CardBack1", false, false))
	_assert_direct_pot_details(table)
	_dispose(mounted)


func _match(
	count: int,
	seed_value: int,
	folded_seat: int = -1,
	shove_hand: int = 99,
	fold_opponents: bool = false,
) -> TournamentMatch:
	var roles: Dictionary[int, StringName] = {0: &"human"}
	var agents: Dictionary[int, Agent] = {0: HumanAgent.new()}
	for seat: int in range(1, count):
		roles[seat] = &"scripted"
		var agent := CallingAgent.new()
		agent.fold_preflop = fold_opponents or seat == folded_seat
		agent.shove_hand = shove_hand
		agents[seat] = agent
	var match_instance := TournamentMatch.new(
		ResolvedTournamentConfig.new(count, 100, 5, 10, seed_value, &"single_table", roles), agents
	)
	assert_ne(match_instance.start(1).status, StepResult.Status.ERROR)
	return match_instance


func _before_settlement(match_instance: TournamentMatch, shove: bool = false) -> GameView:
	for transition: int in range(300):
		var view: GameView = match_instance.get_view_for(0)
		if view.street == &"river" and view.acting_seat == Table.NO_SEAT:
			assert_false(view.hand_complete)
			return view
		if view.hand_complete:
			fail_test("Fixture completed before reaching the river settlement boundary")
			return view
		_step(match_instance, view, shove)
	fail_test("Fixture did not reach settlement within 300 transitions")
	return match_instance.get_view_for(0)


func _before_fold_settlement(match_instance: TournamentMatch) -> void:
	for transition: int in range(50):
		var view: GameView = match_instance.get_view_for(0)
		var remaining: int = 0
		for player: PlayerView in view.seats:
			if not player.folded:
				remaining += 1
		if remaining == 1 and view.acting_seat == Table.NO_SEAT:
			assert_false(view.hand_complete)
			return
		_step(match_instance, view, false)
	fail_test("Fixture did not reach fold settlement within 50 transitions")


func _finish_hand(match_instance: TournamentMatch) -> void:
	for transition: int in range(300):
		var view: GameView = match_instance.get_view_for(0)
		if view.hand_complete:
			return
		_step(match_instance, view, false)
	fail_test("Fixture hand exceeded 300 transitions")


func _step(match_instance: TournamentMatch, view: GameView, shove: bool) -> void:
	var result: StepResult
	if view.acting_seat == 0:
		var action: PlayerAction = (
			PlayerAction.all_in_action()
			if shove and PlayerAction.Kind.ALL_IN in view.legal_actions
			else (
				PlayerAction.check_action()
				if PlayerAction.Kind.CHECK in view.legal_actions
				else PlayerAction.call_action()
			)
		)
		result = match_instance.submit_human_action_without_advance(action)
	else:
		result = match_instance.advance_one_action()
	assert_ne(result.status, StepResult.Status.ERROR)


func _mount(match_instance: TournamentMatch, count: int, hand_pause: float = 60.0) -> Dictionary:
	var harness: Node = Harness.new()
	add_child(harness)
	var rendered: Dictionary = harness.render(
		Fixtures.by_id(&"human-turn-preflop", count), Vector2i(360, 640)
	)
	var table: PokerTableController = rendered.table
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 60.0
	timing.showdown_pause_seconds = hand_pause
	table.set_action_timing_config(timing)
	var names: Dictionary[int, String] = {}
	for seat: int in range(count):
		names[seat] = NAMES[seat]
	table.bind_match(match_instance, 0, {}, names)
	table._action_pacer.cancel()
	assert_true(await harness.settle_layout())
	var descriptor: Dictionary = Fixtures.by_id(&"human-turn-river", count)
	descriptor.view = table._bound_view
	rendered.descriptor = descriptor
	_stabilize_board_slot_names(table)
	assert_eq(Invariants.validate(rendered), PackedStringArray(), "Pre-settlement content must fit")
	return {"harness": harness, "rendered": rendered}


func _stabilize_board_slot_names(table: PokerTableController) -> void:
	# The controller queues old cards for deletion before adding replacements.
	# Same-frame rebinding can give new nodes generated names; keep fixture
	# paths tied to logical card slots without changing any geometry or text.
	for index: int in range(table._card_slots.get_child_count()):
		table._card_slots.get_child(index).name = "CardSlot%d" % (index + 1)


func _assert_default_result(mounted: Dictionary) -> void:
	var table: PokerTableController = mounted.rendered.table
	_stabilize_board_slot_names(table)
	var label: Label = table._action_status
	assert_true(label.is_visible_in_tree())
	assert_gte(label.get_theme_font_size("font_size"), 20)
	assert_false(table._phone_showdown_overlay.visible, "Result must not obscure revealed cards")
	assert_false(table._phone_overflow_menu.visible)
	assert_false(table._modal_guard.is_active())
	assert_eq(table._phone_more_button.text, "Pots")
	for award: PotAward in table._bound_view.pot_awards:
		for seat: int in award.winner_seats:
			assert_string_contains(label.text, NAMES[seat])
	assert_true(
		(
			label.text.begins_with("Winner:")
			or label.text.begins_with("Winners:")
			or label.text.begins_with("Split pot:")
			or (table._bound_view.tournament_status == &"finished" and "wins" in label.text)
		),
		"Default feedback must identify winners, not merely say Hand complete"
	)
	var descriptor: Dictionary = Fixtures.by_id(&"showdown-long", table._bound_view.seats.size())
	descriptor.view = table._bound_view
	mounted.rendered.descriptor = descriptor
	var result_failures := PackedStringArray()
	Invariants._validate_label_fit(label, "phone winner feedback", result_failures)
	assert_eq(result_failures, PackedStringArray(), "The entire named result must fit")
	assert_eq(
		Invariants.validate(mounted.rendered),
		PackedStringArray(),
		"Completed-hand content must fit"
	)
	for seat: int in table._bound_view.revealed_hole_cards:
		if seat == table._bound_view.hero_seat:
			continue
		var cards := table._seat_widgets[seat].find_child("HoleCards", true, false) as Control
		assert_true(cards.visible, "Legitimately revealed opponent cards must remain visible")


func _assert_direct_pot_details(table: PokerTableController) -> void:
	table._phone_more_button.emit_signal("pressed")
	assert_true(table._phone_showdown_overlay.visible)
	assert_false(table._phone_overflow_menu.visible)
	var summary: String = table._phone_showdown_summary.text
	for award: PotAward in table._bound_view.pot_awards:
		assert_string_contains(summary, str(award.amount))
		for seat: int in award.winner_seats:
			assert_string_contains(summary, "%s +%d" % [NAMES[seat], award.amounts_by_seat[seat]])
	table._close_phone_showdown()


func _dispose(mounted: Dictionary) -> void:
	var table: PokerTableController = mounted.rendered.table
	table._action_pacer.cancel()
	table._modal_guard.cancel_advance()
	mounted.harness.free()
