extends "res://tests/support/poker_gut_test.gd"


func test_checking_around_completes_an_unopened_round() -> void:
	var players: Array[Player] = _players(3)
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_true(round.apply_action(0, PlayerAction.check_action()).is_ok())
	assert_eq(round.acting_seat, 1)
	assert_true(round.apply_action(1, PlayerAction.check_action()).is_ok())
	assert_true(round.apply_action(2, PlayerAction.check_action()).is_ok())
	assert_true(round.is_complete())
	assert_eq(round.acting_seat, Table.NO_SEAT)


func test_preflop_call_fold_and_big_blind_check_complete_round() -> void:
	var players: Array[Player] = _players(3)
	players[1].commit_chips(5)
	players[2].commit_chips(10)
	var round := BettingRound.new(Table.new(players, 5, 10), 0, 10)

	assert_true(round.apply_action(0, PlayerAction.call_action()).is_ok())
	assert_eq(players[0].bet_this_round, 10)
	assert_true(round.apply_action(1, PlayerAction.fold_action()).is_ok())
	assert_true(round.apply_action(2, PlayerAction.check_action()).is_ok())
	assert_true(round.is_complete())


func test_first_preflop_raise_must_reach_twice_the_big_blind() -> void:
	var players: Array[Player] = _players(3)
	players[1].commit_chips(5)
	players[2].commit_chips(10)
	var round := BettingRound.new(Table.new(players, 5, 10), 0, 10)

	var rejected: ActionValidationResult = round.apply_action(0, PlayerAction.raise_to(19))
	assert_eq(rejected.code, ActionValidationResult.Code.BELOW_MINIMUM)
	assert_eq(players[0].stack, 100)
	assert_eq(round.current_bet, 10)
	assert_true(round.apply_action(0, PlayerAction.raise_to(20)).is_ok())
	assert_eq(round.current_bet, 20)


func test_subsequent_minimum_raise_stays_one_big_blind_after_larger_raise() -> void:
	var players: Array[Player] = _players(3)
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_true(round.apply_action(0, PlayerAction.bet_to(10)).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(2, PlayerAction.raise_to(30)).is_ok())
	assert_eq(round.minimum_wager_total(), 40)
	assert_eq(round.pending_seats(), [0, 1])
	assert_true(round.can_raise(0))
	assert_true(round.can_raise(1))
	var rejected: ActionValidationResult = round.apply_action(0, PlayerAction.raise_to(39))
	assert_eq(rejected.code, ActionValidationResult.Code.BELOW_MINIMUM)
	assert_true(round.apply_action(0, PlayerAction.raise_to(40)).is_ok())
	assert_eq(round.current_bet, 40)
	assert_eq(round.pending_seats(), [1, 2])


func test_call_can_be_a_short_all_in() -> void:
	var players: Array[Player] = _players_with_stacks([100, 7])
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_true(round.apply_action(0, PlayerAction.bet_to(10)).is_ok())
	var result: ActionValidationResult = round.apply_action(1, PlayerAction.call_action())

	assert_true(result.is_ok())
	assert_eq(result.chips_committed, 7)
	assert_true(players[1].all_in)
	assert_true(round.is_complete())


func test_short_all_in_raise_does_not_reopen_prior_callers_raise_rights() -> void:
	var players: Array[Player] = _players_with_stacks([100, 100, 15])
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_true(round.apply_action(0, PlayerAction.bet_to(10)).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(2, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.current_bet, 15)
	assert_false(round.can_raise(0))
	assert_false(round.can_raise(1))
	assert_eq(round.acting_seat, 0)

	var rejected: ActionValidationResult = round.apply_action(0, PlayerAction.raise_to(30))
	assert_eq(rejected.code, ActionValidationResult.Code.RAISE_NOT_REOPENED)
	assert_true(round.apply_action(0, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.is_complete())


func test_short_all_in_does_not_advertise_an_unaffordable_full_bet() -> void:
	var players: Array[Player] = _players_with_stacks([5, 100])
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_eq(
		round.legal_actions(0),
		[
			PlayerAction.Kind.FOLD,
			PlayerAction.Kind.CHECK,
			PlayerAction.Kind.ALL_IN,
		],
	)
	assert_true(round.apply_action(0, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.current_bet, 5)


func test_short_all_in_does_not_advertise_an_unaffordable_full_raise() -> void:
	var players: Array[Player] = _players_with_stacks([15, 100])
	var round := BettingRound.new(Table.new(players, 5, 10), 0, 10)

	assert_eq(
		round.legal_actions(0),
		[
			PlayerAction.Kind.FOLD,
			PlayerAction.Kind.CALL,
			PlayerAction.Kind.ALL_IN,
		],
	)
	assert_true(round.apply_action(0, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.current_bet, 15)


func test_invalid_action_leaves_round_and_player_unchanged() -> void:
	var players: Array[Player] = _players(2)
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	var result: ActionValidationResult = round.apply_action(0, PlayerAction.call_action())

	assert_eq(result.code, ActionValidationResult.Code.ACTION_NOT_AVAILABLE)
	assert_eq(players[0].stack, 100)
	assert_eq(players[0].bet_this_round, 0)
	assert_eq(round.acting_seat, 0)
	assert_eq(round.current_bet, 0)


func test_folding_to_one_player_completes_immediately() -> void:
	var players: Array[Player] = _players(2)
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_true(round.apply_action(0, PlayerAction.fold_action()).is_ok())
	assert_true(round.is_complete())
	assert_eq(round.acting_seat, Table.NO_SEAT)


func test_lone_actionable_player_does_not_act_without_chips_to_call() -> void:
	var players: Array[Player] = _players_with_stacks([100, 10])
	players[1].commit_chips(10)
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_true(round.is_complete())
	assert_eq(round.acting_seat, Table.NO_SEAT)


func test_lone_actionable_player_must_act_when_facing_all_in_wager() -> void:
	var players: Array[Player] = _players_with_stacks([100, 10])
	players[1].commit_chips(10)
	var round := BettingRound.new(Table.new(players, 5, 10), 0, 10)

	assert_false(round.is_complete())
	assert_eq(round.acting_seat, 0)
	assert_eq(
		round.legal_actions(0),
		[
			PlayerAction.Kind.FOLD,
			PlayerAction.Kind.CALL,
			PlayerAction.Kind.RAISE,
			PlayerAction.Kind.ALL_IN
		]
	)


func _players(count: int) -> Array[Player]:
	var stacks: Array[int] = []
	for _index: int in range(count):
		stacks.append(100)
	return _players_with_stacks(stacks)


func _players_with_stacks(stacks: Array[int]) -> Array[Player]:
	var result: Array[Player] = []
	for seat: int in range(stacks.size()):
		result.append(
			Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, stacks[seat])
		)
	return result
