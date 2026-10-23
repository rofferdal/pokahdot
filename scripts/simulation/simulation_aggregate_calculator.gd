class_name SimulationAggregateCalculator
extends RefCounted

## Deterministic aggregate and uncertainty calculations for completed outcomes.

const Z_95: float = 1.96
const FITNESS_WEIGHTS: Array[float] = [0.30, 0.20, 0.15, 0.15, 0.10, 0.10]


func calculate(
	outcomes: Array[SimulationTournamentOutcome], minimum_samples: int = 30
) -> Dictionary:
	var groups := {
		"by_profile": {},
		"by_matchup": {},
		"by_seat": {},
		"by_regime": {},
		"by_evaluation_plan": {},
	}
	for outcome: SimulationTournamentOutcome in outcomes:
		if outcome == null or not outcome.is_success():
			continue
		for seat: int in outcome.metrics:
			var metric: SimulationSeatMetrics = outcome.metrics[seat]
			_add(groups.by_profile, str(metric.profile_id), metric)
			_add(groups.by_matchup, str(outcome.matchup_id), metric)
			_add(groups.by_seat, str(metric.seat), metric)
			_add(groups.by_regime, str(outcome.regime_id), metric)
			_add(groups.by_evaluation_plan, str(outcome.plan_id), metric)
	var result := {}
	for group_name: String in groups:
		var aggregate_rows: Array[Dictionary] = []
		for group_id: String in groups[group_name]:
			aggregate_rows.append(
				_summarize(group_id, groups[group_name][group_id], minimum_samples)
			)
		aggregate_rows.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				return String(left.group_id) < String(right.group_id)
		)
		result[group_name] = aggregate_rows
	return result


func _add(groups: Dictionary, group_id: String, metric: SimulationSeatMetrics) -> void:
	if not groups.has(group_id):
		groups[group_id] = []
	groups[group_id].append(metric)


func _summarize(group_id: String, metrics: Array, minimum_samples: int) -> Dictionary:
	var values: Dictionary = {}
	var behavior_counts := {
		"aggressive_actions": 0,
		"bet_raise_opportunities": 0,
		"bets_at_check_bet_opportunity": 0,
		"check_bet_opportunities": 0,
		"calls_at_call_raise_opportunity": 0,
		"raises_at_call_raise_opportunity": 0,
		"eligible_bluff_opportunities": 0,
		"bluff_actions": 0,
	}
	var names := [
		"win_score",
		"finish_score",
		"top_third_score",
		"chip_score",
		"survival_score",
		"blind_chip_score",
		"finishing_position",
		"chip_differential",
		"hands_survived",
		"survival_ratio",
		"bnc_per_100",
		"vpip_rate",
		"pfr_rate",
		"aggression_factor",
		"bet_raise_frequency",
		"bet_frequency",
		"raise_share",
		"eligible_bluff_frequency",
		"invalid_action_fallbacks",
	]
	for name: String in names:
		values[name] = []
	for metric: SimulationSeatMetrics in metrics:
		var player_count: int = maxi(2, metric.player_count)
		var finish_score := (
			float(player_count - metric.finishing_position) / float(player_count - 1)
		)
		var chip_score := (
			float(metric.chip_differential + metric.starting_stack)
			/ float(player_count * metric.starting_stack)
		)
		values.win_score.append(1.0 if metric.won_tournament else 0.0)
		values.finish_score.append(clampf(finish_score, 0.0, 1.0))
		values.top_third_score.append(1.0 if metric.top_third else 0.0)
		values.chip_score.append(clampf(chip_score, 0.0, 1.0))
		values.survival_score.append(clampf(metric.survival_ratio, 0.0, 1.0))
		values.blind_chip_score.append((clampf(metric.bnc_per_100, -100.0, 100.0) + 100.0) / 200.0)
		values.finishing_position.append(float(metric.finishing_position))
		values.chip_differential.append(float(metric.chip_differential))
		values.hands_survived.append(float(metric.hands_survived))
		values.survival_ratio.append(metric.survival_ratio)
		values.bnc_per_100.append(metric.bnc_per_100)
		values.vpip_rate.append(metric.vpip_rate)
		values.pfr_rate.append(metric.pfr_rate)
		values.aggression_factor.append(metric.aggression_factor)
		if metric.bet_raise_opportunities > 0:
			values.bet_raise_frequency.append(metric.bet_raise_frequency)
		if metric.check_bet_opportunities > 0:
			values.bet_frequency.append(metric.bet_frequency)
		if metric.calls_at_call_raise_opportunity + metric.raises_at_call_raise_opportunity > 0:
			values.raise_share.append(metric.raise_share)
		if metric.eligible_bluff_opportunities > 0:
			values.eligible_bluff_frequency.append(metric.eligible_bluff_frequency)
		for count_name: String in behavior_counts:
			behavior_counts[count_name] += metric.get(count_name)
		values.invalid_action_fallbacks.append(float(metric.invalid_action_fallbacks))
	var means := {}
	var uncertainty := {}
	for name: String in values:
		means[name] = _mean(values[name])
		uncertainty[name] = _half_width(values[name])
	means.bet_raise_frequency = _ratio(
		behavior_counts.aggressive_actions, behavior_counts.bet_raise_opportunities
	)
	means.bet_frequency = _ratio(
		behavior_counts.bets_at_check_bet_opportunity,
		behavior_counts.check_bet_opportunities,
	)
	means.raise_share = _ratio(
		behavior_counts.raises_at_call_raise_opportunity,
		(
			behavior_counts.calls_at_call_raise_opportunity
			+ behavior_counts.raises_at_call_raise_opportunity
		),
	)
	means.eligible_bluff_frequency = _ratio(
		behavior_counts.bluff_actions, behavior_counts.eligible_bluff_opportunities
	)
	uncertainty.bet_raise_frequency = _proportion_half_width(
		behavior_counts.aggressive_actions, behavior_counts.bet_raise_opportunities
	)
	uncertainty.bet_frequency = _proportion_half_width(
		behavior_counts.bets_at_check_bet_opportunity,
		behavior_counts.check_bet_opportunities,
	)
	uncertainty.raise_share = _proportion_half_width(
		behavior_counts.raises_at_call_raise_opportunity,
		(
			behavior_counts.calls_at_call_raise_opportunity
			+ behavior_counts.raises_at_call_raise_opportunity
		),
	)
	uncertainty.eligible_bluff_frequency = _proportion_half_width(
		behavior_counts.bluff_actions, behavior_counts.eligible_bluff_opportunities
	)
	var fitness := 0.0
	for index: int in range(FITNESS_WEIGHTS.size()):
		fitness += (
			FITNESS_WEIGHTS[index]
			* means[[
				"win_score",
				"finish_score",
				"top_third_score",
				"chip_score",
				"survival_score",
				"blind_chip_score",
			][index]]
		)
	var penalty := 0.0
	for name: String in [
		"win_score",
		"finish_score",
		"top_third_score",
		"chip_score",
		"survival_score",
		"blind_chip_score",
	]:
		penalty += uncertainty[name]
	penalty = clampf(penalty / 6.0, 0.0, 0.10)
	return {
		"group_id": group_id,
		"sample_count": metrics.size(),
		"reportable": metrics.size() >= minimum_samples,
		"means": means,
		"uncertainty_95_half_width": uncertainty,
		"behavior_counts": behavior_counts,
		"fitness": clampf(fitness - penalty, 0.0, 1.0),
		"uncertainty_penalty": penalty,
	}


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _ratio(numerator: int, denominator: int) -> float:
	return float(numerator) / float(denominator) if denominator > 0 else 0.0


func _proportion_half_width(numerator: int, denominator: int) -> float:
	if denominator <= 0:
		return 0.0
	var proportion := _ratio(numerator, denominator)
	return Z_95 * sqrt(proportion * (1.0 - proportion) / float(denominator))


func _half_width(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var mean := _mean(values)
	var squared := 0.0
	for value: float in values:
		squared += pow(value - mean, 2.0)
	var standard_error := sqrt(squared / float(values.size() - 1)) / sqrt(float(values.size()))
	return Z_95 * standard_error
