# gdlint: disable=max-public-methods
extends "res://tests/support/poker_gut_test.gd"

const StrategyModelScript := preload("res://scripts/core/agents/strategy_decision_model.gd")
const StrategyParametersScript := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)


func test_strategy_sizing_obeys_live_repeated_raise_limits_without_fallback() -> void:
	for replay_seed: int in [1, 7, 23, 104729]:
		var players: Array[Player] = []
		for seat: int in range(3):
			players.append(Player.new(StringName("p%d" % seat), "Player", seat, 1000))
		players[2].add_hole_card(CardData.new(14, CardData.Suit.SPADES))
		players[2].add_hole_card(CardData.new(14, CardData.Suit.HEARTS))
		var table := Table.new(players, 5, 10)
		var round := BettingRound.new(table, 0, 10)
		assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
		assert_true(round.apply_action(1, PlayerAction.raise_to(60)).is_ok())
		var view := GameView.for_preflop(table, 2, round, PotManager.new(), [])
		assert_eq(view.minimum_wager_total, 90)
		var parameters := StrategyParametersScript.new()
		parameters.tight_vs_loose = 100
		parameters.call_vs_raise = 100
		parameters.bluff_rate = 0
		var action := _model_with_parameters(replay_seed, parameters).choose_action(view)
		assert_has(view.legal_actions, action.kind)
		if action.kind == PlayerAction.Kind.RAISE:
			assert_between(action.amount, 90, 1000)
		assert_true(round.apply_action(2, action).is_ok(), "seed %d" % replay_seed)


func test_configuration_rejects_missing_mismatched_and_invalid_parameters() -> void:
	var model: DecisionModel = StrategyModelScript.new()
	var invalid_parameters := StrategyParametersScript.new()
	invalid_parameters.bluff_rate = 101

	assert_false(model.configure(null, _rng(1)).is_empty())
	assert_false(model.configure(RandomDecisionModelParameters.new(), _rng(1)).is_empty())
	assert_false(model.configure(invalid_parameters, _rng(1)).is_empty())
	assert_false(model.configure(StrategyParametersScript.new(), null).is_empty())


func test_same_seed_and_view_produce_same_legal_action_sequence() -> void:
	var first := _model(9876)
	var second := _model(9876)
	var view := _view_for_actor()
	var first_actions: Array[String] = []
	var second_actions: Array[String] = []

	for _index: int in range(20):
		first_actions.append(_action_signature(first.choose_action(view)))
		second_actions.append(_action_signature(second.choose_action(view)))

	assert_eq(first_actions, second_actions)
	for action_signature: String in first_actions:
		assert_ne(action_signature, "null")


func test_baseline_prefers_check_then_call_then_fold() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.passive_vs_aggressive = 0
	parameters.call_vs_raise = 0
	var model := _model_with_parameters(42, parameters)
	var check_view := _view_for_check()
	var call_view := _view_for_actor()

	assert_eq(model.choose_action(check_view).kind, PlayerAction.Kind.CHECK)
	assert_eq(model.choose_action(call_view).kind, PlayerAction.Kind.CALL)


func test_policy_keeps_free_check_as_the_passive_baseline() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 0
	var model := _model_with_parameters(43, parameters)
	var view := _view_for_check_with_cards("7S 2H")

	assert_eq(model.choose_action(view).kind, PlayerAction.Kind.CHECK)


func test_policy_folds_weak_hand_when_call_is_not_free() -> void:
	var model := _model_with_tightness(44, 50)
	var view := _view_for_call_with_cards("7S 2H", 100, 10, 100, 0)

	assert_eq(model.choose_action(view).kind, PlayerAction.Kind.FOLD)


func test_policy_folds_a_missed_river_flush_draw_without_future_value() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 100
	parameters.bluff_rate = 0
	var model := _model_with_parameters(440, parameters)
	var view := _river_call_view("AS KS", "2S 7S 9D 4H JC")

	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.FOLD)
	assert_eq(trace.hand_potential_band, &"weak")
	assert_eq(trace.selected_branch, &"fold")


func test_policy_continues_strong_hand_when_call_price_is_reasonable() -> void:
	var model := _model_with_tightness(45, 50)
	var view := _view_for_call_with_cards("AS AH", 100, 10, 100, 0)
	var action: PlayerAction = model.choose_action(view)

	assert_true(action.kind in [PlayerAction.Kind.CALL, PlayerAction.Kind.RAISE])


func test_policy_uses_call_price_and_stack_pressure_for_marginal_hands() -> void:
	var cheap_call := _view_for_call_with_cards("QS JH", 100, 1, 100, 0)
	var expensive_call := _view_for_call_with_cards("QS JH", 20, 80, 100, 0)
	var deep_stack := _view_for_call_with_cards("QS JH", 100, 10, 100, 0)
	var short_stack := _view_for_call_with_cards("QS JH", 100, 10, 10, 0)
	var model := _model_with_tightness(46, 95)
	var cheap_action: PlayerAction = model.choose_action(cheap_call)
	var expensive_action: PlayerAction = model.choose_action(expensive_call)
	var deep_action: PlayerAction = model.choose_action(deep_stack)
	var short_action: PlayerAction = model.choose_action(short_stack)

	assert_true(cheap_action.kind in [PlayerAction.Kind.CALL, PlayerAction.Kind.RAISE])
	assert_eq(expensive_action.kind, PlayerAction.Kind.FOLD)
	assert_true(deep_action.kind in [PlayerAction.Kind.CALL, PlayerAction.Kind.RAISE])
	assert_eq(short_action.kind, PlayerAction.Kind.FOLD)


func test_policy_uses_later_position_as_a_small_continuation_credit() -> void:
	var early := _view_for_call_with_cards("JS 10C", 100, 10, 100, 0)
	var late := _view_for_call_with_cards("JS 10C", 100, 10, 100, 1)
	var model := _model_with_tightness(47, 95)

	assert_eq(model.choose_action(early).kind, PlayerAction.Kind.FOLD)
	assert_eq(model.choose_action(late).kind, PlayerAction.Kind.CALL)


func test_context_uses_heads_up_preflop_and_postflop_action_order() -> void:
	var model := _model(470)
	var preflop_views: Array[GameView] = _context_views(2, 0, &"preflop")
	var flop_views: Array[GameView] = _context_views(2, 0, &"flop")

	assert_eq(model._estimate(preflop_views[0]).context.position, 0)
	assert_eq(model._estimate(preflop_views[1]).context.position, 1)
	assert_eq(model._estimate(flop_views[1]).context.position, 0)
	assert_eq(model._estimate(flop_views[0]).context.position, 1)


func test_context_uses_multiway_street_order_for_every_recipient() -> void:
	var model := _model(471)
	var preflop_views: Array[GameView] = _context_views(4, 0, &"preflop")
	var flop_views: Array[GameView] = _context_views(4, 0, &"flop")
	var expected_preflop: Dictionary[int, int] = {3: 0, 0: 1, 1: 2, 2: 3}
	var expected_flop: Dictionary[int, int] = {1: 0, 2: 1, 3: 2, 0: 3}

	for seat: int in range(4):
		assert_eq(model._estimate(preflop_views[seat]).context.position, expected_preflop[seat])
		assert_eq(model._estimate(flop_views[seat]).context.position, expected_flop[seat])


func test_context_excludes_folded_seats_and_uses_public_stack_and_blind_values() -> void:
	var model := _model(472)
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100),
		Player.new(&"folded", "Folded", 1, 1000),
		Player.new(&"short", "Short", 2, 40),
		Player.new(&"deep", "Deep", 3, 70),
	]
	for player: Player in players:
		for card: CardData in _cards("AS KH"):
			player.add_hole_card(card)
	players[1].fold()
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var view := GameView.for_preflop(table, 0, BettingRound.new(table, 0, 30), PotManager.new(), [])
	var context: HandPotentialContext = model._estimate(view).context

	assert_eq(context.position, 1)
	assert_eq(context.active_opponents, 2)
	assert_eq(context.effective_stack, 70)
	assert_eq(context.big_blind, 10)
	assert_eq(view.minimum_wager_total, 40)


func test_opening_aggression_and_facing_wager_aggression_are_distinct() -> void:
	var opening_parameters := StrategyParametersScript.new()
	opening_parameters.passive_vs_aggressive = 100
	opening_parameters.call_vs_raise = 0
	var opening_model := _model_with_parameters(52, opening_parameters)
	var opening_action: PlayerAction = opening_model.choose_action(
		_view_for_check_with_cards("AS AH")
	)
	var opening_trace: Variant = opening_model.get_last_decision_trace_for_testing()

	var facing_wager_parameters := StrategyParametersScript.new()
	facing_wager_parameters.passive_vs_aggressive = 0
	facing_wager_parameters.call_vs_raise = 100
	var facing_wager_model := _model_with_parameters(52, facing_wager_parameters)
	var facing_wager_action: PlayerAction = facing_wager_model.choose_action(
		_view_for_call_with_cards("AS AH", 100, 10, 100, 0)
	)
	var facing_wager_trace: Variant = facing_wager_model.get_last_decision_trace_for_testing()

	assert_eq(opening_action.kind, PlayerAction.Kind.BET)
	assert_eq(opening_trace.selected_branch, &"continue_aggressive")
	assert_eq(facing_wager_action.kind, PlayerAction.Kind.RAISE)
	assert_eq(facing_wager_trace.selected_branch, &"continue_aggressive")


func test_each_context_ignores_the_other_aggression_parameter() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.passive_vs_aggressive = 0
	parameters.call_vs_raise = 100
	var model := _model_with_parameters(53, parameters)

	assert_eq(
		model.choose_action(_view_for_check_with_cards("AS AH")).kind,
		PlayerAction.Kind.CHECK,
	)
	parameters = StrategyParametersScript.new()
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = 0
	model = _model_with_parameters(53, parameters)
	assert_eq(
		model.choose_action(_view_for_call_with_cards("AS AH", 100, 10, 100, 0)).kind,
		PlayerAction.Kind.CALL,
	)


func test_only_passive_legal_chooses_call_without_rng_rolls() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = 100
	var model := _model_with_parameters(53, parameters)
	var view := _view_for_call_with_cards("AS AH", 100, 10, 10, 0)
	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.CALL)
	assert_eq(trace.selected_branch, &"passive_only")


func test_only_aggressive_legal_chooses_raise_without_passive_fallback() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.passive_vs_aggressive = 0
	parameters.call_vs_raise = 0
	var model := _model_with_parameters(54, parameters)
	var view := _view_for_call_with_cards("AS AH", 100, 10, 100, 0)
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.RAISE]
	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.RAISE)
	assert_eq(trace.selected_branch, &"aggressive_only")


func test_bluff_rate_zero_never_bluffs_and_aggression_does_not_change_that() -> void:
	var passive_parameters := StrategyParametersScript.new()
	passive_parameters.bluff_rate = 0
	passive_parameters.passive_vs_aggressive = 0
	var aggressive_parameters := StrategyParametersScript.new()
	aggressive_parameters.bluff_rate = 0
	aggressive_parameters.passive_vs_aggressive = 100
	var passive_model := _model_with_parameters(48, passive_parameters)
	var aggressive_model := _model_with_parameters(48, aggressive_parameters)
	var view := _view_for_bet_with_cards("7S 2H")

	assert_eq(passive_model.choose_action(view).kind, PlayerAction.Kind.CHECK)
	assert_eq(aggressive_model.choose_action(view).kind, PlayerAction.Kind.CHECK)


func test_bluff_rate_hundred_bluffs_weak_hand_when_bet_is_legal() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.bluff_rate = 100
	var model := _model_with_parameters(49, parameters)
	var view := _view_for_bet_with_cards("7S 2H")
	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.BET)
	assert_eq(action.amount, view.minimum_wager_total)
	assert_eq(trace.hand_potential_band, &"weak")
	assert_eq(trace.selected_branch, &"bluff_bet")


func test_bluff_rate_hundred_bluffs_weak_hand_when_raise_is_legal() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.bluff_rate = 100
	var model := _model_with_parameters(50, parameters)
	var view := _view_for_call_with_cards("7S 2H", 100, 10, 100, 0)
	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.RAISE)
	assert_eq(action.amount, view.minimum_wager_total)
	assert_eq(trace.hand_potential_band, &"weak")
	assert_eq(trace.selected_branch, &"bluff_raise")


func test_seeded_bluff_rolls_are_reproducible_for_the_same_rate() -> void:
	var first_parameters := StrategyParametersScript.new()
	first_parameters.bluff_rate = 50
	var second_parameters := StrategyParametersScript.new()
	second_parameters.bluff_rate = 50
	var first := _model_with_parameters(51, first_parameters)
	var second := _model_with_parameters(51, second_parameters)
	var first_actions: Array[String] = []
	var second_actions: Array[String] = []

	for _attempt: int in range(24):
		var view := _view_for_bet_with_cards("7S 2H")
		first_actions.append(_action_signature(first.choose_action(view)))
		second_actions.append(_action_signature(second.choose_action(view)))

	assert_eq(first_actions, second_actions)


func test_every_strategy_decision_is_legal_and_wager_is_in_range() -> void:
	var model := _model(1234)
	var view := _view_for_actor()

	for _index: int in range(100):
		var action: PlayerAction = model.choose_action(view)
		assert_has(view.legal_actions, action.kind)
		if action.has_wager_amount():
			assert_between(action.amount, view.minimum_wager_total, view.maximum_wager_total)


func test_decision_is_independent_of_opponent_hole_cards_and_deck_order() -> void:
	var model := _model(1234)
	var baseline_view := _view_with_opponent_cards("AC AD", 17)
	var alternate_view := _view_with_opponent_cards("2H 2S", 41)

	assert_eq(
		_action_signature(model.choose_action(baseline_view)),
		_action_signature(model.choose_action(alternate_view)),
	)


func test_decision_uses_snapshot_after_source_table_and_deck_mutation() -> void:
	var model := _model(5678)
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	players[0].add_hole_card(CardData.new(14, CardData.Suit.SPADES))
	players[0].add_hole_card(CardData.new(13, CardData.Suit.HEARTS))
	players[1].add_hole_card(CardData.new(2, CardData.Suit.CLUBS))
	players[1].add_hole_card(CardData.new(2, CardData.Suit.DIAMONDS))
	var table := Table.new(players, 5, 10)
	var deck := Deck.new()
	var view := GameView.for_preflop(table, 0, BettingRound.new(table, 0), PotManager.new(), [])
	var expected := _action_signature(model.choose_action(view))

	players[1].fold()
	players[0].commit_chips(50)
	deck.reset()
	var returned_seats: Array[PlayerView] = view.seats
	returned_seats[0].stack = 1
	returned_seats.clear()

	assert_eq(_action_signature(model.choose_action(view)), expected)


func _model(seed_value: int) -> DecisionModel:
	return _model_with_parameters(seed_value, StrategyParametersScript.new())


func _model_with_tightness(seed_value: int, tight_vs_loose: int) -> DecisionModel:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = tight_vs_loose
	return _model_with_parameters(seed_value, parameters)


func _model_with_parameters(seed_value: int, parameters: DecisionModelParameters) -> DecisionModel:
	var model: DecisionModel = StrategyModelScript.new()
	assert_true(model.configure(parameters, _rng(seed_value)).is_empty())
	return model


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _context_views(player_count: int, button: int, street: StringName) -> Array[GameView]:
	var players: Array[Player] = []
	for seat: int in range(player_count):
		var player := Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100)
		for card: CardData in _cards("AS KH"):
			player.add_hole_card(card)
		players.append(player)
	var table := Table.new(players, 5, 10)
	table.button_seat = button
	var betting_round := BettingRound.new(table, 0)
	var board: Array[CardData] = []
	if street != &"preflop":
		board = _cards("2C 7D 9S")
	var views: Array[GameView] = []
	for seat: int in range(player_count):
		(
			views
			. append(
				(
					GameView
					. for_hand(
						table,
						seat,
						betting_round,
						PotManager.new(),
						[],
						street,
						board,
						[],
						{},
					)
				)
			)
		)
	return views


func _view_for_actor() -> GameView:
	var players: Array[Player] = []
	for seat: int in range(3):
		players.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	players[1].commit_chips(5)
	players[2].commit_chips(10)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	return GameView.for_preflop(table, 0, BettingRound.new(table, 0, 10), PotManager.new(), [])


func _view_for_check() -> GameView:
	var players: Array[Player] = []
	for seat: int in range(2):
		players.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	return GameView.for_preflop(table, 0, BettingRound.new(table, 0), PotManager.new(), [])


func _view_for_check_with_cards(card_codes: String) -> GameView:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	for card: CardData in _cards(card_codes):
		players[0].add_hole_card(card)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	return GameView.for_preflop(table, 0, BettingRound.new(table, 0), PotManager.new(), [])


func _view_for_bet_with_cards(card_codes: String) -> GameView:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	for card: CardData in _cards(card_codes):
		players[0].add_hole_card(card)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var board: Array[CardData] = _cards("3C 8D KH")
	return (
		GameView
		. for_hand(
			table,
			0,
			BettingRound.new(table, 0),
			PotManager.new(),
			[],
			&"flop",
			board,
			[],
			{},
		)
	)


func _view_for_call_with_cards(
	card_codes: String, pot: int, call: int, stack: int, button: int
) -> GameView:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, stack),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	for card: CardData in _cards(card_codes):
		players[0].add_hole_card(card)
	var table := Table.new(players, 5, 10)
	table.button_seat = button
	var view := GameView.for_preflop(
		table, 0, BettingRound.new(table, 0, call), PotManager.new(), []
	)
	view.pot_amount = pot
	return view


func _river_call_view(card_codes: String, board_codes: String) -> GameView:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	for card: CardData in _cards(card_codes):
		players[0].add_hole_card(card)
	players[1].commit_chips(10)
	var table := Table.new(players, 5, 10)
	table.button_seat = 1
	var view := (
		GameView
		. for_hand(
			table,
			0,
			BettingRound.new(table, 0, 10),
			PotManager.new(),
			[],
			&"river",
			_cards(board_codes),
			[],
			{},
		)
	)
	view.pot_amount = 100
	return view


func _view_with_opponent_cards(card_codes: String, deck_seed: int) -> GameView:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	players[0].add_hole_card(CardData.new(14, CardData.Suit.SPADES))
	players[0].add_hole_card(CardData.new(13, CardData.Suit.HEARTS))
	for card: CardData in _cards(card_codes):
		players[1].add_hole_card(card)
	var deck := Deck.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = deck_seed
	deck.shuffle(rng)
	var table := Table.new(players, 5, 10)
	return GameView.for_preflop(table, 0, BettingRound.new(table, 0), PotManager.new(), [])


func _cards(card_codes: String) -> Array[CardData]:
	var cards: Array[CardData] = []
	for token: String in card_codes.split(" "):
		var rank_text := token.substr(0, token.length() - 1)
		var rank: int = int(rank_text)
		if rank_text == "A":
			rank = 14
		elif rank_text == "K":
			rank = 13
		elif rank_text == "Q":
			rank = 12
		elif rank_text == "J":
			rank = 11
		var suit: CardData.Suit = CardData.Suit.CLUBS
		match token.right(1):
			"C":
				suit = CardData.Suit.CLUBS
			"D":
				suit = CardData.Suit.DIAMONDS
			"H":
				suit = CardData.Suit.HEARTS
			"S":
				suit = CardData.Suit.SPADES
		cards.append(CardData.new(rank, suit))
	return cards


func _action_signature(action: PlayerAction) -> String:
	if action == null:
		return "null"
	return "%d:%d" % [action.kind, action.amount]
