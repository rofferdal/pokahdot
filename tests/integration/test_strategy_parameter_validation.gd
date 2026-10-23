extends "res://tests/support/poker_gut_test.gd"

const BATCH_RUNNER_SCRIPT := preload("res://scripts/simulation/simulation_batch_runner.gd")
const TOURNAMENTS_PER_MATCHUP: int = 20


func test_fixed_seed_batches_isolate_each_strategy_parameter() -> void:
	var matchups := _matchups()
	var indexes: Array[int] = []
	for index: int in range(matchups.size() * TOURNAMENTS_PER_MATCHUP):
		indexes.append(index)
	var config := _config()
	var plan := SimulationBatchPlanner.new().plan(config, 41000, matchups, indexes)
	var first := BATCH_RUNNER_SCRIPT.new().run(config, plan.inputs)
	var second := BATCH_RUNNER_SCRIPT.new().run(config, plan.inputs)

	assert_true(first.is_success())
	assert_eq(_metric_summary(first.outcomes), _metric_summary(second.outcomes))
	var metrics := _metrics_by_profile(first.outcomes)
	assert_gt(_rate(metrics.tight_100.vpip, metrics.tight_100.hands), 0.0)
	assert_eq(metrics.tight_0.vpip, 0)
	assert_gt(metrics.tight_100.hands, 0)
	assert_gt(metrics.open_0.bet_opportunities, 0)
	assert_gt(metrics.open_100.bet_opportunities, 0)
	assert_gt(metrics.open_100.bets, 0)
	assert_eq(metrics.open_0.bets, 0)
	assert_gt(metrics.raise_0.calls + metrics.raise_0.raises, 0)
	assert_gt(metrics.raise_100.calls + metrics.raise_100.raises, 0)
	assert_gt(metrics.raise_100.raises, 0)
	assert_eq(metrics.raise_0.raises, 0)
	assert_gt(metrics.bluff_0.bluff_opportunities, 0)
	assert_gt(metrics.bluff_100.bluff_opportunities, 0)
	assert_gt(metrics.bluff_100.bluffs, 0)
	assert_eq(metrics.bluff_100.bluffs, metrics.bluff_100.bluff_opportunities)
	assert_eq(metrics.bluff_0.bluffs, 0)


func _matchups() -> Array[SimulationMatchup]:
	return [
		_pair(
			&"tightness",
			_profile(&"tight_0", 0, 100, 100, 0),
			_profile(&"tight_100", 100, 100, 100, 0)
		),
		_pair(
			&"opening", _profile(&"open_0", 100, 0, 50, 0), _profile(&"open_100", 100, 100, 50, 0)
		),
		_pair(
			&"raising", _profile(&"raise_0", 100, 50, 0, 0), _profile(&"raise_100", 100, 50, 100, 0)
		),
		_pair(
			&"bluffing", _profile(&"bluff_0", 100, 0, 0, 0), _profile(&"bluff_100", 100, 0, 0, 100)
		),
	]


func _pair(id: StringName, first: BotProfile, second: BotProfile) -> SimulationMatchup:
	return SimulationMatchup.new(id, [first, second])


func _profile(
	id: StringName, tightness: int, opening_aggression: int, raise_preference: int, bluff: int
) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = id
	profile.model_id = &"strategy_parameterized"
	var parameters := StrategyDecisionModelParameters.new()
	parameters.tight_vs_loose = tightness
	parameters.passive_vs_aggressive = opening_aggression
	parameters.call_vs_raise = raise_preference
	parameters.bluff_rate = bluff
	profile.parameters = parameters
	return profile


func _config() -> ResolvedTournamentConfig:
	return ResolvedTournamentConfig.new(
		2, 100, 5, 10, 41000, &"single_table", {0: &"random", 1: &"random"}
	)


func _metrics_by_profile(outcomes: Array[SimulationTournamentOutcome]) -> Dictionary:
	var result: Dictionary = {}
	for outcome: SimulationTournamentOutcome in outcomes:
		for seat: int in outcome.metrics:
			var metric: SimulationSeatMetrics = outcome.metrics[seat]
			var key := String(metric.profile_id)
			if not result.has(key):
				result[key] = {
					"hands": 0,
					"vpip": 0,
					"bet_opportunities": 0,
					"bets": 0,
					"calls": 0,
					"raises": 0,
					"bluff_opportunities": 0,
					"bluffs": 0,
				}
			result[key].hands += metric.hands_observed
			result[key].vpip += metric.vpip_hands
			result[key].bet_opportunities += metric.check_bet_opportunities
			result[key].bets += metric.bets_at_check_bet_opportunity
			result[key].calls += metric.calls_at_call_raise_opportunity
			result[key].raises += metric.raises_at_call_raise_opportunity
			result[key].bluff_opportunities += metric.eligible_bluff_opportunities
			result[key].bluffs += metric.bluff_actions
	return result


func _metric_summary(outcomes: Array[SimulationTournamentOutcome]) -> String:
	return JSON.stringify(_metrics_by_profile(outcomes))


func _rate(numerator: int, denominator: int) -> float:
	return float(numerator) / float(denominator) if denominator > 0 else 0.0
