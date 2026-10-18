class_name AvatarAssignmentResult
extends RefCounted

var assignments: Dictionary[int, String] = {}
var error_message: String = ""


func is_ok() -> bool:
	return error_message.is_empty()
