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


func test_blind_growth_saturates_at_the_supported_maximum_without_overflow() -> void:
	var progression := BlindLevelProgression.new(400_000, 800_000, 2)
	for _level: int in range(3):
		for _hand: int in range(10):
			progression.record_completed_hand(2)
		assert_eq(progression.small_blind, 500_000)
		assert_eq(progression.big_blind, ConfigResolver.MAX_STARTUP_CHIPS)
		assert_gt(progression.small_blind, 0)
		assert_gt(progression.big_blind, 0)


func test_both_modes_follow_the_documented_first_five_levels() -> void:
	for aggressive: bool in [false, true]:
		var expected: Array[int] = [10, 14, 18, 24, 30]
		if aggressive:
			expected.assign([10, 18, 32, 56, 98])
		var progression := BlindLevelProgression.new(5, 10, 2, aggressive)
		for level: int in range(expected.size()):
			assert_eq(progression.big_blind, expected[level])
			assert_eq(progression.small_blind * 2, expected[level])
			assert_eq(progression.blind_level, level + 1)
			_advance_level(progression)


func test_both_modes_handle_odd_blinds_and_cap_arithmetic_boundaries() -> void:
	var inputs: Array[int] = [
		1,
		3,
		5,
		7,
		9,
		11,
		571_426,
		571_427,
		571_428,
		571_429,
		799_998,
		799_999,
		800_000,
		800_001,
		999_999,
		1_000_000,
	]
	for aggressive: bool in [false, true]:
		for input: int in inputs:
			var progression := BlindLevelProgression.new(1, input, 2, aggressive)
			assert_eq(progression.big_blind, input, "Level one retains the supplied blind")
			_advance_level(progression)
			var expected: int = (input * (7 if aggressive else 5) + 3) / 4
			if expected % 2 != 0:
				expected += 1
			assert_eq(progression.big_blind, mini(expected, 1_000_000))
			assert_eq(progression.small_blind * 2, progression.big_blind)


func test_aggressive_copy_keeps_growth_mode_and_independent_level_snapshot() -> void:
	var original := BlindLevelProgression.new(5, 10, 6, true)
	for _hand: int in range(11):
		original.record_completed_hand(4)
	var copied := original.copy()
	assert_true(copied.record_completed_hand(4))
	assert_eq(copied.big_blind, 18)
	assert_eq(copied.active_player_count_at_level_start, 4)
	assert_eq(copied.hands_until_next_level, 10)
	assert_eq(original.blind_level, 1)
	assert_eq(original.hands_until_next_level, 1)
	assert_true(original.record_completed_hand(3))
	assert_eq(original.big_blind, 18)
	assert_eq(original.active_player_count_at_level_start, 3)
	_advance_level(copied)
	assert_eq(copied.big_blind, 32)


func test_aggressive_cap_keeps_advancing_level_counters() -> void:
	var progression := BlindLevelProgression.new(300_000, 600_000, 2, true)
	for level: int in range(2, 5):
		_advance_level(progression)
		assert_eq(progression.big_blind, 1_000_000)
		assert_eq(progression.small_blind, 500_000)
		assert_eq(progression.blind_level, level)
		assert_eq(progression.completed_hands_in_level, 0)
		assert_eq(progression.hands_until_next_level, 10)


func _advance_level(progression: BlindLevelProgression) -> void:
	for _hand: int in range(progression.hands_until_next_level):
		progression.record_completed_hand(2)
