class_name ShowdownHandFormatter
extends RefCounted

## Converts recipient-safe showdown results into concise player-facing descriptions.


static func format(showdown_result: ShowdownResult) -> String:
	if showdown_result == null:
		return ""
	var ranks: Array[int] = showdown_result.tie_break_values
	if ranks.is_empty():
		return ""
	var description: String = ""
	match showdown_result.category:
		HandRank.Category.HIGH_CARD:
			description = "%s-high" % _rank_name(ranks[0])
		HandRank.Category.ONE_PAIR:
			description = "Pair of %s" % _rank_name(ranks[0], true)
		HandRank.Category.TWO_PAIR:
			description = (
				"Two pair: %s and %s" % [_rank_name(ranks[0], true), _rank_name(ranks[1], true)]
			)
		HandRank.Category.THREE_OF_A_KIND:
			description = "Three of a kind: %s" % _rank_name(ranks[0], true)
		HandRank.Category.STRAIGHT:
			description = "Straight to %s" % _rank_name(ranks[0])
		HandRank.Category.FLUSH:
			description = "%s-high flush" % _rank_name(ranks[0])
		HandRank.Category.FULL_HOUSE:
			description = (
				"Full house: %s full of %s"
				% [_rank_name(ranks[0], true), _rank_name(ranks[1], true)]
			)
		HandRank.Category.FOUR_OF_A_KIND:
			description = "Four of a kind: %s" % _rank_name(ranks[0], true)
		HandRank.Category.STRAIGHT_FLUSH:
			description = "Straight flush to %s" % _rank_name(ranks[0])
	return description


static func _rank_name(rank: int, plural: bool = false) -> String:
	var singular_names: PackedStringArray = [
		"",
		"",
		"Two",
		"Three",
		"Four",
		"Five",
		"Six",
		"Seven",
		"Eight",
		"Nine",
		"Ten",
		"Jack",
		"Queen",
		"King",
		"Ace",
	]
	var plural_names: PackedStringArray = [
		"",
		"",
		"Twos",
		"Threes",
		"Fours",
		"Fives",
		"Sixes",
		"Sevens",
		"Eights",
		"Nines",
		"Tens",
		"Jacks",
		"Queens",
		"Kings",
		"Aces",
	]
	if rank < 2 or rank >= singular_names.size():
		return "Unknown"
	return plural_names[rank] if plural else singular_names[rank]
