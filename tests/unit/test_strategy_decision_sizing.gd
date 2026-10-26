extends "res://tests/support/poker_gut_test.gd"

const StrategyModelScript := preload("res://scripts/core/agents/strategy_decision_model.gd")
const StrategyParametersScript := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)


func test_marginal_aggression_targets_approximately_half_pot() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = 100
	var model := _model_with_parameters(55, parameters)
	var view := _view_for_bet_with_cards("AS KD")
	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.BET)
	assert_eq(action.amount, 50)
	assert_eq(trace.hand_potential_band, &"marginal")
	assert_eq(trace.selected_branch, &"continue_aggressive")


func test_strong_aggression_targets_approximately_one_pot() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = 100
	var model := _model_with_parameters(56, parameters)
	var view := _view_for_bet_with_cards("9H 9D", 100, 100, "2C 7D 9S")
	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.BET)
	assert_eq(action.amount, 100)
	assert_eq(trace.hand_potential_band, &"strong")
	assert_eq(trace.selected_branch, &"continue_aggressive")


func test_premium_aggression_selects_all_in_as_a_wager_total() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = 100
	var model := _model_with_parameters(57, parameters)
	var view := _view_for_bet_with_cards("AS 5S", 100, 30, "2S 7S KS")
	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.BET)
	assert_eq(action.amount, view.maximum_wager_total)
	assert_eq(action.amount, 30)
	assert_eq(trace.hand_potential_band, &"premium")
	assert_eq(trace.selected_branch, &"continue_aggressive")


func test_raise_sizing_uses_half_of_the_unmatched_pot() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = 100
	var model := _model_with_parameters(58, parameters)
	var view := _view_for_call_with_cards("AS KD", 100, 10, 100, 0)
	var action: PlayerAction = model.choose_action(view)

	assert_eq(action.kind, PlayerAction.Kind.RAISE)
	assert_eq(action.amount, 50)
	assert_between(action.amount, view.minimum_wager_total, view.maximum_wager_total)


func test_strong_raise_uses_the_full_unmatched_pot_target() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = 100
	var model := _model_with_parameters(59, parameters)
	var view := _view_for_call_with_cards("9H 9D", 100, 10, 200, 0, "2C 7D 9S")
	var action: PlayerAction = model.choose_action(view)
	var trace: Variant = model.get_last_decision_trace_for_testing()

	assert_eq(action.kind, PlayerAction.Kind.RAISE)
	assert_eq(action.amount, 100)
	assert_eq(trace.hand_potential_band, &"strong")


func test_marginal_raise_preserves_existing_wager_in_target_total() -> void:
	var parameters := StrategyParametersScript.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = 100
	var model := _model_with_parameters(60, parameters)
	var view := _view_for_call_with_cards("AS KD", 100, 10, 100, 0, "", 5)
	var action: PlayerAction = model.choose_action(view)

	assert_eq(action.kind, PlayerAction.Kind.RAISE)
	assert_eq(action.amount, 55)
	assert_eq(_seat_view(view, view.hero_seat).bet_this_round, 5)


func _seat_view(view: GameView, seat: int) -> PlayerView:
	for player_view: PlayerView in view.seats:
		if player_view.seat == seat:
			return player_view
	return null


func _model_with_parameters(seed_value: int, parameters: DecisionModelParameters) -> DecisionModel:
	var model: DecisionModel = StrategyModelScript.new()
	assert_true(model.configure(parameters, _rng(seed_value)).is_empty())
	return model


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _view_for_bet_with_cards(
	card_codes: String,
	pot: int = 100,
	stack: int = 100,
	board_codes: String = "3C 8D KH",
) -> GameView:
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
			BettingRound.new(table, 0),
			PotManager.new(),
			[],
			&"flop",
			_cards(board_codes),
			[],
			{},
		)
	)
	view.pot_amount = pot
	return view


func _view_for_call_with_cards(
	card_codes: String,
	pot: int,
	call: int,
	stack: int,
	button: int,
	board_codes: String = "",
	existing_wager: int = 0,
) -> GameView:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, stack + existing_wager),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	if existing_wager > 0:
		players[0].commit_chips(existing_wager)
	for card: CardData in _cards(card_codes):
		players[0].add_hole_card(card)
	var table := Table.new(players, 5, 10)
	table.button_seat = button
	var betting_round := BettingRound.new(table, 0, existing_wager + call)
	var view: GameView
	if board_codes.is_empty():
		view = GameView.for_preflop(table, 0, betting_round, PotManager.new(), [])
	else:
		view = (
			GameView
			. for_hand(
				table,
				0,
				betting_round,
				PotManager.new(),
				[],
				&"flop",
				_cards(board_codes),
				[],
				{},
			)
		)
	view.pot_amount = pot
	return view


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
