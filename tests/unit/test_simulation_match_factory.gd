extends "res://tests/support/poker_gut_test.gd"


func test_factory_creates_an_all_bot_match_from_profile_snapshots() -> void:
	var profiles := _random_profiles()
	var creation := SimulationMatchFactory.new().create(_product_config(), profiles)
	profiles[0].profile_id = &"changed_after_construction"
	(profiles[0].parameters as RandomDecisionModelParameters).passive_weight = 0

	assert_true(creation.is_ok())
	assert_eq(creation.effective_seed, 901)
	assert_true(creation.stream_seeds.has(RngStreamFactory.TOURNAMENT_CONSTRUCTION_STREAM_ID))
	assert_true(creation.stream_seeds.has(RngStreamFactory.SEAT_PROFILE_ASSIGNMENT_STREAM_ID))
	assert_true(creation.stream_seeds.has(RngStreamFactory.TRACE_SAMPLING_STREAM_ID))
	assert_ne(creation.match_instance.start().status, StepResult.Status.ERROR)
	assert_false(creation.match_instance.get_view_for(0).seats[0].is_human)
	assert_false(creation.match_instance.get_view_for(0).seats[1].is_human)


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
