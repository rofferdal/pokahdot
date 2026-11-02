extends "res://tests/support/poker_gut_test.gd"


func test_factory_preserves_selected_blind_mode_through_an_actual_level_transition() -> void:
	for aggressive: bool in [false, true]:
		var regime := (
			SimulationRegime
			. new(
				&"progression",
				2,
				10000,
				5,
				10,
				(
					SimulationRegime.AGGRESSIVE_PROGRESSION
					if aggressive
					else SimulationRegime.STANDARD_PROGRESSION
				),
			)
		)
		var profiles := _random_profiles()
		for profile: BotProfile in profiles.values():
			var parameters := profile.parameters as RandomDecisionModelParameters
			parameters.fold_weight = 0
			parameters.passive_weight = 1
			parameters.aggressive_weight = 0
		var creation := SimulationMatchFactory.new().create(
			regime.resolve(901).get_config(), profiles
		)
		assert_true(creation.is_ok(), str(creation.errors))
		var match_instance := creation.match_instance
		var result := match_instance.start()
		for hand: int in range(1, 11):
			while result.status in [StepResult.Status.YIELDED, StepResult.Status.PREFLOP_COMPLETE]:
				result = match_instance.advance_until_blocked()
			assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
			assert_eq(match_instance.get_view_for(0).hand_number, hand)
			assert_eq(match_instance.get_view_for(0).big_blind, 10)
			if hand < 10:
				result = match_instance.advance_until_blocked()
		result = match_instance.advance_until_blocked(1)
		assert_ne(result.status, StepResult.Status.ERROR)
		var next := match_instance.get_view_for(0)
		assert_eq(next.hand_number, 11)
		assert_eq(next.blind_level, 2)
		assert_eq(next.big_blind, 18 if aggressive else 14)


func test_factory_creates_an_all_bot_match_from_profile_snapshots() -> void:
	var profiles := _random_profiles()
	var creation := SimulationMatchFactory.new().create(_product_config(), profiles)
	profiles[0].profile_id = &"changed_after_construction"
	(profiles[0].parameters as RandomDecisionModelParameters).passive_weight = 0

	assert_true(creation.is_ok())
	assert_eq(creation.effective_seed, 901)
	assert_eq(creation.rng_algorithm_version, RngStreamFactory.ALGORITHM_VERSION)
	assert_true(creation.stream_seeds.has(RngStreamFactory.TOURNAMENT_CONSTRUCTION_STREAM_ID))
	assert_true(creation.stream_seeds.has(RngStreamFactory.SEAT_PROFILE_ASSIGNMENT_STREAM_ID))
	assert_true(creation.stream_seeds.has(RngStreamFactory.TRACE_SAMPLING_STREAM_ID))
	assert_ne(creation.match_instance.start().status, StepResult.Status.ERROR)
	assert_false(creation.match_instance.get_view_for(0).seats[0].is_human)
	assert_false(creation.match_instance.get_view_for(0).seats[1].is_human)


func test_factory_can_select_legacy_rng_derivation_for_replay() -> void:
	var rng_factory := RngStreamFactory.new(Callable(), RngStreamFactory.LEGACY_ALGORITHM_VERSION)
	var creation := SimulationMatchFactory.new(null, rng_factory).create(
		_product_config(), _random_profiles()
	)

	assert_true(creation.is_ok())
	assert_eq(creation.rng_algorithm_version, RngStreamFactory.LEGACY_ALGORITHM_VERSION)
	assert_eq(creation.stream_seeds[RngStreamFactory.DECK_STREAM_ID], 835171758)


func test_factory_rejects_missing_or_invalid_profiles() -> void:
	var missing := SimulationMatchFactory.new().create(
		_product_config(), {0: _random_profile(&"one")}
	)
	assert_false(missing.is_ok())
	assert_has(missing.errors, "Every simulation seat must have one bot profile.")

	var invalid_profile := _random_profile(&"invalid")
	(invalid_profile.parameters as RandomDecisionModelParameters).fold_weight = 0
	(invalid_profile.parameters as RandomDecisionModelParameters).passive_weight = 0
	(invalid_profile.parameters as RandomDecisionModelParameters).aggressive_weight = 0
	var invalid := SimulationMatchFactory.new().create(
		_product_config(), {0: invalid_profile, 1: _random_profile(&"valid")}
	)
	assert_false(invalid.is_ok())
	assert_true(invalid.errors[0].contains("At least one random action weight"))


func test_runner_rejects_a_human_wait_state_without_using_input() -> void:
	var human_match := (
		TournamentMatch
		. new(
			_product_config(),
			{0: HumanAgent.new(), 1: RandomAgent.new(_rng(41))},
		)
	)

	var result := SimulationMatchFactory.new().run_to_completion(human_match)

	assert_eq(result.status, StepResult.Status.ERROR)
	assert_true(result.message.contains("cannot wait for human"))


func _product_config() -> ResolvedTournamentConfig:
	return ResolvedTournamentConfig.new(
		2, 30, 5, 10, 901, &"single_table", {0: &"human", 1: &"random"}
	)


func _random_profiles() -> Dictionary[int, BotProfile]:
	return {0: _random_profile(&"first"), 1: _random_profile(&"second")}


func _random_profile(profile_id: StringName) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = profile_id
	profile.model_id = &"random"
	profile.parameters = RandomDecisionModelParameters.new()
	return profile


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
