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


func _players(count: int) -> Array[Player]:
	var result: Array[Player] = []
	for seat: int in range(count):
		result.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	return result


func _commit_and_record(player: Player, pots: PotManager, amount: int) -> void:
	var committed: int = player.commit_chips(amount)
	assert_true(pots.record_contribution(player.seat, committed))
