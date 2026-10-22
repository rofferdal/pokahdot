extends "res://tests/support/poker_gut_test.gd"


func test_match_rejects_incomplete_agent_configuration() -> void:
	var match_instance := TournamentMatch.new(_config(), {0: HumanAgent.new()})

	var result: StepResult = match_instance.start()

	assert_eq(result.status, StepResult.Status.ERROR)
	assert_true(result.message.contains("Every configured seat"))


func test_match_starts_one_seeded_hand_and_exposes_recipient_view_and_events() -> void:
	var match_instance := TournamentMatch.new(_config(), _agents())

	var result: StepResult = match_instance.start()
	var view: GameView = match_instance.get_view_for(0)

	assert_ne(result.status, StepResult.Status.ERROR)
	assert_not_null(view)
	assert_eq(view.seats.size(), 3)
	assert_eq(view.hero_seat, 0)
	assert_eq(view.hero_hole_cards.size(), 2)
	assert_true(match_instance.get_events().size() >= 4)


func test_match_uses_injected_rng_streams() -> void:
	var config := _config()
	var expected_streams := RngStreamFactory.new().create(config)
	var expected_cards := _expected_hero_cards_from(expected_streams, config)
	var injected_streams := RngStreamFactory.new().create(config)
	var match_instance := TournamentMatch.new(
		config, _agents(), TournamentConstructionContract.product(), injected_streams
	)

	var result := match_instance.start()

	assert_ne(result.status, StepResult.Status.ERROR)
	assert_eq(
		_card_ids(match_instance.get_view_for(0).hero_hole_cards),
		_card_ids(expected_cards),
	)


func test_player_quit_finishes_without_winner_before_or_during_hand() -> void:
	var before_start := TournamentMatch.new(_config(), _agents())
	assert_eq(before_start.request_quit().status, StepResult.Status.TOURNAMENT_FINISHED)
	assert_eq(before_start.end_reason, &"player_quit")
	assert_eq(before_start.winner_seat, Table.NO_SEAT)

	var during_hand := TournamentMatch.new(_config(), _agents())
	during_hand.start()
	assert_eq(during_hand.request_quit().status, StepResult.Status.TOURNAMENT_FINISHED)
	assert_eq(during_hand.get_view_for(0).tournament_status, &"finished")
	assert_eq(during_hand.get_view_for(0).end_reason, &"player_quit")


func test_match_starts_next_hand_only_after_completed_hand_boundary() -> void:
	var match_instance := TournamentMatch.new(_config(), _agents())

	var start_result: StepResult = match_instance.start()
	if start_result.status == StepResult.Status.WAITING_FOR_HUMAN:
		start_result = match_instance.submit_human_action(PlayerAction.fold_action())
	assert_eq(start_result.status, StepResult.Status.HAND_COMPLETED)
	assert_eq(match_instance.get_view_for(0).hand_number, 1)

	var next_hand_result: StepResult = match_instance.advance_until_blocked()
	assert_has(
		[StepResult.Status.WAITING_FOR_HUMAN, StepResult.Status.HAND_COMPLETED],
		next_hand_result.status
	)
	assert_eq(match_instance.get_view_for(0).hand_number, 2)


func test_quit_between_completed_hands_finishes_without_starting_another_hand() -> void:
	var match_instance := TournamentMatch.new(_config(), _agents())
	var result_before_quit: StepResult = match_instance.start()
	if result_before_quit.status == StepResult.Status.WAITING_FOR_HUMAN:
		result_before_quit = match_instance.submit_human_action(PlayerAction.fold_action())
	assert_eq(result_before_quit.status, StepResult.Status.HAND_COMPLETED)

	var result: StepResult = match_instance.request_quit()

	assert_eq(result.status, StepResult.Status.TOURNAMENT_FINISHED)
	assert_eq(match_instance.end_reason, &"player_quit")
	assert_eq(match_instance.get_view_for(0).hand_number, 1)


func _config() -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 881
	var overrides := StartupOverrides.new()
	overrides.set_player_count(3)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _agents() -> Dictionary[int, Agent]:
	return {
		0: HumanAgent.new(),
		1: ScriptedAgent.new([PlayerAction.fold_action()]),
		2: ScriptedAgent.new([PlayerAction.fold_action()]),
	}


func _expected_hero_cards_from(
	streams: RngStreams, config: ResolvedTournamentConfig
) -> Array[CardData]:
	var deck := Deck.new()
	deck.shuffle(streams.get_deck_rng())
	var button_rng := streams.get_initial_button_rng()
	var button: int = button_rng.randi_range(0, config.player_count - 1)
	var small_blind: int = (button + 1) % config.player_count
	var first_dealt_seat: int = small_blind
	var hero_cards: Array[CardData] = []
	for _card_index: int in range(2):
		for offset: int in range(config.player_count):
			var seat: int = (first_dealt_seat + offset) % config.player_count
			var card: CardData = deck.draw()
			if seat == 0:
				hero_cards.append(card)
	return hero_cards


func _card_ids(cards: Array[CardData]) -> Array[int]:
	var ids: Array[int] = []
	for card: CardData in cards:
		ids.append(card.card_id)
	return ids
