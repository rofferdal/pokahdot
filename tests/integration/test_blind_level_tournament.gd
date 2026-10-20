extends "res://tests/support/poker_gut_test.gd"


func test_tournament_applies_increased_blinds_only_on_the_next_hand() -> void:
	var config := _config()
	var match_instance := TournamentMatch.new(config, _agents())
	var result: StepResult = match_instance.start()
	var initial_view: GameView = match_instance.get_view_for(0)
	assert_eq(initial_view.small_blind, 5)
	assert_eq(initial_view.big_blind, 10)
	assert_eq(initial_view.blind_level, 1)
	assert_eq(initial_view.hands_until_next_level, 10)

	var completed_hands: int = 0
	while completed_hands < 10:
		while result.status == StepResult.Status.WAITING_FOR_HUMAN:
			var view: GameView = match_instance.get_view_for(0)
			result = match_instance.submit_human_action(
				(
					PlayerAction.check_action()
					if PlayerAction.Kind.CHECK in view.legal_actions
					else PlayerAction.call_action()
				)
			)
		assert_ne(result.status, StepResult.Status.ERROR)
		if result.status == StepResult.Status.HAND_COMPLETED:
			completed_hands += 1
			var completed_view: GameView = match_instance.get_view_for(0)
			assert_eq(completed_view.hand_number, completed_hands)
			assert_eq(completed_view.small_blind, 5)
			assert_eq(completed_view.big_blind, 10)
		if completed_hands < 10:
			result = match_instance.advance_until_blocked()

	assert_eq(completed_hands, 10)
	assert_eq(match_instance.get_view_for(0).blind_level, 1)
	result = match_instance.advance_until_blocked()
	assert_ne(result.status, StepResult.Status.ERROR)
	var next_view: GameView = match_instance.get_view_for(0)
	assert_eq(next_view.hand_number, 11)
	assert_eq(next_view.small_blind, 7)
	assert_eq(next_view.big_blind, 14)
	assert_eq(next_view.blind_level, 2)
	assert_eq(next_view.completed_hands_in_level, 0)
	assert_eq(next_view.hands_until_next_level, 10)
	var acting_view: GameView = match_instance.get_view_for(next_view.acting_seat)
	assert_eq(acting_view.minimum_wager_total, 28)


func _config() -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 70214
	var overrides := StartupOverrides.new()
	overrides.set_player_count(3)
	overrides.set_starting_stack(10000)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _agents() -> Dictionary[int, Agent]:
	var folds: Array[PlayerAction] = []
	for _action: int in range(30):
		folds.append(PlayerAction.fold_action())
	return {
		0: HumanAgent.new(),
		1: ScriptedAgent.new(folds),
		2: ScriptedAgent.new(folds),
	}
