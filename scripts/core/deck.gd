class_name Deck
extends RefCounted

## A fresh, standard 52-card deck for one hand.

const CARD_COUNT: int = 52

var _cards: Array[CardData] = []


func _init() -> void:
	reset()


func reset() -> void:
	_cards.clear()
	for card_rank: int in range(CardData.MIN_RANK, CardData.MAX_RANK + 1):
		for card_suit: CardData.Suit in range(CardData.Suit.CLUBS, CardData.Suit.SPADES + 1):
			_cards.append(CardData.new(card_rank, card_suit))


func shuffle(rng: RandomNumberGenerator) -> void:
	assert(rng != null, "A random number generator is required.")
	for index: int in range(_cards.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var card: CardData = _cards[index]
		_cards[index] = _cards[swap_index]
		_cards[swap_index] = card


func draw() -> CardData:
	if _cards.is_empty():
		# A null result is the explicit exhaustion signal; callers must not continue
		# dealing after it.
		return null
	return _cards.pop_back()


func draw_card() -> CardData:
	return draw()


func remaining_count() -> int:
	return _cards.size()


func cards() -> Array[CardData]:
	return _cards.duplicate()
