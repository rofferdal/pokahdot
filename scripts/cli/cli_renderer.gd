class_name CliRenderer
extends RefCounted

const CliCardFormatterScript = preload("res://scripts/cli/cli_card_formatter.gd")

var _io: CliIO


func _init(io: CliIO) -> void:
	_io = io


func render_preflop(view: GameView) -> void:
	_io.write_line("Hand %d - preflop" % view.hand_number)
	(
		_io
		. write_line(
			(
				"Button: %d  SB: %d  BB: %d  Acting: %s"
				% [
					view.button_seat,
					view.small_blind_seat,
					view.big_blind_seat,
					"-" if view.acting_seat == Table.NO_SEAT else str(view.acting_seat),
				]
			)
		)
	)
	for seat_view: PlayerView in view.seats:
		var display_name: String = seat_view.display_name
		if seat_view.is_human:
			display_name += " (you)"
		(
			_io
			. write_line(
				(
					"Seat %d: %s - %d chips, contribution %d, folded %s, all-in %s"
					% [
						seat_view.seat,
						display_name,
						seat_view.stack,
						seat_view.bet_this_round,
						str(seat_view.folded).to_lower(),
						str(seat_view.all_in).to_lower(),
					]
				)
			)
		)
	_io.write_line("Pot: %d" % view.pot_amount)
	_io.write_line("Action history:")
	for record: PublicActionRecord in view.action_history:
		_io.write_line("  %s" % _format_action(record))
	_io.write_line("Your cards: %s" % CliCardFormatterScript.format_cards(view.hero_hole_cards))
	_io.write_line("Legal actions: %s" % _legal_actions(view))
	if view.hand_complete:
		_io.write_line("Hand complete. Seat %d wins by folds." % view.hand_winner_seat)
	if view.end_reason == &"player_quit":
		_io.write_line("Tournament ended: player_quit")


func _action_names(kinds: Array[PlayerAction.Kind]) -> String:
	var names: PackedStringArray = []
	for kind: PlayerAction.Kind in kinds:
		names.append(PlayerAction.Kind.keys()[kind].to_lower())
	return ", ".join(names)


func _legal_actions(view: GameView) -> String:
	var descriptions := PackedStringArray()
	for kind: PlayerAction.Kind in view.legal_actions:
		var name: String = (
			"allin"
			if kind == PlayerAction.Kind.ALL_IN
			else PlayerAction.Kind.keys()[kind].to_lower()
		)
		if kind == PlayerAction.Kind.CALL:
			name += " (%d)" % view.call_amount
		elif kind == PlayerAction.Kind.BET or kind == PlayerAction.Kind.RAISE:
			name += " (%d-%d total)" % [view.minimum_wager_total, view.maximum_wager_total]
		descriptions.append(name)
	return ", ".join(descriptions) if not descriptions.is_empty() else "none"


func _format_action(record: PublicActionRecord) -> String:
	match record.record_kind:
		PublicActionRecord.Kind.SMALL_BLIND:
			return "Seat %d posts small blind %d" % [record.seat, record.amount]
		PublicActionRecord.Kind.BIG_BLIND:
			return "Seat %d posts big blind %d" % [record.seat, record.amount]
	var action_name: String = PlayerAction.Kind.keys()[record.kind].to_lower()
	if record.kind == PlayerAction.Kind.BET or record.kind == PlayerAction.Kind.RAISE:
		return "Seat %d %ss to %d" % [record.seat, action_name, record.amount]
	if record.kind == PlayerAction.Kind.CALL:
		return "Seat %d calls to %d" % [record.seat, record.amount]
	return "Seat %d %ss" % [record.seat, action_name]
