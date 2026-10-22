extends "res://tests/support/poker_gut_test.gd"


func test_seeded_all_bot_tournament_completes_without_human_input() -> void:
	var factory := SimulationMatchFactory.new()
	var creation := factory.create(_config(), {0: _profile(&"first"), 1: _profile(&"second")})

	assert_true(creation.is_ok())
	var result := factory.run_to_completion(creation.match_instance)

	assert_eq(result.status, StepResult.Status.TOURNAMENT_FINISHED)
	assert_eq(creation.match_instance.end_reason, &"winner")
	assert_true(creation.match_instance.winner_seat >= 0)
	assert_true(creation.match_instance.winner_seat <= 1)
	assert_false(creation.match_instance.get_view_for(0).seats[0].is_human)
	assert_false(creation.match_instance.get_view_for(0).seats[1].is_human)


func test_product_match_still_rejects_zero_human_agents() -> void:
	var match_instance := (
		TournamentMatch
		. new(
			_config(),
			{0: RandomAgent.new(_rng(1)), 1: RandomAgent.new(_rng(2))},
		)
	)

	var result := match_instance.start()

	assert_eq(result.status, StepResult.Status.ERROR)
	assert_true(result.message.contains("exactly one human"))


func _config() -> ResolvedTournamentConfig:
	return ResolvedTournamentConfig.new(
		2, 20, 5, 10, 5081, &"single_table", {0: &"random", 1: &"random"}
	)


func _profile(profile_id: StringName) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = profile_id
	profile.model_id = &"random"
	profile.parameters = RandomDecisionModelParameters.new()
	return profile


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
