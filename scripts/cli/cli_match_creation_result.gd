class_name CliMatchCreationResult
extends RefCounted

## CLI-owned composition result. Startup diagnostics are captured from the
## same profile selection used to construct the tournament.

var match_instance: TournamentMatch:
	get:
		return _match_instance
var human_seat: int:
	get:
		return _human_seat
var diagnostics: PackedStringArray:
	get:
		return _diagnostics.duplicate()

var _match_instance: TournamentMatch
var _human_seat: int
var _diagnostics: PackedStringArray


func _init(
	created_match: TournamentMatch,
	created_human_seat: int,
	startup_diagnostics: PackedStringArray,
) -> void:
	_match_instance = created_match
	_human_seat = created_human_seat
	_diagnostics = startup_diagnostics.duplicate()
