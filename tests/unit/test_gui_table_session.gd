# gdlint: disable=max-public-methods
extends GutTest

var _sessions: Array[GuiTableSession] = []
var _blocked: bool = false
var _held: Callable
var _old_callbacks: int = 0
var _new_callbacks: int = 0


class PassiveAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		return (
			PlayerAction.check_action()
			if PlayerAction.Kind.CHECK in view.legal_actions
			else PlayerAction.call_action()
		)


func before_each() -> void:
	_blocked = false
	_held = Callable()
	_old_callbacks = 0
	_new_callbacks = 0


func after_each() -> void:
	for session: GuiTableSession in _sessions:
		session.stop()
	_sessions.clear()


func test_live_models_copy_assignments_and_never_reveal_private_opponent_cards() -> void:
	var game: TournamentMatch = _game()
	var session: GuiTableSession = _session()
	var names: Dictionary[int, String] = {1: "Emiliano"}
	assert_true(session.bind_match(game, 0, {}, names))
	names[1] = "Changed"
	var model: TableViewModel = session.get_model()
	assert_true(model.valid)
	assert_eq(model.seat_for(1).display_name, "Emiliano")
	for card: CardViewModel in model.seat_for(1).cards.cards:
		assert_eq(card.state, CardViewModel.State.BACK)
		assert_eq(card.rank_text, "")
		assert_eq(card.suit_text, "")
	model.seat_for(1).display_name = "Mutated rendered model"
	assert_eq(session.get_model().seat_for(1).display_name, "Emiliano")
	assert_eq(session.get_view().hero_seat, 0)


func test_every_action_intent_delegates_its_exact_target_to_the_core() -> void:
	for intent: StringName in [&"fold", &"check_call", &"minimum", &"pot", &"wager", &"all_in"]:
		var game: TournamentMatch = _game()
		var session: GuiTableSession = _session()
		assert_true(session.bind_match(game, 0, {}))
		var before: GameView = session.get_view()
		var count: int = before.action_history.size()
		var expected: int = 0
		match intent:
			&"fold":
				expected = 5
			&"check_call":
				expected = 10
			&"minimum", &"wager":
				expected = before.minimum_wager_total
			&"pot":
				expected = ActionBarViewModel.resolve_pot_target(before).wager_total
			&"all_in":
				expected = before.maximum_wager_total
		var raw: String = " 000%d " % before.minimum_wager_total
		var result: StepResult = session.submit_intent(intent, raw)
		assert_ne(result.status, StepResult.Status.ERROR, intent)
		assert_eq(session.get_view().action_history.size(), count + 1, intent)
		var record: PublicActionRecord = session.get_view().action_history[-1]
		assert_eq(record.seat, 0, intent)
		assert_eq(record.amount, expected, intent)
		if intent == &"wager":
			assert_eq(raw, " 00020 ", "Adapter parsing does not mutate the caller's draft")


func test_invalid_or_overflowing_drafts_and_core_rejections_preserve_the_human_turn() -> void:
	var session: GuiTableSession = _session()
	assert_true(session.bind_match(_game(), 0, {}))
	var count: int = session.get_view().action_history.size()
	for raw: String in ["", "no", "2.5", "9223372036854775808", "-9223372036854775809"]:
		assert_eq(session.submit_intent(&"wager", raw).status, StepResult.Status.ERROR)
		assert_eq(session.get_feedback(), "Enter a whole-number wager total.")
		assert_eq(session.get_view().action_history.size(), count)
	assert_eq(session.submit_wager_total(11).status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_false(session.get_feedback().is_empty())
	assert_eq(session.get_model().actions.status_text, session.get_feedback())
	assert_eq(session.get_model().actions.phone_status_text, session.get_feedback())
	assert_eq(session.get_view().acting_seat, 0)
	assert_eq(session.get_view().action_history.size(), count)
	assert_ne(session.submit_wager_total(20).status, StepResult.Status.ERROR)
	assert_eq(session.get_feedback(), "")


func test_check_call_selects_check_when_the_core_offers_a_free_action() -> void:
	var session: GuiTableSession = _session()
	assert_true(session.bind_match(_game(), 0, {}))
	assert_ne(session.submit_intent(&"check_call").status, StepResult.Status.ERROR)
	for index: int in 10:
		if session.get_view().community_cards.size() == 3 and session.get_view().acting_seat == 0:
			break
		session.advance_one_action()
	assert_eq(session.get_view().community_cards.size(), 3)
	assert_true(PlayerAction.Kind.CHECK in session.get_view().legal_actions)
	assert_ne(session.submit_intent(&"check_call").status, StepResult.Status.ERROR)
	assert_eq(session.get_view().action_history[-1].kind, PlayerAction.Kind.CHECK)


func test_action_is_published_before_a_nonblocking_pause_and_bot_progression() -> void:
	var session: GuiTableSession = _session(0.025)
	assert_true(session.bind_match(_game(), 0, {}))
	var count: int = session.get_view().action_history.size()
	assert_ne(session.submit_intent(&"minimum").status, StepResult.Status.ERROR)
	assert_eq(session.get_view().action_history.size(), count + 1)
	assert_true(session.is_advance_pending())
	await get_tree().create_timer(0.25).timeout
	assert_gt(session.get_view().action_history.size(), count + 1)
	assert_eq(session.get_view().acting_seat, 0)
	assert_eq(session.get_view().community_cards.size(), 3)


func test_modal_holds_automatic_advancement_and_blocks_direct_submission() -> void:
	var session: GuiTableSession = _session(0.025)
	assert_true(session.bind_match(_game(), 0, {}))
	session.submit_intent(&"minimum")
	var count: int = session.get_view().action_history.size()
	_blocked = true
	await get_tree().create_timer(0.06).timeout
	assert_true(_held.is_valid())
	assert_true(session.is_advance_pending(), "A held modal callback remains pending")
	assert_eq(session.get_view().action_history.size(), count)
	assert_eq(session.submit_intent(&"fold").status, StepResult.Status.ERROR)
	assert_eq(session.get_view().action_history.size(), count)
	_blocked = false
	_held.call()
	await get_tree().create_timer(0.10).timeout
	assert_gt(session.get_view().action_history.size(), count)


func test_rebinding_and_stopping_invalidate_external_held_callbacks() -> void:
	var session: GuiTableSession = _session(0.025)
	var original: TournamentMatch = _game()
	assert_true(session.bind_match(original, 0, {}))
	session.submit_intent(&"minimum")
	_blocked = true
	await get_tree().create_timer(0.06).timeout
	assert_true(_held.is_valid())
	var stale: Callable = _held
	var old_count: int = original.get_view_for(0).action_history.size()
	_blocked = false
	var replacement: TournamentMatch = _game()
	assert_true(session.bind_match(replacement, 0, {}))
	var new_count: int = session.get_view().action_history.size()
	stale.call()
	assert_eq(session.get_view().action_history.size(), new_count)
	assert_eq(original.get_view_for(0).action_history.size(), old_count)
	session.stop()
	stale.call()
	await get_tree().create_timer(0.06).timeout
	assert_eq(replacement.get_view_for(0).action_history.size(), new_count)
	assert_false(session.is_advance_pending())
	assert_eq(session.submit_intent(&"fold").status, StepResult.Status.ERROR)


func test_manual_next_hand_invalidates_the_completed_hand_timer() -> void:
	var session: GuiTableSession = _session()
	var timing: GuiActionTimingConfig = _timing(0.0)
	timing.showdown_pause_seconds = 0.10
	session.configure(get_tree(), timing, _hold, _is_blocked)
	assert_true(session.bind_match(_game(), 0, {}))
	session.submit_intent(&"fold")
	assert_true(session.get_view().hand_complete)
	assert_true(session.is_advance_pending())
	var hand: int = session.get_view().hand_number
	assert_ne(session.continue_hand().status, StepResult.Status.ERROR)
	assert_eq(session.get_view().hand_number, hand + 1)
	assert_false(session.get_view().hand_complete)
	await get_tree().create_timer(0.15).timeout
	assert_eq(session.get_view().hand_number, hand + 1)
	assert_eq(session.get_view().acting_seat, 0)
	assert_eq(session.continue_hand().status, StepResult.Status.ERROR)


func test_view_only_binding_cancels_live_progression_and_copies_history() -> void:
	var session: GuiTableSession = _session(0.025)
	assert_true(session.bind_match(_game(), 0, {}))
	session.submit_intent(&"minimum")
	var fixture: GameView = _game().get_view_for(0)
	var lines: Array[String] = ["Literal [b]public history[/b]"]
	assert_true(session.bind_view(fixture, {}, {}, lines))
	lines[0] = "Changed"
	await get_tree().create_timer(0.06).timeout
	assert_same(session.get_view(), fixture)
	assert_eq(session.get_model().history.text, "Literal [b]public history[/b]")
	assert_false(session.is_advance_pending())
	assert_eq(session.submit_intent(&"minimum").status, StepResult.Status.ERROR)
	assert_true(session.refresh())


func test_quit_cancels_progression_even_when_confirmation_blocks_ordinary_input() -> void:
	var session: GuiTableSession = _session(0.025)
	var game: TournamentMatch = _game()
	assert_true(session.bind_match(game, 0, {}))
	session.submit_intent(&"minimum")
	var count: int = session.get_view().action_history.size()
	_blocked = true
	assert_eq(session.request_quit().status, StepResult.Status.TOURNAMENT_FINISHED)
	assert_false(session.is_advance_pending())
	assert_eq(session.get_view().tournament_status, &"finished")
	assert_eq(session.get_view().end_reason, &"player_quit")
	assert_eq(session.get_view().tournament_winner_seat, Table.NO_SEAT)
	await get_tree().create_timer(0.06).timeout
	assert_eq(session.get_view().action_history.size(), count)


func test_street_history_retains_fold_copy_and_clears_other_previous_street_actions() -> void:
	var session: GuiTableSession = _session()
	var game: TournamentMatch = _game(3)
	assert_true(session.bind_match(game, 0, {}))
	for index: int in 20:
		var view: GameView = session.get_view()
		if view.community_cards.size() >= 3:
			break
		if view.acting_seat == 0:
			session.submit_intent(&"check_call")
		else:
			session.advance_one_action()
	assert_gte(session.get_view().community_cards.size(), 3)
	var model: TableViewModel = session.get_model()
	assert_true(model.seat_for(1).folded)
	assert_eq(model.seat_for(1).status_text, "Fold")
	assert_eq(model.seat_for(2).latest_action_text, "")
	assert_true(model.history.text.contains("Fold"))
	assert_true(model.history.text.contains("Flop"))
	assert_eq(model.history.text, session.get_model().history.text)


func test_pre_tree_session_binding_can_be_configured_later_and_explicit_steps_respect_input(
) -> void:
	var session := GuiTableSession.new()
	_sessions.append(session)
	assert_true(session.bind_match(_game(), 0, {}))
	session.submit_intent(&"minimum")
	assert_false(session.is_advance_pending())
	session.configure(get_tree(), _timing(0.025), _hold, _is_blocked)
	assert_true(session.is_advance_pending())
	_blocked = true
	assert_eq(session.advance_one_action().status, StepResult.Status.ERROR)
	_blocked = false
	assert_ne(session.advance_one_action().status, StepResult.Status.ERROR)


func test_zero_delay_replaces_pending_pacer_without_a_stale_waiting_flag_or_callback() -> void:
	var pacer := GuiActionPacer.new()
	pacer.configure(get_tree(), _timing(0.04))
	pacer.schedule_delay(0.04, func() -> void: _old_callbacks += 1)
	assert_true(pacer.is_waiting())
	pacer.schedule_delay(0.0, func() -> void: _new_callbacks += 1)
	assert_false(pacer.is_waiting())
	assert_eq(_new_callbacks, 1)
	await get_tree().create_timer(0.07).timeout
	assert_eq(_old_callbacks, 0)
	assert_eq(_new_callbacks, 1)


func test_stopped_session_retains_its_snapshot_but_invalid_rebinding_clears_identity() -> void:
	var session: GuiTableSession = _session()
	assert_true(session.bind_match(_game(), 0, {}))
	var original: GameView = session.get_view()
	session.stop()
	assert_same(session.get_view(), original)
	assert_false(session.bind_match(null, 0, {}))
	assert_null(session.get_view())
	assert_false(session.get_model().valid)
	assert_false(session.bind_view(null, {}))
	assert_null(session.get_view())
	assert_false(session.is_advance_pending())


func test_rebinding_recipients_replaces_private_faces_and_cannot_act_for_another_human() -> void:
	var game: TournamentMatch = _game()
	var session: GuiTableSession = _session()
	assert_true(session.bind_match(game, 0, {}))
	assert_eq(session.get_model().seat_for(0).cards.cards[0].state, CardViewModel.State.FACE)
	assert_true(session.bind_match(game, 1, {}))
	var model: TableViewModel = session.get_model()
	assert_eq(model.hero_seat, 1)
	for card: CardViewModel in model.seat_for(0).cards.cards:
		assert_eq(card.state, CardViewModel.State.BACK)
		assert_eq(card.rank_text, "")
	var count: int = game.get_view_for(0).action_history.size()
	assert_eq(session.submit_intent(&"fold").status, StepResult.Status.ERROR)
	assert_eq(game.get_view_for(0).action_history.size(), count)


func test_explicit_stepping_bypasses_only_the_automatic_pacing_gate() -> void:
	var session: GuiTableSession = _session()
	session.configure(
		get_tree(), _timing(0.0), func(_callback: Callable) -> bool: return true, _is_blocked
	)
	assert_true(session.bind_match(_game(), 0, {}))
	session.submit_intent(&"minimum")
	assert_true(session.is_advance_pending())
	var count: int = session.get_view().action_history.size()
	assert_ne(session.advance_one_action().status, StepResult.Status.ERROR)
	assert_gt(session.get_view().action_history.size(), count)
	_blocked = true
	count = session.get_view().action_history.size()
	assert_eq(session.advance_one_action().status, StepResult.Status.ERROR)
	assert_eq(session.get_view().action_history.size(), count)


func test_short_blind_runout_without_an_action_event_paces_every_community_reveal() -> void:
	var config := ResolvedTournamentConfig.new(
		2, 3, 5, 10, 9123, &"single_table", {0: &"human", 1: &"scripted"}
	)
	var game := TournamentMatch.new(config, {0: HumanAgent.new(), 1: PassiveAgent.new()})
	assert_eq(game.start(1).status, StepResult.Status.YIELDED)
	var initial: GameView = game.get_view_for(0)
	assert_eq(initial.acting_seat, Table.NO_SEAT)
	assert_true(initial.legal_actions.is_empty())
	for event: DomainEvent in game.get_events():
		assert_ne(event.kind, DomainEvent.Kind.ACTION_APPLIED)
	var session: GuiTableSession = _session(0.015)
	var boards: Array[int] = []
	var reference: WeakRef = weakref(session)
	session.changed.connect(
		func() -> void:
			var current := reference.get_ref() as GuiTableSession
			boards.append(current.get_view().community_cards.size())
	)
	assert_true(session.bind_match(game, 0, {}))
	assert_true(session.is_advance_pending())
	for frame: int in 40:
		if session.get_view().hand_complete:
			break
		await get_tree().process_frame
	assert_true(session.get_view().hand_complete)
	assert_eq(session.get_view().community_cards.size(), 5)
	for count: int in [3, 4, 5]:
		assert_true(count in boards, "The runout publishes each street separately")
	assert_eq(game.state, TournamentMatch.State.FINISHED)
	assert_false(session.is_advance_pending())
	var hand: int = session.get_view().hand_number
	await get_tree().create_timer(0.06).timeout
	assert_eq(session.get_view().hand_number, hand)


func test_completed_hand_stays_visible_for_its_configured_showdown_pause() -> void:
	var session: GuiTableSession = _session()
	var timing: GuiActionTimingConfig = _timing(0.0)
	timing.showdown_pause_seconds = 0.10
	session.configure(get_tree(), timing, _hold, _is_blocked)
	assert_true(session.bind_match(_game(), 0, {}))
	session.submit_intent(&"fold")
	assert_true(session.get_view().hand_complete)
	assert_true(session.is_advance_pending())
	var hand: int = session.get_view().hand_number
	await get_tree().create_timer(0.025).timeout
	assert_eq(session.get_view().hand_number, hand)
	assert_true(session.get_view().hand_complete)
	await get_tree().create_timer(0.13).timeout
	assert_eq(session.get_view().hand_number, hand + 1)
	assert_false(session.get_view().hand_complete)
	assert_eq(session.get_view().acting_seat, 0)


func test_new_human_action_expires_a_previous_modal_held_advance_before_its_fresh_pause() -> void:
	var session: GuiTableSession = _session()
	var holding: Array[bool] = [true]
	var callbacks: Array[Callable] = []
	var gate: Callable = func(callback: Callable) -> bool:
		if holding[0]:
			callbacks.append(callback)
			return true
		return false
	session.configure(get_tree(), _timing(0.0), gate)
	assert_true(session.bind_match(_game(), 0, {}))
	session.submit_intent(&"check_call")
	for step: int in 12:
		var view: GameView = session.get_view()
		if view.community_cards.size() == 3 and view.acting_seat == 0:
			break
		session.advance_one_action()
	assert_eq(session.get_view().community_cards.size(), 3)
	assert_eq(session.get_view().acting_seat, 0)
	assert_true(PlayerAction.Kind.BET in session.get_view().legal_actions)
	assert_false(callbacks.is_empty())
	var previous: Callable = callbacks[-1]
	callbacks.clear()
	holding[0] = false
	session.configure(get_tree(), _timing(0.05), gate)
	var before_rejection: int = session.get_view().action_history.size()
	assert_eq(session.submit_wager_total(1).status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_eq(session.get_view().action_history.size(), before_rejection)
	assert_true(session.is_advance_pending(), "Core rejection retains the previous held pause")
	assert_ne(
		session.submit_wager_total(session.get_view().minimum_wager_total).status,
		StepResult.Status.ERROR
	)
	var count: int = session.get_view().action_history.size()
	assert_true(session.is_advance_pending())
	previous.call()
	assert_eq(
		session.get_view().action_history.size(),
		count,
		"Closing an old modal must not skip the new human action's presentation pause"
	)
	assert_true(session.is_advance_pending())
	await get_tree().create_timer(0.09).timeout
	assert_gt(session.get_view().action_history.size(), count)
	callbacks.clear()


func _session(delay: float = 0.5) -> GuiTableSession:
	var session := GuiTableSession.new()
	session.configure(get_tree(), _timing(delay), _hold, _is_blocked)
	_sessions.append(session)
	return session


func _timing(delay: float) -> GuiActionTimingConfig:
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = delay
	timing.showdown_pause_seconds = delay
	return timing


func _hold(callback: Callable) -> bool:
	if _blocked:
		_held = callback
		return true
	return false


func _is_blocked() -> bool:
	return _blocked


func _game(count: int = 2) -> TournamentMatch:
	var ids: Dictionary[int, StringName] = {0: &"human", 1: &"scripted"}
	var agents: Dictionary[int, Agent] = {0: HumanAgent.new(), 1: PassiveAgent.new()}
	if count == 3:
		ids[2] = &"scripted"
		agents[1] = ScriptedAgent.new([PlayerAction.fold_action()])
		agents[2] = PassiveAgent.new()
	var config := ResolvedTournamentConfig.new(count, 100, 5, 10, 9123, &"single_table", ids)
	var game := TournamentMatch.new(config, agents)
	assert_eq(game.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	return game
