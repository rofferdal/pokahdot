extends "res://tests/support/poker_gut_test.gd"

var category_cases: Array[Dictionary] = [
	{"cards": "AS KD 9C 6H 3S", "category": HandRank.Category.HIGH_CARD, "ties": [14, 13, 9, 6, 3]},
	{"cards": "AS AD 9C 6H 3S", "category": HandRank.Category.ONE_PAIR, "ties": [14, 9, 6, 3]},
	{"cards": "AS AD 9C 9H 3S", "category": HandRank.Category.TWO_PAIR, "ties": [14, 9, 3]},
	{"cards": "AS AD AC 6H 3S", "category": HandRank.Category.THREE_OF_A_KIND, "ties": [14, 6, 3]},
	{"cards": "9S 8D 7C 6H 5S", "category": HandRank.Category.STRAIGHT, "ties": [9]},
	{"cards": "AS JS 9S 6S 3S", "category": HandRank.Category.FLUSH, "ties": [14, 11, 9, 6, 3]},
	{"cards": "AS AD AC 6H 6S", "category": HandRank.Category.FULL_HOUSE, "ties": [14, 6]},
	{"cards": "AS AD AC AH 3S", "category": HandRank.Category.FOUR_OF_A_KIND, "ties": [14, 3]},
	{"cards": "9S 8S 7S 6S 5S", "category": HandRank.Category.STRAIGHT_FLUSH, "ties": [9]},
]


func test_all_hand_categories(case: Dictionary = use_parameters(category_cases)) -> void:
	var rank: HandRank = HandEvaluator.new().evaluate(_cards(case.cards))

	assert_not_null(rank)
	assert_eq(rank.category, case.category)
	assert_eq(rank.tie_break_values, case.ties)
	assert_eq(rank.selected_cards.size(), 5)


func test_seven_cards_select_the_strongest_five() -> void:
	var rank: HandRank = HandEvaluator.new().evaluate(_cards("AS AD AC KH KD 2C 3D"))

	assert_eq(rank.category, HandRank.Category.FULL_HOUSE)
	assert_eq(rank.tie_break_values, [14, 13])
	assert_eq(_card_ids(rank.selected_cards).size(), 5)


func test_wheel_is_five_high_and_compares_between_king_high_and_six_high_straight() -> void:
	var evaluator := HandEvaluator.new()
	var wheel: HandRank = evaluator.evaluate(_cards("AS 2D 3C 4H 5S"))
	var king_high: HandRank = evaluator.evaluate(_cards("KS QD 9C 7H 4S"))
	var six_high: HandRank = evaluator.evaluate(_cards("2S 3D 4C 5H 6S"))

	assert_eq(wheel.tie_break_values, [5])
	assert_gt(wheel.compare_to(king_high), 0)
	assert_lt(wheel.compare_to(six_high), 0)


func test_kickers_break_pairs_two_pairs_trips_and_quads() -> void:
	var evaluator := HandEvaluator.new()
	assert_gt(
		evaluator.evaluate(_cards("AS AD KC QH 2S")).compare_to(
			evaluator.evaluate(_cards("AC AH KD JH 9S"))
		),
		0,
	)
	assert_gt(
		evaluator.evaluate(_cards("AS AD KC KH QS")).compare_to(
			evaluator.evaluate(_cards("AC AH KD KS JS"))
		),
		0,
	)
	assert_gt(
		evaluator.evaluate(_cards("AS AD AC KH QS")).compare_to(
			evaluator.evaluate(_cards("AH AC AS KD JS"))
		),
		0,
	)
	assert_gt(
		evaluator.evaluate(_cards("AS AD AC AH KS")).compare_to(
			evaluator.evaluate(_cards("KS KD KC KH AS"))
		),
		0,
	)


func test_equal_ranked_hands_tie_regardless_of_suits() -> void:
	var first: HandRank = HandEvaluator.new().evaluate(_cards("AS AD KC QH JS"))
	var second: HandRank = HandEvaluator.new().evaluate(_cards("AH AC KD QS JH"))

	assert_true(first.ties(second))
	assert_eq(first.compare_to(second), 0)


func test_rejects_wrong_card_count_duplicates_and_null_cards() -> void:
	var evaluator := HandEvaluator.new()
	assert_null(evaluator.evaluate(_cards("AS KD QC JH")))
	assert_null(evaluator.evaluate(_cards("AS KD QC JH 10S 9D 8C 7H")))
	assert_null(evaluator.evaluate(_cards("AS AS QC JH 10S")))
	var cards_with_null: Array[CardData] = _cards("AS KD QC JH")
	cards_with_null.append(null)
	assert_null(evaluator.evaluate(cards_with_null))


func test_returned_collections_cannot_mutate_rank() -> void:
	var rank: HandRank = HandEvaluator.new().evaluate(_cards("AS AD KC QH JS"))
	var ties: Array[int] = rank.tie_break_values
	var selected: Array[CardData] = rank.selected_cards
	ties.clear()
	selected.clear()

	assert_eq(rank.tie_break_values, [14, 13, 12, 11])
	assert_eq(rank.selected_cards.size(), 5)


func _cards(description: String) -> Array[CardData]:
	var result: Array[CardData] = []
	for token: String in description.split(" ", false):
		var rank_text: String = token.left(token.length() - 1)
		var suit_text: String = token.right(1)
		result.append(CardData.new(_rank(rank_text), _suit(suit_text)))
	return result


func _rank(value: String) -> int:
	var named_ranks: Dictionary = {"T": 10, "J": 11, "Q": 12, "K": 13, "A": 14}
	return int(named_ranks.get(value, int(value)))


func _suit(value: String) -> CardData.Suit:
	var suits: Dictionary = {
		"C": CardData.Suit.CLUBS,
		"D": CardData.Suit.DIAMONDS,
		"H": CardData.Suit.HEARTS,
		"S": CardData.Suit.SPADES,
	}
	return suits[value] as CardData.Suit


func _card_ids(cards: Array[CardData]) -> Dictionary:
	var result: Dictionary = {}
	for card: CardData in cards:
		result[card.card_id] = true
	return result
