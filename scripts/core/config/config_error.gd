class_name ConfigError
extends RefCounted

enum Code {
	MISSING_DEFAULTS,
	PLAYER_COUNT_OUT_OF_RANGE,
	STARTING_STACK_NOT_POSITIVE,
	SMALL_BLIND_NOT_POSITIVE,
	BIG_BLIND_NOT_POSITIVE,
	SMALL_BLIND_EXCEEDS_BIG_BLIND,
	TOTAL_CHIPS_OVERFLOW,
	UNSUPPORTED_TOURNAMENT_MODE,
	INVALID_SEAT_AGENTS,
}

var code: Code
var field: StringName
var message: String


func _init(error_code: Code, error_field: StringName, error_message: String) -> void:
	code = error_code
	field = error_field
	message = error_message
