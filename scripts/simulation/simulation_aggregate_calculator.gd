class_name SimulationAggregateCalculator
extends RefCounted

## Tournament-clustered aggregate and uncertainty calculations for completed outcomes.

const Z_95: float = 1.96
const FINITE_SAMPLE_PENALTY_SCALE: float = 0.10
const FITNESS_COMPONENTS: Array[String] = [
	"win_score",
	"finish_score",
	"top_third_score",
	"chip_score",
	"survival_score",
	"blind_chip_score",
]
const BOUNDED_METRICS: Array[String] = [
	"win_score",
	"finish_score",
	"top_third_score",
	"chip_score",
	"survival_score",
	"blind_chip_score",
	"survival_ratio",
	"vpip_rate",
	"pfr_rate",
	"bet_raise_frequency",
	"bet_frequency",
	"raise_share",
	"eligible_bluff_frequency",
]
const FITNESS_WEIGHTS: Array[float] = [0.30, 0.20, 0.15, 0.15, 0.10, 0.10]


func calculate(
	outcomes: Array[SimulationTournamentOutcome], minimum_samples_by_plan: Dictionary = {}
) -> Dictionary:
	var groups := {
		"by_profile": {},
		"by_matchup": {},
		"by_seat": {},
		"by_regime": {},
		"by_evaluation_plan": {},
	}
	var group_minimums := {
		"by_profile": {},
		"by_matchup": {},
		"by_seat": {},
		"by_regime": {},
		"by_evaluation_plan": {},
	}
	for outcome: SimulationTournamentOutcome in outcomes:
		if outcome == null or not outcome.is_success():
			continue
		var minimum_samples: int = maxi(1, int(minimum_samples_by_plan.get(outcome.plan_id, 1)))
		var outcome_metrics: Array = []
		var metrics_by_profile: Dictionary = {}
		for seat: int in outcome.metrics:
			var metric: SimulationSeatMetrics = outcome.metrics[seat]
			outcome_metrics.append(metric)
			if not metrics_by_profile.has(metric.profile_id):
				metrics_by_profile[metric.profile_id] = []
			metrics_by_profile[metric.profile_id].append(metric)
			_add_unit(
				groups.by_seat,
				group_minimums.by_seat,
				str(metric.seat),
				[metric],
				minimum_samples,
			)
		for profile_id: StringName in metrics_by_profile:
			_add_unit(
				groups.by_profile,
				group_minimums.by_profile,
				str(profile_id),
				metrics_by_profile[profile_id],
				minimum_samples,
			)
		_add_unit(
			groups.by_matchup,
			group_minimums.by_matchup,
			str(outcome.matchup_id),
			outcome_metrics,
			minimum_samples,
		)
		_add_unit(
			groups.by_regime,
			group_minimums.by_regime,
			str(outcome.regime_id),
			outcome_metrics,
			minimum_samples,
		)
		_add_unit(
			groups.by_evaluation_plan,
			group_minimums.by_evaluation_plan,
			str(outcome.plan_id),
			outcome_metrics,
			minimum_samples,
		)
	var result := {}
	for group_name: String in groups:
		var aggregate_rows: Array[Dictionary] = []
		for group_id: String in groups[group_name]:
			(
				aggregate_rows
				. append(
					_summarize(
						group_id,
						groups[group_name][group_id],
						group_minimums[group_name][group_id],
					)
				)
			)
		aggregate_rows.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				return String(left.group_id) < String(right.group_id)
		)
		result[group_name] = aggregate_rows
	return result


func _add_unit(
	groups: Dictionary,
	minimums: Dictionary,
	group_id: String,
	metrics: Array,
	minimum_samples: int,
) -> void:
	if not groups.has(group_id):
		groups[group_id] = []
	groups[group_id].append(metrics)
	minimums[group_id] = maxi(int(minimums.get(group_id, 1)), minimum_samples)


func _summarize(group_id: String, units: Array, minimum_samples: int) -> Dictionary:
	var values := _empty_values()
	var behavior_counts := _empty_behavior_counts()
	for unit: Array in units:
		var unit_values := _empty_values()
		var unit_counts := _empty_behavior_counts()
		for metric: SimulationSeatMetrics in unit:
			_append_metric_values(unit_values, metric)
			for count_name: String in behavior_counts:
				var count: int = int(metric.get(count_name))
				unit_counts[count_name] += count
				behavior_counts[count_name] += count
		for name: String in unit_values:
			if (
				not unit_values[name].is_empty()
				and (
					name
					not in [
						"bet_raise_frequency",
						"bet_frequency",
						"raise_share",
						"eligible_bluff_frequency",
					]
				)
			):
				values[name].append(_mean(unit_values[name]))
		_append_unit_rate(
			values.bet_raise_frequency,
			unit_counts.aggressive_actions,
			unit_counts.bet_raise_opportunities,
		)
		_append_unit_rate(
			values.bet_frequency,
			unit_counts.bets_at_check_bet_opportunity,
			unit_counts.check_bet_opportunities,
		)
		_append_unit_rate(
			values.raise_share,
			unit_counts.raises_at_call_raise_opportunity,
			(
				unit_counts.calls_at_call_raise_opportunity
				+ unit_counts.raises_at_call_raise_opportunity
			),
		)
		_append_unit_rate(
			values.eligible_bluff_frequency,
			unit_counts.bluff_actions,
			unit_counts.eligible_bluff_opportunities,
		)

	var means := {}
	var uncertainty := {}
	for name: String in values:
		means[name] = _mean(values[name])
		uncertainty[name] = (
			_bounded_half_width(values[name])
			if name in BOUNDED_METRICS
			else _half_width(values[name])
		)
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
	for rate_name: String in [
		"bet_raise_frequency",
		"bet_frequency",
		"raise_share",
		"eligible_bluff_frequency",
	]:
		uncertainty[rate_name] = _bounded_half_width(values[rate_name])

	var point_fitness := 0.0
	for index: int in range(FITNESS_WEIGHTS.size()):
		point_fitness += FITNESS_WEIGHTS[index] * means[FITNESS_COMPONENTS[index]]
	var penalty := clampf(
		FINITE_SAMPLE_PENALTY_SCALE / sqrt(float(units.size())),
		0.0,
		FINITE_SAMPLE_PENALTY_SCALE,
	)
	return {
		"group_id": group_id,
		"sample_count": units.size(),
		"statistical_unit": "tournament_seed",
		"reportable": units.size() >= minimum_samples,
		"means": means,
		"uncertainty_95_half_width": uncertainty,
		"behavior_counts": behavior_counts,
		"point_fitness": clampf(point_fitness, 0.0, 1.0),
		"fitness": clampf(point_fitness - penalty, 0.0, 1.0),
		"uncertainty_penalty": penalty,
	}


func _empty_values() -> Dictionary:
	var values := {}
	for name: String in [
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
	]:
		values[name] = []
	return values


func _empty_behavior_counts() -> Dictionary:
	return {
		"aggressive_actions": 0,
		"bet_raise_opportunities": 0,
		"bets_at_check_bet_opportunity": 0,
		"check_bet_opportunities": 0,
		"calls_at_call_raise_opportunity": 0,
		"raises_at_call_raise_opportunity": 0,
		"eligible_bluff_opportunities": 0,
		"bluff_actions": 0,
	}


func _append_metric_values(values: Dictionary, metric: SimulationSeatMetrics) -> void:
	var player_count: int = maxi(2, metric.player_count)
	var finish_score := float(player_count - metric.finishing_position) / float(player_count - 1)
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
	if metric.hands_observed > 0:
		values.vpip_rate.append(metric.vpip_rate)
		values.pfr_rate.append(metric.pfr_rate)
	values.aggression_factor.append(metric.aggression_factor)
	values.invalid_action_fallbacks.append(float(metric.invalid_action_fallbacks))


func _append_unit_rate(values: Array, numerator: int, denominator: int) -> void:
	if denominator > 0:
		values.append(_ratio(numerator, denominator))


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _ratio(numerator: int, denominator: int) -> float:
	return float(numerator) / float(denominator) if denominator > 0 else 0.0


func _bounded_half_width(values: Array) -> Variant:
	if values.size() < 2:
		return null
	return maxf(float(_half_width(values)), _wilson_half_width(_mean(values), values.size()))


func _wilson_half_width(proportion: float, sample_count: int) -> float:
	var z_squared := Z_95 * Z_95
	var denominator := 1.0 + z_squared / float(sample_count)
	var radius := (
		Z_95
		* sqrt(
			(
				proportion * (1.0 - proportion) / float(sample_count)
				+ z_squared / (4.0 * float(sample_count * sample_count))
			)
		)
	)
	return radius / denominator


func _half_width(values: Array) -> Variant:
	if values.size() < 2:
		return null
	var mean := _mean(values)
	var squared := 0.0
	for value: float in values:
		squared += pow(value - mean, 2.0)
	var standard_error := sqrt(squared / float(values.size() - 1)) / sqrt(float(values.size()))
	return Z_95 * standard_error
