class_name SimulationAggregateCalculator
extends RefCounted

## Compatibility adapter over the bounded tournament-clustered accumulator.

const ACCUMULATOR_SCRIPT := preload("res://scripts/simulation/simulation_aggregate_accumulator.gd")


func calculate(
	outcomes: Array[SimulationTournamentOutcome], minimum_samples_by_plan: Dictionary = {}
) -> Dictionary:
	var accumulator := ACCUMULATOR_SCRIPT.new()
	for outcome: SimulationTournamentOutcome in outcomes:
		if outcome != null:
			accumulator.add_outcome(
				outcome, maxi(1, int(minimum_samples_by_plan.get(outcome.plan_id, 1)))
			)
	return accumulator.summarize()
