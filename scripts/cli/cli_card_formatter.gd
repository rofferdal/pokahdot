class_name CliCardFormatter
extends RefCounted

## CLI-only presentation rules for standard playing cards.

const RANK_LABELS: Dictionary[int, String] = {
	11: "J",
	12: "Q",
	13: "K",
	14: "A",
}
const SUIT_LABELS: Dictionary[CardData.Suit, String] = {
	CardData.Suit.CLUBS: "♣",
	CardData.Suit.DIAMONDS: "♦",
	CardData.Suit.HEARTS: "♥",
	CardData.Suit.SPADES: "♠",
}


static func format_card(card: CardData) -> String:
	assert(card != null, "A card is required.")
	var rank_label: String = RANK_LABELS.get(card.rank, str(card.rank))
	return rank_label + SUIT_LABELS[card.suit]


static func format_cards(cards: Array[CardData]) -> String:
	var formatted := PackedStringArray()
	for card: CardData in cards:
		formatted.append(format_card(card))
	return "[ %s ]" % " | ".join(formatted)
