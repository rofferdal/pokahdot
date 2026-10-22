class_name SimulationBatchPlan
extends RefCounted

## Validated global tournament plan before any shard filtering or execution.

var inputs: Array[SimulationTournamentInput] = []
var errors: PackedStringArray = []


func _init(
	planned_inputs: Array[SimulationTournamentInput] = [], plan_errors: PackedStringArray = []
) -> void:
	inputs = planned_inputs.duplicate()
	errors = plan_errors.duplicate()


func is_valid() -> bool:
	return errors.is_empty()
