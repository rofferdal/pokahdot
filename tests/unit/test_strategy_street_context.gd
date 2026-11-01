extends "res://tests/support/poker_gut_test.gd"

const ContextScript := preload("res://scripts/core/agents/strategy_street_context.gd")


func test_action_records_preserve_street_and_legacy_constructor_defaults() -> void:
	var legacy := PublicActionRecord.new(0, PlayerAction.Kind.CALL, 10)
	var turn := _record(1, PlayerAction.Kind.RAISE, 60, &"turn")
	assert_eq(legacy.street, &"preflop")
	assert_eq(PublicActionRecord.blind(0, 5, true).street, &"preflop")
	assert_eq(PublicActionRecord.blind(1, 10, false).street, &"preflop")
	assert_eq(turn.copy().street, &"turn")
	assert_ne(turn.copy(), turn)


func test_prior_streets_and_blinds_do_not_count_as_current_actions() -> void:
	var history: Array[PublicActionRecord] = [
		PublicActionRecord.blind(0, 5, true),
		PublicActionRecord.blind(1, 10, false),
		_record(0, PlayerAction.Kind.RAISE, 20, &"preflop"),
		_record(1, PlayerAction.Kind.CALL, 20, &"preflop"),
		_record(1, PlayerAction.Kind.BET, 10, &"flop"),
	]
	var preflop := ContextScript.from_view(_view(&"preflop", 40, 0, history))
	var flop := ContextScript.from_view(_view(&"flop", 50, 10, history))
	assert_eq(preflop.hero_action_count, 1)
	assert_eq(preflop.hero_aggression_count, 1)
	assert_eq(preflop.latest_wager_increase, 10)
	assert_eq(preflop.hero_last_action_kind, PlayerAction.Kind.RAISE)
	assert_eq(flop.hero_action_count, 0)
	assert_eq(flop.hero_aggression_count, 0)
	assert_eq(flop.aggression_count, 1)
	assert_eq(flop.latest_wager_increase, 10)
	assert_eq(flop.hero_last_action_kind, -1)
	assert_false(flop.opponent_aggression_after_hero)
	var new_hand := ContextScript.from_view(_view(&"preflop", 15, 5, []))
	assert_eq(new_hand.hero_action_count, 0)
	assert_eq(new_hand.hero_last_action_kind, -1)
	assert_eq(new_hand.latest_wager_increase, 0)


func test_all_in_call_is_not_aggression_but_short_all_in_raise_is() -> void:
	var history: Array[PublicActionRecord] = [
		PublicActionRecord.blind(0, 5, true),
		PublicActionRecord.blind(1, 5, false),
		_record(2, PlayerAction.Kind.ALL_IN, 8),
		_record(0, PlayerAction.Kind.RAISE, 20),
		_record(1, PlayerAction.Kind.ALL_IN, 20),
		_record(3, PlayerAction.Kind.ALL_IN, 25),
	]
	var context := ContextScript.from_view(_view(&"preflop", 73, 5, history))
	assert_eq(context.aggression_count, 2)
	assert_eq(context.latest_wager_increase, 5)
	assert_eq(context.hero_aggression_count, 1)
	assert_true(context.opponent_aggression_after_hero)
	assert_eq(context.hero_action_count, 1)


func test_multiway_resistance_only_counts_after_hero_aggression() -> void:
	var history: Array[PublicActionRecord] = [
		_record(1, PlayerAction.Kind.RAISE, 30),
		_record(0, PlayerAction.Kind.RAISE, 50),
	]
	var view := _view(&"preflop", 80, 0, history)
	assert_false(ContextScript.from_view(view).opponent_aggression_after_hero)
	history.append(_record(2, PlayerAction.Kind.RAISE, 70))
	history.append(_record(1, PlayerAction.Kind.CALL, 70))
	view = _view(&"preflop", 190, 20, history)
	var context := ContextScript.from_view(view)
	assert_true(context.opponent_aggression_after_hero)
	assert_eq(context.aggression_count, 3)
	assert_eq(context.latest_wager_increase, 20)
	assert_eq(context.hero_aggression_count, 1)


func test_contestable_pot_includes_folded_chips_without_double_counting_targets() -> void:
	var history: Array[PublicActionRecord] = [
		PublicActionRecord.blind(0, 5, true),
		PublicActionRecord.blind(1, 10, false),
		_record(2, PlayerAction.Kind.CALL, 10),
		_record(0, PlayerAction.Kind.CALL, 10),
		_record(1, PlayerAction.Kind.CHECK, 10),
		_record(0, PlayerAction.Kind.BET, 20, &"flop"),
		_record(1, PlayerAction.Kind.RAISE, 40, &"flop"),
		_record(2, PlayerAction.Kind.FOLD, 0, &"flop"),
	]
	var context := ContextScript.from_view(_view(&"flop", 90, 20, history))
	assert_true(context.pot_is_reliable)
	assert_eq(context.contestable_pot_before_call, 90)
	assert_almost_eq(context.call_price, 20.0 / 110.0, 0.000001)


func test_complete_history_caps_unavailable_side_pots_at_prospective_contribution() -> void:
	var history: Array[PublicActionRecord] = [
		_record(0, PlayerAction.Kind.RAISE, 30),
		_record(1, PlayerAction.Kind.RAISE, 100),
		_record(2, PlayerAction.Kind.CALL, 100),
	]
	var view := _view(&"preflop", 230, 20, history)
	view._pots = _side_pots()
	var context := ContextScript.from_view(view)
	assert_true(context.pot_is_reliable)
	assert_eq(context.contestable_pot_before_call, 130)
	assert_almost_eq(context.call_price, 20.0 / 150.0, 0.000001)


func test_incomplete_side_pot_history_disables_cheap_call_credit() -> void:
	var view := _view(&"preflop", 230, 20, [])
	view._pots = _side_pots()
	var context := ContextScript.from_view(view)
	assert_false(context.pot_is_reliable)
	assert_eq(context.contestable_pot_before_call, 0)
	assert_eq(context.call_price, 1.0)


func test_scalar_only_synthetic_pot_keeps_legacy_price_and_context_is_detached() -> void:
	var view := _view(&"flop", 100, 10, [])
	var context := ContextScript.from_view(view)
	view.pot_amount = 1
	view.call_amount = 100
	assert_true(context.pot_is_reliable)
	assert_eq(context.contestable_pot_before_call, 100)
	assert_almost_eq(context.call_price, 10.0 / 110.0, 0.000001)
	assert_eq(ContextScript.from_view(null).call_price, 0.0)
	assert_false(ContextScript.from_view(null).pot_is_reliable)


func test_hand_controller_records_each_street_without_altering_history_order() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 100),
		Player.new(&"bot", "Bot", 1, 100),
	]
	players[0].agent = HumanAgent.new()
	players[1].agent = (
		ScriptedAgent
		. new(
			[
				PlayerAction.check_action(),
				PlayerAction.check_action(),
				PlayerAction.check_action(),
				PlayerAction.check_action(),
			]
		)
	)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var deck_rng := RandomNumberGenerator.new()
	deck_rng.seed = 91
	var button_rng := RandomNumberGenerator.new()
	button_rng.seed = 92
	var hand := HandController.new(table, Deck.new(), deck_rng, button_rng)
	assert_eq(hand.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	hand.submit_human_action(PlayerAction.call_action())
	hand.submit_human_action(PlayerAction.check_action())
	hand.submit_human_action(PlayerAction.check_action())
	assert_eq(
		hand.submit_human_action(PlayerAction.check_action()).status,
		StepResult.Status.HAND_COMPLETED,
	)
	var streets: Array[StringName] = []
	for record: PublicActionRecord in hand.get_view_for(0).action_history:
		streets.append(record.street)
	assert_eq(
		streets,
		[
			&"preflop",
			&"preflop",
			&"preflop",
			&"preflop",
			&"flop",
			&"flop",
			&"turn",
			&"turn",
			&"river",
			&"river"
		],
	)


func _view(
	street: StringName,
	pot: int,
	call: int,
	history: Array[PublicActionRecord],
) -> GameView:
	var view := GameView.new()
	view.street = street
	view.hero_seat = 0
	view.big_blind = 10
	view.pot_amount = pot
	view.call_amount = call
	view._action_history = history.duplicate()
	return view


func _record(
	seat: int, kind: PlayerAction.Kind, amount: int, street: StringName = &"preflop"
) -> PublicActionRecord:
	return PublicActionRecord.new(seat, kind, amount, PublicActionRecord.Kind.ACTION, street)


func _side_pots() -> Array[PotLayer]:
	return [PotLayer.new(90, 30, [0, 1, 2], [0, 1, 2]), PotLayer.new(140, 100, [1, 2], [1, 2])]
