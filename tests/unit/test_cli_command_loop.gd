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
