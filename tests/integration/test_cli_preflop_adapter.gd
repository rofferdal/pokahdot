extends "res://tests/support/poker_gut_test.gd"

const CliMatchFactoryScript = preload("res://scripts/cli/cli_match_factory.gd")
const CliCardFormatterScript = preload("res://scripts/cli/cli_card_formatter.gd")


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
	var has_tight_passive: bool = false
	var has_loose_aggressive: bool = false
	for line: String in diagnostics:
		has_tight_passive = has_tight_passive or line.contains("model=tight_passive")
		has_loose_aggressive = has_loose_aggressive or line.contains("model=loose_aggressive")
		assert_false(line.contains("parameters"))
		assert_false(line.contains("rng"))
	assert_true(has_tight_passive)
	assert_true(has_loose_aggressive)


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

	assert_eq(status, CliCommandLoop.Status.EOF)
	assert_eq(match_instance.state, TournamentMatch.State.FINISHED)
	assert_eq(match_instance.end_reason, &"winner")
	assert_true(match_instance.winner_seat >= 0)
	assert_true(io.count_writes_containing("Hand 2 -") >= 1)
	assert_true(io.contains_write("Tournament winner: seat %d" % match_instance.winner_seat))


func _config(count: int, stack: int, small_blind: int, big_blind: int) -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 4242
	var overrides := StartupOverrides.new()
	overrides.set_player_count(count)
	overrides.set_starting_stack(stack)
	overrides.set_small_blind(small_blind)
	overrides.set_big_blind(big_blind)
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
		1:
		(
			ScriptedAgent
			. new(
				[
					PlayerAction.check_action(),
					PlayerAction.check_action(),
					PlayerAction.check_action(),
					PlayerAction.check_action(),
				]
			)
		),
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
