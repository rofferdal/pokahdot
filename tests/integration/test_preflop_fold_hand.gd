extends "res://tests/support/poker_gut_test.gd"


func test_seeded_match_completes_preflop_when_all_opponents_fold() -> void:
	var match_instance := TournamentMatch.new(_config(), _agents())

	var result: StepResult = match_instance.start()
	if result.status == StepResult.Status.WAITING_FOR_HUMAN:
		result = match_instance.submit_human_action(PlayerAction.raise_to(20))

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	var view: GameView = match_instance.get_view_for(0)
	assert_eq(view.seats[0].stack + view.seats[1].stack + view.seats[2].stack, 3000)
	assert_eq(view.hero_hole_cards.size(), 2)
	var events: Array[DomainEvent] = match_instance.get_events()
	assert_eq(events[-2].kind, DomainEvent.Kind.POT_AWARDED)
	assert_eq(events[-1].kind, DomainEvent.Kind.HAND_COMPLETED)


func _config() -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 4242
	var overrides := StartupOverrides.new()
	overrides.set_player_count(3)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _agents() -> Dictionary[int, Agent]:
	return {
		0: HumanAgent.new(),
		1: ScriptedAgent.new([PlayerAction.fold_action()]),
		2: ScriptedAgent.new([PlayerAction.fold_action()]),
	}
