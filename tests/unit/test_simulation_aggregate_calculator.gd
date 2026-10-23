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
		[_outcome(0, first), _outcome(1, second)], 1
	)
	var row: Dictionary = aggregates.by_profile[0]
	assert_almost_eq(row.means.bet_raise_frequency, 0.01, 0.0001)
	assert_almost_eq(row.means.bet_frequency, 0.1, 0.0001)
	assert_almost_eq(row.means.raise_share, 0.1, 0.0001)
	assert_almost_eq(row.means.eligible_bluff_frequency, 1.0, 0.0001)
	assert_almost_eq(
		row.uncertainty_95_half_width.bet_raise_frequency,
		1.96 * sqrt(0.01 * 0.99 / 100.0),
		0.0001,
	)
	assert_eq(row.behavior_counts.bet_raise_opportunities, 100)
	assert_eq(row.behavior_counts.eligible_bluff_opportunities, 1)


func _outcome(index: int, metric: SimulationSeatMetrics) -> SimulationTournamentOutcome:
	return (
		SimulationTournamentOutcome
		. new(
			index,
			1000 + index,
			&"matchup",
			{0: &"profile"},
			SimulationCompletionResult.new(
				SimulationCompletionResult.Status.COMPLETED, &"winner", 0, 1
			),
			[],
			{0: metric},
		)
	)
