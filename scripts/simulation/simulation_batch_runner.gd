class_name SimulationBatchRunner
extends RefCounted

## Evaluates immutable, pre-planned simulation inputs without changing profiles.
##
## The runner deliberately does not select matchups, seats, or indexes. That
## makes a caller's global plan and a filtered shard execute identically.

const BATCH_RESULT_SCRIPT := preload("res://scripts/simulation/simulation_batch_result.gd")
const TOURNAMENT_METRICS_SCRIPT := preload(
	"res://scripts/simulation/simulation_tournament_metrics.gd"
)
const TRACE_CONFIG_SCRIPT := preload("res://scripts/simulation/simulation_trace_config.gd")
const TRACE_ENTRY_SCRIPT := preload("res://scripts/simulation/simulation_trace_entry.gd")

var _factory: SimulationMatchFactory


func _init(factory: SimulationMatchFactory = null) -> void:
	_factory = SimulationMatchFactory.new() if factory == null else factory


func run(
	base_config: ResolvedTournamentConfig,
	inputs: Array[SimulationTournamentInput],
	max_transitions: int = 256,
	trace_config: SimulationTraceConfig = null,
) -> RefCounted:
	var outcomes: Array[SimulationTournamentOutcome] = []
	var resolved_trace_config := TRACE_CONFIG_SCRIPT.new() if trace_config == null else trace_config
	for input: SimulationTournamentInput in inputs:
		outcomes.append(_run_one(base_config, input, max_transitions, resolved_trace_config))
	return BATCH_RESULT_SCRIPT.new(outcomes)


# gdlint: disable=max-returns
func _run_one(
	base_config: ResolvedTournamentConfig,
	input: SimulationTournamentInput,
	max_transitions: int,
	trace_config: SimulationTraceConfig,
) -> SimulationTournamentOutcome:
	var trace_errors := trace_config.validate()
	if not trace_errors.is_empty():
		return _invalid_outcome(input, trace_errors[0])
	if base_config == null:
		return _invalid_outcome(input, "A base tournament configuration is required.")
	if input == null:
		return _invalid_outcome(null, "A simulation tournament input is required.")
	var input_errors: PackedStringArray = input.validate(base_config.player_count)
	if not input_errors.is_empty():
		return _invalid_outcome(input, input_errors[0])
	if max_transitions <= 0:
		return _invalid_outcome(input, "Simulation transitions must be positive.")

	var creation := _factory.create(
		_config_for_input(base_config, input), input.get_seat_profiles()
	)
	if not creation.is_ok():
		return _failure_outcome(
			input,
			SimulationDiagnostic.Stage.MATCH_CONSTRUCTION,
			(
				creation.errors[0]
				if not creation.errors.is_empty()
				else "Simulation match construction failed."
			),
		)
	var execution_config := _config_for_input(base_config, input)
	var execution := _run_with_metrics(
		creation.match_instance,
		input,
		execution_config.starting_stack,
		max_transitions,
		trace_config,
		creation.effective_seed
	)
	var result: StepResult = execution.result
	if result.status != StepResult.Status.TOURNAMENT_FINISHED:
		return _failure_outcome(input, SimulationDiagnostic.Stage.EXECUTION, result.message)
	var outcome := (
		SimulationTournamentOutcome
		. new(
			input.tournament_index,
			creation.effective_seed,
			input.matchup.matchup_id,
			_seat_mapping(input),
			(
				SimulationCompletionResult
				. new(
					SimulationCompletionResult.Status.COMPLETED,
					creation.match_instance.end_reason,
					creation.match_instance.winner_seat,
					creation.match_instance.hand_number,
				)
			),
			[],
			execution.metrics.get_seat_metrics(),
			execution.traces,
			input.regime_id,
		)
	)
	outcome.plan_id = input.plan_id
	outcome.plan_tournament_index = input.plan_tournament_index
	outcome.matchup_occurrence = input.matchup_occurrence
	outcome.rotation = input.rotation
	return outcome


func _run_with_metrics(
	match_instance: TournamentMatch,
	input: SimulationTournamentInput,
	starting_stack: int,
	max_transitions: int,
	trace_config: SimulationTraceConfig,
	effective_seed: int,
) -> Dictionary:
	var profiles: Dictionary[int, StringName] = _seat_mapping(input)
	var starting_stacks: Dictionary[int, int] = {}
	for seat: int in profiles:
		starting_stacks[seat] = starting_stack
	var metrics = TOURNAMENT_METRICS_SCRIPT.new(profiles, starting_stacks)
	var traces: Array[SimulationTraceEntry] = []
	var trace_rng := (
		RngStreamFactory
		. new()
		. create_named(effective_seed, ["trace_sampling"])
		. get_trace_sampling_rng()
	)
	var event_cursor: int = 0
	var decision_cursors: Dictionary[int, int] = {}
	var result: StepResult = match_instance.start(max_transitions)
	while true:
		_capture_decisions(
			metrics,
			traces,
			trace_config,
			trace_rng,
			match_instance,
			input,
			event_cursor,
			decision_cursors,
		)
		event_cursor = match_instance.get_events().size()
		if (
			result.status
			in [StepResult.Status.HAND_COMPLETED, StepResult.Status.TOURNAMENT_FINISHED]
		):
			_capture_completed_hand(metrics, match_instance)
			_capture_hand_trace(traces, trace_config, trace_rng, match_instance, input)
		if result.status == StepResult.Status.HAND_COMPLETED:
			# HandController starts a fresh event list for the next hand.
			event_cursor = 0
		if result.status == StepResult.Status.TOURNAMENT_FINISHED:
			var final_view: GameView = match_instance.get_view_for(0)
			metrics.finish(
				_stacks(final_view), match_instance.winner_seat, match_instance.hand_number
			)
			return {"result": result, "metrics": metrics, "traces": traces}
		if result.status == StepResult.Status.WAITING_FOR_HUMAN:
			return {
				"result":
				StepResult.new(
					StepResult.Status.ERROR, "A simulation tournament cannot wait for human input."
				),
				"metrics": metrics,
				"traces": traces
			}
		if result.status == StepResult.Status.ERROR:
			if trace_config.mode == SimulationTraceConfig.Mode.ERRORS:
				traces.append(TRACE_ENTRY_SCRIPT.error(input.tournament_index, result.message))
			return {"result": result, "metrics": metrics, "traces": traces}
		result = match_instance.advance_until_blocked(max_transitions)
	return {
		"result":
		StepResult.new(StepResult.Status.ERROR, "Simulation execution stopped unexpectedly."),
		"metrics": metrics,
		"traces": traces
	}


func _capture_decisions(
	metrics: RefCounted,
	traces: Array[SimulationTraceEntry],
	trace_config: SimulationTraceConfig,
	trace_rng: RandomNumberGenerator,
	match_instance: TournamentMatch,
	input: SimulationTournamentInput,
	event_cursor: int,
	decision_cursors: Dictionary[int, int],
) -> void:
	var events := match_instance.get_events()
	for event_index: int in range(event_cursor, events.size()):
		var event: DomainEvent = events[event_index]
		if event.kind not in [DomainEvent.Kind.ACTION_APPLIED, DomainEvent.Kind.ACTION_REJECTED]:
			continue
		var agent := match_instance.get_agent_for_simulation(event.seat)
		if not agent is BotAgent:
			continue
		var history := (agent as BotAgent).get_decision_history_for_simulation()
		var cursor: int = decision_cursors.get(event.seat, 0)
		if cursor >= history.size():
			continue
		var decision: Dictionary = history[cursor]
		decision_cursors[event.seat] = cursor + 1
		if event.kind == DomainEvent.Kind.ACTION_REJECTED:
			continue
		var trace: RefCounted = decision.trace
		(
			metrics
			. observe_decision(
				event.seat,
				decision.legal_actions,
				decision.action,
				trace,
				int(decision.get("all_in_aggression_kind", -1)),
			)
		)
		if trace_config.mode != SimulationTraceConfig.Mode.SAMPLED:
			continue
		_append_sample(
			traces,
			trace_config.max_entries_per_tournament,
			trace_rng,
			TRACE_ENTRY_SCRIPT.decision(
				input.tournament_index,
				match_instance.hand_number,
				event.seat,
				(agent as BotAgent).profile_id,
				decision.street,
				trace,
				decision.action
			)
		)


func _capture_hand_trace(
	traces: Array[SimulationTraceEntry],
	trace_config: SimulationTraceConfig,
	trace_rng: RandomNumberGenerator,
	match_instance: TournamentMatch,
	input: SimulationTournamentInput,
) -> void:
	if trace_config.mode != SimulationTraceConfig.Mode.SAMPLED:
		return
	var view := match_instance.get_view_for(0)
	if view == null or not view.hand_complete:
		return
	_append_sample(
		traces,
		trace_config.max_entries_per_tournament,
		trace_rng,
		TRACE_ENTRY_SCRIPT.hand_outcome(
			input.tournament_index, view.hand_number, view.hand_winner_seat, &"hand_completed"
		)
	)


func _append_sample(
	traces: Array[SimulationTraceEntry],
	limit: int,
	rng: RandomNumberGenerator,
	entry: SimulationTraceEntry,
) -> void:
	if traces.size() < limit:
		traces.append(entry)
		return
	var replacement := rng.randi_range(0, traces.size())
	if replacement < traces.size():
		traces[replacement] = entry


func _capture_completed_hand(metrics: RefCounted, match_instance: TournamentMatch) -> void:
	var view: GameView = match_instance.get_view_for(0)
	if view == null or not view.hand_complete:
		return
	(
		metrics
		. observe_hand(
			view.active_seats_at_hand_start,
			view.hand_start_stacks,
			_stacks(view),
			view.big_blind,
			view.action_history,
			match_instance.get_events(),
		)
	)


func _stacks(view: GameView) -> Dictionary[int, int]:
	var stacks: Dictionary[int, int] = {}
	for seat_view: PlayerView in view.seats:
		stacks[seat_view.seat] = seat_view.stack
	return stacks


func _config_for_input(
	base_config: ResolvedTournamentConfig, input: SimulationTournamentInput
) -> ResolvedTournamentConfig:
	if input.regime != null:
		var resolution := input.regime.resolve(input.effective_seed)
		if resolution.is_ok():
			return resolution.get_config()
	return (
		ResolvedTournamentConfig
		. new(
			base_config.player_count,
			base_config.starting_stack,
			base_config.small_blind,
			base_config.big_blind,
			input.effective_seed,
			base_config.tournament_mode,
			base_config.seat_agents,
			base_config.use_legacy_models,
		)
	)


func _seat_mapping(input: SimulationTournamentInput) -> Dictionary[int, StringName]:
	var mapping: Dictionary[int, StringName] = {}
	for seat: int in input.get_seat_profiles():
		mapping[seat] = input.get_seat_profiles()[seat].profile_id
	return mapping


func _invalid_outcome(
	input: SimulationTournamentInput, message: String
) -> SimulationTournamentOutcome:
	return _failure_outcome(input, SimulationDiagnostic.Stage.INPUT_VALIDATION, message)


func _failure_outcome(
	input: SimulationTournamentInput, stage: SimulationDiagnostic.Stage, message: String
) -> SimulationTournamentOutcome:
	var index: int = -1 if input == null else input.tournament_index
	var seed: int = 0 if input == null else input.effective_seed
	var matchup_id: StringName = (
		&"" if input == null or input.matchup == null else input.matchup.matchup_id
	)
	var mapping: Dictionary[int, StringName] = {} if input == null else _seat_mapping(input)
	return (
		SimulationTournamentOutcome
		. new(
			index,
			seed,
			matchup_id,
			mapping,
			SimulationCompletionResult.new(SimulationCompletionResult.Status.FAILED),
			[SimulationDiagnostic.new(stage, message)],
		)
	)
