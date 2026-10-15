class_name ConfigResolution
extends RefCounted

var _config: ResolvedTournamentConfig
var _errors: Array[ConfigError]


func _init(
	resolved_config: ResolvedTournamentConfig = null,
	validation_errors: Array[ConfigError] = [],
) -> void:
	_config = resolved_config
	_errors = validation_errors.duplicate()


func is_ok() -> bool:
	return _config != null and _errors.is_empty()


func get_config() -> ResolvedTournamentConfig:
	return _config


func get_errors() -> Array[ConfigError]:
	return _errors.duplicate()


func has_error(code: ConfigError.Code) -> bool:
	for validation_error: ConfigError in _errors:
		if validation_error.code == code:
			return true
	return false
