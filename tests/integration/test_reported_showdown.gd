extends "res://tests/support/poker_gut_test.gd"


func test_pair_of_kings_is_decided_by_complete_kicker_order_and_rendered() -> void:
	var players: Array[Player] = [
		Player.new(&"queen_kicker", "Queen kicker", 0, 100, HumanAgent.new()),
		Player.new(&"six_kicker", "Six kicker", 1, 100),
		Player.new(&"nine_kicker", "Nine kicker", 2, 100),
	]
	var hole_cards: Dictionary[int, Array] = {
		0: [_card(7, CardData.Suit.CLUBS), _card(12, CardData.Suit.DIAMONDS)],
		1: [_card(11, CardData.Suit.HEARTS), _card(6, CardData.Suit.CLUBS)],
		2: [_card(9, CardData.Suit.SPADES), _card(11, CardData.Suit.DIAMONDS)],
	}
	var board: Array[CardData] = [
		_card(14, CardData.Suit.DIAMONDS),
		_card(13, CardData.Suit.DIAMONDS),
		_card(2, CardData.Suit.DIAMONDS),
		_card(3, CardData.Suit.CLUBS),
		_card(13, CardData.Suit.SPADES),
	]
	var evaluator := HandEvaluator.new()
	var ranks: Dictionary[int, HandRank] = {}
	var results: Dictionary[int, ShowdownResult] = {}
	var pots := PotManager.new()
	for seat: int in range(players.size()):
		for card: CardData in hole_cards[seat]:
			players[seat].add_hole_card(card)
		players[seat].commit_chips(10)
		pots.record_contribution(seat, 10)
		var seven_cards: Array[CardData] = []
		seven_cards.assign(hole_cards[seat])
		seven_cards.append_array(board)
		ranks[seat] = evaluator.evaluate(seven_cards)
		var revealed_cards: Array[CardData] = []
		revealed_cards.assign(hole_cards[seat])
		results[seat] = ShowdownResult.new(seat, revealed_cards, ranks[seat])

	assert_eq(ranks[0].category, HandRank.Category.ONE_PAIR)
	assert_eq(ranks[0].tie_break_values, [13, 14, 12, 7])
	assert_eq(ranks[1].tie_break_values, [13, 14, 11, 6])
	assert_eq(ranks[2].tie_break_values, [13, 14, 11, 9])
	assert_eq(_card_codes(ranks[0].selected_cards), ["7:0", "12:1", "14:1", "13:1", "13:3"])
	assert_eq(_card_codes(ranks[1].selected_cards), ["11:2", "6:0", "14:1", "13:1", "13:3"])
	assert_eq(_card_codes(ranks[2].selected_cards), ["9:3", "11:1", "14:1", "13:1", "13:3"])

	var layers: Array[PotLayer] = pots.derive_pots(players)
	var awards: Array[PotAward] = pots.award_showdown(players, ranks, 2)
	assert_eq(awards.size(), 1)
	assert_eq(awards[0].winner_seats, [0])
	assert_eq(awards[0].amounts_by_seat, {0: 30})

	var table := Table.new(players, 5, 10)
	table.button_seat = 2
	var view := (
		GameView
		. for_hand(
			table,
			0,
			null,
			pots,
			[],
			&"hand_end",
			board,
			awards,
			hole_cards,
			1,
			layers,
			results,
		)
	)
	view.hand_complete = true
	view.hand_winner_seat = 0
	var io := FakeCliIO.new()
	CliRenderer.new(io).render_hand(view)

	assert_true(io.contains_write("Board: [ A♦ | K♦ | 2♦ | 3♣ | K♠ ]"))
	assert_true(
		io.contains_write(
			(
				"  Seat 0: [ 7♣ | Q♦ ]; one pair; kickers [ 13, 14, 12, 7 ]; "
				+ "best five [ 7♣ | Q♦ | A♦ | K♦ | K♠ ]"
			)
		)
	)
	assert_true(
		io.contains_write(
			(
				"  Seat 1: [ J♥ | 6♣ ]; one pair; kickers [ 13, 14, 11, 6 ]; "
				+ "best five [ J♥ | 6♣ | A♦ | K♦ | K♠ ]"
			)
		)
	)
	assert_true(
		io.contains_write(
			(
				"  Seat 2: [ 9♠ | J♦ ]; one pair; kickers [ 13, 14, 11, 9 ]; "
				+ "best five [ 9♠ | J♦ | A♦ | K♦ | K♠ ]"
			)
		)
	)


func _card(rank: int, suit: CardData.Suit) -> CardData:
	return CardData.new(rank, suit)


func _card_codes(cards: Array[CardData]) -> Array[String]:
	var codes: Array[String] = []
	for card: CardData in cards:
		codes.append(card.code())
	return codes
