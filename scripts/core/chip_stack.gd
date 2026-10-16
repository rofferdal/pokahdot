class_name ChipStack
extends RefCounted

## Owns a non-negative quantity of tournament chips.

var amount: int:
	get:
		return _amount

var _amount: int


func _init(initial_amount: int = 0) -> void:
	assert(initial_amount >= 0, "A chip stack cannot start with a negative amount.")
	_amount = initial_amount


func debit(requested_amount: int) -> int:
	if requested_amount <= 0:
		return 0

	var removed: int = mini(requested_amount, _amount)
	_amount -= removed
	return removed


func credit(added_amount: int) -> bool:
	if added_amount < 0 or added_amount > ChipStack.maximum_safe_credit(_amount):
		return false

	_amount += added_amount
	return true


static func maximum_safe_credit(current_amount: int) -> int:
	return (1 << 63) - 1 - current_amount
