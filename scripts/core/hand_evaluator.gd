class_name HandEvaluator
extends RefCounted

## Pure Hold'em evaluator that selects the strongest five cards from five to seven.

const MIN_CARDS: int = 5
const MAX_CARDS: int = 7


func evaluate(cards: Array[CardData]) -> HandRank:
	if not _is_valid_input(cards):
		return null

	var best_rank: HandRank = null
	var card_count: int = cards.size()
	for first: int in range(card_count - 4):
		for second: int in range(first + 1, card_count - 3):
			for third: int in range(second + 1, card_count - 2):
				for fourth: int in range(third + 1, card_count - 1):
					for fifth: int in range(fourth + 1, card_count):
						var five_cards: Array[CardData] = [
							cards[first], cards[second], cards[third], cards[fourth], cards[fifth]
						]
						var candidate: HandRank = _evaluate_five(five_cards)
						if best_rank == null or candidate.compare_to(best_rank) > 0:
							best_rank = candidate
	return best_rank


func _is_valid_input(cards: Array[CardData]) -> bool:
	if cards.size() < MIN_CARDS or cards.size() > MAX_CARDS:
		return false
	var seen_ids: Dictionary = {}
	for card: CardData in cards:
		if card == null or seen_ids.has(card.card_id):
			return false
		seen_ids[card.card_id] = true
	return true


func _evaluate_five(cards: Array[CardData]) -> HandRank:
	var ranks_descending: Array[int] = _ranks_descending(cards)
	var rank_counts: Dictionary = {}
	for card: CardData in cards:
		rank_counts[card.rank] = int(rank_counts.get(card.rank, 0)) + 1

	var straight_high: int = _straight_high(rank_counts)
	var is_flush: bool = _is_flush(cards)
	var strong_rank: HandRank = _evaluate_straight_or_better(
		cards, ranks_descending, rank_counts, straight_high, is_flush
	)
	if strong_rank != null:
		return strong_rank
	return _evaluate_grouped_or_high_card(cards, ranks_descending, rank_counts)


func _evaluate_straight_or_better(
	cards: Array[CardData],
	ranks_descending: Array[int],
	rank_counts: Dictionary,
	straight_high: int,
	is_flush: bool,
) -> HandRank:
	if is_flush and straight_high > 0:
		return HandRank.new(HandRank.Category.STRAIGHT_FLUSH, [straight_high], cards)

	var four_rank: int = _highest_rank_with_count(rank_counts, 4)
	if four_rank > 0:
		return (
			HandRank
			. new(
				HandRank.Category.FOUR_OF_A_KIND,
				[four_rank, _highest_rank_excluding(rank_counts, [four_rank])],
				cards,
			)
		)

	var three_rank: int = _highest_rank_with_count(rank_counts, 3)
	var pair_ranks: Array[int] = _ranks_with_count(rank_counts, 2)
	if three_rank > 0 and not pair_ranks.is_empty():
		return HandRank.new(HandRank.Category.FULL_HOUSE, [three_rank, pair_ranks[0]], cards)
	if is_flush:
		return HandRank.new(HandRank.Category.FLUSH, ranks_descending, cards)
	if straight_high > 0:
		return HandRank.new(HandRank.Category.STRAIGHT, [straight_high], cards)
	return null


func _evaluate_grouped_or_high_card(
	cards: Array[CardData], ranks_descending: Array[int], rank_counts: Dictionary
) -> HandRank:
	var three_rank: int = _highest_rank_with_count(rank_counts, 3)
	var pair_ranks: Array[int] = _ranks_with_count(rank_counts, 2)
	if three_rank > 0:
		return (
			HandRank
			. new(
				HandRank.Category.THREE_OF_A_KIND,
				[three_rank] + _distinct_ranks_excluding(rank_counts, [three_rank]),
				cards,
			)
		)
	if pair_ranks.size() >= 2:
		var high_pair: int = pair_ranks[0]
		var low_pair: int = pair_ranks[1]
		return (
			HandRank
			. new(
				HandRank.Category.TWO_PAIR,
				[high_pair, low_pair, _highest_rank_excluding(rank_counts, [high_pair, low_pair])],
				cards,
			)
		)
	if pair_ranks.size() == 1:
		return (
			HandRank
			. new(
				HandRank.Category.ONE_PAIR,
				[pair_ranks[0]] + _distinct_ranks_excluding(rank_counts, [pair_ranks[0]]),
				cards,
			)
		)
	return HandRank.new(HandRank.Category.HIGH_CARD, ranks_descending, cards)


func _ranks_descending(cards: Array[CardData]) -> Array[int]:
	var ranks: Array[int] = []
	for card: CardData in cards:
		ranks.append(card.rank)
	ranks.sort()
	ranks.reverse()
	return ranks


func _straight_high(rank_counts: Dictionary) -> int:
	var unique_ranks: Array[int] = []
	for rank_value: Variant in rank_counts.keys():
		unique_ranks.append(int(rank_value))
	if rank_counts.has(CardData.MAX_RANK):
		unique_ranks.append(1)
	unique_ranks.sort()
	unique_ranks.reverse()

	var run_length: int = 1
	for index: int in range(1, unique_ranks.size()):
		if unique_ranks[index - 1] - 1 == unique_ranks[index]:
			run_length += 1
			if run_length == 5:
				return unique_ranks[index - 4]
		else:
			run_length = 1
	return 0


func _is_flush(cards: Array[CardData]) -> bool:
	var suit: CardData.Suit = cards[0].suit
	for card: CardData in cards:
		if card.suit != suit:
			return false
	return true


func _highest_rank_with_count(rank_counts: Dictionary, count: int) -> int:
	for rank: int in range(CardData.MAX_RANK, CardData.MIN_RANK - 1, -1):
		if int(rank_counts.get(rank, 0)) == count:
			return rank
	return 0


func _ranks_with_count(rank_counts: Dictionary, count: int) -> Array[int]:
	var result: Array[int] = []
	for rank: int in range(CardData.MAX_RANK, CardData.MIN_RANK - 1, -1):
		if int(rank_counts.get(rank, 0)) == count:
			result.append(rank)
	return result


func _highest_rank_excluding(rank_counts: Dictionary, excluded: Array[int]) -> int:
	for rank: int in range(CardData.MAX_RANK, CardData.MIN_RANK - 1, -1):
		if rank_counts.has(rank) and not excluded.has(rank):
			return rank
	return 0


func _distinct_ranks_excluding(rank_counts: Dictionary, excluded: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for rank: int in range(CardData.MAX_RANK, CardData.MIN_RANK - 1, -1):
		if rank_counts.has(rank) and not excluded.has(rank):
			result.append(rank)
	return result
