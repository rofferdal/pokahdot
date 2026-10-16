extends "res://tests/support/poker_gut_test.gd"

const CliCardFormatterScript = preload("res://scripts/cli/cli_card_formatter.gd")


func test_renderer_outputs_preflop_public_state_and_only_hero_cards() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 100, HumanAgent.new()),
		Player.new(&"bot", "Bot", 1, 100),
	]
	var deck := Deck.new()
	for _index: int in range(2):
		for player: Player in players:
			player.add_hole_card(deck.draw())
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var view := GameView.for_preflop(table, 0, BettingRound.new(table, 0), PotManager.new(), [])
	var io := FakeCliIO.new()

	CliRenderer.new(io).render_preflop(view)

	assert_true(io.contains_write("Hand 1 - preflop"))
	assert_eq(io.count_writes_containing("Seat 0: Human (you) - 100 chips"), 1)
	assert_eq(io.count_writes_containing("Seat 1: Bot - 100 chips"), 1)
	assert_true(io.contains_write("Button: 0  SB: 0  BB: 1  Acting: 0"))
	assert_true(io.contains_write("Pot: 0"))
	assert_true(io.contains_write("Legal actions: fold, check, bet (10-100 total), allin"))
	assert_eq(io.count_writes_containing("Your cards:"), 1)
	for card: CardData in players[1].hole_cards:
		assert_eq(io.count_writes_containing(card.code()), 0)
	for card: CardData in players[0].hole_cards:
		assert_eq(io.count_writes_containing(CliCardFormatterScript.format_card(card)), 1)
		assert_eq(io.count_writes_containing(card.code()), 0)


func test_renderer_outputs_ordered_blinds_and_action_limits() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 95),
		Player.new(&"bot", "Bot", 1, 90),
	]
	players[0].bet_this_round = 5
	players[1].bet_this_round = 10
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var history: Array[PublicActionRecord] = [
		PublicActionRecord.blind(0, 5, true),
		PublicActionRecord.blind(1, 10, false),
	]
	var view := GameView.for_preflop(
		table, 0, BettingRound.new(table, 0, 10), PotManager.new(), history
	)
	var io := FakeCliIO.new()

	CliRenderer.new(io).render_preflop(view)

	assert_true(io.contains_write("  Seat 0 posts small blind 5"))
	assert_true(io.contains_write("  Seat 1 posts big blind 10"))
	assert_true(
		(
			io.writes.find("  Seat 0 posts small blind 5")
			< io.writes.find("  Seat 1 posts big blind 10")
		)
	)
	assert_true(io.contains_write("Legal actions: fold, call (5), raise (20-100 total), allin"))


func test_card_formatter_covers_every_rank_and_suit() -> void:
	var rank_labels: Dictionary[int, String] = {
		2: "2",
		3: "3",
		4: "4",
		5: "5",
		6: "6",
		7: "7",
		8: "8",
		9: "9",
		10: "10",
		11: "J",
		12: "Q",
		13: "K",
		14: "A",
	}
	var suit_labels: Dictionary[CardData.Suit, String] = {
		CardData.Suit.CLUBS: "♣",
		CardData.Suit.DIAMONDS: "♦",
		CardData.Suit.HEARTS: "♥",
		CardData.Suit.SPADES: "♠",
	}
	for rank: int in rank_labels:
		for suit: CardData.Suit in suit_labels:
			assert_eq(
				CliCardFormatterScript.format_card(CardData.new(rank, suit)),
				rank_labels[rank] + suit_labels[suit],
			)


func test_card_formatter_uses_collection_delimiters_and_utf8_suits() -> void:
	var cards: Array[CardData] = [
		CardData.new(14, CardData.Suit.SPADES),
		CardData.new(10, CardData.Suit.HEARTS),
		CardData.new(13, CardData.Suit.DIAMONDS),
	]

	assert_eq(CliCardFormatterScript.format_cards(cards), "[ A♠ | 10♥ | K♦ ]")


func test_renderer_marks_only_player_with_human_agent() -> void:
	var players: Array[Player] = [
		Player.new(&"bot_0", "Bot 1", 0, 100),
		Player.new(&"human", "Hero", 1, 100, HumanAgent.new()),
		Player.new(&"bot_2", "Bot 2", 2, 100),
		Player.new(&"bot_3", "Bot 3", 3, 100),
	]
	var table := Table.new(players, 5, 10)
	var view := GameView.for_preflop(table, 1, BettingRound.new(table, 1), PotManager.new(), [])
	var io := FakeCliIO.new()

	CliRenderer.new(io).render_preflop(view)

	assert_eq(io.count_writes_containing("(you)"), 1)
	assert_eq(io.count_writes_containing("Seat 1: Hero (you) -"), 1)
	assert_eq(io.count_writes_containing("Bot 1 (you)"), 0)
	assert_eq(io.count_writes_containing("Bot 2 (you)"), 0)
	assert_eq(io.count_writes_containing("Bot 3 (you)"), 0)


func test_renderer_outputs_board_pot_layers_and_street_with_formatted_cards() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 90, HumanAgent.new()),
		Player.new(&"bot", "Bot", 1, 90),
	]
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var pots := PotManager.new()
	pots.record_contribution(0, 10)
	pots.record_contribution(1, 10)
	var board: Array[CardData] = [
		CardData.new(14, CardData.Suit.SPADES),
		CardData.new(10, CardData.Suit.HEARTS),
		CardData.new(13, CardData.Suit.DIAMONDS),
	]
	var view := GameView.for_hand(
		table, 0, BettingRound.new(table, 1), pots, [], &"flop", board, [], {}
	)
	var io := FakeCliIO.new()

	CliRenderer.new(io).render_hand(view)

	assert_true(io.contains_write("Hand 1 - flop"))
	assert_true(io.contains_write("Board: [ A♠ | 10♥ | K♦ ]"))
	assert_true(io.contains_write("  Pot 1: 20 chips; eligible seats [ 0, 1 ]"))
	for card: CardData in board:
		assert_eq(io.count_writes_containing(card.code()), 0)


func test_renderer_outputs_showdown_awards_and_final_stacks_without_hidden_cards() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 108, HumanAgent.new()),
		Player.new(&"bot", "Bot", 1, 107),
		Player.new(&"folded", "Folded", 2, 85),
	]
	var table := Table.new(players, 5, 10)
	table.button_seat = 2
	var hero_cards: Array[CardData] = [
		CardData.new(14, CardData.Suit.SPADES), CardData.new(12, CardData.Suit.CLUBS)
	]
	var bot_cards: Array[CardData] = [
		CardData.new(14, CardData.Suit.HEARTS), CardData.new(12, CardData.Suit.DIAMONDS)
	]
	var hidden_cards: Array[CardData] = [
		CardData.new(2, CardData.Suit.CLUBS), CardData.new(3, CardData.Suit.CLUBS)
	]
	for card: CardData in hero_cards:
		players[0].add_hole_card(card)
	for card: CardData in bot_cards:
		players[1].add_hole_card(card)
	for card: CardData in hidden_cards:
		players[2].add_hole_card(card)
	var shown: Dictionary[int, Array] = {0: hero_cards, 1: bot_cards}
	var awards: Array[PotAward] = [PotAward.new(0, 15, [0, 1], {0: 8, 1: 7})]
	var layers: Array[PotLayer] = [PotLayer.new(15, 5, [0, 1, 2], [0, 1])]
	var view := GameView.for_hand(
		table, 0, null, PotManager.new(), [], &"hand_end", [], awards, shown, 1, layers
	)
	view.hand_complete = true
	view.hand_winner_seat = Table.NO_SEAT
	var io := FakeCliIO.new()

	CliRenderer.new(io).render_hand(view)

	assert_true(io.contains_write("Showdown:"))
	assert_true(io.contains_write("  Seat 0: [ A♠ | Q♣ ]"))
	assert_true(io.contains_write("  Seat 1: [ A♥ | Q♦ ]"))
	assert_true(io.contains_write("  Pot 1: seat 0 wins 8"))
	assert_true(io.contains_write("  Pot 1: seat 1 wins 7"))
	assert_true(io.contains_write("Hand complete after showdown."))
	assert_true(io.contains_write("  Seat 2: 85 chips"))
	for card: CardData in hidden_cards:
		assert_eq(io.count_writes_containing(CliCardFormatterScript.format_card(card)), 0)
