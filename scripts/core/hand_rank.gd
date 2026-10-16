class_name HandRank
extends RefCounted

## Comparable value describing the best five-card poker hand.

enum Category {
	HIGH_CARD,
	ONE_PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
}

var category: Category
var tie_break_values: Array[int]:
	get:
		return _tie_break_values.duplicate()
var selected_cards: Array[CardData]:
	get:
		return _selected_cards.duplicate()

var _tie_break_values: Array[int]
var _selected_cards: Array[CardData]


func _init(
	hand_category: Category,
	hand_tie_break_values: Array,
	hand_selected_cards: Array[CardData],
) -> void:
	assert(hand_selected_cards.size() == 5, "A hand rank must select exactly five cards.")
	category = hand_category
	for value: Variant in hand_tie_break_values:
		assert(value is int, "Tie-break values must be integers.")
		_tie_break_values.append(int(value))
	_selected_cards = hand_selected_cards.duplicate()


func compare_to(other: HandRank) -> int:
	assert(other != null, "A hand rank can only be compared with another hand rank.")
	if category != other.category:
		return 1 if category > other.category else -1

	var other_values: Array[int] = other.tie_break_values
	var compared_count: int = mini(_tie_break_values.size(), other_values.size())
	for index: int in range(compared_count):
		if _tie_break_values[index] != other_values[index]:
			return 1 if _tie_break_values[index] > other_values[index] else -1
	if _tie_break_values.size() == other_values.size():
		return 0
	return 1 if _tie_break_values.size() > other_values.size() else -1


func ties(other: HandRank) -> bool:
	return other != null and compare_to(other) == 0
