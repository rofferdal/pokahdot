class_name ShowdownResult
extends RefCounted

## Immutable, recipient-safe description of one hand revealed at showdown.

var seat: int:
	get:
		return _seat
var hole_cards: Array[CardData]:
	get:
		return _hole_cards.duplicate()
var category: HandRank.Category:
	get:
		return _category
var tie_break_values: Array[int]:
	get:
		return _tie_break_values.duplicate()
var selected_cards: Array[CardData]:
	get:
		return _selected_cards.duplicate()

var _seat: int
var _hole_cards: Array[CardData]
var _category: HandRank.Category
var _tie_break_values: Array[int]
var _selected_cards: Array[CardData]


func _init(result_seat: int, revealed_cards: Array[CardData], rank: HandRank) -> void:
	assert(result_seat >= 0, "A showdown result requires a valid seat.")
	assert(revealed_cards.size() == 2, "A showdown result requires two hole cards.")
	assert(rank != null, "A showdown result requires an evaluated hand rank.")
	_seat = result_seat
	_hole_cards = revealed_cards.duplicate()
	_category = rank.category
	_tie_break_values = rank.tie_break_values
	_selected_cards = rank.selected_cards
