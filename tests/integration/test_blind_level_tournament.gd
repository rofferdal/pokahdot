extends "res://tests/support/poker_gut_test.gd"


class BoundaryAgent:
	extends Agent
	var _contests_boundary: bool

	func _init(contests_boundary: bool) -> void:
		_contests_boundary = contests_boundary

	func choose_action(view: GameView) -> PlayerAction:
		if _contests_boundary and view.hand_number == 10:
			return PlayerAction.all_in_action()
		return PlayerAction.fold_action()


func test_elimination_at_level_boundary_sets_the_next_active_player_snapshot() -> void:
	for aggressive: bool in [false, true]:
		var defaults := TournamentConfig.new()
		defaults.rng_seed = 70215
		defaults.aggressive_blinds = aggressive
		var overrides := StartupOverrides.new().set_player_count(5).set_starting_stack(10000)
		var config := ConfigResolver.new().resolve(defaults, overrides).get_config()
		var agents: Dictionary[int, Agent] = {0: HumanAgent.new()}
		for seat: int in range(1, 5):
			agents[seat] = BoundaryAgent.new(seat == 1)
		var match_instance := TournamentMatch.new(config, agents)
		var result := match_instance.start()
		for hand: int in range(1, 11):
			for _action: int in range(20):
				if result.status != StepResult.Status.WAITING_FOR_HUMAN:
					break
				var action := (
					PlayerAction.all_in_action() if hand == 10 else PlayerAction.raise_to(30)
				)
				result = match_instance.submit_human_action(action)
			assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
			var completed := match_instance.get_view_for(0)
			assert_eq(completed.big_blind, 10)
			assert_eq(completed.blind_level, 1)
			assert_eq(completed.hand_number, hand)
			if hand < 10:
				assert_eq(completed.active_seats.size(), 5)
				result = match_instance.advance_until_blocked()
		var completed := match_instance.get_view_for(0)
		assert_eq(completed.active_seats.size(), 4)
		result = match_instance.advance_until_blocked()
		assert_ne(result.status, StepResult.Status.ERROR)
		var next := match_instance.get_view_for(0)
		assert_eq(next.blind_level, 2)
		assert_eq(next.big_blind, 18 if aggressive else 14)
		assert_eq(next.hands_until_next_level, 10)
		assert_eq(next.active_player_count_at_level_start, 4)


func test_tournament_applies_increased_blinds_only_on_the_next_hand() -> void:
	_assert_next_hand_blinds(false, 14)
	_assert_next_hand_blinds(true, 18)


func _assert_next_hand_blinds(aggressive: bool, expected_big_blind: int) -> void:
	var config := _config(aggressive)
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
			assert_eq(view.minimum_wager_total, view.big_blind * 2)
			result = match_instance.submit_human_action(PlayerAction.raise_to(view.big_blind * 3))
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
	assert_eq(next_view.small_blind, expected_big_blind / 2)
	assert_eq(next_view.big_blind, expected_big_blind)
	assert_eq(next_view.blind_level, 2)
	assert_eq(next_view.completed_hands_in_level, 0)
	assert_eq(next_view.hands_until_next_level, 10)
	var acting_view: GameView = match_instance.get_view_for(next_view.acting_seat)
	assert_eq(acting_view.minimum_wager_total, expected_big_blind * 2)


func _config(aggressive: bool = false) -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 70214
	defaults.aggressive_blinds = aggressive
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
