extends "res://tests/support/poker_gut_test.gd"


func test_behavior_rates_use_summed_counts_and_ignore_zero_denominators() -> void:
	var first := SimulationSeatMetrics.new(&"profile", 0, 100)
	first.bet_raise_opportunities = 1
	first.aggressive_actions = 1
	first.check_bet_opportunities = 1
	first.bets_at_check_bet_opportunity = 1
	first.calls_at_call_raise_opportunity = 0
	first.raises_at_call_raise_opportunity = 1
	first.eligible_bluff_opportunities = 1
	first.bluff_actions = 1
	first.finish(100, 1, true, 2, 1)
	var second := SimulationSeatMetrics.new(&"profile", 0, 100)
	second.bet_raise_opportunities = 99
	second.check_bet_opportunities = 9
	second.calls_at_call_raise_opportunity = 9
	second.finish(100, 2, false, 2, 1)

	var aggregates := SimulationAggregateCalculator.new().calculate(
		[_outcome(0, first), _outcome(1, second)], {&"plan": 1}
	)
	var row: Dictionary = aggregates.by_profile[0]
	assert_almost_eq(row.means.bet_raise_frequency, 0.01, 0.0001)
	assert_almost_eq(row.means.bet_frequency, 0.1, 0.0001)
	assert_almost_eq(row.means.raise_share, 0.1, 0.0001)
	assert_almost_eq(row.means.eligible_bluff_frequency, 1.0, 0.0001)
	assert_almost_eq(
		row.uncertainty_95_half_width.bet_raise_frequency,
		0.98,
		0.0001,
	)
	assert_eq(row.behavior_counts.bet_raise_opportunities, 100)
	assert_eq(row.behavior_counts.eligible_bluff_opportunities, 1)
	assert_eq(row.statistical_unit, "tournament_seed")


func test_reportability_uses_the_plan_threshold_instead_of_a_global_default() -> void:
	var first := SimulationSeatMetrics.new(&"profile", 0, 100)
	first.finish(200, 1, true, 2, 1)
	var second := SimulationSeatMetrics.new(&"profile", 0, 100)
	second.finish(0, 2, false, 2, 1)
	var outcomes: Array[SimulationTournamentOutcome] = [_outcome(0, first), _outcome(1, second)]

	var strict := SimulationAggregateCalculator.new().calculate(outcomes, {&"plan": 3})
	var exact := SimulationAggregateCalculator.new().calculate(outcomes, {&"plan": 2})

	assert_false(strict.by_profile[0].reportable)
	assert_true(exact.by_profile[0].reportable)
	assert_false(strict.by_evaluation_plan[0].reportable)
	assert_true(exact.by_evaluation_plan[0].reportable)


func test_repeated_profile_seats_are_one_tournament_sample() -> void:
	var winner := SimulationSeatMetrics.new(&"mirror", 0, 100)
	winner.finish(200, 1, true, 2, 1)
	var runner_up := SimulationSeatMetrics.new(&"mirror", 1, 100)
	runner_up.finish(0, 2, false, 2, 1)
	var outcome := _outcome_with_metrics(0, {0: winner, 1: runner_up})

	var aggregates := SimulationAggregateCalculator.new().calculate([outcome], {&"plan": 2})
	var profile_row: Dictionary = aggregates.by_profile[0]
	var matchup_row: Dictionary = aggregates.by_matchup[0]

	assert_eq(profile_row.sample_count, 1)
	assert_eq(matchup_row.sample_count, 1)
	assert_false(profile_row.reportable)
	assert_almost_eq(profile_row.means.win_score, 0.5, 0.0001)
	assert_null(profile_row.uncertainty_95_half_width.win_score)


func test_sparse_uncertainty_is_missing_and_penalty_is_separate() -> void:
	var metric := SimulationSeatMetrics.new(&"profile", 0, 100)
	metric.bet_raise_opportunities = 1
	metric.finish(0, 2, false, 2, 1)

	var aggregates := SimulationAggregateCalculator.new().calculate(
		[_outcome(0, metric)], {&"plan": 1}
	)
	var row: Dictionary = aggregates.by_profile[0]

	assert_null(row.uncertainty_95_half_width.win_score)
	assert_null(row.uncertainty_95_half_width.bet_raise_frequency)
	assert_almost_eq(row.uncertainty_penalty, 0.10, 0.0001)
	assert_almost_eq(row.fitness, maxf(0.0, row.point_fitness - 0.10), 0.0001)


func test_boundary_rates_have_nonzero_uncertainty_with_two_tournaments() -> void:
	var first := SimulationSeatMetrics.new(&"profile", 0, 100)
	first.bet_raise_opportunities = 5
	first.hands_observed = 1
	first.finish(0, 2, false, 2, 1)
	var second := SimulationSeatMetrics.new(&"profile", 0, 100)
	second.bet_raise_opportunities = 8
	second.hands_observed = 1
	second.finish(0, 2, false, 2, 1)

	var aggregates := SimulationAggregateCalculator.new().calculate(
		[_outcome(0, first), _outcome(1, second)], {&"plan": 2}
	)
	var row: Dictionary = aggregates.by_profile[0]

	assert_gt(row.uncertainty_95_half_width.win_score, 0.0)
	assert_gt(row.uncertainty_95_half_width.bet_raise_frequency, 0.0)
	assert_gt(row.uncertainty_95_half_width.vpip_rate, 0.0)
	assert_lt(row.uncertainty_penalty, 0.10)


func _outcome(index: int, metric: SimulationSeatMetrics) -> SimulationTournamentOutcome:
	return _outcome_with_metrics(index, {0: metric})


func _outcome_with_metrics(index: int, metrics: Dictionary) -> SimulationTournamentOutcome:
	var seat_mapping: Dictionary[int, StringName] = {}
	for seat: int in metrics:
		seat_mapping[seat] = metrics[seat].profile_id
	var outcome := (
		SimulationTournamentOutcome
		. new(
			index,
			1000 + index,
			&"matchup",
			seat_mapping,
			SimulationCompletionResult.new(
				SimulationCompletionResult.Status.COMPLETED, &"winner", 0, 1
			),
			[],
			metrics,
		)
	)
	outcome.plan_id = &"plan"
	return outcome
