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


func test_trace_reservoir_samples_early_and_late_entries_fairly() -> void:
	var first_retained := 0
	var last_retained := 0
	var runner := BATCH_RUNNER_SCRIPT.new()
	for seed: int in range(1, 401):
		var traces: Array[SimulationTraceEntry] = []
		var sampling_state := {&"observed": 0}
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for item: int in range(100):
			(
				runner
				. _append_sample(
					traces,
					5,
					rng,
					sampling_state,
					SimulationTraceEntry.error(0, str(item)),
				)
			)
		assert_eq(traces.size(), 5)
		assert_eq(sampling_state[&"observed"], 100)
		for trace: SimulationTraceEntry in traces:
			if trace.message == "0":
				first_retained += 1
			if trace.message == "99":
				last_retained += 1
	assert_gt(first_retained, 5)
	assert_lt(first_retained, 45)
	assert_gt(last_retained, 5)
	assert_lt(last_retained, 45)


func test_failure_outcome_preserves_identity_and_copied_partial_traces() -> void:
	var first := _profile(&"first")
	var second := _profile(&"second")
	var matchup := SimulationMatchup.new(&"failed_match", [first, second])
	var input := (
		SimulationTournamentInput
		. new(
			17,
			2717,
			matchup,
			{0: second, 1: first},
			4,
			1,
			&"short_stack",
			&"candidate_plan",
			9,
		)
	)
	var partial_traces: Array[SimulationTraceEntry] = [
		SimulationTraceEntry.error(17, "safe partial evidence")
	]

	var outcome: SimulationTournamentOutcome = BATCH_RUNNER_SCRIPT.new()._failure_outcome(
		input, SimulationDiagnostic.Stage.EXECUTION, "transition limit", partial_traces
	)
	partial_traces[0].message = "mutated after outcome"

	assert_false(outcome.is_success())
	assert_eq(outcome.tournament_index, 17)
	assert_eq(outcome.effective_seed, 2717)
	assert_eq(outcome.matchup_id, &"failed_match")
	assert_eq(outcome.final_seat_mapping, {0: &"second", 1: &"first"})
	assert_eq(outcome.regime_id, &"short_stack")
	assert_eq(outcome.plan_id, &"candidate_plan")
	assert_eq(outcome.plan_tournament_index, 9)
	assert_eq(outcome.matchup_occurrence, 4)
	assert_eq(outcome.rotation, 1)
	assert_eq(outcome.diagnostics[0].stage, SimulationDiagnostic.Stage.EXECUTION)
	assert_eq(outcome.diagnostics[0].message, "transition limit")
	assert_eq(outcome.traces.size(), 1)
	assert_eq(outcome.traces[0].message, "safe partial evidence")


func test_aggregate_reports_small_samples_as_non_reportable() -> void:
	var first := _profile(&"first")
	var second := _profile(&"second")
	var matchup := SimulationMatchup.new(&"aggregate_match", [first, second])
	var input := SimulationTournamentInput.new(
		4, 1704, matchup, {0: first, 1: second}, 0, 0, &"", &"strict_plan"
	)
	var result := BATCH_RUNNER_SCRIPT.new().run(_config(), [input], 256, null, {&"strict_plan": 2})

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


class RejectingModel:
	extends DecisionModel
	var decisions: int = 0
	var full_wager_opportunities: int = 0

	func choose_action(view: GameView) -> PlayerAction:
		decisions += 1
		if (
			PlayerAction.Kind.BET in view.legal_actions
			or PlayerAction.Kind.RAISE in view.legal_actions
		):
			full_wager_opportunities += 1
		return PlayerAction.raise_to(0)

	func get_last_decision_trace_for_testing() -> RefCounted:
		return StrategyDecisionTrace.new(
			&"test", StrategyDecisionTrace.WEAK_BAND, &"bluff_raise", [], null
		)


func test_rejected_decisions_measure_applied_fallback_once_without_false_bluffs() -> void:
	var first := _profile(&"first")
	var second := _profile(&"second")
	var matchup := SimulationMatchup.new(&"rejected_match", [first, second])
	var input := SimulationTournamentInput.new(0, 1700, matchup, {0: first, 1: second})
	var models: Array[RejectingModel] = [RejectingModel.new(), RejectingModel.new()]
	var agents: Dictionary[int, Agent] = {
		0: BotAgent.new(models[0], first), 1: BotAgent.new(models[1], second)
	}
	var match_instance := TournamentMatch.new(
		_config(), agents, TournamentConstructionContract.simulation()
	)
	var result: Dictionary = BATCH_RUNNER_SCRIPT.new()._run_with_metrics(
		match_instance,
		input,
		20,
		256,
		SimulationTraceConfig.new(SimulationTraceConfig.Mode.SAMPLED, 1000),
		1700,
		RngStreamFactory.ALGORITHM_VERSION
	)
	assert_eq(result.result.status, StepResult.Status.TOURNAMENT_FINISHED)
	var metrics: Dictionary = result.metrics.get_seat_metrics()
	var total_decisions: int = 0
	for seat: int in agents:
		assert_eq(metrics[seat].invalid_action_fallbacks, models[seat].decisions)
		assert_eq(metrics[seat].eligible_bluff_opportunities, models[seat].full_wager_opportunities)
		assert_eq(metrics[seat].bluff_actions, 0)
		assert_true((agents[seat] as BotAgent).drain_decisions_for_simulation().is_empty())
		total_decisions += models[seat].decisions
	var traced_decisions: int = 0
	for trace: SimulationTraceEntry in result.traces:
		if trace.kind == SimulationTraceEntry.Kind.DECISION:
			traced_decisions += 1
			assert_eq(trace.action_kind, PlayerAction.Kind.FOLD)
			assert_eq(trace.selected_branch, &"fallback")
	assert_gt(total_decisions, 2)
	assert_eq(traced_decisions, total_decisions)
