class_name PotManager
extends RefCounted

## Records per-seat hand contributions and performs pot settlement.

var total_amount: int:
	get:
		return _total_amount
var contributions: Dictionary[int, int]:
	get:
		return _contributions.duplicate()

var _contributions: Dictionary[int, int] = {}
var _total_amount: int = 0


func record_contribution(seat: int, amount: int) -> bool:
	if seat < 0 or amount < 0 or amount > ChipStack.maximum_safe_credit(_total_amount):
		return false
	var previous: int = _contributions.get(seat, 0)
	if amount > ChipStack.maximum_safe_credit(previous):
		return false
	_contributions[seat] = previous + amount
	_total_amount += amount
	return true


func contribution_for(seat: int) -> int:
	return _contributions.get(seat, 0)


func award_single_winner(winner: Player) -> int:
	if winner == null or winner.folded or _total_amount == 0:
		return 0
	if not winner.award_chips(_total_amount):
		return 0
	var awarded: int = _total_amount
	clear()
	return awarded


func clear() -> void:
	_contributions.clear()
	_total_amount = 0
