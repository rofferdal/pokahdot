class_name CardViewModel
extends RefCounted

## Detached card presentation. Back/empty states contain no card identity.
enum State { EMPTY, BACK, FACE }

var state: State = State.EMPTY
var rank_text: String = ""
var suit_text: String = ""
var suit: int = -1
var rank: int = 0


static func face(card: CardData) -> CardViewModel:
	if card == null:
		return empty()
	var result := CardViewModel.new()
	result.state = State.FACE
	result.rank = card.rank
	result.suit = card.suit
	result.rank_text = {11: "J", 12: "Q", 13: "K", 14: "A"}.get(card.rank, str(card.rank))
	result.suit_text = ["♣", "♦", "♥", "♠"][card.suit]
	return result


static func back() -> CardViewModel:
	var result := CardViewModel.new()
	result.state = State.BACK
	return result


static func empty() -> CardViewModel:
	return CardViewModel.new()
