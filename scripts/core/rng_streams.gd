class_name RngStreams
extends RefCounted

## Named random streams for one tournament.

var effective_seed: int:
	get:
		return _effective_seed

var _effective_seed: int
var _streams: Dictionary[String, RandomNumberGenerator]
var _stream_seeds: Dictionary[String, int]


func _init(
	stream_effective_seed: int,
	streams: Dictionary[String, RandomNumberGenerator],
	stream_seeds: Dictionary[String, int],
) -> void:
	_effective_seed = stream_effective_seed
	_streams = streams.duplicate()
	_stream_seeds = stream_seeds.duplicate()


func get_deck_rng() -> RandomNumberGenerator:
	return get_rng(RngStreamFactory.DECK_STREAM_ID)


func get_initial_button_rng() -> RandomNumberGenerator:
	return get_rng(RngStreamFactory.INITIAL_BUTTON_STREAM_ID)


func get_bot_rng(seat: int) -> RandomNumberGenerator:
	return get_rng(RngStreamFactory.bot_stream_id(seat))


func get_tournament_construction_rng() -> RandomNumberGenerator:
	return get_rng(RngStreamFactory.TOURNAMENT_CONSTRUCTION_STREAM_ID)


func get_seat_profile_assignment_rng() -> RandomNumberGenerator:
	return get_rng(RngStreamFactory.SEAT_PROFILE_ASSIGNMENT_STREAM_ID)


func get_trace_sampling_rng() -> RandomNumberGenerator:
	return get_rng(RngStreamFactory.TRACE_SAMPLING_STREAM_ID)


func get_rng(stream_id: String) -> RandomNumberGenerator:
	return _streams.get(stream_id)


func get_stream_seed(stream_id: String) -> int:
	return _stream_seeds.get(stream_id, 0)


func get_stream_seeds() -> Dictionary[String, int]:
	return _stream_seeds.duplicate()


func get_bot_seats() -> Array[int]:
	var seats: Array[int] = []
	for stream_id: String in _streams:
		if stream_id.begins_with("bot:"):
			seats.append(stream_id.trim_prefix("bot:").to_int())
	seats.sort()
	return seats
