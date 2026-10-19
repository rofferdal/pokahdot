extends "res://tests/support/poker_gut_test.gd"

const ModelScript := preload("res://scripts/core/agents/strategy_decision_model.gd")
const ParametersScript := preload("res://scripts/core/agents/strategy_decision_model_parameters.gd")


func test_free_check_is_selected_when_no_call_price_is_due() -> void:
	var parameters := ParametersScript.new()
	parameters.bluff_rate = 0
	var view := _view("7S 2H", 0, 0, 100)
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CHECK, PlayerAction.Kind.BET]

	var action: PlayerAction = _model(2001, parameters).choose_action(view)

	assert_eq(action.kind, PlayerAction.Kind.CHECK)


func test_call_and_fold_are_selected_from_their_available_passive_actions() -> void:
	var cheap_call := _view("AS AH", 100, 1, 100)
	cheap_call._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL]
	assert_eq(
		_model(2002, ParametersScript.new()).choose_action(cheap_call).kind, PlayerAction.Kind.CALL
	)

	var parameters := ParametersScript.new()
	parameters.tight_vs_loose = 100
	var expensive_call := _view("7S 2H", 20, 80, 100)
	expensive_call._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL]
	assert_eq(_model(2003, parameters).choose_action(expensive_call).kind, PlayerAction.Kind.FOLD)


func test_unavailable_bets_and_raises_are_never_requested() -> void:
	var parameters := ParametersScript.new()
	parameters.bluff_rate = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_bet = 100
	var model := _model(2004, parameters)
	var no_bet_view := _view("7S 2H", 0, 0, 100)
	no_bet_view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CHECK]
	var no_raise_view := _view("7S 2H", 100, 10, 100)
	no_raise_view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL]

	var no_bet_action: PlayerAction = model.choose_action(no_bet_view)
	var no_raise_action: PlayerAction = model.choose_action(no_raise_view)

	assert_true(no_bet_action.kind in no_bet_view.legal_actions)
	assert_true(no_bet_action.kind not in [PlayerAction.Kind.BET, PlayerAction.Kind.RAISE])
	assert_true(no_raise_action.kind in no_raise_view.legal_actions)
	assert_true(no_raise_action.kind not in [PlayerAction.Kind.BET, PlayerAction.Kind.RAISE])


func test_short_stack_call_and_all_in_actions_remain_legal() -> void:
	var parameters := ParametersScript.new()
	parameters.tight_vs_loose = 0
	var short_stack := _view("AS AH", 100, 1, 1)
	short_stack._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL]
	var call_action: PlayerAction = _model(2005, parameters).choose_action(short_stack)

	var all_in_view := _view("AS AH", 100, 1, 1)
	all_in_view._legal_actions = [PlayerAction.Kind.ALL_IN]
	var all_in_action: PlayerAction = _model(2006, parameters).choose_action(all_in_view)

	assert_has(short_stack.legal_actions, call_action.kind)
	assert_eq(all_in_action.kind, PlayerAction.Kind.ALL_IN)


func test_every_non_empty_legal_action_combination_returns_a_legal_action() -> void:
	var model := _model(2007, ParametersScript.new())
	var action_kinds: Array[PlayerAction.Kind] = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CHECK,
		PlayerAction.Kind.CALL,
		PlayerAction.Kind.BET,
		PlayerAction.Kind.RAISE,
		PlayerAction.Kind.ALL_IN,
	]

	for mask: int in range(1, 1 << action_kinds.size()):
		var view := _view("AS KD", 100, 10, 100)
		var legal_actions: Array[PlayerAction.Kind] = []
		for index: int in range(action_kinds.size()):
			if (mask & (1 << index)) != 0:
				legal_actions.append(action_kinds[index])
		view._legal_actions = legal_actions

		var action: PlayerAction = model.choose_action(view)

		assert_not_null(action, "Every non-empty legal action set must produce an action.")
		assert_has(view.legal_actions, action.kind)
		if action.has_wager_amount():
			assert_between(action.amount, view.minimum_wager_total, view.maximum_wager_total)


func test_seeded_property_regression_keeps_actions_and_wagers_legal() -> void:
	var seeds: Array[int] = [11, 29, 47, 83, 131]
	var card_sets: Array[String] = ["AS KD", "7S 2H", "9H 9D", "QS JH"]
	for seed_value: int in seeds:
		var view_rng := _rng(seed_value)
		var parameters := ParametersScript.new()
		parameters.tight_vs_loose = view_rng.randi_range(0, 100)
		parameters.passive_vs_aggressive = view_rng.randi_range(0, 100)
		parameters.call_vs_bet = view_rng.randi_range(0, 100)
		parameters.bluff_rate = view_rng.randi_range(0, 100)
		var model := _model(seed_value, parameters)
		for attempt: int in range(40):
			var stack: int = view_rng.randi_range(40, 200)
			var call: int = view_rng.randi_range(0, mini(40, stack))
			var view := _view(
				card_sets[view_rng.randi_range(0, card_sets.size() - 1)],
				view_rng.randi_range(0, 500),
				call,
				stack,
			)
			var mask: int = view_rng.randi_range(1, 63)
			view._legal_actions = _actions_for_mask(mask)

			var action: PlayerAction = model.choose_action(view)

			assert_not_null(action, "Seeded legal views must always produce an action.")
			assert_has(view.legal_actions, action.kind)
			assert_true(action.has_valid_shape())
			if action.has_wager_amount():
				assert_between(action.amount, view.minimum_wager_total, view.maximum_wager_total)


func test_seeded_realistic_views_do_not_use_fallback_for_normal_actions() -> void:
	var legal_masks: Array[int] = [3, 5, 21, 9, 33]
	for seed_value: int in range(75, 125):
		var parameters := ParametersScript.new()
		parameters.tight_vs_loose = seed_value % 101
		parameters.passive_vs_aggressive = (seed_value * 3) % 101
		parameters.call_vs_bet = (seed_value * 7) % 101
		parameters.bluff_rate = (seed_value * 11) % 101
		var model := _model(seed_value, parameters)
		var view := _view("AS KD", seed_value * 3, seed_value % 20, 100 + seed_value)
		view._legal_actions = _actions_for_mask(legal_masks[seed_value % legal_masks.size()])

		var action: PlayerAction = model.choose_action(view)
		var trace: Variant = model.get_last_decision_trace_for_testing()

		assert_has(view.legal_actions, action.kind)
		assert_ne(trace.selected_branch, &"fallback")
		if action.has_wager_amount():
			assert_between(action.amount, view.minimum_wager_total, view.maximum_wager_total)


func _model(seed_value: int, parameters: DecisionModelParameters) -> DecisionModel:
	var model: DecisionModel = ModelScript.new()
	assert_true(model.configure(parameters, _rng(seed_value)).is_empty())
	return model


func _actions_for_mask(mask: int) -> Array[PlayerAction.Kind]:
	var action_kinds: Array[PlayerAction.Kind] = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CHECK,
		PlayerAction.Kind.CALL,
		PlayerAction.Kind.BET,
		PlayerAction.Kind.RAISE,
		PlayerAction.Kind.ALL_IN,
	]
	var actions: Array[PlayerAction.Kind] = []
	for index: int in range(action_kinds.size()):
		if (mask & (1 << index)) != 0:
			actions.append(action_kinds[index])
	return actions


func _view(card_codes: String, pot: int, call: int, stack: int) -> GameView:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, stack),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	for card: CardData in _cards(card_codes):
		players[0].add_hole_card(card)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var view := (
		GameView
		. for_hand(
			table,
			0,
			BettingRound.new(table, 0, call),
			PotManager.new(),
			[],
			&"preflop",
			[],
			[],
			{},
		)
	)
	view.pot_amount = pot
	return view


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


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
