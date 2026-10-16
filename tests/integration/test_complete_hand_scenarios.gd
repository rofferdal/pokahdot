extends "res://tests/support/poker_gut_test.gd"


class RiggedDeck:
	extends Deck
	var draw_order: Array[CardData] = []

	func shuffle(_rng: RandomNumberGenerator) -> void:
		_cards = draw_order.duplicate()
		_cards.reverse()


func test_checked_down_hand_reaches_showdown_with_five_board_cards() -> void:
	var players := _heads_up_players(
		100,
		[
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
		]
	)
	var controller := _controller(players)

	assert_eq(controller.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_eq(
		controller.submit_human_action(PlayerAction.call_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN,
	)
	assert_eq(controller.state, HandController.State.FLOP)
	assert_eq(controller.community_cards.size(), 3)
	assert_eq(
		controller.submit_human_action(PlayerAction.check_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN,
	)
	assert_eq(controller.state, HandController.State.TURN)
	assert_eq(controller.community_cards.size(), 4)
	assert_eq(
		controller.submit_human_action(PlayerAction.check_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN,
	)
	assert_eq(controller.state, HandController.State.RIVER)
	assert_eq(controller.community_cards.size(), 5)

	var result: StepResult = controller.submit_human_action(PlayerAction.check_action())

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	assert_eq(controller.showdown_hands.size(), 2)
	assert_eq(controller.pot_awards.size(), 1)
	assert_eq(controller.events[-1].kind, DomainEvent.Kind.HAND_COMPLETED)
	assert_chip_total(_stacks(players), 200)


func test_fold_after_flop_awards_the_pot_without_revealing_cards() -> void:
	var players := _heads_up_players(100, [PlayerAction.check_action(), PlayerAction.bet_to(10)])
	var controller := _controller(players)
	controller.start()
	controller.submit_human_action(PlayerAction.call_action())

	var result: StepResult = controller.submit_human_action(PlayerAction.fold_action())

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	assert_eq(controller.community_cards.size(), 3)
	assert_eq(controller.winner_seat, 1)
	assert_true(controller.showdown_hands.is_empty())
	assert_eq(controller.events[-2].kind, DomainEvent.Kind.POT_AWARDED)
	assert_eq(controller.events[-1].kind, DomainEvent.Kind.HAND_COMPLETED)
	assert_chip_total(_stacks(players), 200)


func test_board_plays_and_splits_the_showdown_pot() -> void:
	var players := _heads_up_players(
		100,
		[
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
		]
	)
	var deck := RiggedDeck.new()
	deck.draw_order = [
		_card(2, CardData.Suit.DIAMONDS),
		_card(3, CardData.Suit.DIAMONDS),
		_card(4, CardData.Suit.HEARTS),
		_card(5, CardData.Suit.HEARTS),
		_card(10, CardData.Suit.CLUBS),
		_card(11, CardData.Suit.CLUBS),
		_card(12, CardData.Suit.CLUBS),
		_card(13, CardData.Suit.CLUBS),
		_card(14, CardData.Suit.CLUBS),
	]
	var controller := _controller(players, deck)
	controller.start()
	controller.submit_human_action(PlayerAction.call_action())
	controller.submit_human_action(PlayerAction.check_action())
	controller.submit_human_action(PlayerAction.check_action())

	var result: StepResult = controller.submit_human_action(PlayerAction.check_action())

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	assert_eq(controller.winner_seat, Table.NO_SEAT)
	assert_eq(controller.pot_awards.size(), 1)
	assert_eq(controller.pot_awards[0].amount, 20)
	assert_eq(controller.pot_awards[0].winner_seats, [0, 1])
	assert_eq(controller.pot_awards[0].amounts_by_seat, {0: 10, 1: 10})
	assert_eq(players[0].stack, 100)
	assert_eq(players[1].stack, 100)


func test_multiway_all_in_derives_and_awards_main_and_side_pots() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 20, HumanAgent.new()),
		(
			Player
			. new(
				&"bot_1",
				"Bot 1",
				1,
				40,
				ScriptedAgent.new([PlayerAction.call_action(), PlayerAction.all_in_action()]),
			)
		),
		(
			Player
			. new(
				&"bot_2",
				"Bot 2",
				2,
				80,
				ScriptedAgent.new([PlayerAction.all_in_action()]),
			)
		),
	]
	var deck := RiggedDeck.new()
	deck.draw_order = [
		_card(13, CardData.Suit.HEARTS),
		_card(12, CardData.Suit.HEARTS),
		_card(14, CardData.Suit.HEARTS),
		_card(13, CardData.Suit.DIAMONDS),
		_card(12, CardData.Suit.DIAMONDS),
		_card(14, CardData.Suit.DIAMONDS),
		_card(14, CardData.Suit.SPADES),
		_card(2, CardData.Suit.CLUBS),
		_card(3, CardData.Suit.CLUBS),
		_card(7, CardData.Suit.SPADES),
		_card(9, CardData.Suit.SPADES),
	]
	var controller := _controller(players, deck)
	controller.start()

	var result: StepResult = controller.submit_human_action(PlayerAction.all_in_action())

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	assert_eq(controller.community_cards.size(), 5)
	assert_eq(controller.showdown_hands.size(), 3)
	assert_eq(controller.pot_layers.size(), 2)
	assert_eq(_layer_amounts(controller.pot_layers), [60, 40])
	assert_eq(controller.pot_layers[0].eligible_seats, [0, 1, 2])
	assert_eq(controller.pot_layers[1].eligible_seats, [1, 2])
	assert_eq(controller.pot_awards.size(), 2)
	assert_eq(controller.pot_awards[0].winner_seats, [0])
	assert_eq(controller.pot_awards[1].winner_seats, [1])
	assert_eq(_stacks(players), [60, 40, 40])
	assert_chip_total(_stacks(players), 140)


func _heads_up_players(stack: int, bot_actions: Array[PlayerAction]) -> Array[Player]:
	return [
		Player.new(&"human", "Human", 0, stack, HumanAgent.new()),
		Player.new(&"bot", "Bot", 1, stack, ScriptedAgent.new(bot_actions)),
	]


func _controller(players: Array[Player], deck: Deck = null) -> HandController:
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var deck_rng := RandomNumberGenerator.new()
	deck_rng.seed = 123
	var button_rng := RandomNumberGenerator.new()
	button_rng.seed = 456
	return HandController.new(table, deck if deck != null else Deck.new(), deck_rng, button_rng)


func _card(rank: int, suit: CardData.Suit) -> CardData:
	return CardData.new(rank, suit)


func _stacks(players: Array[Player]) -> Array[int]:
	var stacks: Array[int] = []
	for player: Player in players:
		stacks.append(player.stack)
	return stacks


func _layer_amounts(layers: Array[PotLayer]) -> Array[int]:
	var amounts: Array[int] = []
	for layer: PotLayer in layers:
		amounts.append(layer.amount)
	return amounts
