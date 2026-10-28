extends "res://tests/support/poker_gut_test.gd"


class RejectingFallbackHandController:
	extends HandController

	func _fallback_action(_seat: int) -> PlayerAction:
		return PlayerAction.call_action()


class MatchingAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		if PlayerAction.Kind.CHECK in view.legal_actions:
			return PlayerAction.check_action()
		return PlayerAction.call_action()


func test_short_big_blind_keeps_nominal_call_and_raise_totals() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 100, HumanAgent.new()),
		Player.new(&"sb", "SB", 1, 100, MatchingAgent.new()),
		Player.new(&"bb", "BB", 2, 7, MatchingAgent.new()),
	]
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)
	assert_eq(controller.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	var before := controller.get_view_for(0)
	assert_eq(before.pot_amount, 12)
	assert_eq(before.call_amount, 10)
	assert_eq(before.minimum_wager_total, 20)
	assert_eq(before.action_history[1].amount, 7)
	assert_eq(
		controller.submit_human_action(PlayerAction.raise_to(19)).status,
		StepResult.Status.WAITING_FOR_HUMAN
	)
	assert_eq(controller.events[-1].rejection_code, ActionValidationResult.Code.BELOW_MINIMUM)
	assert_eq(controller.get_view_for(0).action_history.size(), before.action_history.size())
	assert_eq(players[0].stack, 100)
	assert_eq(
		controller.submit_human_action_without_advance(PlayerAction.raise_to(20)).status,
		StepResult.Status.YIELDED
	)
	assert_eq(players[0].bet_this_round, 20)


func test_full_increment_resets_on_every_street_and_views_keep_recipient_limits() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 1000, HumanAgent.new()),
		Player.new(&"bot", "Bot", 1, 1000, MatchingAgent.new()),
	]
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)
	assert_eq(controller.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_eq(
		controller.submit_human_action(PlayerAction.raise_to(30)).status,
		StepResult.Status.WAITING_FOR_HUMAN
	)
	var amount: int = 40
	for street: StringName in [&"flop", &"turn", &"river"]:
		var view := controller.get_view_for(0)
		assert_eq(view.street, street)
		assert_eq(view.minimum_wager_total, 10)
		assert_eq(view.call_amount, 0)
		assert_eq(view.maximum_wager_total, players[0].stack)
		assert_has(view.legal_actions, PlayerAction.Kind.BET)
		assert_true(controller.get_view_for(1).legal_actions.is_empty())
		assert_eq(
			controller.submit_human_action_without_advance(PlayerAction.bet_to(amount)).status,
			StepResult.Status.YIELDED
		)
		var opponent := controller.get_view_for(1)
		assert_eq(opponent.minimum_wager_total, amount * 2)
		assert_eq(opponent.call_amount, amount)
		assert_eq(opponent.maximum_wager_total, players[1].stack)
		assert_has(opponent.legal_actions, PlayerAction.Kind.RAISE)
		assert_eq(opponent.hero_hole_cards, players[1].hole_cards)
		assert_true(opponent.revealed_hole_cards.is_empty())
		assert_true(controller.get_view_for(0).legal_actions.is_empty())
		var result := controller.advance_until_blocked()
		assert_eq(
			result.status,
			(
				StepResult.Status.HAND_COMPLETED
				if street == &"river"
				else StepResult.Status.WAITING_FOR_HUMAN
			)
		)
		amount += 10
	assert_chip_total([players[0].stack, players[1].stack], 2000)
	for event: DomainEvent in controller.events:
		assert_ne(event.kind, DomainEvent.Kind.ACTION_REJECTED)


func test_short_all_in_rejection_preserves_history_and_stacks() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 100, HumanAgent.new()),
		Player.new(&"caller", "Caller", 1, 100, MatchingAgent.new()),
		Player.new(&"short", "Short", 2, 40, ScriptedAgent.new([PlayerAction.all_in_action()])),
	]
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)
	controller.start()
	assert_eq(
		controller.submit_human_action(PlayerAction.raise_to(30)).status,
		StepResult.Status.WAITING_FOR_HUMAN
	)
	var before := controller.get_view_for(0)
	assert_eq(before.minimum_wager_total, 60)
	for action: PlayerAction in [PlayerAction.raise_to(60), PlayerAction.all_in_action()]:
		assert_eq(
			controller.submit_human_action(action).status, StepResult.Status.WAITING_FOR_HUMAN
		)
		var after := controller.get_view_for(0)
		assert_eq(
			controller.events[-1].rejection_code, ActionValidationResult.Code.RAISE_NOT_REOPENED
		)
		assert_eq(after.action_history.size(), before.action_history.size())
		assert_eq(after.pot_amount, before.pot_amount)
		assert_eq(after.acting_seat, before.acting_seat)
		assert_eq(after.minimum_wager_total, before.minimum_wager_total)
		assert_eq(after.legal_actions, before.legal_actions)
		assert_eq(players[0].stack, 70)
	assert_eq(
		controller.submit_human_action(PlayerAction.call_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN
	)


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
	var rejection: DomainEvent = controller.events[-1]
	assert_eq(rejection.kind, DomainEvent.Kind.ACTION_REJECTED)
	assert_eq(rejection.requested_action_kind, PlayerAction.Kind.CHECK)
	assert_eq(rejection.rejection_code, ActionValidationResult.Code.ACTION_NOT_AVAILABLE)
	assert_false(rejection.message.is_empty())
	assert_false(rejection.fallback_applied)


func test_invalid_bot_action_uses_validated_fold_first_fallback_with_diagnostics() -> void:
	var bot := ScriptedAgent.new([PlayerAction.call_action()])
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 100, HumanAgent.new()),
		Player.new(&"bot", "Bot", 1, 100, bot),
	]
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)
	controller.start()

	var result: StepResult = controller.submit_human_action(PlayerAction.call_action())
	var rejection: DomainEvent = _last_event(controller.events, DomainEvent.Kind.ACTION_REJECTED)

	assert_eq(result.status, StepResult.Status.HAND_COMPLETED)
	assert_not_null(rejection)
	assert_eq(rejection.requested_action_kind, PlayerAction.Kind.CALL)
	assert_eq(rejection.requested_action_amount, 0)
	assert_eq(rejection.rejection_code, ActionValidationResult.Code.ACTION_NOT_AVAILABLE)
	assert_false(rejection.message.is_empty())
	assert_true(rejection.fallback_applied)
	assert_eq(rejection.applied_action_kind, PlayerAction.Kind.FOLD)
	assert_eq(rejection.applied_action_amount, 10)
	assert_eq(bot.observed_records[-1].kind, PlayerAction.Kind.FOLD)


func test_rejected_fallback_returns_error_without_false_action_progress() -> void:
	var bot := ScriptedAgent.new([PlayerAction.call_action()])
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 100, HumanAgent.new()),
		Player.new(&"bot", "Bot", 1, 100, bot),
	]
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _rejecting_fallback_controller(table)
	controller.start()

	var result: StepResult = controller.submit_human_action(PlayerAction.call_action())
	var events: Array[DomainEvent] = controller.events
	var bot_applied_count: int = 0
	for event: DomainEvent in events:
		if event.kind == DomainEvent.Kind.ACTION_APPLIED and event.seat == 1:
			bot_applied_count += 1
	var rejection: DomainEvent = _last_event(events, DomainEvent.Kind.ACTION_REJECTED)

	assert_eq(result.status, StepResult.Status.ERROR)
	assert_string_contains(result.message, "fallback was also rejected")
	assert_eq(controller.get_view_for(0).acting_seat, 1)
	assert_eq(bot_applied_count, 0)
	assert_eq(bot.observed_records.size(), 1)
	assert_not_null(rejection)
	assert_false(rejection.fallback_applied)
	assert_eq(rejection.applied_action_kind, -1)


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


func test_short_big_blind_posts_actual_chips_then_runs_out_after_nominal_call() -> void:
	var players: Array[Player] = [
		Player.new(&"human", "Human", 0, 900, HumanAgent.new()),
		Player.new(&"short_bb", "Short BB", 1, 631, ScriptedAgent.new([])),
	]
	var table := Table.new(players, 660, 1000)
	table.button_seat = 0
	var controller := _controller(table)

	var result: StepResult = controller.start(1)

	assert_eq(result.status, StepResult.Status.WAITING_FOR_HUMAN)
	var history: Array[PublicActionRecord] = controller.get_view_for(0).action_history
	assert_eq(history[0].amount, 660)
	assert_eq(history[1].amount, 631)
	assert_true(players[1].all_in)
	assert_eq(history.size(), 2)
	assert_eq(controller.get_view_for(0).call_amount, 240)
	assert_eq(
		controller.submit_human_action_without_advance(PlayerAction.call_action()).status,
		StepResult.Status.YIELDED
	)
	for _step: int in range(16):
		if controller.state == HandController.State.COMPLETE:
			break
		var view: GameView = controller.get_view_for(0)
		assert_eq(view.acting_seat, Table.NO_SEAT)
		assert_true(view.legal_actions.is_empty())
		var transition: StepResult = controller.advance_one_action()
		assert_ne(transition.status, StepResult.Status.ERROR)
	assert_eq(controller.community_cards.size(), 5)
	assert_eq(controller.events[-1].kind, DomainEvent.Kind.HAND_COMPLETED)
	assert_chip_total([players[0].stack, players[1].stack], 1531)


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


func _rejecting_fallback_controller(table: Table) -> HandController:
	var deck_rng := RandomNumberGenerator.new()
	deck_rng.seed = 123
	var button_rng := RandomNumberGenerator.new()
	button_rng.seed = 456
	return RejectingFallbackHandController.new(table, Deck.new(), deck_rng, button_rng)


func _last_event(events: Array[DomainEvent], kind: DomainEvent.Kind) -> DomainEvent:
	for index: int in range(events.size() - 1, -1, -1):
		if events[index].kind == kind:
			return events[index]
	return null


func test_single_step_preserves_human_mailbox_until_bulk_advance() -> void:
	var players := _players_with_agents()
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var controller := _controller(table)
	assert_eq(controller.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	var human := players[0].agent as HumanAgent
	human.submit_action(PlayerAction.call_action())
	var history_size: int = controller.get_view_for(0).action_history.size()
	assert_eq(controller.advance_one_action().status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_true(human.has_pending_action())
	assert_eq(controller.get_view_for(0).action_history.size(), history_size)
	assert_eq(controller.advance_until_blocked(1).status, StepResult.Status.YIELDED)
	assert_false(human.has_pending_action())
	assert_eq(controller.get_view_for(0).action_history.size(), history_size + 1)
