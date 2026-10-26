class_name CliCommandLoop
extends RefCounted

enum Status {
	QUIT,
	EOF,
}

const PotWagerTargetScript := preload("res://scripts/core/pot_wager_target.gd")

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
			CliCommand.Kind.POT_BET, CliCommand.Kind.POT_RAISE:
				_io.write_line("No active human turn.")
			CliCommand.Kind.UNKNOWN:
				_io.write_line(
					"Unknown command '%s'. Type 'help' for available commands." % command.text
				)

	return Status.EOF


func run_match(match_instance: TournamentMatch, human_seat: int) -> Status:
	var result: StepResult = match_instance.start()
	var exit_status: Status = Status.EOF
	if result.status == StepResult.Status.ERROR:
		_io.write_line("Unable to start tournament: %s" % result.message)
		return exit_status
	_render(match_instance, human_seat)

	while true:
		if result.status == StepResult.Status.ERROR:
			_io.write_line("Tournament error: %s" % result.message)
			break
		if result.status == StepResult.Status.HAND_COMPLETED:
			_io.write_text("Press Enter for the next hand, or type 'quit': ")
			var between_hands_input: CliInputLine = _io.read_line()
			if between_hands_input.is_eof:
				match_instance.request_quit()
				_render(match_instance, human_seat)
				_io.write_line("Input closed. Goodbye.")
				break
			var between_hands_command: CliCommand = _parser.parse(between_hands_input.text)
			if between_hands_command.kind == CliCommand.Kind.QUIT:
				match_instance.request_quit()
				_render(match_instance, human_seat)
				_io.write_line("Goodbye.")
				exit_status = Status.QUIT
				break
			if between_hands_command.kind == CliCommand.Kind.HELP:
				_print_help()
				continue
			if (
				between_hands_command.kind == CliCommand.Kind.POT_BET
				or between_hands_command.kind == CliCommand.Kind.POT_RAISE
			):
				_io.write_line("Action rejected: No active human turn.")
				continue
			result = match_instance.advance_until_blocked()
			_render(match_instance, human_seat)
			continue
		if result.status == StepResult.Status.TOURNAMENT_FINISHED:
			break
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
			break
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
				exit_status = Status.QUIT
				break
			CliCommand.Kind.ACTION:
				result = match_instance.submit_human_action(command.action)
				if result.status != StepResult.Status.ERROR and not result.message.is_empty():
					_io.write_line("Action rejected: %s" % result.message)
				_render(match_instance, human_seat)
			CliCommand.Kind.POT_BET, CliCommand.Kind.POT_RAISE:
				var pot_action: PlayerAction = _resolve_pot_action(
					match_instance.get_view_for(human_seat), command
				)
				if pot_action != null:
					result = match_instance.submit_human_action(pot_action)
					if result.status != StepResult.Status.ERROR and not result.message.is_empty():
						_io.write_line("Action rejected: %s" % result.message)
				_render(match_instance, human_seat)
			CliCommand.Kind.UNKNOWN:
				_io.write_line(
					"Unknown command '%s'. Type 'help' for available commands." % command.text
				)

	return exit_status


func _render(match_instance: TournamentMatch, human_seat: int) -> void:
	var view: GameView = match_instance.get_view_for(human_seat)
	if view != null:
		_renderer.render_hand(view)


func _resolve_pot_action(view: GameView, command: CliCommand) -> PlayerAction:
	if view == null or view.acting_seat != view.hero_seat:
		_io.write_line("Action rejected: No active human turn.")
		return null
	var wager_kind := (
		PlayerAction.Kind.BET
		if command.kind == CliCommand.Kind.POT_BET
		else PlayerAction.Kind.RAISE
	)
	if wager_kind not in view.legal_actions:
		var command_name := "potbet" if wager_kind == PlayerAction.Kind.BET else "potraise"
		var action_name := "Bet" if wager_kind == PlayerAction.Kind.BET else "Raise"
		_io.write_line(
			"Action rejected: %s is available only when %s is legal." % [command_name, action_name]
		)
		return null
	var existing_wager := 0
	for seat_view: PlayerView in view.seats:
		if seat_view.seat == view.hero_seat:
			existing_wager = seat_view.bet_this_round
			break
	var pot_target: PotWagerTargetResult = (
		PotWagerTargetScript
		. resolve(
			view.pot_amount,
			existing_wager,
			view.call_amount,
			view.minimum_wager_total,
			view.maximum_wager_total,
		)
	)
	if not pot_target.available:
		var fallback := "bet <total>" if wager_kind == PlayerAction.Kind.BET else "raise <total>"
		_io.write_line(
			"Action rejected: The exact Pot target is unavailable; use %s or allin." % fallback
		)
		return null
	return (
		PlayerAction.bet_to(pot_target.wager_total)
		if wager_kind == PlayerAction.Kind.BET
		else PlayerAction.raise_to(pot_target.wager_total)
	)


func _print_help() -> void:
	_io.write_line("Available commands:")
	_io.write_line("  help - show this help")
	_io.write_line("  quit, exit - exit Pokahdot")
	_io.write_line("  fold, check, call, bet <total>, raise <total>, potbet, potraise, allin")
