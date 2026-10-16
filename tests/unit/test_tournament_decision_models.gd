extends "res://tests/support/poker_gut_test.gd"


func test_tight_passive_parameter_boundaries_and_default_profile() -> void:
	var parameters := TightPassiveDecisionModelParameters.new()
	parameters.minimum_preflop_high_rank = 2
	parameters.raise_frequency = 0
	assert_true(parameters.validate().is_empty())
	parameters.minimum_preflop_high_rank = 15
	assert_false(parameters.validate().is_empty())

	var profile := load("res://resources/bot_profiles/tight_passive_default.tres") as BotProfile
	assert_eq(profile.profile_id, &"tight_passive_default")
	assert_eq(profile.model_id, &"tight_passive")


func test_loose_aggressive_parameter_boundaries_and_default_profile() -> void:
	var parameters := LooseAggressiveDecisionModelParameters.new()
	parameters.fold_frequency = 0
	parameters.aggression_frequency = 100
	assert_true(parameters.validate().is_empty())
	parameters.aggression_frequency = 101
	assert_false(parameters.validate().is_empty())

	var profile := load("res://resources/bot_profiles/loose_aggressive_default.tres") as BotProfile
	assert_eq(profile.profile_id, &"loose_aggressive_default")
	assert_eq(profile.model_id, &"loose_aggressive")


func test_models_only_return_legal_actions_and_wagers() -> void:
	var view := _view_for_actor()
	var tight := TightPassiveDecisionModel.new()
	var loose := LooseAggressiveDecisionModel.new()
	assert_true(tight.configure(TightPassiveDecisionModelParameters.new(), _rng(1)).is_empty())
	assert_true(loose.configure(LooseAggressiveDecisionModelParameters.new(), _rng(2)).is_empty())

	for model: DecisionModel in [tight, loose]:
		for _index: int in range(50):
			var action: PlayerAction = model.choose_action(view)
			assert_has(view.legal_actions, action.kind)
			if action.has_wager_amount():
				assert_between(action.amount, view.minimum_wager_total, view.maximum_wager_total)


func test_same_model_uses_independent_profiles_and_rng_streams_per_seat() -> void:
	var registry := DecisionModelRegistry.new()
	assert_true(
		registry.register_model(
			&"loose_aggressive",
			LooseAggressiveDecisionModel,
			LooseAggressiveDecisionModelParameters
		)
	)
	var first_profile := LooseAggressiveDecisionModelParameters.new()
	first_profile.aggression_frequency = 0
	var second_profile := LooseAggressiveDecisionModelParameters.new()
	second_profile.aggression_frequency = 100
	var streams := RngStreamFactory.new().create(_config())
	var factory := AgentFactory.new(registry)

	var first := factory.create_bot(_profile(&"first", first_profile), streams.get_bot_rng(1))
	var second := factory.create_bot(_profile(&"second", second_profile), streams.get_bot_rng(2))

	assert_true(first.is_ok())
	assert_true(second.is_ok())
	var first_action: PlayerAction = first.agent.choose_action(_view_for_check())
	var second_action: PlayerAction = second.agent.choose_action(_view_for_check())
	assert_ne(first_action.kind, second_action.kind)


func _profile(profile_id: StringName, parameters: DecisionModelParameters) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = profile_id
	profile.model_id = &"loose_aggressive"
	profile.parameters = parameters
	return profile


func _config() -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 456
	var overrides := StartupOverrides.new()
	overrides.set_player_count(3)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _view_for_actor() -> GameView:
	var players: Array[Player] = []
	for seat: int in range(3):
		players.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	players[1].commit_chips(5)
	players[2].commit_chips(10)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	return GameView.for_preflop(table, 0, BettingRound.new(table, 0, 10), PotManager.new(), [])


func _view_for_check() -> GameView:
	var players: Array[Player] = []
	for seat: int in range(2):
		players.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	return GameView.for_preflop(table, 0, BettingRound.new(table, 0), PotManager.new(), [])
