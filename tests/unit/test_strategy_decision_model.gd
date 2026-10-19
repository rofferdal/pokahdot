extends "res://tests/support/poker_gut_test.gd"

const StrategyModelScript := preload("res://scripts/core/agents/strategy_decision_model.gd")
const StrategyParametersScript := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)


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
	var model := _model(42)
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


func test_continuation_uses_both_seeded_style_rolls_when_both_actions_are_legal() -> void:
	var aggressive_parameters := StrategyParametersScript.new()
	aggressive_parameters.passive_vs_aggressive = 100
	aggressive_parameters.call_vs_bet = 100
	var aggressive_model := _model_with_parameters(52, aggressive_parameters)
	var aggressive_view := _view_for_call_with_cards("AS AH", 100, 10, 100, 0)
	var aggressive_action: PlayerAction = aggressive_model.choose_action(aggressive_view)
	var aggressive_trace: Variant = aggressive_model.get_last_decision_trace_for_testing()

	var passive_parameters := StrategyParametersScript.new()
	passive_parameters.passive_vs_aggressive = 100
	passive_parameters.call_vs_bet = 0
	var passive_model := _model_with_parameters(52, passive_parameters)
	var passive_view := _view_for_call_with_cards("AS AH", 100, 10, 100, 0)
	var passive_action: PlayerAction = passive_model.choose_action(passive_view)
	var passive_trace: Variant = passive_model.get_last_decision_trace_for_testing()

	assert_eq(aggressive_action.kind, PlayerAction.Kind.RAISE)
	assert_eq(aggressive_trace.selected_branch, &"continue_aggressive")
	assert_eq(passive_action.kind, PlayerAction.Kind.CALL)
	assert_eq(passive_trace.selected_branch, &"continue_passive")


func test_only_passive_legal_chooses_call_without_rng_rolls() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_bet = 100
	var model := _model_with_parameters(53, parameters)
	var view := _view_for_call_with_cards("AS AH", 100, 10, 10, 0)
	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.CALL)
	assert_eq(trace.selected_branch, &"passive_only")


func test_only_aggressive_legal_chooses_raise_without_passive_fallback() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.passive_vs_aggressive = 0
	parameters.call_vs_bet = 0
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
