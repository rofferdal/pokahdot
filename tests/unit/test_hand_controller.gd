extends "res://tests/support/poker_gut_test.gd"


func test_setup_posts_blinds_deals_cards_and_waits_for_human() -> void:
	var players: Array[Player] = _players_with_agents()
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)

	var result: StepResult = controller.start()
	var view: GameView = controller.get_view_for(0)

	assert_eq(result.status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_eq(players[0].stack, 100)
	assert_eq(players[1].stack, 95)
	assert_eq(players[2].stack, 90)
	assert_eq(view.pot_amount, 15)
	assert_eq(view.hero_hole_cards.size(), 2)
	assert_eq(players[1].hole_cards.size(), 2)
	assert_eq(players[2].hole_cards.size(), 2)


func test_human_action_resumes_bots_and_fold_to_one_awards_pot() -> void:
	var players: Array[Player] = _players_with_agents()
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)
	controller.start()

	var result: StepResult = controller.submit_human_action(PlayerAction.raise_to(20))

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	assert_eq(controller.state, HandController.State.COMPLETE)
	assert_eq(controller.winner_seat, 0)
	assert_eq(players[0].stack, 115)
	assert_chip_total([players[0].stack, players[1].stack, players[2].stack], 300)
	assert_eq(controller.events[-2].kind, DomainEvent.Kind.POT_AWARDED)
	assert_eq(controller.events[-2].amount, 35)


func test_illegal_human_action_is_rejected_without_losing_turn() -> void:
	var players: Array[Player] = _players_with_agents()
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)
	controller.start()

	var result: StepResult = controller.submit_human_action(PlayerAction.check_action())

	assert_eq(result.status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_false(result.message.is_empty())
	assert_eq(controller.get_view_for(0).acting_seat, 0)
	assert_eq(players[0].stack, 100)


func test_checked_down_hand_advances_all_streets_and_awards_showdown() -> void:
	var players: Array[Player] = _heads_up_players(
		[
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action(),
			PlayerAction.check_action()
		]
	)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)

	assert_eq(controller.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_eq(
		controller.submit_human_action(PlayerAction.call_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN
	)
	assert_eq(controller.state, HandController.State.FLOP)
	assert_eq(controller.community_cards.size(), 3)
	assert_eq(
		controller.submit_human_action(PlayerAction.check_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN
	)
	assert_eq(controller.state, HandController.State.TURN)
	assert_eq(controller.community_cards.size(), 4)
	assert_eq(
		controller.submit_human_action(PlayerAction.check_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN
	)
	assert_eq(controller.state, HandController.State.RIVER)
	assert_eq(controller.community_cards.size(), 5)

	var result: StepResult = controller.submit_human_action(PlayerAction.check_action())

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	assert_eq(controller.state, HandController.State.COMPLETE)
	assert_eq(controller.community_cards.size(), 5)
	assert_eq(controller.showdown_hands.size(), 2)
	assert_false(controller.pot_awards.is_empty())
	assert_eq(controller.events[-1].kind, DomainEvent.Kind.HAND_COMPLETED)
	assert_chip_total([players[0].stack, players[1].stack], 200)


func test_fold_on_flop_awards_without_revealing_showdown_hands() -> void:
	var players: Array[Player] = _heads_up_players(
		[PlayerAction.check_action(), PlayerAction.bet_to(10)]
	)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)
	controller.start()
	controller.submit_human_action(PlayerAction.call_action())

	var result: StepResult = controller.submit_human_action(PlayerAction.fold_action())

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	assert_eq(controller.winner_seat, 1)
	assert_eq(controller.community_cards.size(), 3)
	assert_true(controller.showdown_hands.is_empty())
	assert_eq(players[1].stack, 110)
	assert_chip_total([players[0].stack, players[1].stack], 200)


func test_all_in_preflop_runs_out_board_and_completes_automatically() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 20, HumanAgent.new()),
		Player.new(&"bot_1", "Bot 1", 1, 20, ScriptedAgent.new([PlayerAction.call_action()])),
		Player.new(&"bot_2", "Bot 2", 2, 20, ScriptedAgent.new([PlayerAction.call_action()])),
	]
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)
	controller.start()

	var result: StepResult = controller.submit_human_action(PlayerAction.all_in_action())

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	assert_eq(controller.community_cards.size(), 5)
	assert_eq(controller.showdown_hands.size(), 3)
	assert_eq(controller.state, HandController.State.COMPLETE)
	assert_chip_total([players[0].stack, players[1].stack, players[2].stack], 60)


func _players_with_agents() -> Array[Player]:
	return [
		Player.new(&"human", "Human", 0, 100, HumanAgent.new()),
		Player.new(&"bot_1", "Bot 1", 1, 100, ScriptedAgent.new([PlayerAction.fold_action()])),
		Player.new(&"bot_2", "Bot 2", 2, 100, ScriptedAgent.new([PlayerAction.fold_action()])),
	]


func _heads_up_players(bot_actions: Array[PlayerAction]) -> Array[Player]:
	return [
		Player.new(&"human", "Human", 0, 100, HumanAgent.new()),
		Player.new(&"bot", "Bot", 1, 100, ScriptedAgent.new(bot_actions)),
	]


func _controller(table: Table) -> HandController:
	var deck_rng := RandomNumberGenerator.new()
	deck_rng.seed = 123
	var button_rng := RandomNumberGenerator.new()
	button_rng.seed = 456
	return HandController.new(table, Deck.new(), deck_rng, button_rng)
