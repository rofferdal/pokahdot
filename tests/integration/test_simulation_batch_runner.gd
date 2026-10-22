extends "res://tests/support/poker_gut_test.gd"

const BATCH_RUNNER_SCRIPT := preload("res://scripts/simulation/simulation_batch_runner.gd")


func test_runner_evaluates_explicit_indexes_without_mutating_snapshots() -> void:
	var first := _profile(&"first")
	var second := _profile(&"second")
	var matchup := SimulationMatchup.new(&"first_vs_second", [first, second])
	var inputs: Array[SimulationTournamentInput] = [
		SimulationTournamentInput.new(7, 1707, matchup, {0: first, 1: second}),
		SimulationTournamentInput.new(11, 1711, matchup, {0: second, 1: first}),
	]

	var result := BATCH_RUNNER_SCRIPT.new().run(_config(), inputs)
	first.profile_id = &"changed_after_run"

	assert_true(result.is_success())
	assert_eq(result.outcomes.size(), 2)
	assert_eq(result.outcomes[0].tournament_index, 7)
	assert_eq(result.outcomes[1].tournament_index, 11)
	assert_eq(result.outcomes[0].effective_seed, 1707)
	assert_eq(result.outcomes[1].effective_seed, 1711)
	assert_eq(result.outcomes[0].final_seat_mapping, {0: &"first", 1: &"second"})
	assert_eq(result.outcomes[1].final_seat_mapping, {0: &"second", 1: &"first"})
	for outcome: SimulationTournamentOutcome in result.outcomes:
		assert_eq(outcome.completion.status, SimulationCompletionResult.Status.COMPLETED)
		assert_eq(outcome.completion.termination_reason, &"winner")
		assert_gte(outcome.completion.tournament_hand_count, 1)
		assert_eq(outcome.metrics.size(), 2)
		assert_eq(outcome.metrics[0].hands_observed, outcome.completion.tournament_hand_count)
		assert_eq(outcome.metrics[1].hands_observed, outcome.completion.tournament_hand_count)


func test_runner_keeps_invalid_input_as_a_structured_outcome() -> void:
	var profile := _profile(&"only")
	var input := SimulationTournamentInput.new(
		2, 1702, SimulationMatchup.new(&"only", [profile]), {0: profile}
	)

	var result := BATCH_RUNNER_SCRIPT.new().run(_config(), [input])

	assert_false(result.is_success())
	assert_eq(result.outcomes.size(), 1)
	assert_eq(result.outcomes[0].diagnostics[0].stage, SimulationDiagnostic.Stage.INPUT_VALIDATION)
	assert_true(result.outcomes[0].diagnostics[0].message.contains("Every simulation seat"))


func test_sampled_trace_is_bounded_private_and_reproducible() -> void:
	var first := _profile(&"first")
	var second := _profile(&"second")
	first.model_id = &"strategy_parameterized"
	second.model_id = &"strategy_parameterized"
	first.parameters = StrategyDecisionModelParameters.new()
	second.parameters = StrategyDecisionModelParameters.new()
	var matchup := SimulationMatchup.new(&"trace_match", [first, second])
	var input := SimulationTournamentInput.new(3, 1703, matchup, {0: first, 1: second})
	var trace_config := SimulationTraceConfig.new(SimulationTraceConfig.Mode.SAMPLED, 8)
	var first_result := BATCH_RUNNER_SCRIPT.new().run(_config(), [input], 256, trace_config)
	var second_result := BATCH_RUNNER_SCRIPT.new().run(_config(), [input], 256, trace_config)

	assert_true(first_result.is_success())
	assert_eq(first_result.outcomes[0].traces.size(), 8)
	assert_eq(
		_trace_summary(first_result.outcomes[0].traces),
		_trace_summary(second_result.outcomes[0].traces)
	)
	for trace: SimulationTraceEntry in first_result.outcomes[0].traces:
		assert_false("hole_cards" in trace)
		assert_false("opponent" in trace.message)


func test_aggregate_reports_small_samples_as_non_reportable() -> void:
	var first := _profile(&"first")
	var second := _profile(&"second")
	var matchup := SimulationMatchup.new(&"aggregate_match", [first, second])
	var input := SimulationTournamentInput.new(4, 1704, matchup, {0: first, 1: second})
	var result := BATCH_RUNNER_SCRIPT.new().run(_config(), [input])

	var profile_rows: Array = result.aggregates.by_profile
	assert_eq(profile_rows.size(), 2)
	assert_false(profile_rows[0].reportable)
	assert_eq(profile_rows[0].sample_count, 1)
	assert_gte(profile_rows[0].uncertainty_95_half_width.size(), 6)


func _config() -> ResolvedTournamentConfig:
	return ResolvedTournamentConfig.new(
		2, 20, 5, 10, 1700, &"single_table", {0: &"random", 1: &"random"}
	)


func _profile(profile_id: StringName) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = profile_id
	profile.model_id = &"random"
	profile.parameters = RandomDecisionModelParameters.new()
	return profile


func _trace_summary(traces: Array[SimulationTraceEntry]) -> Array[String]:
	var summary: Array[String] = []
	for trace: SimulationTraceEntry in traces:
		(
			summary
			. append(
				(
					"%d:%d:%d:%s:%s:%s:%d"
					% [
						trace.kind,
						trace.hand_number,
						trace.seat,
						trace.profile_id,
						trace.street,
						trace.selected_branch,
						trace.action_amount,
					]
				)
			)
		)
	return summary
