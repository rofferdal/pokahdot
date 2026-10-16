class_name PotLayer
extends RefCounted

## Immutable snapshot of one main- or side-pot layer.

var amount: int:
	get:
		return _amount
var contribution_cap: int:
	get:
		return _contribution_cap
var contributor_seats: Array[int]:
	get:
		return _contributor_seats.duplicate()
var eligible_seats: Array[int]:
	get:
		return _eligible_seats.duplicate()

var _contributor_seats: Array[int]
var _eligible_seats: Array[int]
var _amount: int
var _contribution_cap: int


func _init(
	pot_amount: int,
	pot_contribution_cap: int,
	pot_contributor_seats: Array[int],
	pot_eligible_seats: Array[int],
) -> void:
	assert(pot_amount > 0, "A pot layer must contain chips.")
	_amount = pot_amount
	_contribution_cap = pot_contribution_cap
	_contributor_seats = pot_contributor_seats.duplicate()
	_eligible_seats = pot_eligible_seats.duplicate()
