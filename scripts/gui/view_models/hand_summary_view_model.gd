class_name HandSummaryViewModel
extends RefCounted

## Recipient-safe result copy for inline feedback and the full hand summary.
var visible: bool = false
var winner_seats := PackedInt32Array()
var winner_names := PackedStringArray()
var result_prefix: String = ""
var result_text: String = ""
var lines: Array[HandSummaryLineViewModel] = []
var text: String = ""


static func build(view: GameView, names: Dictionary[int, String] = {}) -> HandSummaryViewModel:
	var result := HandSummaryViewModel.new()
	if view == null:
		return result
	result.visible = (
		not view.showdown_results.is_empty()
		or not view.pot_awards.is_empty()
		or view.hand_winner_seat != Table.NO_SEAT
	)
	for award: PotAward in view.pot_awards:
		var recipients := PackedStringArray()
		for seat: int in award.winner_seats:
			if not result.winner_seats.has(seat):
				result.winner_seats.append(seat)
			recipients.append(
				"%s +%d" % [_name(view, names, seat), award.amounts_by_seat.get(seat, 0)]
			)
		var pot_name: String = (
			"Main pot" if award.pot_index == 0 else "Side pot %d" % award.pot_index
		)
		result.lines.append(
			HandSummaryLineViewModel.create(
				"%s (%d): %s" % [pot_name, award.amount, ", ".join(recipients)], true
			)
		)
	if result.winner_seats.is_empty() and view.hand_winner_seat != Table.NO_SEAT:
		result.winner_seats.append(view.hand_winner_seat)
		result.lines.append(
			HandSummaryLineViewModel.create(
				"%s wins the hand" % _name(view, names, view.hand_winner_seat),
				true,
				view.hand_winner_seat
			)
		)
	result.winner_seats.sort()
	for seat: int in result.winner_seats:
		result.winner_names.append(_name(view, names, seat))
	if view.hand_complete and not result.winner_names.is_empty():
		result.result_prefix = "Winner: " if result.winner_names.size() == 1 else "Winners: "
		result.result_text = result.result_prefix + ", ".join(result.winner_names)
	var showdown_seats: Array = view.showdown_results.keys()
	showdown_seats.sort()
	for seat: int in showdown_seats:
		var known: bool = false
		for player: PlayerView in view.seats:
			known = known or player.seat == seat
		if not known:
			continue
		var description: String = ShowdownHandFormatter.format(view.showdown_results[seat])
		if not description.is_empty():
			result.lines.append(
				HandSummaryLineViewModel.create(
					"%s — %s" % [_name(view, names, seat), description],
					result.winner_seats.has(seat),
					seat
				)
			)
	var copies := PackedStringArray()
	for line: HandSummaryLineViewModel in result.lines:
		copies.append(line.text)
	result.text = "\n".join(copies)
	return result


static func _name(view: GameView, names: Dictionary[int, String], seat: int) -> String:
	for player: PlayerView in view.seats:
		if player.seat == seat:
			return (
				NameAssignmentService.HUMAN_LABEL
				if player.is_human
				else names.get(seat, player.display_name)
			)
	return "Player %d" % (seat + 1)
