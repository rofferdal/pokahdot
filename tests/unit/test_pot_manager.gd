extends "res://tests/support/poker_gut_test.gd"


func test_ledger_tracks_each_seat_and_total_independently() -> void:
	var pots := PotManager.new()

	assert_true(pots.record_contribution(0, 10))
	assert_true(pots.record_contribution(1, 20))
	assert_true(pots.record_contribution(0, 5))

	assert_eq(pots.contribution_for(0), 15)
	assert_eq(pots.contribution_for(1), 20)
	assert_eq(pots.total_amount, 35)


func test_ledger_rejects_negative_values_without_mutation() -> void:
	var pots := PotManager.new()
	assert_true(pots.record_contribution(0, 10))

	assert_false(pots.record_contribution(0, -1))
	assert_false(pots.record_contribution(-1, 5))
	assert_eq(pots.contributions, {0: 10})
	assert_eq(pots.total_amount, 10)


func test_returned_contribution_ledger_is_a_copy() -> void:
	var pots := PotManager.new()
	pots.record_contribution(0, 10)
	var returned: Dictionary[int, int] = pots.contributions

	returned[0] = 999
	returned[1] = 999

	assert_eq(pots.contributions, {0: 10})
	assert_eq(pots.total_amount, 10)


func test_fold_to_one_awards_every_contribution_and_clears_ledger() -> void:
	var players: Array[Player] = _players(3)
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 20)
	_commit_and_record(players[1], pots, 20)
	_commit_and_record(players[2], pots, 10)
	players[1].fold()
	players[2].fold()

	assert_eq(pots.award_single_winner(players[0]), 50)
	assert_eq(players[0].stack, 130)
	assert_eq(pots.total_amount, 0)
	assert_eq(pots.contributions, {})
	assert_chip_total([players[0].stack, players[1].stack, players[2].stack], 300)


func test_folded_player_cannot_receive_single_winner_award() -> void:
	var players: Array[Player] = _players(2)
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 10)
	_commit_and_record(players[1], pots, 10)
	players[0].fold()

	assert_eq(pots.award_single_winner(players[0]), 0)
	assert_eq(pots.total_amount, 20)
	assert_eq(players[0].stack, 90)


func test_derives_main_and_side_pots_with_folded_chips_but_only_live_eligibility() -> void:
	var players: Array[Player] = _players(3)
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 40)
	_commit_and_record(players[1], pots, 100)
	_commit_and_record(players[2], pots, 100)
	players[2].fold()

	var layers: Array[PotLayer] = pots.derive_pots(players)

	assert_eq(layers.size(), 2)
	assert_eq(layers[0].amount, 120)
	assert_eq(layers[0].contributor_seats, [0, 1, 2])
	assert_eq(layers[0].eligible_seats, [0, 1])
	assert_eq(layers[1].amount, 120)
	assert_eq(layers[1].contributor_seats, [1, 2])
	assert_eq(layers[1].eligible_seats, [1])


func test_unequal_blinds_remain_one_total_pot_without_an_all_in() -> void:
	var players: Array[Player] = _players(2)
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 5)
	_commit_and_record(players[1], pots, 10)

	var layers: Array[PotLayer] = pots.derive_pots(players)

	assert_eq(layers.size(), 1)
	assert_eq(layers[0].amount, 15)
	assert_eq(layers[0].contributor_seats, [0, 1])
	assert_eq(layers[0].eligible_seats, [0, 1])


func test_called_wager_without_an_all_in_does_not_create_a_side_pot() -> void:
	var players: Array[Player] = _players(3)
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 20)
	_commit_and_record(players[1], pots, 40)
	_commit_and_record(players[2], pots, 40)

	var layers: Array[PotLayer] = pots.derive_pots(players)

	assert_eq(layers.size(), 1)
	assert_eq(layers[0].amount, 100)
	assert_eq(layers[0].eligible_seats, [0, 1, 2])


func test_folded_contributions_do_not_create_duplicate_layers_with_same_eligibility() -> void:
	var players: Array[Player] = _players(3)
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 100)
	_commit_and_record(players[1], pots, 100)
	_commit_and_record(players[2], pots, 50)
	players[2].fold()

	var layers: Array[PotLayer] = pots.derive_pots(players)

	assert_eq(layers.size(), 1)
	assert_eq(layers[0].amount, 250)
	assert_eq(layers[0].contributor_seats, [0, 1, 2])
	assert_eq(layers[0].eligible_seats, [0, 1])


func test_dead_money_from_folded_only_upper_layer_joins_previous_live_pot() -> void:
	var players: Array[Player] = [
		Player.new(&"player_0", "Player 0", 0, 20),
		Player.new(&"player_1", "Player 1", 1, 20),
		Player.new(&"player_2", "Player 2", 2, 100),
		Player.new(&"player_3", "Player 3", 3, 100),
	]
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 20)
	_commit_and_record(players[1], pots, 20)
	_commit_and_record(players[2], pots, 100)
	_commit_and_record(players[3], pots, 100)
	players[2].fold()
	players[3].fold()

	var layers: Array[PotLayer] = pots.derive_pots(players)

	assert_eq(layers.size(), 1)
	assert_eq(layers[0].amount, 240)
	assert_eq(layers[0].contributor_seats, [0, 1, 2, 3])
	assert_eq(layers[0].eligible_seats, [0, 1])


func test_unmatched_all_in_excess_is_returned_instead_of_awarded_as_a_side_pot() -> void:
	var players: Array[Player] = [
		Player.new(&"player_0", "Player 0", 0, 100),
		Player.new(&"player_1", "Player 1", 1, 50),
	]
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 100)
	_commit_and_record(players[1], pots, 50)
	var layers: Array[PotLayer] = pots.derive_pots(players)

	assert_eq(layers.size(), 1)
	assert_eq(layers[0].amount, 100)

	var awards: Array[PotAward] = (
		pots
		. award_showdown(
			players,
			{
				0: _rank("AS AD KC QH JS"),
				1: _rank("KS KD AC QH JS"),
			},
			0,
		)
	)

	assert_eq(awards.size(), 1)
	assert_eq(awards[0].amount, 100)
	assert_eq(awards[0].amounts_by_seat, {0: 100})
	assert_eq([players[0].stack, players[1].stack], [150, 0])
	assert_eq(pots.total_amount, 0)


func test_showdown_awards_each_side_pot_to_its_best_eligible_hand() -> void:
	var players: Array[Player] = _players(3)
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 40)
	_commit_and_record(players[1], pots, 100)
	_commit_and_record(players[2], pots, 100)
	var ranks: Dictionary[int, HandRank] = {
		0: _rank("AS AD KC QH JS"),
		1: _rank("KS KD AC QH JS"),
		2: _rank("QS QD AC KH JS"),
	}

	var awards: Array[PotAward] = pots.award_showdown(players, ranks, 2)

	assert_eq(awards.size(), 2)
	assert_eq(awards[0].amounts_by_seat, {0: 120})
	assert_eq(awards[1].amounts_by_seat, {1: 120})
	assert_eq([players[0].stack, players[1].stack, players[2].stack], [180, 120, 0])
	assert_eq(pots.total_amount, 0)
	assert_chip_total([players[0].stack, players[1].stack, players[2].stack], 300)


func test_split_pot_gives_odd_chip_to_first_winner_clockwise_from_button() -> void:
	var players: Array[Player] = _players(3)
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 5)
	_commit_and_record(players[1], pots, 5)
	_commit_and_record(players[2], pots, 5)
	players[2].fold()
	var tied_rank: HandRank = _rank("AS KD QC JH 9S")
	var ranks: Dictionary[int, HandRank] = {0: tied_rank, 1: tied_rank}

	var awards: Array[PotAward] = pots.award_showdown(players, ranks, 2)

	assert_eq(awards.size(), 1)
	assert_eq(awards[0].winner_seats, [0, 1])
	assert_eq(awards[0].amounts_by_seat, {0: 8, 1: 7})
	assert_eq([players[0].stack, players[1].stack, players[2].stack], [103, 102, 95])
	assert_chip_total([players[0].stack, players[1].stack, players[2].stack], 300)


func test_showdown_rejects_missing_eligible_rank_without_mutating_chips() -> void:
	var players: Array[Player] = _players(2)
	var pots := PotManager.new()
	_commit_and_record(players[0], pots, 10)
	_commit_and_record(players[1], pots, 10)

	assert_eq(pots.award_showdown(players, {0: _rank("AS AD KC QH JS")}, 0), [])
	assert_eq([players[0].stack, players[1].stack], [90, 90])
	assert_eq(pots.total_amount, 20)


func _players(count: int) -> Array[Player]:
	var result: Array[Player] = []
	for seat: int in range(count):
		result.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	return result


func _commit_and_record(player: Player, pots: PotManager, amount: int) -> void:
	var committed: int = player.commit_chips(amount)
	assert_true(pots.record_contribution(player.seat, committed))


func _rank(description: String) -> HandRank:
	var cards: Array[CardData] = []
	var suits: Dictionary = {
		"C": CardData.Suit.CLUBS,
		"D": CardData.Suit.DIAMONDS,
		"H": CardData.Suit.HEARTS,
		"S": CardData.Suit.SPADES,
	}
	var named_ranks: Dictionary = {"T": 10, "J": 11, "Q": 12, "K": 13, "A": 14}
	for token: String in description.split(" ", false):
		var rank_text: String = token.left(token.length() - 1)
		var card_rank: int = int(named_ranks.get(rank_text, int(rank_text)))
		cards.append(CardData.new(card_rank, suits[token.right(1)] as CardData.Suit))
	return HandEvaluator.new().evaluate(cards)
