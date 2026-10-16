class_name PotAward
extends RefCounted

## Immutable settlement record for one pot layer.

var pot_index: int:
	get:
		return _pot_index
var amount: int:
	get:
		return _amount
var winner_seats: Array[int]:
	get:
		return _winner_seats.duplicate()
var amounts_by_seat: Dictionary[int, int]:
	get:
		return _amounts_by_seat.duplicate()

var _winner_seats: Array[int]
var _amounts_by_seat: Dictionary[int, int]
var _pot_index: int
var _amount: int


func _init(
	award_pot_index: int,
	award_amount: int,
	award_winner_seats: Array[int],
	award_amounts_by_seat: Dictionary[int, int],
) -> void:
	_pot_index = award_pot_index
	_amount = award_amount
	_winner_seats = award_winner_seats.duplicate()
	_amounts_by_seat = award_amounts_by_seat.duplicate()
