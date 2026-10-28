extends "res://tests/support/poker_gut_test.gd"


func test_help_prints_available_shell_and_poker_commands() -> void:
	var io := FakeCliIO.new()
	io.queue_line("help").queue_line("quit")

	var status := _run_loop(io)

	assert_eq(status, CliCommandLoop.Status.QUIT)
	assert_true(io.contains_write("Available commands:"))
	assert_true(io.contains_write("  help - show this help"))
	assert_true(io.contains_write("  quit, exit - exit Pokahdot"))
	assert_true(
		io.contains_write(
			"  fold, check, call, bet <total>, raise <total>, potbet, potraise, allin"
		)
	)
	assert_write_precedes(io, "Available commands:", "Goodbye.")


func test_blank_input_is_ignored_and_loop_continues() -> void:
	var io := FakeCliIO.new()
	io.queue_blank_line().queue_line("quit")

	var status := _run_loop(io)

	assert_eq(status, CliCommandLoop.Status.QUIT)
	assert_eq(io.count_writes_containing("Unknown command"), 0)
	assert_eq(io.count_writes_containing("Available commands:"), 0)
	assert_eq(io.count_writes_containing("pokahdot> "), 2)


func test_unknown_command_is_reported_and_loop_recovers() -> void:
	var io := FakeCliIO.new()
	io.queue_line("  DEAL NOW ").queue_line("quit")

	var status := _run_loop(io)

	assert_eq(status, CliCommandLoop.Status.QUIT)
	assert_true(
		io.contains_write("Unknown command 'deal now'. Type 'help' for available commands.")
	)
	assert_true(io.contains_write("Goodbye."))


func test_pot_commands_are_recognized_without_an_active_human_turn() -> void:
	var io := FakeCliIO.new()
	io.queue_line("potbet").queue_line("potraise").queue_line("quit")

	var status := _run_loop(io)

	assert_eq(status, CliCommandLoop.Status.QUIT)
	assert_eq(io.count_writes_containing("No active human turn."), 2)
	assert_eq(io.count_writes_containing("Unknown command"), 0)


func test_quit_ends_loop_with_quit_status() -> void:
	var io := FakeCliIO.new()
	io.queue_line("quit")

	var status := _run_loop(io)

	assert_eq(status, CliCommandLoop.Status.QUIT)
	assert_true(io.contains_write("Goodbye."))


func test_exit_is_an_alias_for_quit() -> void:
	var io := FakeCliIO.new()
	io.queue_line("exit")

	var status := _run_loop(io)

	assert_eq(status, CliCommandLoop.Status.QUIT)
	assert_true(io.contains_write("Goodbye."))


func test_eof_ends_loop_with_eof_status_and_message() -> void:
	var io := FakeCliIO.new()
	io.queue_eof()

	var status := _run_loop(io)

	assert_eq(status, CliCommandLoop.Status.EOF)
	assert_true(io.contains_write("Input closed. Goodbye."))
	assert_false(io.contains_write("Goodbye."))


func _run_loop(io: FakeCliIO) -> CliCommandLoop.Status:
	return CliCommandLoop.new(io).run()


func assert_write_precedes(io: FakeCliIO, earlier: String, later: String) -> void:
	assert_true(io.writes.find(earlier) < io.writes.find(later))


class FailingMatch:
	extends TournamentMatch

	func _init() -> void:
		super(null, {})

	func start(_max_transitions: int = 32) -> StepResult:
		return StepResult.new(StepResult.Status.YIELDED)

	func advance_until_blocked(_max_transitions: int = 32) -> StepResult:
		return StepResult.new(StepResult.Status.ERROR, "Injected advancement failure.")

	func get_view_for(_seat: int) -> GameView:
		return null


func test_advancement_failure_returns_error_instead_of_eof() -> void:
	var io := FakeCliIO.new()
	var status := CliCommandLoop.new(io).run_match(FailingMatch.new(), 0)
	assert_eq(status, CliCommandLoop.Status.ERROR)
	assert_true(io.contains_write("Tournament error: Injected advancement failure."))


func test_match_start_failure_returns_error_with_nonzero_exit() -> void:
	var io := FakeCliIO.new()
	var match_instance := TournamentMatch.new(null, {})
	var status := CliCommandLoop.new(io).run_match(match_instance, 0)
	assert_eq(status, CliCommandLoop.Status.ERROR)
	assert_eq(CliCommandLoop.exit_code(status), 1)
	assert_eq(io.count_writes_containing("Unable to start tournament:"), 1)
	for success: CliCommandLoop.Status in [
		CliCommandLoop.Status.COMPLETED, CliCommandLoop.Status.QUIT, CliCommandLoop.Status.EOF
	]:
		assert_eq(CliCommandLoop.exit_code(success), 0)


func test_inspection_commands_in_shell_report_no_active_tournament() -> void:
	var io := FakeCliIO.new()
	io.queue_line("state").queue_line("history").queue_line("quit")
	assert_eq(_run_loop(io), CliCommandLoop.Status.QUIT)
	assert_eq(io.count_writes_containing("No active tournament."), 2)


func test_potraise_resolves_exact_live_repeated_raise_target() -> void:
	var config := ResolvedTournamentConfig.new(
		2, 500, 5, 10, 4242, &"single_table", {0: &"human", 1: &"scripted"}
	)
	var match_instance := (
		TournamentMatch
		. new(
			config,
			{
				0: HumanAgent.new(),
				1: ScriptedAgent.new([PlayerAction.call_action(), PlayerAction.raise_to(40)]),
			}
		)
	)
	assert_eq(match_instance.start().status, StepResult.Status.WAITING_FOR_HUMAN)
	assert_eq(
		match_instance.submit_human_action(PlayerAction.check_action()).status,
		StepResult.Status.WAITING_FOR_HUMAN,
	)
	assert_eq(
		match_instance.submit_human_action(PlayerAction.bet_to(20)).status,
		StepResult.Status.WAITING_FOR_HUMAN,
	)
	var before := match_instance.get_view_for(0)
	assert_eq(before.minimum_wager_total, 60)
	assert_eq(before.pot_amount, 80)
	var action := CliCommandLoop.new(FakeCliIO.new())._resolve_pot_action(
		before, CommandParser.new().parse("potraise")
	)
	assert_not_null(action)
	assert_eq(action.amount, 100)
	assert_eq(
		match_instance.submit_human_action_without_advance(action).status, StepResult.Status.YIELDED
	)
	var after := match_instance.get_view_for(0)
	assert_eq(after.seats[0].bet_this_round, 100)
	assert_eq(before.seats[0].stack - after.seats[0].stack, 80)
	assert_eq(after.pot_amount, 160)


func test_potraise_below_tracked_minimum_is_unavailable_without_clamping() -> void:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100), Player.new(&"opponent", "Opponent", 1, 100)
	]
	var table := Table.new(players, 5, 10)
	var round := BettingRound.new(table, 1)
	assert_true(round.apply_action(1, PlayerAction.bet_to(40)).is_ok())
	var pots := PotManager.new()
	pots.record_contribution(1, 40)
	var view := GameView.for_preflop(table, 0, round, pots, [])
	var io := FakeCliIO.new()
	var action := CliCommandLoop.new(io)._resolve_pot_action(
		view, CommandParser.new().parse("potraise")
	)
	assert_eq(view.minimum_wager_total, 80)
	assert_null(action)
	assert_true(
		io.contains_write(
			"Action rejected: The exact Pot target is unavailable; use raise <total> or allin."
		)
	)
	assert_eq(round.acting_seat, 0)
	assert_eq(round.current_bet, 40)
	assert_eq(players[0].stack, 100)
	assert_eq(round.minimum_wager_total(), 80)


func test_parsed_allin_is_validated_against_open_and_closed_core_rights() -> void:
	var players: Array[Player] = [
		Player.new(&"raiser", "Raiser", 0, 100),
		Player.new(&"caller", "Caller", 1, 100),
		Player.new(&"short", "Short", 2, 40),
		Player.new(&"unacted", "Unacted", 3, 50),
	]
	var round := BettingRound.new(Table.new(players, 5, 10), 0, 10)
	assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
	assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
	var command := CommandParser.new().parse("allin")
	assert_true(round.apply_action(2, command.action).is_ok())
	assert_has(round.legal_actions(3), PlayerAction.Kind.ALL_IN)
	assert_does_not_have(round.legal_actions(3), PlayerAction.Kind.RAISE)
	assert_true(round.apply_action(3, command.action).is_ok())
	assert_eq(round.minimum_wager_total(), 70)
	assert_does_not_have(round.legal_actions(0), PlayerAction.Kind.ALL_IN)
	assert_eq(
		round.apply_action(0, command.action).code, ActionValidationResult.Code.RAISE_NOT_REOPENED
	)
	assert_eq(round.acting_seat, 0)
	assert_eq(players[0].stack, 70)
	assert_eq(players[0].bet_this_round, 30)
	assert_eq(round.current_bet, 50)
