extends "res://tests/support/poker_gut_test.gd"

const CASES: Array[Dictionary] = [
	{"category": HandRank.Category.HIGH_CARD, "ties": [14, 13, 11, 9, 7], "text": "A-high"},
	{"category": HandRank.Category.ONE_PAIR, "ties": [12, 14, 13, 11], "text": "Pair: Q"},
	{"category": HandRank.Category.TWO_PAIR, "ties": [13, 10, 14], "text": "Two pair: K / 10"},
	{
		"category": HandRank.Category.THREE_OF_A_KIND,
		"ties": [11, 14, 13],
		"text": "Three of a kind: J"
	},
	{"category": HandRank.Category.STRAIGHT, "ties": [5], "text": "Straight: 5-high"},
	{"category": HandRank.Category.FLUSH, "ties": [13, 11, 9, 7, 2], "text": "Flush: K-high"},
	{"category": HandRank.Category.FULL_HOUSE, "ties": [14, 13], "text": "Full house: A / K"},
	{"category": HandRank.Category.FOUR_OF_A_KIND, "ties": [12, 14], "text": "Four of a kind: Q"},
	{"category": HandRank.Category.STRAIGHT_FLUSH, "ties": [14], "text": "Straight flush: A-high"},
]


func test_inline_copy_preserves_category_and_relevant_rank_symbols(
	case: Dictionary = use_parameters(CASES)
) -> void:
	var holes: Array[CardData] = [
		CardData.new(14, CardData.Suit.CLUBS), CardData.new(13, CardData.Suit.DIAMONDS)
	]
	var selected: Array[CardData] = holes.duplicate()
	selected.append_array(
		[
			CardData.new(12, CardData.Suit.HEARTS),
			CardData.new(11, CardData.Suit.SPADES),
			CardData.new(10, CardData.Suit.CLUBS)
		]
	)
	var ties: Array[int] = []
	ties.assign(case.ties)
	var result := ShowdownResult.new(
		0, holes, HandRank.new(case.category as HandRank.Category, ties, selected)
	)
	assert_eq(ShowdownHandFormatter.format_inline(result), case.text)
	var font: Font = ThemeDB.fallback_font
	assert_lte(
		font.get_string_size(case.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x,
		234.0,
		"Complete inline copy must fit the narrowest supported compact landscape band"
	)


func test_inline_copy_has_no_summary_for_unrevealed_seat() -> void:
	assert_eq(ShowdownHandFormatter.format_inline(null), "")
