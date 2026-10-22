class_name SimulationDiagnostic
extends RefCounted

enum Stage { INPUT_VALIDATION, MATCH_CONSTRUCTION, EXECUTION, INVARIANT }

var stage: Stage
var message: String
var seat: int


func _init(diagnostic_stage: Stage, diagnostic_message: String, diagnostic_seat: int = -1) -> void:
	stage = diagnostic_stage
	message = diagnostic_message
	seat = diagnostic_seat
