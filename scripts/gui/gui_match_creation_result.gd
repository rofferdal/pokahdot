class_name GuiMatchCreationResult
extends RefCounted

## GUI-owned tournament composition result with presentation-only mappings.

var match_instance: TournamentMatch:
	get:
		return _match_instance
var name_assignments: Dictionary[int, String]:
	get:
		return _name_assignments.duplicate()
var avatar_assignments: Dictionary[int, String]:
	get:
		return _avatar_assignments.duplicate()
var effective_seed: int:
	get:
		return _effective_seed
var error_message: String:
	get:
		return _error_message

var _match_instance: TournamentMatch
var _name_assignments: Dictionary[int, String]
var _avatar_assignments: Dictionary[int, String]
var _effective_seed: int
var _error_message: String


func _init(
	created_match: TournamentMatch = null,
	visual_name_assignments: Dictionary[int, String] = {},
	visual_avatar_assignments: Dictionary[int, String] = {},
	creation_effective_seed: int = 0,
	creation_error: String = "",
) -> void:
	_match_instance = created_match
	_name_assignments = visual_name_assignments.duplicate()
	_avatar_assignments = visual_avatar_assignments.duplicate()
	_effective_seed = creation_effective_seed
	_error_message = creation_error


func is_ok() -> bool:
	return _error_message.is_empty() and _match_instance != null
