class_name AgentCreationResult
extends RefCounted

var agent: Agent
var errors: PackedStringArray


func _init(created_agent: Agent = null, creation_errors: PackedStringArray = []) -> void:
	agent = created_agent
	errors = creation_errors.duplicate()


func is_ok() -> bool:
	return agent != null and errors.is_empty()
