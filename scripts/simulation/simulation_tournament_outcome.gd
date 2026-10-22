class_name SimulationTournamentOutcome
extends RefCounted

## Core-independent tournament result; it never retains a live match or view.

var tournament_index: int
var effective_seed: int
var matchup_id: StringName
var regime_id: StringName = &""
var final_seat_mapping: Dictionary[int, StringName]
var completion: SimulationCompletionResult
var diagnostics: Array[SimulationDiagnostic]
var metrics: Dictionary
var traces: Array[SimulationTraceEntry]


func _init(
	index: int,
	seed: int,
	matchup: StringName,
	seat_mapping: Dictionary[int, StringName],
	completion_result: SimulationCompletionResult,
	outcome_diagnostics: Array[SimulationDiagnostic] = [],
	outcome_metrics: Dictionary = {},
	outcome_traces: Array[SimulationTraceEntry] = [],
	outcome_regime_id: StringName = &"",
) -> void:
	tournament_index = index
	effective_seed = seed
	matchup_id = matchup
	final_seat_mapping = seat_mapping.duplicate()
	completion = completion_result
	diagnostics = outcome_diagnostics.duplicate()
	metrics = outcome_metrics.duplicate()
	regime_id = outcome_regime_id
	for trace: SimulationTraceEntry in outcome_traces:
		traces.append(trace.copy())


func is_success() -> bool:
	return (
		completion != null
		and completion.status == SimulationCompletionResult.Status.COMPLETED
		and diagnostics.is_empty()
	)
