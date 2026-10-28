# gdlint: disable=max-public-methods
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


func test_minimum_wager_total_saturates_instead_of_overflowing() -> void:
	var players: Array[Player] = _players_with_stacks([IntegerBounds.MAX_INT_64, 100])
	var round := BettingRound.new(Table.new(players, 1, 10), 0, IntegerBounds.MAX_INT_64 - 5)

	assert_eq(round.minimum_wager_total(), IntegerBounds.MAX_INT_64)
	assert_gt(round.minimum_wager_total(), 0)


func test_repeated_raises_track_equal_and_larger_full_increments() -> void:
	var players: Array[Player] = _players(3)
	players[1].commit_chips(5)
	players[2].commit_chips(10)
	var table := Table.new(players, 5, 10)
	var round := BettingRound.new(table, 0, 10)

	assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
	assert_eq(round.minimum_wager_total(), 50)
	_assert_below_minimum_unchanged(table, round, 49)
	assert_true(round.apply_action(1, PlayerAction.raise_to(50)).is_ok())
	assert_eq(round.minimum_wager_total(), 70)
	_assert_below_minimum_unchanged(table, round, 69)
	assert_true(round.apply_action(2, PlayerAction.raise_to(80)).is_ok())
	assert_eq(round.minimum_wager_total(), 110)
	assert_eq(round.pending_seats(), [0, 1])
	assert_true(round.can_raise(0))
	assert_true(round.can_raise(1))


func test_larger_preflop_raise_changes_the_following_minimum() -> void:
	var players: Array[Player] = _players(3)
	var table := Table.new(players, 5, 10)
	var round := BettingRound.new(table, 0, 10)

	assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
	assert_eq(round.minimum_wager_total(), 50)
	assert_true(round.apply_action(1, PlayerAction.raise_to(60)).is_ok())
	assert_eq(round.minimum_wager_total(), 90)
	_assert_below_minimum_unchanged(table, round, 89)
	assert_true(round.apply_action(2, PlayerAction.raise_to(90)).is_ok())
	assert_eq(round.minimum_wager_total(), 120)


func test_postflop_opening_full_bet_sets_the_raise_increment() -> void:
	var players: Array[Player] = _players(3)
	var table := Table.new(players, 5, 10)
	var round := BettingRound.new(table, 0)

	assert_true(round.apply_action(0, PlayerAction.bet_to(40)).is_ok())
	assert_eq(round.minimum_wager_total(), 80)
	_assert_below_minimum_unchanged(table, round, 79)
	assert_true(round.apply_action(1, PlayerAction.raise_to(80)).is_ok())
	assert_eq(round.minimum_wager_total(), 120)


func test_checks_calls_and_folds_preserve_the_full_increment() -> void:
	var players: Array[Player] = _players(4)
	var table := Table.new(players, 5, 10)
	var round := BettingRound.new(table, 0)

	assert_true(round.apply_action(0, PlayerAction.check_action()).is_ok())
	assert_eq(round.minimum_wager_total(), 10)
	assert_true(round.apply_action(1, PlayerAction.bet_to(30)).is_ok())
	assert_eq(round.minimum_wager_total(), 60)
	assert_true(round.apply_action(2, PlayerAction.call_action()).is_ok())
	assert_eq(round.minimum_wager_total(), 60)
	assert_true(round.apply_action(3, PlayerAction.fold_action()).is_ok())
	assert_eq(round.minimum_wager_total(), 60)
	assert_true(round.apply_action(0, PlayerAction.call_action()).is_ok())
	assert_eq(round.minimum_wager_total(), 60)
	assert_true(round.is_complete())


func test_tracked_large_opening_increment_saturates_the_minimum() -> void:
	var players: Array[Player] = _players_with_stacks(
		[IntegerBounds.MAX_INT_64, IntegerBounds.MAX_INT_64]
	)
	var round := BettingRound.new(Table.new(players, 5, 10), 0)
	var large_bet: int = IntegerBounds.MAX_INT_64 - 10

	assert_true(round.apply_action(0, PlayerAction.bet_to(large_bet)).is_ok())
	assert_eq(round.minimum_wager_total(), IntegerBounds.MAX_INT_64)
	assert_gt(round.minimum_wager_total(), 0)
	assert_eq(round.call_amount(1), large_bet)
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_eq(round.minimum_wager_total(), IntegerBounds.MAX_INT_64)


func test_unrepresentable_full_raise_allows_only_short_all_in_increase() -> void:
	var players: Array[Player] = _players_with_stacks(
		[IntegerBounds.MAX_INT_64, IntegerBounds.MAX_INT_64]
	)
	var table := Table.new(players, 5, 10)
	var round := BettingRound.new(table, 0)
	assert_true(round.apply_action(0, PlayerAction.bet_to(IntegerBounds.MAX_INT_64 - 10)).is_ok())
	assert_eq(round.minimum_wager_total(), IntegerBounds.MAX_INT_64)
	assert_does_not_have(round.legal_actions(1), PlayerAction.Kind.RAISE)
	assert_has(round.legal_actions(1), PlayerAction.Kind.ALL_IN)
	var before: Array = _round_snapshot(table, round)
	assert_eq(
		round.apply_action(1, PlayerAction.raise_to(IntegerBounds.MAX_INT_64)).code,
		ActionValidationResult.Code.ACTION_NOT_AVAILABLE
	)
	assert_eq(_round_snapshot(table, round), before)
	assert_true(round.apply_action(1, PlayerAction.all_in_action()).is_ok())
	assert_false(round.can_raise(0))
	assert_eq(round.minimum_wager_total(), IntegerBounds.MAX_INT_64)
	assert_true(round.apply_action(0, PlayerAction.call_action()).is_ok())
	assert_true(round.is_complete())


func test_exactly_representable_full_minimum_still_allows_ordinary_raise() -> void:
	var players: Array[Player] = _players_with_stacks([IntegerBounds.MAX_INT_64, 100])
	var round := BettingRound.new(Table.new(players, 5, 10), 0, IntegerBounds.MAX_INT_64 - 10)
	assert_eq(round.minimum_wager_total(), IntegerBounds.MAX_INT_64)
	assert_has(round.legal_actions(0), PlayerAction.Kind.RAISE)
	assert_true(round.apply_action(0, PlayerAction.raise_to(IntegerBounds.MAX_INT_64)).is_ok())


func _assert_below_minimum_unchanged(table: Table, round: BettingRound, total: int) -> void:
	var before: Array = _round_snapshot(table, round)
	var rejected: ActionValidationResult = round.apply_action(
		round.acting_seat, PlayerAction.raise_to(total)
	)
	assert_eq(rejected.code, ActionValidationResult.Code.BELOW_MINIMUM)
	assert_eq(_round_snapshot(table, round), before)


func _round_snapshot(table: Table, round: BettingRound) -> Array:
	var snapshot: Array = [
		round.acting_seat,
		round.current_bet,
		round.minimum_wager_total(),
		round.pending_seats(),
		round.is_complete(),
	]
	for player: Player in table.players:
		(
			snapshot
			. append(
				[
					player.stack,
					player.bet_this_round,
					player.total_contribution,
					player.folded,
					player.all_in,
					round.can_raise(player.seat),
					round.legal_actions(player.seat),
				]
			)
		)
	return snapshot


func test_short_all_in_after_larger_raise_preserves_increment_and_closed_rights() -> void:
	for short_total: int in [35, 40]:
		var players: Array[Player] = _players_with_stacks([100, 100, short_total, 100, 100])
		var table := Table.new(players, 5, 10)
		var round := BettingRound.new(table, 0, 10)

		assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
		assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
		assert_true(round.apply_action(2, PlayerAction.all_in_action()).is_ok())
		assert_eq(round.current_bet, short_total)
		assert_eq(round.minimum_wager_total(), short_total + 20)
		assert_eq(round.pending_seats(), [0, 1, 3, 4])
		assert_eq(round.acting_seat, 3)
		assert_false(round.can_raise(0))
		assert_false(round.can_raise(1))
		assert_true(round.can_raise(3))
		assert_has(round.legal_actions(3), PlayerAction.Kind.RAISE)
		assert_true(round.apply_action(3, PlayerAction.call_action()).is_ok())
		assert_eq(round.acting_seat, 4)
		assert_true(round.apply_action(4, PlayerAction.fold_action()).is_ok())
		assert_eq(round.acting_seat, 0)
		assert_eq(round.pending_seats(), [0, 1])
		_assert_closed_raise_rejected_unchanged(table, round)
		assert_true(round.apply_action(0, PlayerAction.call_action()).is_ok())
		assert_eq(round.acting_seat, 1)
		_assert_closed_raise_rejected_unchanged(table, round)
		assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
		assert_true(round.is_complete())
		assert_eq(round.pending_seats(), [])
		assert_eq(round.acting_seat, Table.NO_SEAT)


func test_exact_full_all_in_increment_reopens_raiser_and_caller() -> void:
	var players: Array[Player] = _players_with_stacks([100, 100, 50, 100])
	var round := BettingRound.new(Table.new(players, 5, 10), 0, 10)

	assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(2, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.minimum_wager_total(), 70)
	assert_eq(round.pending_seats(), [0, 1, 3])
	assert_eq(round.acting_seat, 3)
	assert_true(round.can_raise(0))
	assert_true(round.can_raise(1))
	assert_true(round.apply_action(3, PlayerAction.call_action()).is_ok())
	assert_has(round.legal_actions(0), PlayerAction.Kind.RAISE)
	assert_true(round.apply_action(0, PlayerAction.raise_to(70)).is_ok())
	assert_eq(round.minimum_wager_total(), 90)
	assert_eq(round.pending_seats(), [1, 3])
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(3, PlayerAction.call_action()).is_ok())
	assert_true(round.is_complete())


func test_unacted_short_stack_can_only_raise_by_all_in() -> void:
	var players: Array[Player] = _players_with_stacks([100, 100, 40, 50])
	var table := Table.new(players, 5, 10)
	var round := BettingRound.new(table, 0, 10)

	assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(2, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.minimum_wager_total(), 60)
	assert_eq(round.maximum_wager_total(3), 50)
	assert_eq(
		round.legal_actions(3),
		[PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL, PlayerAction.Kind.ALL_IN],
	)
	var before: Array = _round_snapshot(table, round)
	assert_eq(
		round.apply_action(3, PlayerAction.raise_to(50)).code,
		ActionValidationResult.Code.ACTION_NOT_AVAILABLE,
	)
	assert_eq(_round_snapshot(table, round), before)
	assert_true(round.apply_action(3, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.current_bet, 50)
	assert_eq(round.minimum_wager_total(), 70)
	assert_false(round.can_raise(0))
	assert_false(round.can_raise(1))
	assert_eq(round.pending_seats(), [0, 1])
	assert_true(round.apply_action(0, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.is_complete())


func test_closed_rights_allow_exact_all_in_call_after_larger_raise() -> void:
	var players: Array[Player] = _players_with_stacks([40, 100, 40])
	var round := BettingRound.new(Table.new(players, 5, 10), 0, 10)

	assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(2, PlayerAction.all_in_action()).is_ok())
	assert_false(round.can_raise(0))
	assert_eq(round.call_amount(0), 10)
	assert_eq(round.maximum_wager_total(0), 40)
	assert_eq(
		round.legal_actions(0),
		[PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL, PlayerAction.Kind.ALL_IN],
	)
	assert_true(round.apply_action(0, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.current_bet, 40)
	assert_eq(round.minimum_wager_total(), 60)
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.is_complete())


func test_multiple_short_all_ins_do_not_cumulatively_reopen_action() -> void:
	var players: Array[Player] = _players_with_stacks([100, 35, 50, 100])
	var table := Table.new(players, 5, 10)
	var round := BettingRound.new(table, 0, 10)

	assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
	assert_true(round.apply_action(1, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.minimum_wager_total(), 55)
	assert_true(round.apply_action(2, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.current_bet, 50)
	assert_eq(round.minimum_wager_total(), 70)
	assert_false(round.can_raise(0))
	assert_true(round.can_raise(3))
	assert_eq(round.pending_seats(), [0, 3])
	assert_true(round.apply_action(3, PlayerAction.call_action()).is_ok())
	assert_eq(round.acting_seat, 0)
	_assert_closed_raise_rejected_unchanged(table, round)
	assert_true(round.apply_action(0, PlayerAction.call_action()).is_ok())
	assert_true(round.is_complete())


func test_short_opening_all_in_keeps_big_blind_increment_and_checker_closed() -> void:
	var players: Array[Player] = _players_with_stacks([100, 5, 100])
	var table := Table.new(players, 5, 10)
	var round := BettingRound.new(table, 0)

	assert_true(round.apply_action(0, PlayerAction.check_action()).is_ok())
	assert_true(round.apply_action(1, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.current_bet, 5)
	assert_eq(round.minimum_wager_total(), 15)
	assert_eq(round.pending_seats(), [0, 2])
	assert_eq(round.acting_seat, 2)
	assert_false(round.can_raise(0))
	assert_true(round.can_raise(2))
	assert_has(round.legal_actions(2), PlayerAction.Kind.RAISE)
	assert_true(round.apply_action(2, PlayerAction.call_action()).is_ok())
	assert_eq(round.acting_seat, 0)
	_assert_closed_raise_rejected_unchanged(table, round)
	assert_true(round.apply_action(0, PlayerAction.call_action()).is_ok())
	assert_true(round.is_complete())


func test_full_opening_all_in_sets_the_opening_bet_increment() -> void:
	var players: Array[Player] = _players_with_stacks([40, 100, 100])
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_true(round.apply_action(0, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.current_bet, 40)
	assert_eq(round.minimum_wager_total(), 80)
	assert_true(round.apply_action(1, PlayerAction.raise_to(80)).is_ok())
	assert_eq(round.minimum_wager_total(), 120)
	assert_true(round.apply_action(2, PlayerAction.call_action()).is_ok())
	assert_true(round.is_complete())


func _assert_closed_raise_rejected_unchanged(table: Table, round: BettingRound) -> void:
	assert_has(round.legal_actions(round.acting_seat), PlayerAction.Kind.CALL)
	assert_does_not_have(round.legal_actions(round.acting_seat), PlayerAction.Kind.RAISE)
	assert_does_not_have(round.legal_actions(round.acting_seat), PlayerAction.Kind.ALL_IN)
	for action: PlayerAction in [
		PlayerAction.raise_to(round.minimum_wager_total()), PlayerAction.all_in_action()
	]:
		var before: Array = _round_snapshot(table, round)
		assert_eq(
			round.apply_action(round.acting_seat, action).code,
			ActionValidationResult.Code.RAISE_NOT_REOPENED,
		)
		assert_eq(_round_snapshot(table, round), before)


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


func test_closed_raise_rights_reject_an_all_in_increase_without_mutation() -> void:
	var players: Array[Player] = _players_with_stacks([100, 100, 15])
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_true(round.apply_action(0, PlayerAction.bet_to(10)).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(2, PlayerAction.all_in_action()).is_ok())
	assert_eq(round.current_bet, 15)
	assert_eq(round.acting_seat, 0)
	assert_false(round.can_raise(0))
	assert_has(round.legal_actions(0), PlayerAction.Kind.CALL)
	assert_does_not_have(round.legal_actions(0), PlayerAction.Kind.ALL_IN)

	var rejected: ActionValidationResult = round.apply_action(0, PlayerAction.all_in_action())

	assert_eq(rejected.code, ActionValidationResult.Code.RAISE_NOT_REOPENED)
	assert_eq(players[0].stack, 90)
	assert_eq(players[0].bet_this_round, 10)
	assert_eq(round.current_bet, 15)
	assert_eq(round.acting_seat, 0)
	assert_eq(round.pending_seats(), [0, 1])


func test_closed_raise_rights_still_allow_an_exact_all_in_call() -> void:
	var players: Array[Player] = _players_with_stacks([15, 100, 15])
	var round := BettingRound.new(Table.new(players, 5, 10), 0)

	assert_true(round.apply_action(0, PlayerAction.bet_to(10)).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	assert_true(round.apply_action(2, PlayerAction.all_in_action()).is_ok())
	assert_false(round.can_raise(0))
	assert_has(round.legal_actions(0), PlayerAction.Kind.CALL)
	assert_has(round.legal_actions(0), PlayerAction.Kind.ALL_IN)

	var result: ActionValidationResult = round.apply_action(0, PlayerAction.all_in_action())

	assert_true(result.is_ok())
	assert_eq(result.chips_committed, 5)
	assert_true(players[0].all_in)
	assert_eq(round.current_bet, 15)


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
