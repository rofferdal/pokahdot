class_name PotManager
extends RefCounted

## Records per-seat hand contributions and performs pot settlement.

var total_amount: int:
	get:
		return _total_amount
var contributions: Dictionary[int, int]:
	get:
		return _contributions.duplicate()

var _contributions: Dictionary[int, int] = {}
var _total_amount: int = 0


func record_contribution(seat: int, amount: int) -> bool:
	if seat < 0 or amount < 0 or amount > ChipStack.maximum_safe_credit(_total_amount):
		return false
	var previous: int = _contributions.get(seat, 0)
	if amount > ChipStack.maximum_safe_credit(previous):
		return false
	_contributions[seat] = previous + amount
	_total_amount += amount
	return true


func contribution_for(seat: int) -> int:
	return _contributions.get(seat, 0)


func award_single_winner(winner: Player) -> int:
	if winner == null or winner.folded or _total_amount == 0:
		return 0
	if not winner.award_chips(_total_amount):
		return 0
	var awarded: int = _total_amount
	clear()
	return awarded


func derive_pots(players: Array[Player]) -> Array[PotLayer]:
	var derivation: Dictionary = _derive_pots_with_returns(players)
	return derivation["layers"] as Array[PotLayer]


func award_showdown(
	players: Array[Player], hand_ranks: Dictionary[int, HandRank], button_seat: int
) -> Array[PotAward]:
	var derivation: Dictionary = _derive_pots_with_returns(players)
	var pots: Array[PotLayer] = derivation["layers"] as Array[PotLayer]
	var unmatched_returns: Dictionary[int, int] = derivation["returns"]
	if pots.is_empty() or button_seat < 0 or button_seat >= players.size():
		return []
	var awards: Array[PotAward] = []
	var total_awards: Dictionary[int, int] = {}
	for pot_index: int in range(pots.size()):
		var winners: Array[int] = _best_eligible_seats(pots[pot_index], hand_ranks)
		if winners.is_empty():
			return []
		var split: Dictionary[int, int] = _split_amount(
			pots[pot_index].amount, winners, button_seat, players.size()
		)
		for seat: int in split:
			total_awards[seat] = int(total_awards.get(seat, 0)) + split[seat]
		awards.append(PotAward.new(pot_index, pots[pot_index].amount, winners, split))
	for seat: int in unmatched_returns:
		total_awards[seat] = int(total_awards.get(seat, 0)) + unmatched_returns[seat]
	if not _can_credit_all(players, total_awards):
		return []
	for seat: int in total_awards:
		players[seat].award_chips(total_awards[seat])
	clear()
	return awards


func clear() -> void:
	_contributions.clear()
	_total_amount = 0


func _players_cover_contributions(players: Array[Player]) -> bool:
	for seat: int in _contributions:
		if seat < 0 or seat >= players.size() or players[seat] == null:
			return false
	return true


func _derive_pots_with_returns(players: Array[Player]) -> Dictionary:
	var empty: Array[PotLayer] = []
	var no_returns: Dictionary[int, int] = {}
	if not _players_cover_contributions(players):
		return {"layers": empty, "returns": no_returns}

	var thresholds: Array[int] = []
	for contribution: int in _contributions.values():
		if contribution > 0 and not thresholds.has(contribution):
			thresholds.append(contribution)
	thresholds.sort()
	if thresholds.is_empty():
		return {"layers": empty, "returns": no_returns}

	# Unequal wagers during an ordinary betting round are not side pots.  An
	# all-in is the event that fixes a contribution boundary; until then all
	# committed chips belong to one pot.
	if not _has_contributing_all_in(players):
		var contributors: Array[int] = _seats_with_positive_contribution()
		var eligible: Array[int] = _eligible_seats(contributors, players)
		var single_pot := PotLayer.new(_total_amount, thresholds.back(), contributors, eligible)
		var ordinary_layers: Array[PotLayer] = [single_pot]
		return {"layers": ordinary_layers, "returns": no_returns}

	var result: Array[PotLayer] = []
	var previous_threshold: int = 0
	var unmatched_returns: Dictionary[int, int] = {}
	for threshold: int in thresholds:
		var contributors: Array[int] = _seats_above_threshold(previous_threshold)
		var amount: int = _amount_between(previous_threshold, threshold)
		if amount > 0 and contributors.size() == 1:
			var unmatched_seat: int = contributors[0]
			unmatched_returns[unmatched_seat] = (
				int(unmatched_returns.get(unmatched_seat, 0)) + amount
			)
		else:
			var eligible: Array[int] = _eligible_seats(contributors, players)
			if amount > 0:
				var layer := PotLayer.new(amount, threshold, contributors, eligible)
				if eligible.is_empty() and not result.is_empty():
					_add_dead_money_to_previous_layer(result, layer)
				else:
					_append_or_merge_layer(result, layer)
		previous_threshold = threshold
	return {"layers": result, "returns": unmatched_returns}


func _has_contributing_all_in(players: Array[Player]) -> bool:
	for seat: int in _contributions:
		if _contributions[seat] > 0 and players[seat].all_in:
			return true
	return false


func _seats_with_positive_contribution() -> Array[int]:
	var result: Array[int] = []
	for seat: int in _contributions:
		if _contributions[seat] > 0:
			result.append(seat)
	result.sort()
	return result


func _seats_above_threshold(threshold: int) -> Array[int]:
	var result: Array[int] = []
	for seat: int in _contributions:
		if _contributions[seat] > threshold:
			result.append(seat)
	result.sort()
	return result


func _amount_between(lower: int, upper: int) -> int:
	var amount: int = 0
	for contribution: int in _contributions.values():
		amount += maxi(0, mini(contribution, upper) - lower)
	return amount


func _eligible_seats(contributors: Array[int], players: Array[Player]) -> Array[int]:
	var result: Array[int] = []
	for seat: int in contributors:
		if not players[seat].folded:
			result.append(seat)
	return result


func _append_or_merge_layer(layers: Array[PotLayer], layer: PotLayer) -> void:
	if layers.is_empty() or layers.back().eligible_seats != layer.eligible_seats:
		layers.append(layer)
		return
	var previous: PotLayer = layers.pop_back()
	var contributors: Array[int] = previous.contributor_seats
	for seat: int in layer.contributor_seats:
		if not contributors.has(seat):
			contributors.append(seat)
	contributors.sort()
	(
		layers
		. append(
			(
				PotLayer
				. new(
					previous.amount + layer.amount,
					layer.contribution_cap,
					contributors,
					layer.eligible_seats,
				)
			)
		)
	)


func _add_dead_money_to_previous_layer(layers: Array[PotLayer], dead_layer: PotLayer) -> void:
	var previous: PotLayer = layers.pop_back()
	var contributors: Array[int] = previous.contributor_seats
	for seat: int in dead_layer.contributor_seats:
		if not contributors.has(seat):
			contributors.append(seat)
	contributors.sort()
	(
		layers
		. append(
			(
				PotLayer
				. new(
					previous.amount + dead_layer.amount,
					dead_layer.contribution_cap,
					contributors,
					previous.eligible_seats,
				)
			)
		)
	)


func _best_eligible_seats(pot: PotLayer, hand_ranks: Dictionary[int, HandRank]) -> Array[int]:
	var winners: Array[int] = []
	var best_rank: HandRank = null
	for seat: int in pot.eligible_seats:
		var rank: HandRank = hand_ranks.get(seat)
		if rank == null:
			return []
		var comparison: int = 1 if best_rank == null else rank.compare_to(best_rank)
		if comparison > 0:
			best_rank = rank
			winners.assign([seat])
		elif comparison == 0:
			winners.append(seat)
	return winners


func _split_amount(
	amount: int, winners: Array[int], button_seat: int, player_count: int
) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	var share: int = amount / winners.size()
	for seat: int in winners:
		result[seat] = share
	var odd_chips: int = amount % winners.size()
	for offset: int in range(1, player_count + 1):
		var seat: int = posmod(button_seat + offset, player_count)
		if winners.has(seat) and odd_chips > 0:
			result[seat] += 1
			odd_chips -= 1
	return result


func _can_credit_all(players: Array[Player], awards: Dictionary[int, int]) -> bool:
	for seat: int in awards:
		if awards[seat] > ChipStack.maximum_safe_credit(players[seat].stack):
			return false
	return true
