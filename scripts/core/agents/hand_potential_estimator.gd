class_name HandPotentialEstimator
extends RefCounted

## Pure hand-potential service boundary.
##
## It accepts only the hero's cards, public board cards, and explicitly
## supplied public context. It never receives or retains Table, Player, Deck,
## GUI, CLI, or mutable match-state objects.

const HandPotentialContextScript := preload("res://scripts/core/agents/hand_potential_context.gd")
const HandPotentialEstimateScript := preload("res://scripts/core/agents/hand_potential_estimate.gd")


func estimate(
	hero_cards: Array[CardData],
	public_board: Array[CardData],
	context: HandPotentialContext,
) -> HandPotentialEstimate:
	if context == null or not context.is_valid():
		return null
	if hero_cards.size() != 2 or public_board.size() > 5:
		return null
	if not _contains_valid_unique_cards(hero_cards, public_board):
		return null
	return HandPotentialEstimateScript.new(hero_cards, public_board, context)


func _contains_valid_unique_cards(
	hero_cards: Array[CardData], public_board: Array[CardData]
) -> bool:
	var seen_ids: Dictionary = {}
	for card: CardData in hero_cards + public_board:
		if card == null or seen_ids.has(card.card_id):
			return false
		seen_ids[card.card_id] = true
	return true
