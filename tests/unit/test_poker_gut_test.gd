extends "res://tests/support/poker_gut_test.gd"


func test_assert_chip_total_accepts_conserved_stacks() -> void:
	var stacks: Array[int] = [100, 250, 650]

	assert_chip_total(stacks, 1000, "three-player table")


func test_assert_unique_card_codes_accepts_a_deck_without_duplicates() -> void:
	var card_codes: Array[String] = ["As", "Kd", "7h", "2c"]

	assert_unique_card_codes(card_codes, "test hand")
