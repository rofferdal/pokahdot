class_name AvatarAssignmentResult
extends RefCounted

var assignments: Dictionary[int, String]:
	get:
		return _assignments.duplicate()
var error_message: String:
	get:
		return _error_message

var _assignments: Dictionary[int, String]
var _error_message: String


func _init(
	seat_assignments: Dictionary[int, String] = {},
	assignment_error: String = "",
) -> void:
	_assignments = seat_assignments.duplicate()
	_error_message = assignment_error


func is_ok() -> bool:
	return _error_message.is_empty()
