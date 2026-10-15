class_name CliCommandLoop
extends RefCounted

enum Status {
	QUIT,
	EOF,
}

var _io: CliIO
var _parser: CommandParser


func _init(io: CliIO, parser: CommandParser = null) -> void:
	_io = io
	_parser = parser if parser != null else CommandParser.new()


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
			CliCommand.Kind.UNKNOWN:
				_io.write_line(
					"Unknown command '%s'. Type 'help' for available commands." % command.text
				)

	return Status.EOF


func _print_help() -> void:
	_io.write_line("Available commands:")
	_io.write_line("  help - show this help")
	_io.write_line("  quit, exit - exit Pokahdot")
	_io.write_line("Poker gameplay commands are not available yet.")
