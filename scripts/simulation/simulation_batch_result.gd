class_name SimulationBatchResult
extends RefCounted

## Typed result of executing a fixed, already-planned set of tournaments.
##
## Planning and serialization intentionally remain outside this value. Inputs
## are evaluated in their supplied order so callers can retain global indexes
## when executing a shard.

var outcomes: Array[SimulationTournamentOutcome] = []
var aggregates: Dictionary = {}


func _init(
	batch_outcomes: Array[SimulationTournamentOutcome] = [],
	minimum_samples_by_plan: Dictionary = {},
) -> void:
	for outcome: SimulationTournamentOutcome in batch_outcomes:
		outcomes.append(outcome)
	aggregates = SimulationAggregateCalculator.new().calculate(outcomes, minimum_samples_by_plan)


func is_success() -> bool:
	for outcome: SimulationTournamentOutcome in outcomes:
		if outcome == null or not outcome.is_success():
			return false
	return true
