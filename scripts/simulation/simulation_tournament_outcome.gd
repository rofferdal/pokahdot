class_name SimulationTournamentOutcome
extends RefCounted

## Core-independent tournament result; it never retains a live match or view.

var tournament_index: int
var effective_seed: int
var matchup_id: StringName
var final_seat_mapping: Dictionary[int, StringName]
var completion: SimulationCompletionResult
var diagnostics: Array[SimulationDiagnostic]


func _init(
	index: int,
	seed: int,
	matchup: StringName,
	seat_mapping: Dictionary[int, StringName],
	completion_result: SimulationCompletionResult,
	outcome_diagnostics: Array[SimulationDiagnostic] = [],
) -> void:
	tournament_index = index
	effective_seed = seed
	matchup_id = matchup
	final_seat_mapping = seat_mapping.duplicate()
	completion = completion_result
	diagnostics = outcome_diagnostics.duplicate()


func is_success() -> bool:
	return (
		completion != null
		and completion.status == SimulationCompletionResult.Status.COMPLETED
		and diagnostics.is_empty()
	)
