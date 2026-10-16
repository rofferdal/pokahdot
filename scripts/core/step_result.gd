class_name StepResult
extends RefCounted

enum Status {
	WAITING_FOR_HUMAN,
	HAND_COMPLETED,
	PREFLOP_COMPLETE,
	TOURNAMENT_FINISHED,
	YIELDED,
	ERROR,
}

var status: Status
var message: String


func _init(result_status: Status, result_message: String = "") -> void:
	status = result_status
	message = result_message
