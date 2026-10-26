class_name PotWagerTargetResult
extends RefCounted

## Typed result for a total wager target. `total` is never an additional-chip amount.

var total: int
var available: bool
var reason: StringName


func _init(result_total: int, is_available: bool, result_reason: StringName) -> void:
	total = result_total
	available = is_available
	reason = result_reason
