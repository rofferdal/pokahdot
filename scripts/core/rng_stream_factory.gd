class_name RngStreamFactory
extends RefCounted

const HASH_MODULUS: int = 2147483647
const HASH_MULTIPLIER: int = 31
const HUMAN_AGENT_ID: StringName = &"human"

var _time_seed_provider: Callable


func _init(time_seed_provider: Callable = Callable()) -> void:
	_time_seed_provider = time_seed_provider


func create(config: ResolvedTournamentConfig) -> RngStreams:
	assert(config != null, "A resolved tournament configuration is required.")

	var effective_seed := _resolve_effective_seed(config.rng_seed)
	var deck_rng := _create_stream(effective_seed, "deck")
	var initial_button_rng := _create_stream(effective_seed, "initial_button")
	var bot_rngs: Dictionary[int, RandomNumberGenerator] = {}
	var seat_agents: Dictionary[int, StringName] = config.seat_agents

	for seat: int in range(config.player_count):
		if seat_agents[seat] != HUMAN_AGENT_ID:
			bot_rngs[seat] = _create_stream(effective_seed, "bot:%d" % seat)

	return RngStreams.new(effective_seed, deck_rng, initial_button_rng, bot_rngs)


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


func _create_stream(effective_seed: int, stream_id: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _derive_seed(effective_seed, stream_id)
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
