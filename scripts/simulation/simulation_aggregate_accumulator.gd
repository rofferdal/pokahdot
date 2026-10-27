class_name SimulationAggregateAccumulator
extends RefCounted

## Constant space per declared aggregate group, using tournament-clustered moments.
## Callers supply each completed tournament exactly once, in global-index order.
## Returned summaries own their dictionaries and retain no supplied outcome values.

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

var _groups: Dictionary[String, Dictionary] = {
	"by_profile": {},
	"by_matchup": {},
	"by_seat": {},
	"by_regime": {},
	"by_evaluation_plan": {},
}


func add_outcome(outcome: SimulationTournamentOutcome, minimum: int = 1) -> void:
	if outcome == null or not outcome.is_success():
		return
	var metrics: Array[SimulationSeatMetrics] = []
	for seat: int in outcome.metrics:
		metrics.append(outcome.metrics[seat])
	_add_tournament_metrics(
		metrics, outcome.matchup_id, outcome.regime_id, outcome.plan_id, minimum
	)


## Accepts one already-validated report tournament record, such as a checkpoint.
## Rehydration retains only this tournament's small per-seat metric collection.
func add_tournament(record: Dictionary, minimum: int = 1) -> void:
	if record.get("termination_reason", "") != "winner":
		return
	var metrics: Array[SimulationSeatMetrics] = []
	var results: Array = record.profile_results
	for result: Dictionary in results:
		var metric := SimulationSeatMetrics.new(
			StringName(result.profile_id), int(result.seat), int(result.starting_stack)
		)
		for field: String in result:
			if field not in ["profile_id", "seat", "starting_stack"]:
				metric.set(field, result[field])
		metric.player_count = results.size()
		metrics.append(metric)
	_add_tournament_metrics(
		metrics,
		StringName(record.matchup_id),
		StringName(record.regime_id),
		StringName(record.plan_id),
		minimum
	)


func summarize() -> Dictionary:
	var result: Dictionary = {}
	for group_name: String in _groups:
		var rows: Array[Dictionary] = []
		for group_id: String in _groups[group_name]:
			var group: AggregateGroup = _groups[group_name][group_id]
			rows.append(_summarize_group(group_id, group))
		rows.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				return String(left.group_id) < String(right.group_id)
		)
		result[group_name] = rows
	return result


func _add_tournament_metrics(
	metrics: Array[SimulationSeatMetrics],
	matchup_id: StringName,
	regime_id: StringName,
	plan_id: StringName,
	minimum: int
) -> void:
	var by_profile: Dictionary[StringName, Array] = {}
	for metric: SimulationSeatMetrics in metrics:
		if not by_profile.has(metric.profile_id):
			by_profile[metric.profile_id] = []
		by_profile[metric.profile_id].append(metric)
		_add_unit(_groups.by_seat, str(metric.seat), [metric], minimum)
	for profile_id: StringName in by_profile:
		_add_unit(_groups.by_profile, str(profile_id), by_profile[profile_id], minimum)
	_add_unit(_groups.by_matchup, str(matchup_id), metrics, minimum)
	_add_unit(_groups.by_regime, str(regime_id), metrics, minimum)
	_add_unit(_groups.by_evaluation_plan, str(plan_id), metrics, minimum)


func _add_unit(groups: Dictionary, id: String, metrics: Array, minimum: int) -> void:
	if not groups.has(id):
		groups[id] = AggregateGroup.new(_empty_values(), _empty_behavior_counts())
	var group: AggregateGroup = groups[id]
	group.sample_count += 1
	group.minimum = maxi(group.minimum, minimum)
	var values := _empty_values()
	var counts := _empty_behavior_counts()
	for metric: SimulationSeatMetrics in metrics:
		_append_metric_values(values, metric)
		for name: String in counts:
			var count: int = int(metric.get(name))
			counts[name] += count
			group.behavior_counts[name] += count
	for name: String in values:
		if not values[name].is_empty():
			group.moments[name].add(_mean(values[name]))
	_add_rate(
		group, "bet_raise_frequency", counts.aggressive_actions, counts.bet_raise_opportunities
	)
	_add_rate(
		group, "bet_frequency", counts.bets_at_check_bet_opportunity, counts.check_bet_opportunities
	)
	_add_rate(
		group,
		"raise_share",
		counts.raises_at_call_raise_opportunity,
		counts.calls_at_call_raise_opportunity + counts.raises_at_call_raise_opportunity
	)
	_add_rate(
		group, "eligible_bluff_frequency", counts.bluff_actions, counts.eligible_bluff_opportunities
	)


func _add_rate(group: AggregateGroup, name: String, numerator: int, denominator: int) -> void:
	if denominator > 0:
		group.moments[name].add(_ratio(numerator, denominator))


func _summarize_group(id: String, group: AggregateGroup) -> Dictionary:
	var means: Dictionary = {}
	var uncertainty: Dictionary = {}
	for name: String in group.moments:
		var moment: Moment = group.moments[name]
		means[name] = moment.total / float(moment.count) if moment.count > 0 else 0.0
		var half_width: Variant = null
		if moment.count >= 2:
			half_width = (
				Z_95
				* sqrt(maxf(0.0, moment.m2) / float(moment.count - 1))
				/ sqrt(float(moment.count))
			)
			if name in BOUNDED_METRICS:
				half_width = maxf(half_width, _wilson_half_width(means[name], moment.count))
		uncertainty[name] = half_width
	var counts: Dictionary = group.behavior_counts
	means.bet_raise_frequency = _ratio(counts.aggressive_actions, counts.bet_raise_opportunities)
	means.bet_frequency = _ratio(
		counts.bets_at_check_bet_opportunity, counts.check_bet_opportunities
	)
	means.raise_share = _ratio(
		counts.raises_at_call_raise_opportunity,
		counts.calls_at_call_raise_opportunity + counts.raises_at_call_raise_opportunity
	)
	means.eligible_bluff_frequency = _ratio(
		counts.bluff_actions, counts.eligible_bluff_opportunities
	)
	var point_fitness: float = 0.0
	for index: int in range(FITNESS_WEIGHTS.size()):
		point_fitness += FITNESS_WEIGHTS[index] * means[FITNESS_COMPONENTS[index]]
	var penalty: float = clampf(
		FINITE_SAMPLE_PENALTY_SCALE / sqrt(float(group.sample_count)),
		0.0,
		FINITE_SAMPLE_PENALTY_SCALE
	)
	return {
		"group_id": id,
		"sample_count": group.sample_count,
		"statistical_unit": "tournament_seed",
		"reportable": group.sample_count >= group.minimum,
		"means": means,
		"uncertainty_95_half_width": uncertainty,
		"behavior_counts": group.behavior_counts.duplicate(),
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


func _mean(values: Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size()) if not values.is_empty() else 0.0


func _ratio(numerator: int, denominator: int) -> float:
	return float(numerator) / float(denominator) if denominator > 0 else 0.0


func _wilson_half_width(proportion: float, count: int) -> float:
	var sample_count: float = float(count)
	var z_squared: float = Z_95 * Z_95
	var denominator: float = 1.0 + z_squared / sample_count
	var radius: float = (
		Z_95
		* sqrt(
			(
				proportion * (1.0 - proportion) / sample_count
				+ z_squared / (4.0 * sample_count * sample_count)
			)
		)
	)
	return radius / denominator


class Moment:
	extends RefCounted
	var count: int = 0
	var total: float = 0.0
	var mean: float = 0.0
	var m2: float = 0.0

	func add(value: float) -> void:
		count += 1
		total += value
		var delta: float = value - mean
		mean += delta / float(count)
		m2 += delta * (value - mean)


class AggregateGroup:
	extends RefCounted
	var sample_count: int = 0
	var minimum: int = 1
	var behavior_counts: Dictionary
	var moments: Dictionary[String, Moment] = {}

	func _init(values: Dictionary, counts: Dictionary) -> void:
		behavior_counts = counts
		for name: String in values:
			moments[name] = Moment.new()
