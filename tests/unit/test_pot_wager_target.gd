extends "res://tests/support/poker_gut_test.gd"

const PotWagerTargetScript := preload("res://scripts/core/pot_wager_target.gd")
const MAX_INT_64: int = 9223372036854775807


func test_unopened_pot_bet_targets_the_current_pot_total() -> void:
	var result: PotWagerTargetResult = PotWagerTargetScript.resolve(20, 0, 0, 10, 100)
	assert_true(result.available)
	assert_eq(result.contribution, 20)
	assert_eq(result.wager_total, 20)
	assert_eq(result.reason, PotWagerTargetScript.AVAILABLE)


func test_pot_raise_adds_the_displayed_pot_to_the_street_total() -> void:
	var result: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 0, 10, 20, 100)
	assert_true(result.available)
	assert_eq(result.contribution, 30)
	assert_eq(result.wager_total, 30)
	assert_eq(30 + (result.wager_total - 0), 60)


func test_pot_raise_adds_the_displayed_pot_after_an_existing_street_wager() -> void:
	var result: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 5, 5, 20, 100)
	assert_true(result.available)
	assert_eq(result.contribution, 30)
	assert_eq(result.wager_total, 35)
	assert_eq(30 + (result.wager_total - 5), 60)


func test_half_pot_fraction_uses_the_displayed_pot_and_existing_wager_semantics() -> void:
	var result: PotWagerTargetResult = PotWagerTargetScript.calculate_fraction(100, 0, 10, 2)
	assert_true(result.available)
	assert_eq(result.contribution, 50)
	assert_eq(result.wager_total, 50)


func test_pot_target_is_independent_of_call_amount() -> void:
	var without_call: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 5, 0, 0, 100)
	var with_call: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 5, 10, 0, 100)
	assert_eq(without_call.wager_total, 35)
	assert_eq(with_call.wager_total, 35)


func test_fraction_target_is_independent_of_call_amount() -> void:
	var without_call: PotWagerTargetResult = PotWagerTargetScript.calculate_fraction(101, 5, 0, 2)
	var with_call: PotWagerTargetResult = PotWagerTargetScript.calculate_fraction(101, 5, 10, 2)
	assert_eq(without_call.wager_total, 55)
	assert_eq(with_call.wager_total, 55)


func test_exact_minimum_and_maximum_targets_are_available() -> void:
	var at_minimum: PotWagerTargetResult = PotWagerTargetScript.resolve(20, 0, 0, 20, 100)
	var at_maximum: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 0, 10, 20, 30)
	assert_true(at_minimum.available)
	assert_eq(at_minimum.wager_total, 20)
	assert_true(at_maximum.available)
	assert_eq(at_maximum.wager_total, 30)


func test_exact_pot_target_outside_legal_bounds_is_unavailable() -> void:
	var below_minimum: PotWagerTargetResult = PotWagerTargetScript.resolve(5, 0, 0, 10, 100)
	var above_maximum: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 0, 10, 20, 29)
	assert_false(below_minimum.available)
	assert_eq(below_minimum.contribution, 5)
	assert_eq(below_minimum.wager_total, 5)
	assert_eq(below_minimum.reason, PotWagerTargetScript.OUTSIDE_LEGAL_RANGE)
	assert_false(above_maximum.available)
	assert_eq(above_maximum.contribution, 30)
	assert_eq(above_maximum.wager_total, 30)
	assert_eq(above_maximum.reason, PotWagerTargetScript.OUTSIDE_LEGAL_RANGE)


func test_invalid_or_overflowing_inputs_are_explicitly_unavailable() -> void:
	for invalid_result: PotWagerTargetResult in [
		PotWagerTargetScript.resolve(-1, 0, 0, 0, 100),
		PotWagerTargetScript.resolve(10, -1, 0, 0, 100),
		PotWagerTargetScript.resolve(10, 0, -1, 0, 100),
		PotWagerTargetScript.resolve(10, 0, 0, -1, 100),
		PotWagerTargetScript.resolve(10, 0, 0, 101, 100),
	]:
		assert_false(invalid_result.available)
		assert_eq(invalid_result.contribution, 0)
		assert_eq(invalid_result.wager_total, 0)
		assert_eq(invalid_result.reason, PotWagerTargetScript.INVALID_INPUT)

	var overflow: PotWagerTargetResult = PotWagerTargetScript.resolve(
		MAX_INT_64, 1, 0, 0, MAX_INT_64
	)
	assert_false(overflow.available)
	assert_eq(overflow.contribution, 0)
	assert_eq(overflow.wager_total, 0)
	assert_eq(overflow.reason, PotWagerTargetScript.OVERFLOW)
