class_name RngStreamFactory
extends RefCounted

const HASH_MODULUS: int = 2147483647
const HASH_MULTIPLIER: int = 31
const HUMAN_AGENT_ID: StringName = &"human"
const TOURNAMENT_CONSTRUCTION_STREAM_ID := "tournament_construction"
const SEAT_PROFILE_ASSIGNMENT_STREAM_ID := "seat_profile_assignment"
const DECK_STREAM_ID := "deck"
const INITIAL_BUTTON_STREAM_ID := "initial_button"
const TRACE_SAMPLING_STREAM_ID := "trace_sampling"

var _time_seed_provider: Callable


func _init(time_seed_provider: Callable = Callable()) -> void:
	_time_seed_provider = time_seed_provider


func create(config: ResolvedTournamentConfig) -> RngStreams:
	assert(config != null, "A resolved tournament configuration is required.")

	var effective_seed := _resolve_effective_seed(config.rng_seed)
	var stream_ids: PackedStringArray = [
		TOURNAMENT_CONSTRUCTION_STREAM_ID,
		SEAT_PROFILE_ASSIGNMENT_STREAM_ID,
		DECK_STREAM_ID,
		INITIAL_BUTTON_STREAM_ID,
		TRACE_SAMPLING_STREAM_ID,
	]
	var seat_agents: Dictionary[int, StringName] = config.seat_agents

	for seat: int in range(config.player_count):
		if seat_agents[seat] != HUMAN_AGENT_ID:
			stream_ids.append(bot_stream_id(seat))

	return create_named(effective_seed, stream_ids)


func create_named(effective_seed: int, stream_ids: PackedStringArray) -> RngStreams:
	var streams: Dictionary[String, RandomNumberGenerator] = {}
	var stream_seeds: Dictionary[String, int] = {}
	for stream_id: String in stream_ids:
		if stream_id.is_empty() or streams.has(stream_id):
			continue
		var derived_seed := _derive_seed(effective_seed, stream_id)
		streams[stream_id] = _create_stream_from_seed(derived_seed)
		stream_seeds[stream_id] = derived_seed
	return RngStreams.new(effective_seed, streams, stream_seeds)


static func bot_stream_id(seat: int) -> String:
	return "bot:%d" % seat


func _resolve_effective_seed(configured_seed: int) -> int:
	if configured_seed != 0:
		return configured_seed

	var time_seed: int
	if _time_seed_provider.is_valid():
		time_seed = int(_time_seed_provider.call())
	else:
		var unix_microseconds := int(Time.get_unix_time_from_system() * 1_000_000.0)
		time_seed = unix_microseconds ^ Time.get_ticks_usec()

	if time_seed == 0:
		return 1
	return time_seed


func _create_stream_from_seed(derived_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = derived_seed
	return rng


func _derive_seed(effective_seed: int, stream_id: String) -> int:
	var derived_seed: int = effective_seed % HASH_MODULUS
	if derived_seed < 0:
		derived_seed += HASH_MODULUS
	if derived_seed == 0:
		derived_seed = 1

	for character_byte: int in stream_id.to_utf8_buffer():
		derived_seed = (derived_seed * HASH_MULTIPLIER + character_byte) % HASH_MODULUS

	if derived_seed == 0:
		return 1
	return derived_seed
