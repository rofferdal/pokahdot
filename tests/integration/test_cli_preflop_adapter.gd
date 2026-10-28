extends "res://tests/support/poker_gut_test.gd"

const CliMatchFactoryScript = preload("res://scripts/cli/cli_match_factory.gd")
const CliMatchCreationResultScript = preload("res://scripts/cli/cli_match_creation_result.gd")
const CliCardFormatterScript = preload("res://scripts/cli/cli_card_formatter.gd")


class CheckingCallingAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		if PlayerAction.Kind.CHECK in view.legal_actions:
			return PlayerAction.check_action()
		if PlayerAction.Kind.CALL in view.legal_actions:
			return PlayerAction.call_action()
		return PlayerAction.fold_action()


func test_match_loop_renders_before_prompt_rejects_without_losing_turn_and_settles() -> void:
	var io := FakeCliIO.new()
	io.queue_line("nonsense").queue_line("raise 1").queue_line("raise 20")
	var match_instance := TournamentMatch.new(_config(3, 1000, 5, 10), _folding_agents(3))

	var status := CliCommandLoop.new(io).run_match(match_instance, 0)
	assert_eq(status, CliCommandLoop.Status.EOF)
	assert_true(io.writes.find("Hand 1 - preflop") < io.writes.find("pokahdot> "))
	assert_true(
		io.contains_write("Unknown command 'nonsense'. Type 'help' for available commands.")
	)
	assert_true(
		io.contains_write("Action rejected: The wager is below the minimum full bet or raise.")
	)
	assert_true(io.count_writes_containing("Hand 1 -") >= 3)
	assert_true(io.contains_write("Hand complete. Seat 0 wins by folds."))
	assert_true(io.contains_write("  Seat 0 raises to 20"))
	_assert_no_bot_cards_are_rendered(io, match_instance)


func test_repeated_raise_transcript_rejects_obsolete_amount_and_recovers_to_minimum() -> void:
	for compact: bool in [false, true]:
		var io := FakeCliIO.new()
		for command: String in ["check", "bet 20", "raise 50", "state", "raise 60"]:
			io.queue_line(command)
		var match_instance := (
			TournamentMatch
			. new(
				_config(2, 500, 5, 10),
				{
					0: HumanAgent.new(),
					1:
					ScriptedAgent.new(
						[
							PlayerAction.call_action(),
							PlayerAction.raise_to(40),
							PlayerAction.fold_action()
						]
					),
				}
			)
		)
		assert_eq(
			CliCommandLoop.new(io, null, null, compact).run_match(match_instance, 0),
			CliCommandLoop.Status.EOF
		)
		assert_true(
			io.contains_write(
				"Legal actions: fold, call (20), raise (60-490 total), potraise (80), allin"
			)
		)
		assert_eq(
			io.count_writes_containing(
				"Action rejected: The wager is below the minimum full bet or raise."
			),
			1
		)
		assert_true(io.contains_write("  Seat 0 raises to 60"))
		assert_false(io.contains_write("  Seat 0 raises to 50"))
		assert_true(io.contains_write("Hand complete. Seat 0 wins by folds."))
		var view := match_instance.get_view_for(0)
		var human_raises: Array[PublicActionRecord] = view.action_history.filter(
			func(record: PublicActionRecord) -> bool:
				return record.seat == 0 and record.kind == PlayerAction.Kind.RAISE
		)
		assert_eq(human_raises.size(), 1)
		assert_eq(human_raises[0].amount, 60)
		var rejections: Array[DomainEvent] = match_instance.get_events().filter(
			func(event: DomainEvent) -> bool: return event.kind == DomainEvent.Kind.ACTION_REJECTED
		)
		assert_eq(rejections.size(), 1)
		assert_eq(rejections[0].rejection_code, ActionValidationResult.Code.BELOW_MINIMUM)
		assert_eq(rejections[0].requested_action_amount, 50)
		assert_false(rejections[0].fallback_applied)
		_assert_no_bot_cards_are_rendered(io, match_instance)


func test_match_loop_executes_potbet_from_the_current_recipient_safe_view() -> void:
	var io := FakeCliIO.new()
	io.queue_line("check").queue_line("potbet")
	var agents: Dictionary[int, Agent] = {
		0: HumanAgent.new(),
		1:
		(
			ScriptedAgent
			. new(
				[
					PlayerAction.call_action(),
					PlayerAction.fold_action(),
				]
			)
		),
	}
	var match_instance := TournamentMatch.new(_config(2, 100, 5, 10), agents)

	var status := CliCommandLoop.new(io).run_match(match_instance, 0)
	assert_eq(status, CliCommandLoop.Status.EOF)
	assert_true(
		io.contains_write("Legal actions: fold, check, bet (10-90 total), potbet (20), allin")
	)
	assert_true(io.contains_write("  Seat 0 bets to 20"))
	assert_true(io.contains_write("Hand complete. Seat 0 wins by folds."))


func test_match_loop_rejects_wrong_kind_and_unavailable_pot_target_actionably() -> void:
	var io := FakeCliIO.new()
	io.queue_line("potbet").queue_line("potraise").queue_line("raise 20")
	var match_instance := TournamentMatch.new(_config(3, 35, 5, 10), _folding_agents(3))

	var status := CliCommandLoop.new(io).run_match(match_instance, 0)

	assert_eq(status, CliCommandLoop.Status.EOF)
	assert_true(io.contains_write("Action rejected: potbet is available only when Bet is legal."))
	assert_true(
		io.contains_write(
			"Action rejected: The exact Pot target is unavailable; use raise <total> or allin."
		)
	)
	assert_true(io.contains_write("  Seat 0 raises to 20"))
	assert_eq(io.count_writes_containing("Unknown command"), 0)


func test_cli_potraise_adds_observed_pot_and_submits_street_total_after_blind() -> void:
	var io := FakeCliIO.new()
	var match_instance := TournamentMatch.new(_config(3, 100, 5, 10), _folding_agents(3))
	assert_eq(match_instance.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	var before := match_instance.get_view_for(0)
	var stack_before: int = _seat_view(before, 0).stack
	var chips_before: int = _total_chips_and_pot(before)
	var parsed := CommandParser.new().parse("potraise")
	var action: PlayerAction = CliCommandLoop.new(io)._resolve_pot_action(before, parsed)

	assert_not_null(action)
	assert_eq(before.pot_amount, 30)
	assert_eq(_seat_view(before, 0).bet_this_round, 10)
	assert_eq(before.call_amount, 0)
	assert_eq(action.kind, PlayerAction.Kind.RAISE)
	assert_eq(action.amount, 40)
	assert_eq(
		match_instance.submit_human_action_without_advance(action).status,
		StepResult.Status.YIELDED,
	)
	var after := match_instance.get_view_for(0)
	assert_eq(stack_before - _seat_view(after, 0).stack, 30)
	assert_eq(after.pot_amount, 60)
	assert_eq(_current_bet(after), 40)
	assert_eq(_total_chips_and_pot(after), chips_before)
	assert_eq(_latest_player_action_for(after, 0).amount, 40)
	CliRenderer.new(io).render_hand(after)
	assert_true(io.contains_write("  Seat 0 raises to 40"))


func test_cli_potraise_facing_wager_doubles_pot_and_reopens_action() -> void:
	var io := FakeCliIO.new()
	var agents: Dictionary[int, Agent] = {
		0: HumanAgent.new(),
		1: ScriptedAgent.new([PlayerAction.call_action(), PlayerAction.bet_to(10)]),
	}
	var match_instance := TournamentMatch.new(_config(2, 100, 5, 10), agents)
	assert_eq(match_instance.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_eq(
		match_instance.submit_human_action(PlayerAction.check_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN,
	)
	assert_eq(
		match_instance.submit_human_action(PlayerAction.check_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN,
	)
	var before := match_instance.get_view_for(0)
	var stack_before: int = _seat_view(before, 0).stack
	var chips_before: int = _total_chips_and_pot(before)
	var action: PlayerAction = CliCommandLoop.new(io)._resolve_pot_action(
		before, CommandParser.new().parse("potraise")
	)

	assert_eq(before.pot_amount, 30)
	assert_eq(_seat_view(before, 0).bet_this_round, 0)
	assert_eq(before.call_amount, 10)
	assert_eq(action.amount, 30)
	assert_eq(
		match_instance.submit_human_action_without_advance(action).status,
		StepResult.Status.YIELDED,
	)
	var after := match_instance.get_view_for(0)
	assert_eq(stack_before - _seat_view(after, 0).stack, 30)
	assert_eq(after.pot_amount, 60)
	assert_eq(_current_bet(after), 30)
	assert_eq(_total_chips_and_pot(after), chips_before)
	var opponent_view := match_instance.get_view_for(1)
	assert_eq(opponent_view.call_amount, 20)
	assert_has(opponent_view.legal_actions, PlayerAction.Kind.RAISE)


func test_cli_repeated_potraises_preserve_observed_contribution_and_total_target() -> void:
	var io := FakeCliIO.new()
	var agents: Dictionary[int, Agent] = {
		0: HumanAgent.new(),
		1: ScriptedAgent.new([PlayerAction.call_action(), PlayerAction.raise_to(40)]),
	}
	var match_instance := TournamentMatch.new(_config(2, 500, 5, 10), agents)
	assert_eq(match_instance.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_eq(
		match_instance.submit_human_action(PlayerAction.check_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN,
	)
	var flop_view := match_instance.get_view_for(0)
	var pot_bet: PlayerAction = CliCommandLoop.new(io)._resolve_pot_action(
		flop_view, CommandParser.new().parse("potbet")
	)
	assert_eq(
		match_instance.submit_human_action(pot_bet).status, StepResult.Status.WAITING_FOR_HUMAN
	)
	var before := match_instance.get_view_for(0)
	var stack_before: int = _seat_view(before, 0).stack
	var chips_before: int = _total_chips_and_pot(before)
	var repeated_raise: PlayerAction = CliCommandLoop.new(io)._resolve_pot_action(
		before, CommandParser.new().parse("potraise")
	)

	assert_eq(before.pot_amount, 80)
	assert_eq(_seat_view(before, 0).bet_this_round, 20)
	assert_eq(before.call_amount, 20)
	assert_eq(repeated_raise.amount, 100)
	assert_eq(
		match_instance.submit_human_action_without_advance(repeated_raise).status,
		StepResult.Status.YIELDED,
	)
	var after := match_instance.get_view_for(0)
	assert_eq(stack_before - _seat_view(after, 0).stack, 80)
	assert_eq(after.pot_amount, 160)
	assert_eq(_current_bet(after), 100)
	assert_eq(_total_chips_and_pot(after), chips_before)


func test_pot_command_between_hands_is_rejected_without_starting_next_hand() -> void:
	var io := FakeCliIO.new()
	io.queue_line("raise 20").queue_line("potbet").queue_line("quit")
	var match_instance := TournamentMatch.new(_config(3, 100, 5, 10), _folding_agents(3))

	var status := CliCommandLoop.new(io).run_match(match_instance, 0)

	assert_eq(status, CliCommandLoop.Status.QUIT)
	assert_true(io.contains_write("Action rejected: No active human turn."))
	assert_eq(io.count_writes_containing("Hand 2 -"), 0)


func test_between_hands_rejects_every_action_and_unknown_command_without_advancing() -> void:
	var io := FakeCliIO.new()
	io.queue_line("raise 20")
	for command: String in [
		"fold",
		"call",
		"check",
		"bet 10",
		"raise 20",
		"allin",
		"potraise",
		"state",
		"history",
		"typo",
		"help"
	]:
		io.queue_line(command)
	io.queue_line("quit")
	var match_instance := TournamentMatch.new(_config(3, 100, 5, 10), _folding_agents(3))
	assert_eq(CliCommandLoop.new(io).run_match(match_instance, 0), CliCommandLoop.Status.QUIT)
	assert_eq(match_instance.hand_number, 1)
	assert_eq(io.count_writes_containing("No active human turn."), 7)
	assert_eq(io.count_writes_containing("Unknown command 'typo'"), 1)


func test_only_blank_or_continue_advances_between_hands() -> void:
	for next_hand: String in ["", "continue"]:
		var io := FakeCliIO.new()
		io.queue_line("continue").queue_line("raise 20").queue_line(next_hand).queue_line("quit")
		var match_instance := TournamentMatch.new(_config(3, 100, 5, 10), _folding_agents(3))
		assert_eq(CliCommandLoop.new(io).run_match(match_instance, 0), CliCommandLoop.Status.QUIT)
		assert_eq(match_instance.hand_number, 2)
		assert_true(io.contains_write("Continue is available only between hands."))


func test_quit_routes_through_match_and_renders_player_quit() -> void:
	var io := FakeCliIO.new()
	io.queue_line("quit")
	var match_instance := TournamentMatch.new(_config(2, 100, 5, 10), _passive_agents())

	var status := CliCommandLoop.new(io).run_match(match_instance, 0)

	assert_eq(status, CliCommandLoop.Status.QUIT)
	assert_eq(match_instance.state, TournamentMatch.State.FINISHED)
	assert_eq(match_instance.end_reason, &"player_quit")
	assert_true(io.contains_write("Tournament ended: player_quit"))


func test_match_loop_plays_a_complete_checked_down_hand_to_showdown() -> void:
	var io := FakeCliIO.new()
	for _street: int in range(4):
		# One of these is accepted for every passive turn. A rejected action must
		# preserve the turn, so the following command completes it deterministically.
		io.queue_line("call").queue_line("check")
	var match_instance := TournamentMatch.new(_config(2, 100, 5, 10), _showdown_agents())

	var status := CliCommandLoop.new(io).run_match(match_instance, 0)
	var view: GameView = match_instance.get_view_for(0)

	assert_eq(status, CliCommandLoop.Status.EOF)
	assert_true(io.contains_write("Hand 1 - hand_end"))
	assert_true(io.contains_write("Hand 1 - flop"))
	assert_true(io.contains_write("Hand 1 - turn"))
	assert_true(io.contains_write("Hand 1 - river"))
	assert_true(io.contains_write("Hand 1 - hand_end"))
	assert_true(io.count_writes_containing("Board: [ ") >= 4)
	assert_true(io.contains_write("Showdown:"))
	assert_true(io.contains_write("Awards:"))


func test_match_factory_uses_resolved_non_default_configuration() -> void:
	var config := _config(4, 240, 12, 24)
	var factory := CliMatchFactoryScript.new()
	var match_instance: TournamentMatch = factory.create(config)

	var result: StepResult = match_instance.start()
	var view: GameView = match_instance.get_view_for(factory.human_seat(config))

	assert_ne(result.status, StepResult.Status.ERROR)
	assert_eq(view.seats.size(), 4)
	assert_eq(view.pot_amount, 36)
	assert_eq(view.hero_hole_cards.size(), 2)
	assert_eq(view.seats[view.small_blind_seat].bet_this_round, 12)
	assert_eq(view.seats[view.big_blind_seat].bet_this_round, 24)
	assert_true(view.seats[factory.human_seat(config)].is_human)
	var diagnostics: PackedStringArray = factory.diagnostics(config)
	assert_has(diagnostics, "Bot roster version: curated_v2")
	assert_has(diagnostics, "Legacy heuristic models: not included")
	var has_selected_profile_ids := false
	for line: String in diagnostics:
		has_selected_profile_ids = (
			has_selected_profile_ids or line.begins_with("Selected bot profile IDs: ")
		)
	assert_true(has_selected_profile_ids)
	var selected_profiles: Dictionary[String, bool] = {}
	for line: String in diagnostics:
		assert_false(line.contains("parameters"))
		assert_false(line.contains("rng"))
		if line.contains("profile="):
			selected_profiles[line.get_slice("profile=", 1)] = true
	assert_eq(selected_profiles.size(), config.player_count - 1)
	for model_family: String in _selected_model_families(diagnostics):
		assert_eq(model_family, "strategy_parameterized")


func test_match_factory_selects_the_legacy_mixed_roster_only_when_enabled() -> void:
	var factory := CliMatchFactoryScript.new()
	var default_diagnostics := factory.diagnostics(_config(6, 240, 12, 24))
	var legacy_diagnostics := factory.diagnostics(_config(6, 240, 12, 24, true))
	var legacy_match := factory.create(_config(6, 240, 12, 24, true))

	assert_has(default_diagnostics, "Legacy heuristic models: not included")
	assert_has(legacy_diagnostics, "Legacy heuristic models: included")
	assert_eq(_diagnostic_profile_count(legacy_diagnostics), 5)
	assert_ne(legacy_match.start().status, StepResult.Status.ERROR)
	var human_view := legacy_match.get_view_for(0)
	assert_eq(human_view.hero_hole_cards.size(), 2)
	assert_true(human_view.revealed_hole_cards.is_empty())
	for line: String in legacy_diagnostics:
		assert_false(line.contains("experimental"))


func test_match_factory_legacy_selection_has_the_shared_family_split_for_every_table_size() -> void:
	var factory := CliMatchFactoryScript.new()
	for player_count: int in range(2, 10):
		var config := _config(player_count, 240, 12, 24, true)
		var model_families := _selected_model_families(factory.diagnostics(config))
		var legacy_count := 0
		for model_family: String in model_families:
			if model_family != "strategy_parameterized":
				legacy_count += 1
		assert_eq(model_families.size(), player_count - 1)
		assert_eq(legacy_count, player_count / 2)
		assert_eq(factory.human_seat(config), 0)


func test_match_factory_repeats_legacy_profile_selection_for_a_fixed_seed() -> void:
	var factory := CliMatchFactoryScript.new()
	var first_config := _config(7, 240, 12, 24, true)
	var second_config := _config(7, 240, 12, 24, true)

	assert_eq(factory.diagnostics(first_config), factory.diagnostics(second_config))


func test_default_startup_diagnostics_name_each_bot_from_the_created_match_assignment() -> void:
	var config := _config(6, 240, 12, 24)
	var factory := CliMatchFactoryScript.new()
	var creation := factory.create_with_diagnostics(config)

	_assert_startup_profile_names_match_created_agents(config, creation)
	assert_has(creation.diagnostics, "Legacy heuristic models: not included")
	for model_family: String in _selected_model_families(creation.diagnostics):
		assert_eq(model_family, "strategy_parameterized")
	assert_eq(
		creation.diagnostics,
		factory.create_with_diagnostics(config).diagnostics,
		"A fixed seed must preserve the startup seat-to-profile mapping.",
	)


func test_mixed_startup_diagnostics_name_each_bot_from_the_created_match_assignment() -> void:
	var config := _config(7, 240, 12, 24, true)
	var factory := CliMatchFactoryScript.new()
	var creation := factory.create_with_diagnostics(config)

	_assert_startup_profile_names_match_created_agents(config, creation)
	assert_has(creation.diagnostics, "Legacy heuristic models: included")
	var model_families := _selected_model_families(creation.diagnostics)
	assert_has(model_families, "strategy_parameterized")
	var has_legacy_family := false
	for model_family: String in model_families:
		if model_family != "strategy_parameterized":
			has_legacy_family = true
	assert_true(has_legacy_family)


func test_default_and_non_default_tables_mark_exactly_one_human_across_snapshots() -> void:
	for count: int in [TournamentConfig.new().player_count, 3]:
		var io := FakeCliIO.new()
		io.queue_line("raise 20")
		var match_instance := TournamentMatch.new(
			_config(count, 1000, 5, 10), _folding_agents(count)
		)

		CliCommandLoop.new(io).run_match(match_instance, 0)

		assert_true(io.count_writes_containing("Hand 1 -") >= 2)
		assert_true(io.count_writes_containing("(you)") >= io.count_writes_containing("Hand 1 -"))
		assert_true(io.count_writes_containing("Seat 0: Player 1 (you) -") >= 1)
		for seat: int in range(1, count):
			assert_eq(io.count_writes_containing("Seat %d: Player %d (you)" % [seat, seat + 1]), 0)


func test_cli_runs_seeded_short_stack_tournament_to_a_displayed_winner() -> void:
	var config := _config(3, 20, 5, 10)
	var factory := CliMatchFactoryScript.new()
	var io := FakeCliIO.new()
	for _input_pair: int in range(400):
		io.queue_line("fold").queue_blank_line()
	var match_instance: TournamentMatch = factory.create(config)

	var status := CliCommandLoop.new(io).run_match(match_instance, factory.human_seat(config))

	assert_eq(status, CliCommandLoop.Status.COMPLETED)
	assert_eq(match_instance.state, TournamentMatch.State.FINISHED)
	assert_eq(match_instance.end_reason, &"winner")
	assert_true(match_instance.winner_seat >= 0)
	assert_true(io.count_writes_containing("Hand 2 -") >= 1)
	assert_true(io.contains_write("Tournament winner: seat %d" % match_instance.winner_seat))


func _config(
	count: int, stack: int, small_blind: int, big_blind: int, use_legacy_models: bool = false
) -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 4242
	var overrides := StartupOverrides.new()
	overrides.set_player_count(count)
	overrides.set_starting_stack(stack)
	overrides.set_small_blind(small_blind)
	overrides.set_big_blind(big_blind)
	overrides.set_use_legacy_models(use_legacy_models)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _folding_agents(count: int) -> Dictionary[int, Agent]:
	var agents: Dictionary[int, Agent] = {0: HumanAgent.new()}
	for seat: int in range(1, count):
		agents[seat] = ScriptedAgent.new([PlayerAction.call_action(), PlayerAction.fold_action()])
	return agents


func _passive_agents() -> Dictionary[int, Agent]:
	return {
		0: HumanAgent.new(),
		1: ScriptedAgent.new([PlayerAction.call_action(), PlayerAction.check_action()]),
	}


func _showdown_agents() -> Dictionary[int, Agent]:
	return {
		0: HumanAgent.new(),
		1: CheckingCallingAgent.new(),
	}


func _assert_no_bot_cards_are_rendered(io: FakeCliIO, match_instance: TournamentMatch) -> void:
	var hero_cards: PackedStringArray = []
	for card: CardData in match_instance.get_view_for(0).hero_hole_cards:
		hero_cards.append(CliCardFormatterScript.format_card(card))
	for write: String in io.writes:
		if not write.begins_with("Your cards:"):
			continue
		assert_true(write.begins_with("Your cards: [ "))
		for token: String in write.trim_prefix("Your cards: [ ").trim_suffix(" ]").split(" | "):
			assert_true(token in hero_cards)
			assert_false(token.contains(":"))


func _seat_view(view: GameView, seat: int) -> PlayerView:
	for seat_view: PlayerView in view.seats:
		if seat_view.seat == seat:
			return seat_view
	return null


func _total_chips_and_pot(view: GameView) -> int:
	var total := view.pot_amount
	for seat_view: PlayerView in view.seats:
		total += seat_view.stack
	return total


func _current_bet(view: GameView) -> int:
	var current_bet := 0
	for seat_view: PlayerView in view.seats:
		current_bet = maxi(current_bet, seat_view.bet_this_round)
	return current_bet


func _latest_player_action_for(view: GameView, seat: int) -> PublicActionRecord:
	for index: int in range(view.action_history.size() - 1, -1, -1):
		var record: PublicActionRecord = view.action_history[index]
		if record.record_kind == PublicActionRecord.Kind.ACTION and record.seat == seat:
			return record
	return null


func _diagnostic_profile_count(diagnostics: PackedStringArray) -> int:
	var profile_ids: Dictionary[String, bool] = {}
	for line: String in diagnostics:
		if line.contains("profile="):
			profile_ids[line.get_slice("profile=", 1)] = true
	return profile_ids.size()


func _selected_model_families(diagnostics: PackedStringArray) -> PackedStringArray:
	for line: String in diagnostics:
		if line.begins_with("Selected bot model families: "):
			return line.trim_prefix("Selected bot model families: ").split(",", false)
	return PackedStringArray()


func _assert_startup_profile_names_match_created_agents(
	config: ResolvedTournamentConfig, creation: CliMatchCreationResultScript
) -> void:
	var roster := PlayableBotRoster.new()
	var streams := RngStreamFactory.new().create(config)
	var selection := (
		roster
		. select(
			config.player_count - 1,
			streams.get_seat_profile_assignment_rng(),
			config.use_legacy_models,
		)
	)
	assert_true(selection.is_ok())
	var profiles := selection.get_profiles()
	var selected_profile_ids := PackedStringArray()
	var selected_model_families := PackedStringArray()
	for profile: BotProfile in profiles:
		selected_profile_ids.append(String(profile.profile_id))
		selected_model_families.append(String(profile.model_id))
	assert_has(creation.diagnostics, "Bot roster version: %s" % roster.get_roster_version())
	assert_has(
		creation.diagnostics,
		"Selected bot profile IDs: %s" % ",".join(selected_profile_ids),
	)
	assert_has(
		creation.diagnostics,
		"Selected bot model families: %s" % ",".join(selected_model_families),
	)

	var seat_row_count := 0
	for line: String in creation.diagnostics:
		if line.begins_with("Seat "):
			seat_row_count += 1
		assert_false(line.contains("parameters"))
		assert_false(line.contains("rng"))
	assert_eq(seat_row_count, config.player_count)

	var profile_index := 0
	for seat: int in range(config.player_count):
		var seat_prefix := "Seat %d:" % seat
		var matching_row := ""
		var matching_row_count := 0
		for line: String in creation.diagnostics:
			if line.begins_with(seat_prefix):
				matching_row = line
				matching_row_count += 1
		assert_eq(matching_row_count, 1, "Each seat must have exactly one startup row.")
		var agent: Agent = creation.match_instance.get_agent_for_simulation(seat)
		if seat == creation.human_seat:
			assert_eq(matching_row, "Seat %d: human" % seat)
			assert_false(matching_row.contains("name="))
			assert_true(agent is HumanAgent)
			continue

		var profile: BotProfile = profiles[profile_index]
		profile_index += 1
		assert_false(profile.display_name.is_empty())
		assert_eq(
			matching_row,
			(
				"Seat %d: model=%s profile=%s name=%s"
				% [seat, profile.model_id, profile.profile_id, profile.display_name]
			),
		)
		assert_true(agent is BotAgent)
		assert_eq((agent as BotAgent).profile_id, profile.profile_id)
		assert_eq((agent as BotAgent).model_id, profile.model_id)
	assert_eq(profile_index, profiles.size())
