extends "res://tests/support/poker_gut_test.gd"

const PotWagerTargetScript := preload("res://scripts/core/pot_wager_target.gd")
const MAX_INT_64: int = 9223372036854775807


func test_unopened_pot_bet_targets_the_current_pot_total() -> void:
	var result: PotWagerTargetResult = PotWagerTargetScript.resolve(20, 0, 0, 10, 100)
	assert_true(result.available)
	assert_eq(result.total, 20)
	assert_eq(result.reason, PotWagerTargetScript.AVAILABLE)


func test_pot_raise_includes_the_call_and_post_call_pot() -> void:
	var result: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 0, 10, 20, 100)
	assert_true(result.available)
	assert_eq(result.total, 50)


func test_pot_raise_includes_an_existing_street_wager() -> void:
	var result: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 5, 5, 20, 100)
	assert_true(result.available)
	assert_eq(result.total, 45)


func test_half_pot_fraction_uses_the_post_call_pot_and_total_wager_semantics() -> void:
	var result: PotWagerTargetResult = PotWagerTargetScript.calculate_fraction(100, 0, 10, 2)
	assert_true(result.available)
	assert_eq(result.total, 65)


func test_exact_minimum_and_maximum_targets_are_available() -> void:
	var at_minimum: PotWagerTargetResult = PotWagerTargetScript.resolve(20, 0, 0, 20, 100)
	var at_maximum: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 0, 10, 20, 50)
	assert_true(at_minimum.available)
	assert_eq(at_minimum.total, 20)
	assert_true(at_maximum.available)
	assert_eq(at_maximum.total, 50)


func test_exact_pot_target_outside_legal_bounds_is_unavailable() -> void:
	var below_minimum: PotWagerTargetResult = PotWagerTargetScript.resolve(5, 0, 0, 10, 100)
	var above_maximum: PotWagerTargetResult = PotWagerTargetScript.resolve(30, 0, 10, 20, 49)
	assert_false(below_minimum.available)
	assert_eq(below_minimum.total, 5)
	assert_eq(below_minimum.reason, PotWagerTargetScript.OUTSIDE_LEGAL_RANGE)
	assert_false(above_maximum.available)
	assert_eq(above_maximum.total, 50)
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
		assert_eq(invalid_result.total, 0)
		assert_eq(invalid_result.reason, PotWagerTargetScript.INVALID_INPUT)

	var overflow: PotWagerTargetResult = PotWagerTargetScript.resolve(
		MAX_INT_64, 0, 1, 0, MAX_INT_64
	)
	assert_false(overflow.available)
	assert_eq(overflow.total, 0)
	assert_eq(overflow.reason, PotWagerTargetScript.OVERFLOW)
