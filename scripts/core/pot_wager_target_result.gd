class_name PotWagerTargetResult
extends RefCounted

## Typed Pot-shortcut result with distinct display contribution and core wager total.

var contribution: int
var wager_total: int
var available: bool
var reason: StringName


func _init(
	result_contribution: int,
	result_wager_total: int,
	is_available: bool,
	result_reason: StringName,
) -> void:
	contribution = result_contribution
	wager_total = result_wager_total
	available = is_available
	reason = result_reason
