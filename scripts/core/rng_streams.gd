class_name RngStreams
extends RefCounted

## Named random streams for one tournament.

var effective_seed: int:
	get:
		return _effective_seed

var _effective_seed: int
var _deck_rng: RandomNumberGenerator
var _initial_button_rng: RandomNumberGenerator
var _bot_rngs: Dictionary[int, RandomNumberGenerator]


func _init(
	stream_effective_seed: int,
	deck_rng: RandomNumberGenerator,
	initial_button_rng: RandomNumberGenerator,
	bot_rngs: Dictionary[int, RandomNumberGenerator],
) -> void:
	_effective_seed = stream_effective_seed
	_deck_rng = deck_rng
	_initial_button_rng = initial_button_rng
	_bot_rngs = bot_rngs.duplicate()


func get_deck_rng() -> RandomNumberGenerator:
	return _deck_rng


func get_initial_button_rng() -> RandomNumberGenerator:
	return _initial_button_rng


func get_bot_rng(seat: int) -> RandomNumberGenerator:
	return _bot_rngs.get(seat)


func get_bot_seats() -> Array[int]:
	var seats: Array[int] = []
	for seat: int in _bot_rngs:
		seats.append(seat)
	seats.sort()
	return seats
