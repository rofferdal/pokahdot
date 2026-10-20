class_name CliRenderer
extends RefCounted

const CliCardFormatterScript = preload("res://scripts/cli/cli_card_formatter.gd")

var _io: CliIO


func _init(io: CliIO) -> void:
	_io = io


func render_preflop(view: GameView) -> void:
	render_hand(view)


func render_hand(view: GameView) -> void:
	_io.write_line("Hand %d - %s" % [view.hand_number, view.street])
	(
		_io
		. write_line(
			(
				"Blinds: %d/%d - Level %d (%d hands completed, %d until next level)"
				% [
					view.small_blind,
					view.big_blind,
					view.blind_level,
					view.completed_hands_in_level,
					view.hands_until_next_level,
				]
			)
		)
	)
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
		var display_name := _player_display_name(seat_view, view.button_seat)
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
	_io.write_line("Remaining seats: %s" % _seat_list(view.active_seats))
	if not view.eliminated_seats.is_empty():
		_io.write_line("Eliminated seats: %s" % _seat_list(view.eliminated_seats))
	_io.write_line("Pot: %d" % view.pot_amount)
	if not view.community_cards.is_empty():
		_io.write_line("Board: %s" % CliCardFormatterScript.format_cards(view.community_cards))
	if not view.pots.is_empty():
		_io.write_line("Pots:")
		for pot_index: int in range(view.pots.size()):
			var pot: PotLayer = view.pots[pot_index]
			_io.write_line(
				(
					"  Pot %d: %d chips; eligible seats %s"
					% [pot_index + 1, pot.amount, _seat_list(pot.eligible_seats)]
				)
			)
	_io.write_line("Action history:")
	for record: PublicActionRecord in view.action_history:
		_io.write_line("  %s" % _format_action(record))
	_io.write_line("Your cards: %s" % CliCardFormatterScript.format_cards(view.hero_hole_cards))
	if not view.revealed_hole_cards.is_empty():
		_io.write_line("Showdown:")
		var revealed_seats: Array[int] = []
		for revealed_seat: int in view.revealed_hole_cards:
			revealed_seats.append(revealed_seat)
		revealed_seats.sort()
		for revealed_seat: int in revealed_seats:
			var cards: Array[CardData] = []
			cards.assign(view.revealed_hole_cards[revealed_seat])
			var line: String = (
				"  Seat %d: %s" % [revealed_seat, CliCardFormatterScript.format_cards(cards)]
			)
			var showdown: ShowdownResult = view.showdown_results.get(revealed_seat)
			if showdown != null:
				line += (
					"; %s; kickers %s; best five %s"
					% [
						_category_name(showdown.category),
						_int_list(showdown.tie_break_values),
						CliCardFormatterScript.format_cards(showdown.selected_cards),
					]
				)
			_io.write_line(line)
	if not view.pot_awards.is_empty():
		_io.write_line("Awards:")
		for award: PotAward in view.pot_awards:
			for winning_seat: int in award.winner_seats:
				_io.write_line(
					(
						"  Pot %d: seat %d wins %d"
						% [award.pot_index + 1, winning_seat, award.amounts_by_seat[winning_seat]]
					)
				)
	_io.write_line("Legal actions: %s" % _legal_actions(view))
	if view.hand_complete:
		if view.revealed_hole_cards.is_empty():
			_io.write_line("Hand complete. Seat %d wins by folds." % view.hand_winner_seat)
		else:
			_io.write_line("Hand complete after showdown.")
		_io.write_line("Final stacks:")
		for seat_view: PlayerView in view.seats:
			var display_name := _player_display_name(seat_view, view.button_seat)
			_io.write_line(
				"  Seat %d: %s - %d chips" % [seat_view.seat, display_name, seat_view.stack]
			)
	if view.end_reason == &"winner":
		_io.write_line("Tournament winner: seat %d" % view.tournament_winner_seat)
	if view.end_reason == &"player_quit":
		_io.write_line("Tournament ended: player_quit")


func _player_display_name(seat_view: PlayerView, button_seat: int) -> String:
	var display_name: String = seat_view.display_name
	if seat_view.is_human:
		display_name += " (you)"
	if seat_view.seat == button_seat:
		display_name += " (dealer)"
	return display_name


func _action_names(kinds: Array[PlayerAction.Kind]) -> String:
	var names: PackedStringArray = []
	for kind: PlayerAction.Kind in kinds:
		names.append(PlayerAction.Kind.keys()[kind].to_lower())
	return ", ".join(names)


func _seat_list(seats: Array[int]) -> String:
	var labels := PackedStringArray()
	for seat: int in seats:
		labels.append(str(seat))
	return "[ %s ]" % ", ".join(labels)


func _int_list(values: Array[int]) -> String:
	var labels := PackedStringArray()
	for value: int in values:
		labels.append(str(value))
	return "[ %s ]" % ", ".join(labels)


func _category_name(category: HandRank.Category) -> String:
	return HandRank.Category.keys()[category].to_lower().replace("_", " ")


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
