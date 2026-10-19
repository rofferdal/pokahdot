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
	var model: DecisionModel = StrategyModelScript.new()
	assert_true(model.configure(StrategyParametersScript.new(), _rng(seed_value)).is_empty())
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
