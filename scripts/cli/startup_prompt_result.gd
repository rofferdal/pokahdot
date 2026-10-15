class_name StartupPromptResult
extends RefCounted

enum Status {
	READY,
	QUIT,
	EOF,
	ERROR,
}

var status: Status:
	get:
		return _status

var config: ResolvedTournamentConfig:
	get:
		return _config

var _status: Status
var _config: ResolvedTournamentConfig


func _init(result_status: Status, resolved_config: ResolvedTournamentConfig = null) -> void:
	_status = result_status
	_config = resolved_config


func is_ready() -> bool:
	return _status == Status.READY and _config != null
