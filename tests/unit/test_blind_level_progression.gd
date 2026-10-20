extends "res://tests/support/poker_gut_test.gd"


func test_five_or_more_players_use_twice_the_level_start_count() -> void:
	var progression := BlindLevelProgression.new(5, 10, 6)

	for _hand: int in range(11):
		assert_false(progression.record_completed_hand(4))

	assert_eq(progression.blind_level, 1)
	assert_eq(progression.completed_hands_in_level, 11)
	assert_eq(progression.hands_until_next_level, 1)
	assert_eq(progression.active_player_count_at_level_start, 6)
	assert_true(progression.record_completed_hand(4))
	assert_eq(progression.blind_level, 2)
	assert_eq(progression.completed_hands_in_level, 0)
	assert_eq(progression.hands_until_next_level, 10)
	assert_eq(progression.active_player_count_at_level_start, 4)


func test_under_five_players_use_ten_hand_interval_and_keep_it_stable() -> void:
	var progression := BlindLevelProgression.new(5, 10, 4)

	for _hand: int in range(9):
		assert_false(progression.record_completed_hand(6))
	assert_eq(progression.hands_until_next_level, 1)
	assert_eq(progression.active_player_count_at_level_start, 4)
	assert_true(progression.record_completed_hand(3))
	assert_eq(progression.blind_level, 2)
	assert_eq(progression.active_player_count_at_level_start, 3)


func test_blind_increase_rounds_up_to_an_even_big_blind() -> void:
	var progression := BlindLevelProgression.new(5, 10, 2)
	for _hand: int in range(9):
		progression.record_completed_hand(2)
	assert_true(progression.record_completed_hand(2))
	assert_eq(progression.small_blind, 7)
	assert_eq(progression.big_blind, 14)

	var next := BlindLevelProgression.new(7, 14, 2)
	for _hand: int in range(9):
		next.record_completed_hand(2)
	assert_true(next.record_completed_hand(2))
	assert_eq(next.small_blind, 9)
	assert_eq(next.big_blind, 18)


func test_odd_big_blind_inputs_round_up_to_the_next_even_integer() -> void:
	for input: int in [1, 3, 5, 7, 9, 11]:
		var progression := BlindLevelProgression.new(1, input, 2)
		for _hand: int in range(9):
			progression.record_completed_hand(2)
		assert_true(progression.record_completed_hand(2))
		assert_eq(progression.big_blind % 2, 0)
		assert_eq(progression.small_blind * 2, progression.big_blind)
		assert_true(progression.big_blind * 4 >= input * 5)
