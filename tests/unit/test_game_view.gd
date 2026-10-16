extends "res://tests/support/poker_gut_test.gd"


func test_preflop_view_contains_public_table_and_betting_state() -> void:
	var players: Array[Player] = _players()
	players[1].commit_chips(5)
	players[2].commit_chips(10)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var betting := BettingRound.new(table, 0, 10)
	var pots := PotManager.new()
	pots.record_contribution(1, 5)
	pots.record_contribution(2, 10)

	var view := GameView.for_preflop(table, 0, betting, pots, [], 7)

	assert_eq(view.street, &"preflop")
	assert_eq(view.hand_number, 7)
	assert_eq(view.button_seat, 0)
	assert_eq(view.small_blind_seat, 1)
	assert_eq(view.big_blind_seat, 2)
	assert_eq(view.acting_seat, 0)
	assert_eq(view.pot_amount, 15)
	assert_eq(view.call_amount, 10)
	assert_has(view.legal_actions, PlayerAction.Kind.CALL)


func test_view_reveals_only_recipient_hole_cards() -> void:
	var players: Array[Player] = _players()
	_deal_private_cards(players)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var betting := BettingRound.new(table, 0)

	var hero_view := GameView.for_preflop(table, 0, betting, PotManager.new(), [])
	var opponent_view := GameView.for_preflop(table, 1, betting, PotManager.new(), [])

	assert_eq(hero_view.hero_seat, 0)
	assert_eq(_card_codes(hero_view.hero_hole_cards), _card_codes(players[0].hole_cards))
	assert_eq(opponent_view.hero_seat, 1)
	assert_eq(_card_codes(opponent_view.hero_hole_cards), _card_codes(players[1].hole_cards))
	assert_eq(hero_view.seats[1].player_id, players[1].player_id)
	assert_ne(hero_view.seats[1], players[1])


func test_view_is_a_snapshot_and_returned_collections_cannot_mutate_it() -> void:
	var players: Array[Player] = _players()
	_deal_private_cards(players)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var view := GameView.for_preflop(table, 0, BettingRound.new(table, 0), PotManager.new(), [])
	var returned_seats: Array[PlayerView] = view.seats
	var returned_cards: Array[CardData] = view.hero_hole_cards
	var original_stack: int = view.seats[0].stack

	players[0].commit_chips(25)
	returned_seats.clear()
	returned_cards.clear()

	assert_eq(view.seats.size(), 3)
	assert_eq(view.seats[0].stack, original_stack)
	assert_eq(view.hero_hole_cards.size(), 2)


func test_public_action_history_is_copied_without_private_cards() -> void:
	var players: Array[Player] = _players()
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var history: Array[PublicActionRecord] = [
		PublicActionRecord.new(2, PlayerAction.Kind.RAISE, 30),
		PublicActionRecord.new(0, PlayerAction.Kind.CALL, 30),
	]
	var view := GameView.for_preflop(
		table, 1, BettingRound.new(table, 0), PotManager.new(), history
	)

	history.clear()
	var returned_history: Array[PublicActionRecord] = view.action_history
	returned_history.clear()

	assert_eq(view.action_history.size(), 2)
	assert_eq(view.action_history[0].seat, 2)
	assert_eq(view.action_history[0].amount, 30)


func _players() -> Array[Player]:
	var result: Array[Player] = []
	for seat: int in range(3):
		result.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	return result


func _deal_private_cards(players: Array[Player]) -> void:
	var deck := Deck.new()
	for _card_index: int in range(2):
		for player: Player in players:
			player.add_hole_card(deck.draw())


func _card_codes(cards: Array[CardData]) -> Array[String]:
	var result: Array[String] = []
	for card: CardData in cards:
		result.append(card.code())
	return result
