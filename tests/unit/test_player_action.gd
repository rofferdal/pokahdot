extends "res://tests/support/poker_gut_test.gd"


func test_non_wager_actions_have_zero_amount_and_valid_shape() -> void:
	var actions: Array[PlayerAction] = [
		PlayerAction.fold_action(),
		PlayerAction.check_action(),
		PlayerAction.call_action(),
		PlayerAction.all_in_action(),
	]

	for action: PlayerAction in actions:
		assert_eq(action.amount, 0)
		assert_false(action.has_wager_amount())
		assert_true(action.has_valid_shape())


func test_bet_and_raise_amounts_are_target_totals() -> void:
	var bet := PlayerAction.bet_to(25)
	var raise := PlayerAction.raise_to(60)

	assert_eq(bet.kind, PlayerAction.Kind.BET)
	assert_eq(bet.amount, 25)
	assert_true(bet.has_valid_shape())
	assert_eq(raise.kind, PlayerAction.Kind.RAISE)
	assert_eq(raise.amount, 60)
	assert_true(raise.has_valid_shape())


func test_action_shape_rejects_amount_on_fixed_actions_and_non_positive_wagers() -> void:
	assert_false(PlayerAction.new(PlayerAction.Kind.CALL, 10).has_valid_shape())
	assert_false(PlayerAction.bet_to(0).has_valid_shape())
	assert_false(PlayerAction.raise_to(-1).has_valid_shape())


func test_typed_validation_results_distinguish_acceptance_and_rejection() -> void:
	var accepted := ActionValidationResult.accepted(15)
	var rejected := (
		ActionValidationResult
		. rejected(
			ActionValidationResult.Code.BELOW_MINIMUM,
			"Raise total is below the minimum.",
		)
	)

	assert_true(accepted.is_ok())
	assert_eq(accepted.chips_committed, 15)
	assert_false(rejected.is_ok())
	assert_eq(rejected.code, ActionValidationResult.Code.BELOW_MINIMUM)
	assert_eq(rejected.message, "Raise total is below the minimum.")
