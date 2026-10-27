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


func test_streamed_moments_match_independent_three_sample_variance() -> void:
	var accumulator := SimulationAggregateAccumulator.new()
	for index: int in range(3):
		var metric := SimulationSeatMetrics.new(&"profile", 0, 100)
		metric.hands_observed = 1
		metric.finish(100 + index * 20, 1, true, 2, 1)
		accumulator.add_outcome(_outcome(index, metric), 3)
	var row: Dictionary = accumulator.summarize().by_profile[0]
	assert_eq(row.sample_count, 3)
	assert_true(row.reportable)
	assert_almost_eq(row.means.chip_differential, 20.0, 1e-12)
	# Values 0, 20, 40 have unbiased sample variance 400.
	assert_almost_eq(
		row.uncertainty_95_half_width.chip_differential, 1.96 * sqrt(400.0 / 3.0), 1e-12
	)
	assert_gt(row.uncertainty_95_half_width.win_score, 0.0)
	assert_null(row.uncertainty_95_half_width.eligible_bluff_frequency)


func test_checkpoint_records_preserve_correlated_seats_rates_and_plan_minimums() -> void:
	var live := SimulationAggregateAccumulator.new()
	var checkpoint := SimulationAggregateAccumulator.new()
	for index: int in range(3):
		var winner := SimulationSeatMetrics.new(&"mirror", 0, 100)
		winner.hands_observed = 1
		winner.bet_raise_opportunities = index * 2
		winner.aggressive_actions = index
		winner.finish(200, 1, true, 2, 1)
		var runner_up := SimulationSeatMetrics.new(&"mirror", 1, 100)
		runner_up.hands_observed = 1
		runner_up.bet_raise_opportunities = index
		runner_up.finish(0, 2, false, 2, 1)
		var outcome := _outcome_with_metrics(index, {1: runner_up, 0: winner})
		outcome.plan_id = &"strict" if index == 0 else &"lenient"
		var minimum: int = 4 if index == 0 else 1
		live.add_outcome(outcome, minimum)
		var record: Dictionary = JSON.parse_string(
			JSON.stringify(SimulationReport._tournament_dictionary(outcome), "", true, true)
		)
		checkpoint.add_tournament(record, minimum)
	assert_eq(checkpoint.summarize(), live.summarize())
	var row: Dictionary = checkpoint.summarize().by_profile[0]
	assert_eq(row.sample_count, 3)
	assert_false(row.reportable)
	assert_almost_eq(row.means.win_score, 0.5, 1e-12)
	assert_almost_eq(row.means.bet_raise_frequency, 1.0 / 3.0, 1e-12)
	assert_gt(row.uncertainty_95_half_width.bet_raise_frequency, 0.0)
	assert_null(row.uncertainty_95_half_width.eligible_bluff_frequency)


func test_summaries_and_supplied_metrics_do_not_share_accumulator_ownership() -> void:
	var accumulator := SimulationAggregateAccumulator.new()
	var metric := SimulationSeatMetrics.new(&"profile", 0, 100)
	metric.bet_raise_opportunities = 4
	metric.finish(200, 1, true, 2, 1)
	accumulator.add_outcome(_outcome(0, metric))
	var first: Dictionary = accumulator.summarize()
	metric.bet_raise_opportunities = 999
	first.by_profile[0].means.win_score = -1.0
	first.by_profile[0].behavior_counts.bet_raise_opportunities = 999
	first.by_profile.clear()
	var second: Dictionary = accumulator.summarize()
	assert_eq(second.by_profile.size(), 1)
	assert_eq(second.by_profile[0].behavior_counts.bet_raise_opportunities, 4)
	assert_eq(second.by_profile[0].means.win_score, 1.0)


func test_ten_thousand_streamed_tournaments_release_outcomes_and_seat_metrics() -> void:
	var accumulator := SimulationAggregateAccumulator.new()
	var first_outcome: WeakRef
	var first_metric: WeakRef
	for index: int in range(10000):
		var metric := SimulationSeatMetrics.new(&"profile", 0, 100)
		metric.finish(
			200 if index % 2 == 0 else 0, 1 if index % 2 == 0 else 2, index % 2 == 0, 2, 1
		)
		var outcome := _outcome(index, metric)
		if index == 0:
			first_outcome = weakref(outcome)
			first_metric = weakref(metric)
		accumulator.add_outcome(outcome)
	assert_null(first_outcome.get_ref())
	assert_null(first_metric.get_ref())
	var summary: Dictionary = accumulator.summarize()
	for group_name: String in summary:
		assert_eq(summary[group_name].size(), 1)
		assert_eq(summary[group_name][0].sample_count, 10000)
	assert_almost_eq(summary.by_profile[0].means.win_score, 0.5, 1e-12)
	assert_almost_eq(summary.by_profile[0].means.chip_differential, 0.0, 1e-12)


func test_failed_checkpoint_outcomes_are_ignored_by_aggregates() -> void:
	var accumulator := SimulationAggregateAccumulator.new()
	accumulator.add_tournament({"termination_reason": "", "diagnostics": ["failed"]})
	accumulator.add_outcome(null)
	for rows: Array in accumulator.summarize().values():
		assert_true(rows.is_empty())


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
