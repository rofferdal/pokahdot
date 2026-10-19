class_name HandPotentialEstimate
extends RefCounted

## Result of a HandPotentialEstimator request.
##
## Preflop score calibration is deliberately explainable and bounded:
## pair strength 45%, rank strength 30%, suitedness 10%, connectivity 10%,
## and position 5%. The postflop score is a bounded strength/potential
## heuristic, not equity. Postflop fields describe the made hand, one-card
## draw quality, public-board texture, and whether a future card can improve
## the hand. They never use an opponent card or an undealt-card collection.
## The copied inputs make the contract observable without exposing mutable
## caller-owned collections.

const HandEvaluatorScript := preload("res://scripts/core/hand_evaluator.gd")

const MAX_DRAW_QUALITY: int = 100
const DIRECT_FLUSH_DRAW_QUALITY: int = 85
const BACKDOOR_FLUSH_DRAW_QUALITY: int = 25
const OPEN_ENDED_STRAIGHT_DRAW_QUALITY: int = 80
const GUTSHOT_STRAIGHT_DRAW_QUALITY: int = 55
const BACKDOOR_STRAIGHT_DRAW_QUALITY: int = 25
const MADE_HAND_STRENGTHS: Dictionary = {
	HandRank.Category.HIGH_CARD: 15.0,
	HandRank.Category.ONE_PAIR: 40.0,
	HandRank.Category.TWO_PAIR: 62.0,
	HandRank.Category.THREE_OF_A_KIND: 72.0,
	HandRank.Category.STRAIGHT: 86.0,
	HandRank.Category.FLUSH: 90.0,
	HandRank.Category.FULL_HOUSE: 95.0,
	HandRank.Category.FOUR_OF_A_KIND: 98.0,
	HandRank.Category.STRAIGHT_FLUSH: 100.0,
}
const CATEGORY_NAMES: Dictionary = {
	HandRank.Category.HIGH_CARD: &"high_card",
	HandRank.Category.ONE_PAIR: &"one_pair",
	HandRank.Category.TWO_PAIR: &"two_pair",
	HandRank.Category.THREE_OF_A_KIND: &"three_of_a_kind",
	HandRank.Category.STRAIGHT: &"straight",
	HandRank.Category.FLUSH: &"flush",
	HandRank.Category.FULL_HOUSE: &"full_house",
	HandRank.Category.FOUR_OF_A_KIND: &"four_of_a_kind",
	HandRank.Category.STRAIGHT_FLUSH: &"straight_flush",
}

var score: int = 0
var hero_cards: Array[CardData] = []
var public_board: Array[CardData] = []
var context: HandPotentialContext

## The strongest made category currently available from hero cards and board.
## A high card is a valid made class even when no pair or stronger hand exists.
var made_hand_class: HandRank.Category = HandRank.Category.HIGH_CARD
## Alias with poker-domain wording for callers that prefer category terminology.
var made_hand_category: HandRank.Category = HandRank.Category.HIGH_CARD
## Stable, presentation-independent name for diagnostics and tests.
var made_hand_class_name: StringName = &"high_card"
## Quality of a flush draw that can complete with one future public card.
## A made flush is represented by the made-hand class, so this is zero then.
var flush_draw_quality: int = 0
## Quality of a straight draw that can complete with one future public card.
## A made straight is represented by the made-hand class, so this is zero then.
var straight_draw_quality: int = 0
## Estimated outs for the strongest direct flush/straight improvement route.
var improvement_outs: int = 0
## Bounded heuristic for useful improvement on the remaining street(s).
var improvement_potential: int = 0
## Public board texture flags. They are independent so a board can be both.
var is_paired_board: bool = false
var is_coordinated_board: bool = false
## True when the river board itself ties the best available hero hand.
var is_board_only_hand: bool = false

## Backwards-friendly aliases that keep the result readable at call sites.
var paired_board: bool:
	get:
		return is_paired_board
var coordinated_board: bool:
	get:
		return is_coordinated_board
var board_only_hand: bool:
	get:
		return is_board_only_hand
var has_flush_draw: bool:
	get:
		return flush_draw_quality > 0
var has_straight_draw: bool:
	get:
		return straight_draw_quality > 0


func _init(
	result_hero_cards: Array[CardData],
	result_public_board: Array[CardData],
	result_context: HandPotentialContext,
) -> void:
	hero_cards = result_hero_cards.duplicate()
	public_board = result_public_board.duplicate()
	context = (
		HandPotentialContext
		. new(
			result_context.street,
			result_context.position,
			result_context.active_opponents,
			result_context.pot_size,
			result_context.call_amount,
			result_context.effective_stack,
			result_context.big_blind,
		)
	)
	if public_board.is_empty():
		score = _preflop_score()
	else:
		_analyze_postflop()
		score = _postflop_score()


func _analyze_postflop() -> void:
	var combined_cards: Array[CardData] = hero_cards + public_board
	var made_rank: HandRank = null
	if combined_cards.size() >= HandEvaluatorScript.MIN_CARDS:
		made_rank = HandEvaluatorScript.new().evaluate(combined_cards)
	if made_rank != null:
		made_hand_class = made_rank.category
		made_hand_category = made_rank.category
		made_hand_class_name = _category_name(made_rank.category)
		is_board_only_hand = _is_board_only(made_rank)
	else:
		made_hand_class = HandRank.Category.HIGH_CARD
		made_hand_category = HandRank.Category.HIGH_CARD
		made_hand_class_name = &"high_card"

	is_paired_board = _has_duplicate_rank(public_board)
	is_coordinated_board = (
		_has_coordinated_ranks(public_board) or _has_coordinated_suits(public_board)
	)
	flush_draw_quality = _flush_draw_quality(combined_cards, made_rank)
	straight_draw_quality = _straight_draw_quality(combined_cards, made_rank)
	var flush_outs: int = _flush_outs(combined_cards, made_rank)
	var straight_outs: int = _straight_outs(combined_cards, made_rank)
	improvement_outs = maxi(flush_outs, straight_outs)
	improvement_potential = _improvement_potential(
		combined_cards, made_rank, flush_outs, straight_outs
	)


func _postflop_score() -> int:
	var made_component: float = _made_hand_strength()
	var draw_component: float = float(maxi(flush_draw_quality, straight_draw_quality))
	var texture_penalty: float = 0.0
	if is_paired_board and made_hand_class <= HandRank.Category.ONE_PAIR:
		texture_penalty += 5.0
	if is_coordinated_board and made_hand_class <= HandRank.Category.ONE_PAIR:
		texture_penalty += 5.0
	var score_value: float = made_component + draw_component * 0.35 - texture_penalty
	if made_hand_class == HandRank.Category.HIGH_CARD:
		score_value += float(improvement_potential) * 0.25
	return clampi(roundi(score_value), 0, 100)


func _made_hand_strength() -> float:
	return float(MADE_HAND_STRENGTHS.get(made_hand_class, 15.0))


func _category_name(category: HandRank.Category) -> StringName:
	return CATEGORY_NAMES.get(category, &"high_card") as StringName


func _is_board_only(made_rank: HandRank) -> bool:
	if public_board.size() < HandEvaluatorScript.MIN_CARDS:
		return false
	var board_rank: HandRank = HandEvaluatorScript.new().evaluate(public_board)
	return board_rank != null and board_rank.ties(made_rank)


func _has_duplicate_rank(cards: Array[CardData]) -> bool:
	var rank_counts: Dictionary = {}
	for card: CardData in cards:
		rank_counts[card.rank] = int(rank_counts.get(card.rank, 0)) + 1
		if int(rank_counts[card.rank]) >= 2:
			return true
	return false


func _has_coordinated_ranks(cards: Array[CardData]) -> bool:
	if cards.size() < 3:
		return false
	var ranks: Dictionary = {}
	for card: CardData in cards:
		ranks[card.rank] = true
	if ranks.has(CardData.MAX_RANK):
		ranks[1] = true
	for high_rank: int in range(5, CardData.MAX_RANK + 1):
		var connected_count: int = 0
		for rank: int in range(high_rank - 4, high_rank + 1):
			if ranks.has(rank):
				connected_count += 1
		if connected_count >= 3:
			return true
	return false


func _has_coordinated_suits(cards: Array[CardData]) -> bool:
	var suit_counts: Dictionary = {}
	for card: CardData in cards:
		suit_counts[card.suit] = int(suit_counts.get(card.suit, 0)) + 1
	var highest_count: int = 0
	for count: Variant in suit_counts.values():
		highest_count = maxi(highest_count, int(count))
	return highest_count >= 3


func _flush_draw_quality(combined_cards: Array[CardData], made_rank: HandRank) -> int:
	if (
		made_rank != null
		and (
			made_rank.category == HandRank.Category.FLUSH
			or made_rank.category == HandRank.Category.STRAIGHT_FLUSH
		)
	):
		return 0
	var highest_count: int = _highest_suit_count(combined_cards)
	if highest_count >= 5:
		return 0
	if highest_count == 4:
		return DIRECT_FLUSH_DRAW_QUALITY
	if highest_count == 3 and public_board.size() == 3:
		return BACKDOOR_FLUSH_DRAW_QUALITY
	return 0


func _highest_suit_count(cards: Array[CardData]) -> int:
	var suit_counts: Dictionary = {}
	for card: CardData in cards:
		suit_counts[card.suit] = int(suit_counts.get(card.suit, 0)) + 1
	var highest_count: int = 0
	for count: Variant in suit_counts.values():
		highest_count = maxi(highest_count, int(count))
	return highest_count


func _flush_outs(combined_cards: Array[CardData], made_rank: HandRank) -> int:
	if (
		made_rank != null
		and (
			made_rank.category == HandRank.Category.FLUSH
			or made_rank.category == HandRank.Category.STRAIGHT_FLUSH
		)
	):
		return 0
	var suit_counts: Dictionary = {}
	for card: CardData in combined_cards:
		suit_counts[card.suit] = int(suit_counts.get(card.suit, 0)) + 1
	var outs: int = 0
	for count: Variant in suit_counts.values():
		if int(count) == 4:
			outs = maxi(outs, 13 - int(count))
	return outs


func _straight_draw_quality(combined_cards: Array[CardData], made_rank: HandRank) -> int:
	if (
		made_rank != null
		and (
			made_rank.category == HandRank.Category.STRAIGHT
			or made_rank.category == HandRank.Category.STRAIGHT_FLUSH
		)
	):
		return 0
	var completion_ranks: Array[int] = _straight_completion_ranks(combined_cards)
	if completion_ranks.size() >= 2:
		return OPEN_ENDED_STRAIGHT_DRAW_QUALITY
	if completion_ranks.size() == 1:
		return GUTSHOT_STRAIGHT_DRAW_QUALITY
	if _maximum_straight_window_count(combined_cards) == 3 and public_board.size() == 3:
		return BACKDOOR_STRAIGHT_DRAW_QUALITY
	return 0


func _straight_outs(combined_cards: Array[CardData], made_rank: HandRank) -> int:
	if (
		made_rank != null
		and (
			made_rank.category == HandRank.Category.STRAIGHT
			or made_rank.category == HandRank.Category.STRAIGHT_FLUSH
		)
	):
		return 0
	var rank_counts: Dictionary = {}
	for card: CardData in combined_cards:
		rank_counts[card.rank] = int(rank_counts.get(card.rank, 0)) + 1
	var outs: int = 0
	for rank: int in _straight_completion_ranks(combined_cards):
		outs += 4 - int(rank_counts.get(rank, 0))
	return outs


func _straight_completion_ranks(cards: Array[CardData]) -> Array[int]:
	var ranks: Dictionary = {}
	for card: CardData in cards:
		ranks[card.rank] = true
	if ranks.has(CardData.MAX_RANK):
		ranks[1] = true
	var completion_ranks: Dictionary = {}
	for high_rank: int in range(5, CardData.MAX_RANK + 1):
		var missing_rank: int = 0
		var present_count: int = 0
		for rank: int in range(high_rank - 4, high_rank + 1):
			if ranks.has(rank):
				present_count += 1
			else:
				missing_rank = rank
		if present_count == 4 and missing_rank > 1:
			completion_ranks[missing_rank] = true
		elif present_count == 4 and missing_rank == 1:
			completion_ranks[CardData.MAX_RANK] = true
	var result: Array[int] = []
	for rank_value: Variant in completion_ranks.keys():
		result.append(int(rank_value))
	return result


func _maximum_straight_window_count(cards: Array[CardData]) -> int:
	var ranks: Dictionary = {}
	for card: CardData in cards:
		ranks[card.rank] = true
	if ranks.has(CardData.MAX_RANK):
		ranks[1] = true
	var maximum: int = 0
	for high_rank: int in range(5, CardData.MAX_RANK + 1):
		var present_count: int = 0
		for rank: int in range(high_rank - 4, high_rank + 1):
			if ranks.has(rank):
				present_count += 1
		maximum = maxi(maximum, present_count)
	return maximum


func _improvement_potential(
	combined_cards: Array[CardData],
	made_rank: HandRank,
	flush_outs: int,
	straight_outs: int,
) -> int:
	if public_board.size() >= 5:
		return 0
	var direct_draw_quality: int = maxi(flush_draw_quality, straight_draw_quality)
	var pair_upgrade: int = _pair_upgrade_potential(combined_cards, made_rank)
	var potential: int = maxi(direct_draw_quality, pair_upgrade)
	if direct_draw_quality > 0 and is_paired_board:
		potential -= 5
	if direct_draw_quality > 0 and is_coordinated_board:
		potential -= 5
	if flush_outs > 0 and straight_outs > 0:
		potential += 10
	return clampi(potential, 0, MAX_DRAW_QUALITY)


func _pair_upgrade_potential(combined_cards: Array[CardData], made_rank: HandRank) -> int:
	if made_rank != null and made_rank.category >= HandRank.Category.STRAIGHT:
		return 0
	var rank_counts: Dictionary = {}
	for card: CardData in combined_cards:
		rank_counts[card.rank] = int(rank_counts.get(card.rank, 0)) + 1
	var pair_outs: int = 0
	for card: CardData in hero_cards:
		if int(rank_counts.get(card.rank, 0)) == 1:
			pair_outs += 3
	# This is intentionally a probability-like quality, not a raw outs count:
	# six overcard outs are about 24% by the river from the flop and about 13%
	# on the turn. It therefore does not overstate a one-pair improvement.
	return clampi(pair_outs * (4 if public_board.size() == 3 else 2), 0, 60)


func _preflop_score() -> int:
	if hero_cards.size() != 2 or not public_board.is_empty():
		return 0
	var first: CardData = hero_cards[0]
	var second: CardData = hero_cards[1]
	var pair_component: float = _pair_strength(first.rank, second.rank)
	var rank_component: float = _rank_strength(first.rank, second.rank)
	var suited_component: float = 100.0 if first.suit == second.suit else 0.0
	var connectivity_component: float = _connectivity_strength(first.rank, second.rank)
	var position_component: float = _position_strength()
	var weighted_score: float = (
		pair_component * 0.45
		+ rank_component * 0.30
		+ suited_component * 0.10
		+ connectivity_component * 0.10
		+ position_component * 0.05
	)
	return clampi(roundi(weighted_score), 0, 100)


func _pair_strength(first_rank: int, second_rank: int) -> float:
	if first_rank != second_rank:
		return 0.0
	# Pocket twos start at 40; aces reach 100, preserving premium-pair order.
	return 40.0 + (float(first_rank - CardData.MIN_RANK) / 12.0) * 60.0


func _rank_strength(first_rank: int, second_rank: int) -> float:
	var first_strength: float = float(first_rank - CardData.MIN_RANK) / 12.0
	var second_strength: float = float(second_rank - CardData.MIN_RANK) / 12.0
	return (first_strength + second_strength) * 50.0


func _connectivity_strength(first_rank: int, second_rank: int) -> float:
	var high_rank: int = maxi(first_rank, second_rank)
	var low_rank: int = mini(first_rank, second_rank)
	var gap: int = high_rank - low_rank
	var strength: float = 0.0
	if low_rank == CardData.MIN_RANK and high_rank == CardData.MAX_RANK:
		strength = 70.0
	else:
		match gap:
			1:
				strength = 100.0
			2:
				strength = 70.0
			3:
				strength = 40.0
			4:
				strength = 20.0
	return strength


func _position_strength() -> float:
	# Context.position is an ordinal: 0 is earliest, later positions increase.
	var denominator: int = maxi(context.active_opponents, 1)
	return clampf(float(context.position) / float(denominator) * 100.0, 0.0, 100.0)
