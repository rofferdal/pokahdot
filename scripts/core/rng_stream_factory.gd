class_name RngStreamFactory
extends RefCounted

const HASH_MODULUS: int = 2147483647
const HASH_MULTIPLIER: int = 31
const LEGACY_ALGORITHM_VERSION := "named_stream_v1"
const ALGORITHM_VERSION := "named_stream_sha256_v2"
const HASH_DOMAIN := "pokahdot:rng-stream:sha256:v2"
const HUMAN_AGENT_ID: StringName = &"human"
const TOURNAMENT_CONSTRUCTION_STREAM_ID := "tournament_construction"
const SEAT_PROFILE_ASSIGNMENT_STREAM_ID := "seat_profile_assignment"
const DECK_STREAM_ID := "deck"
const INITIAL_BUTTON_STREAM_ID := "initial_button"
const TRACE_SAMPLING_STREAM_ID := "trace_sampling"

var _time_seed_provider: Callable
var _algorithm_version: String


func _init(
	time_seed_provider: Callable = Callable(),
	algorithm_version: String = LEGACY_ALGORITHM_VERSION,
) -> void:
	assert(is_supported_algorithm(algorithm_version), "The RNG stream algorithm is unsupported.")
	_time_seed_provider = time_seed_provider
	_algorithm_version = algorithm_version


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
	return RngStreams.new(effective_seed, streams, stream_seeds, _algorithm_version)


static func is_supported_algorithm(algorithm_version: String) -> bool:
	return algorithm_version in [LEGACY_ALGORITHM_VERSION, ALGORITHM_VERSION]


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
	if _algorithm_version == LEGACY_ALGORITHM_VERSION:
		return _derive_legacy_seed(effective_seed, stream_id)
	return _derive_sha256_seed(effective_seed, stream_id)


func _derive_legacy_seed(effective_seed: int, stream_id: String) -> int:
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


func _derive_sha256_seed(effective_seed: int, stream_id: String) -> int:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(HASH_DOMAIN.to_utf8_buffer())
	context.update(PackedByteArray([0]))
	context.update(String.num_int64(effective_seed).to_utf8_buffer())
	context.update(PackedByteArray([0]))
	context.update(stream_id.to_utf8_buffer())
	var digest := context.finish()
	# Fold the first digest bytes into a positive 63-bit seed without integer overflow.
	var derived_seed: int = digest[0] & 0x7f
	for index: int in range(1, 8):
		derived_seed = derived_seed * 256 + digest[index]
	return 1 if derived_seed == 0 else derived_seed
