class_name CliCommandLoop
extends RefCounted

enum Status {
	QUIT,
	EOF,
}

var _io: CliIO
var _parser: CommandParser
var _renderer: CliRenderer


func _init(io: CliIO, parser: CommandParser = null, renderer: CliRenderer = null) -> void:
	_io = io
	_parser = parser if parser != null else CommandParser.new()
	_renderer = renderer if renderer != null else CliRenderer.new(io)


func run() -> Status:
	_io.write_line("Type 'help' for available commands or 'quit' to exit.")

	while true:
		_io.write_text("pokahdot> ")
		var input: CliInputLine = _io.read_line()
		if input.is_eof:
			_io.write_line("Input closed. Goodbye.")
			return Status.EOF

		var command: CliCommand = _parser.parse(input.text)
		match command.kind:
			CliCommand.Kind.EMPTY:
				continue
			CliCommand.Kind.HELP:
				_print_help()
			CliCommand.Kind.QUIT:
				_io.write_line("Goodbye.")
				return Status.QUIT
			CliCommand.Kind.ACTION:
				_io.write_line("No active human turn.")
			CliCommand.Kind.UNKNOWN:
				_io.write_line(
					"Unknown command '%s'. Type 'help' for available commands." % command.text
				)

	return Status.EOF


func run_match(match_instance: TournamentMatch, human_seat: int) -> Status:
	var result: StepResult = match_instance.start()
	if result.status == StepResult.Status.ERROR:
		_io.write_line("Unable to start tournament: %s" % result.message)
		return Status.EOF
	_render(match_instance, human_seat)

	while true:
		if result.status == StepResult.Status.ERROR:
			_io.write_line("Tournament error: %s" % result.message)
			return Status.EOF
		if result.status == StepResult.Status.HAND_COMPLETED:
			return Status.EOF
		if result.status == StepResult.Status.YIELDED:
			result = match_instance.advance_until_blocked()
			_render(match_instance, human_seat)
			continue
		_io.write_text("pokahdot> ")
		var input: CliInputLine = _io.read_line()
		if input.is_eof:
			match_instance.request_quit()
			_render(match_instance, human_seat)
			_io.write_line("Input closed. Goodbye.")
			return Status.EOF
		var command: CliCommand = _parser.parse(input.text)
		match command.kind:
			CliCommand.Kind.EMPTY:
				continue
			CliCommand.Kind.HELP:
				_print_help()
			CliCommand.Kind.QUIT:
				match_instance.request_quit()
				_render(match_instance, human_seat)
				_io.write_line("Goodbye.")
				return Status.QUIT
			CliCommand.Kind.ACTION:
				result = match_instance.submit_human_action(command.action)
				if result.status != StepResult.Status.ERROR and not result.message.is_empty():
					_io.write_line("Action rejected: %s" % result.message)
				_render(match_instance, human_seat)
			CliCommand.Kind.UNKNOWN:
				_io.write_line(
					"Unknown command '%s'. Type 'help' for available commands." % command.text
				)

	return Status.EOF


func _render(match_instance: TournamentMatch, human_seat: int) -> void:
	var view: GameView = match_instance.get_view_for(human_seat)
	if view != null:
		_renderer.render_hand(view)


func _print_help() -> void:
	_io.write_line("Available commands:")
	_io.write_line("  help - show this help")
	_io.write_line("  quit, exit - exit Pokahdot")
	_io.write_line("  fold, check, call, bet <total>, raise <total>, allin")
