extends "res://tests/support/poker_gut_test.gd"

const CliMatchFactoryScript = preload("res://scripts/cli/cli_match_factory.gd")


func test_seeded_short_stack_tournament_conserves_chips_until_one_winner_remains() -> void:
	var match_instance := TournamentMatch.new(_config(), _agents())
	var result: StepResult = match_instance.start()
	var completed_hands: int = 0
	var observed_buttons: Array[int] = []
	var saw_skipped_busted_seat: bool = false
	var saw_heads_up_transition: bool = false

	for _transition: int in range(80):
		if result.status == StepResult.Status.WAITING_FOR_HUMAN:
			result = match_instance.submit_human_action(PlayerAction.fold_action())
		if result.status == StepResult.Status.HAND_COMPLETED:
			completed_hands += 1
			var view: GameView = match_instance.get_view_for(0)
			assert_chip_total(_stacks(view), 30)
			observed_buttons.append(view.button_seat)
			var completed_hand_button: int = view.button_seat
			var active_seats_after_completion: Array[int] = view.active_seats
			result = match_instance.advance_until_blocked()
			if result.status != StepResult.Status.TOURNAMENT_FINISHED:
				var next_hand_view: GameView = match_instance.get_view_for(0)
				var expected_button: int = _next_active_seat(
					completed_hand_button, active_seats_after_completion, 3
				)
				assert_eq(next_hand_view.button_seat, expected_button)
				if next_hand_view.active_seats.size() < active_seats_after_completion.size():
					saw_skipped_busted_seat = true
				if next_hand_view.active_seats.size() == 2:
					saw_heads_up_transition = true
					assert_eq(next_hand_view.small_blind_seat, next_hand_view.button_seat)
					assert_eq(
						next_hand_view.big_blind_seat,
						_next_active_seat(
							next_hand_view.button_seat, next_hand_view.active_seats, 3
						)
					)
		if result.status == StepResult.Status.TOURNAMENT_FINISHED:
			break

	assert_eq(result.status, StepResult.Status.TOURNAMENT_FINISHED)
	assert_eq(match_instance.end_reason, &"winner")
	assert_true(match_instance.winner_seat >= 0)
	assert_true(completed_hands >= 2)
	assert_true(observed_buttons.size() >= 2)
	assert_true(saw_skipped_busted_seat)
	assert_true(saw_heads_up_transition)
	assert_eq(match_instance.get_view_for(0).active_seats.size(), 1)
	assert_eq(match_instance.winner_seat, match_instance.get_view_for(0).active_seats[0])


func test_next_hand_moves_button_and_blinds_clockwise_before_heads_up() -> void:
	var match_instance := TournamentMatch.new(_three_player_config(), _folding_agents())
	var result: StepResult = match_instance.start()
	var first_view: GameView = match_instance.get_view_for(0)
	assert_eq(first_view.active_seats, [0, 1, 2])

	if result.status == StepResult.Status.WAITING_FOR_HUMAN:
		result = match_instance.submit_human_action(PlayerAction.fold_action())
	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)

	result = match_instance.advance_until_blocked()
	var second_view: GameView = match_instance.get_view_for(0)
	var expected_button: int = posmod(first_view.button_seat + 1, 3)
	assert_ne(result.status, StepResult.Status.ERROR)
	assert_eq(second_view.hand_number, 2)
	assert_eq(second_view.button_seat, expected_button)
	assert_eq(second_view.small_blind_seat, posmod(expected_button + 1, 3))
	assert_eq(second_view.big_blind_seat, posmod(expected_button + 2, 3))


func test_short_stack_startup_preset_keeps_resolved_table_values_across_hands() -> void:
	var io := FakeCliIO.new()
	io.queue_line("short-stack")
	var startup_result: StartupPromptResult = StartupConfigPrompt.new(io).run(
		TournamentConfig.new()
	)
	assert_true(startup_result.is_ready())
	var match_instance := TournamentMatch.new(startup_result.config, _folding_agents())
	var result: StepResult = match_instance.start()
	_assert_short_stack_view(match_instance.get_view_for(0))
	if result.status == StepResult.Status.WAITING_FOR_HUMAN:
		result = match_instance.submit_human_action(PlayerAction.fold_action())
	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	result = match_instance.advance_until_blocked()
	for _transition: int in range(3):
		if result.status != StepResult.Status.HAND_COMPLETED:
			break
		result = match_instance.advance_until_blocked()

	assert_ne(result.status, StepResult.Status.ERROR)
	assert_ne(result.status, StepResult.Status.TOURNAMENT_FINISHED)
	_assert_short_stack_view(match_instance.get_view_for(0))


func test_seeded_standard_agent_tournament_smoke_conserves_chips_after_every_hand() -> void:
	var config := _full_smoke_config()
	var factory := CliMatchFactoryScript.new()
	var match_instance: TournamentMatch = factory.create(config)
	var result: StepResult = match_instance.start()
	var completed_hands: int = 0
	var total_chips: int = config.player_count * config.starting_stack

	for _transition: int in range(400):
		if result.status == StepResult.Status.WAITING_FOR_HUMAN:
			result = match_instance.submit_human_action(PlayerAction.fold_action())
		if result.status == StepResult.Status.HAND_COMPLETED:
			completed_hands += 1
			assert_chip_total(
				_stacks(match_instance.get_view_for(factory.human_seat(config))), total_chips
			)
			result = match_instance.advance_until_blocked()
		if result.status == StepResult.Status.TOURNAMENT_FINISHED:
			break

	assert_eq(result.status, StepResult.Status.TOURNAMENT_FINISHED)
	assert_eq(match_instance.end_reason, &"winner")
	assert_true(completed_hands > 0)
	assert_chip_total(_stacks(match_instance.get_view_for(factory.human_seat(config))), total_chips)


func test_quit_before_during_and_between_hands_has_no_winner() -> void:
	var before_start := TournamentMatch.new(_three_player_config(), _folding_agents())
	_assert_player_quit(before_start, before_start.request_quit())

	var during_hand := TournamentMatch.new(_three_player_config(), _folding_agents())
	during_hand.start()
	_assert_player_quit(during_hand, during_hand.request_quit())

	var between_hands := TournamentMatch.new(_three_player_config(), _folding_agents())
	var result: StepResult = between_hands.start()
	if result.status == StepResult.Status.WAITING_FOR_HUMAN:
		result = between_hands.submit_human_action(PlayerAction.fold_action())
	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	var hand_number: int = between_hands.get_view_for(0).hand_number
	_assert_player_quit(between_hands, between_hands.request_quit())
	assert_eq(between_hands.get_view_for(0).hand_number, hand_number)


func _config() -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 991
	var overrides := StartupOverrides.new()
	overrides.set_player_count(3)
	overrides.set_starting_stack(10)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _three_player_config() -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 345
	var overrides := StartupOverrides.new()
	overrides.set_player_count(3)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _full_smoke_config() -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 20261016
	var overrides := StartupOverrides.new()
	overrides.set_player_count(3)
	overrides.set_starting_stack(20)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _agents() -> Dictionary[int, Agent]:
	return {
		0: HumanAgent.new(),
		1: ScriptedAgent.new([PlayerAction.fold_action()]),
		2: ScriptedAgent.new([PlayerAction.fold_action()]),
	}


func _folding_agents() -> Dictionary[int, Agent]:
	return {
		0: HumanAgent.new(),
		1: ScriptedAgent.new([PlayerAction.fold_action()]),
		2: ScriptedAgent.new([PlayerAction.fold_action()]),
	}


func _stacks(view: GameView) -> Array[int]:
	var stacks: Array[int] = []
	for seat: PlayerView in view.seats:
		stacks.append(seat.stack)
	return stacks


func _next_active_seat(from_seat: int, active_seats: Array[int], player_count: int) -> int:
	for offset: int in range(1, player_count + 1):
		var candidate: int = posmod(from_seat + offset, player_count)
		if candidate in active_seats:
			return candidate
	return Table.NO_SEAT


func _assert_short_stack_view(view: GameView) -> void:
	assert_eq(view.seats.size(), 3)
	assert_eq(view.seats[view.small_blind_seat].bet_this_round, 5)
	assert_eq(view.seats[view.big_blind_seat].bet_this_round, 10)


func _assert_player_quit(match_instance: TournamentMatch, result: StepResult) -> void:
	assert_eq(result.status, StepResult.Status.TOURNAMENT_FINISHED)
	assert_eq(match_instance.state, TournamentMatch.State.FINISHED)
	assert_eq(match_instance.end_reason, &"player_quit")
	assert_eq(match_instance.winner_seat, Table.NO_SEAT)
