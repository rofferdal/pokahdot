extends "res://tests/support/poker_gut_test.gd"


func test_same_nonzero_seed_produces_same_stream_sequences() -> void:
	var first: RngStreams = _create_streams(123456)
	var second: RngStreams = _create_streams(123456)

	assert_eq(first.effective_seed, 123456)
	assert_eq(second.effective_seed, 123456)
	assert_eq(
		_capture_sequence(first.get_deck_rng()),
		_capture_sequence(second.get_deck_rng()),
	)
	assert_eq(
		_capture_sequence(first.get_initial_button_rng()),
		_capture_sequence(second.get_initial_button_rng()),
	)
	for seat: int in first.get_bot_seats():
		assert_eq(
			_capture_sequence(first.get_bot_rng(seat)),
			_capture_sequence(second.get_bot_rng(seat)),
			"bot seat %d" % seat,
		)


func test_named_streams_are_distinct_instances_and_sequences() -> void:
	var streams: RngStreams = _create_streams(123456)
	var deck_rng: RandomNumberGenerator = streams.get_deck_rng()
	var button_rng: RandomNumberGenerator = streams.get_initial_button_rng()
	var bot_rng: RandomNumberGenerator = streams.get_bot_rng(1)

	assert_ne(deck_rng, button_rng)
	assert_ne(deck_rng, bot_rng)
	assert_ne(button_rng, bot_rng)
	assert_ne(_capture_sequence(deck_rng), _capture_sequence(button_rng))
	assert_ne(_capture_sequence(deck_rng), _capture_sequence(bot_rng))
	assert_ne(_capture_sequence(button_rng), _capture_sequence(bot_rng))
	assert_ne(streams.get_tournament_construction_rng(), streams.get_seat_profile_assignment_rng())
	assert_ne(streams.get_seat_profile_assignment_rng(), streams.get_trace_sampling_rng())


func test_named_stream_seed_identities_are_complete_and_reproducible() -> void:
	var first: RngStreams = _create_streams(123456, 4)
	var second: RngStreams = _create_streams(123456, 4)
	var identities: Dictionary[String, int] = first.get_stream_seeds()

	for stream_id: String in [
		RngStreamFactory.TOURNAMENT_CONSTRUCTION_STREAM_ID,
		RngStreamFactory.SEAT_PROFILE_ASSIGNMENT_STREAM_ID,
		RngStreamFactory.DECK_STREAM_ID,
		RngStreamFactory.INITIAL_BUTTON_STREAM_ID,
		RngStreamFactory.TRACE_SAMPLING_STREAM_ID,
		RngStreamFactory.bot_stream_id(1),
		RngStreamFactory.bot_stream_id(2),
		RngStreamFactory.bot_stream_id(3),
	]:
		assert_true(identities.has(stream_id), stream_id)
		assert_eq(identities[stream_id], second.get_stream_seed(stream_id), stream_id)
		assert_ne(identities[stream_id], 0, stream_id)


func test_heavy_deck_consumption_does_not_change_bot_streams() -> void:
	var consumed_streams: RngStreams = _create_streams(123456)
	var untouched_streams: RngStreams = _create_streams(123456)
	var deck_rng: RandomNumberGenerator = consumed_streams.get_deck_rng()

	for _index: int in range(10000):
		deck_rng.randi()

	for seat: int in consumed_streams.get_bot_seats():
		assert_eq(
			_capture_sequence(consumed_streams.get_bot_rng(seat)),
			_capture_sequence(untouched_streams.get_bot_rng(seat)),
			"bot seat %d" % seat,
		)


func test_bot_stream_derivation_is_seat_stable_and_retrieval_order_independent() -> void:
	var first: RngStreams = _create_streams(123456)
	var second: RngStreams = _create_streams(123456)
	var first_seat_one: Array[int] = _capture_sequence(first.get_bot_rng(1))
	var first_seat_three: Array[int] = _capture_sequence(first.get_bot_rng(3))
	var first_seat_five: Array[int] = _capture_sequence(first.get_bot_rng(5))
	var second_seat_five: Array[int] = _capture_sequence(second.get_bot_rng(5))
	var second_seat_three: Array[int] = _capture_sequence(second.get_bot_rng(3))
	var second_seat_one: Array[int] = _capture_sequence(second.get_bot_rng(1))

	assert_eq(first_seat_one, second_seat_one, "bot seat 1")
	assert_eq(first_seat_three, second_seat_three, "bot seat 3")
	assert_eq(first_seat_five, second_seat_five, "bot seat 5")


func test_only_active_bot_seats_have_streams() -> void:
	var streams: RngStreams = _create_streams(123456, 4)

	assert_eq(streams.get_bot_seats(), [1, 2, 3])
	assert_null(streams.get_bot_rng(0))
	assert_null(streams.get_bot_rng(4))
	for seat: int in streams.get_bot_seats():
		assert_not_null(streams.get_bot_rng(seat), "bot seat %d" % seat)


func test_zero_rng_seed_uses_injected_time_seed_provider() -> void:
	var factory: RngStreamFactory = RngStreamFactory.new(func() -> int: return 987654321)
	var streams: RngStreams = factory.create(_resolve_config(0))

	assert_eq(streams.effective_seed, 987654321)


func test_zero_time_seed_provider_still_produces_nonzero_effective_seed() -> void:
	var factory: RngStreamFactory = RngStreamFactory.new(func() -> int: return 0)
	var streams: RngStreams = factory.create(_resolve_config(0))

	assert_ne(streams.effective_seed, 0)


func _create_streams(seed: int, player_count: int = 6) -> RngStreams:
	var factory: RngStreamFactory = RngStreamFactory.new()
	return factory.create(_resolve_config(seed, player_count))


func _resolve_config(seed: int, player_count: int = 6) -> ResolvedTournamentConfig:
	var defaults: TournamentConfig = TournamentConfig.new()
	defaults.rng_seed = seed
	defaults.player_count = player_count
	var resolution: ConfigResolution = ConfigResolver.new().resolve(defaults, null)
	assert_true(resolution.is_ok())
	return resolution.get_config()


func _capture_sequence(rng: RandomNumberGenerator) -> Array[int]:
	var sequence: Array[int] = []
	for _index: int in range(8):
		sequence.append(rng.randi())
	return sequence
