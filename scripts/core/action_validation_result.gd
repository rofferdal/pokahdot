class_name ActionValidationResult
extends RefCounted

## Typed outcome returned when a betting action is validated or applied.

enum Code {
	OK,
	ROUND_COMPLETE,
	NOT_ACTING_PLAYER,
	PLAYER_CANNOT_ACT,
	ACTION_NOT_AVAILABLE,
	INVALID_AMOUNT,
	BELOW_MINIMUM,
	ABOVE_MAXIMUM,
	RAISE_NOT_REOPENED,
}

var code: Code
var message: String
var chips_committed: int


func _init(result_code: Code, result_message: String = "", committed: int = 0) -> void:
	code = result_code
	message = result_message
	chips_committed = committed


func is_ok() -> bool:
	return code == Code.OK


static func accepted(committed: int = 0) -> ActionValidationResult:
	return ActionValidationResult.new(Code.OK, "", committed)


static func rejected(rejection_code: Code, rejection_message: String) -> ActionValidationResult:
	assert(rejection_code != Code.OK, "A rejection must use a non-OK code.")
	return ActionValidationResult.new(rejection_code, rejection_message)
