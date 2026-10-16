extends "res://tests/support/poker_gut_test.gd"


func test_parameter_boundaries_and_all_zero_rejection() -> void:
	var parameters := RandomDecisionModelParameters.new()
	parameters.fold_weight = 0
	parameters.passive_weight = 0
	parameters.aggressive_weight = 0
	assert_false(parameters.validate().is_empty())

	parameters.aggressive_weight = 100
	assert_true(parameters.validate().is_empty())
	parameters.aggressive_weight = 101
	assert_false(parameters.validate().is_empty())


func test_same_seed_and_view_produce_same_decision_sequence() -> void:
	var view: GameView = _view_for_actor()
	var first: RandomDecisionModel = _model(9876)
	var second: RandomDecisionModel = _model(9876)
	var first_actions: Array[String] = []
	var second_actions: Array[String] = []

	for _index: int in range(20):
		first_actions.append(_action_signature(first.choose_action(view)))
		second_actions.append(_action_signature(second.choose_action(view)))

	assert_eq(first_actions, second_actions)


func test_every_random_decision_is_legal_and_wager_is_in_range() -> void:
	var view: GameView = _view_for_actor()
	var model: RandomDecisionModel = _model(1234)

	for _index: int in range(100):
		var action: PlayerAction = model.choose_action(view)
		assert_has(view.legal_actions, action.kind)
		if action.has_wager_amount():
			assert_between(action.amount, view.minimum_wager_total, view.maximum_wager_total)


func test_default_profile_and_random_agent_are_valid() -> void:
	var profile := load("res://resources/bot_profiles/random_default.tres") as BotProfile
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var agent := RandomAgent.new(rng)

	assert_not_null(profile)
	assert_eq(profile.profile_id, &"random_default")
	assert_eq(profile.model_id, &"random")
	assert_not_null(agent.choose_action(_view_for_actor()))


func _model(seed_value: int) -> RandomDecisionModel:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var model := RandomDecisionModel.new()
	assert_true(model.configure(RandomDecisionModelParameters.new(), rng).is_empty())
	return model


func _view_for_actor() -> GameView:
	var players: Array[Player] = []
	for seat: int in range(3):
		players.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	players[1].commit_chips(5)
	players[2].commit_chips(10)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var betting := BettingRound.new(table, 0, 10)
	return GameView.for_preflop(table, 0, betting, PotManager.new(), [])


func _action_signature(action: PlayerAction) -> String:
	return "%d:%d" % [action.kind, action.amount]
