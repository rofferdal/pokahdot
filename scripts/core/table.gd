class_name Table
extends RefCounted

## Owns fixed seats and clockwise position traversal for a tournament table.

const NO_SEAT: int = -1

var small_blind: int
var big_blind: int
var button_seat: int = NO_SEAT
var players: Array[Player]:
	get:
		return _players.duplicate()

var _players: Array[Player] = []


func _init(table_players: Array[Player], small_blind_amount: int, big_blind_amount: int) -> void:
	assert(table_players.size() >= 2, "A table requires at least two players.")
	assert(small_blind_amount > 0, "The small blind must be positive.")
	assert(
		big_blind_amount >= small_blind_amount, "The big blind must be at least the small blind."
	)
	_players = table_players.duplicate()
	small_blind = small_blind_amount
	big_blind = big_blind_amount
	_validate_seats()


func active_seats() -> Array[int]:
	var result: Array[int] = []
	for player: Player in _players:
		if not player.busted:
			result.append(player.seat)
	return result


func active_player_count() -> int:
	return active_seats().size()


func set_blinds(small_blind_amount: int, big_blind_amount: int) -> void:
	assert(small_blind_amount > 0, "The small blind must be positive.")
	assert(
		big_blind_amount >= small_blind_amount, "The big blind must be at least the small blind."
	)
	small_blind = small_blind_amount
	big_blind = big_blind_amount


func get_player(seat: int) -> Player:
	if seat < 0 or seat >= _players.size():
		return null
	return _players[seat]


func next_active_seat(from_seat: int) -> int:
	if active_player_count() == 0:
		return NO_SEAT
	for offset: int in range(1, _players.size() + 1):
		var candidate: int = posmod(from_seat + offset, _players.size())
		if not _players[candidate].busted:
			return candidate
	return NO_SEAT


func choose_initial_button(rng: RandomNumberGenerator) -> int:
	assert(rng != null, "A random number generator is required.")
	var seats: Array[int] = active_seats()
	if seats.is_empty():
		button_seat = NO_SEAT
	else:
		button_seat = seats[rng.randi_range(0, seats.size() - 1)]
	return button_seat


func advance_button() -> int:
	button_seat = next_active_seat(button_seat)
	return button_seat


func small_blind_seat() -> int:
	if active_player_count() == 2:
		return button_seat
	return next_active_seat(button_seat)


func big_blind_seat() -> int:
	return next_active_seat(small_blind_seat())


func first_to_act_preflop() -> int:
	if active_player_count() == 2:
		return button_seat
	return next_active_seat(big_blind_seat())


func first_to_act_postflop() -> int:
	return next_active_seat(button_seat)


func first_to_receive_card() -> int:
	return small_blind_seat()


func _validate_seats() -> void:
	for expected_seat: int in range(_players.size()):
		assert(_players[expected_seat] != null, "Table players cannot be null.")
		assert(
			_players[expected_seat].seat == expected_seat,
			"Players must be ordered in contiguous seats starting at zero.",
		)
