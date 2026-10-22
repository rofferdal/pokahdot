class_name SimulationCompletionResult
extends RefCounted

enum Status { COMPLETED, FAILED }

var status: Status
var termination_reason: StringName
var winner_seat: int
var tournament_hand_count: int


func _init(
	completion_status: Status,
	reason: StringName = &"",
	winner: int = -1,
	hand_count: int = 0,
) -> void:
	status = completion_status
	termination_reason = reason
	winner_seat = winner
	tournament_hand_count = hand_count
