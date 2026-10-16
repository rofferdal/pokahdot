class_name CardData
extends Resource

## Immutable value object for one standard Hold'em card.

enum Suit {
	CLUBS,
	DIAMONDS,
	HEARTS,
	SPADES,
}

const MIN_RANK: int = 2
const MAX_RANK: int = 14

var card_id: int:
	get:
		return _card_id
var rank: int:
	get:
		return _rank
var suit: Suit:
	get:
		return _suit

var _card_id: int
var _rank: int
var _suit: Suit


func _init(card_rank: int = MIN_RANK, card_suit: Suit = Suit.CLUBS) -> void:
	assert(card_rank >= MIN_RANK and card_rank <= MAX_RANK, "Card rank must be between 2 and 14.")
	assert(card_suit >= Suit.CLUBS and card_suit <= Suit.SPADES, "Card suit is invalid.")
	_rank = card_rank
	_suit = card_suit
	_card_id = (card_rank - MIN_RANK) * 4 + int(card_suit)


func code() -> String:
	return "%d:%d" % [_rank, _suit]


func _to_string() -> String:
	return code()
