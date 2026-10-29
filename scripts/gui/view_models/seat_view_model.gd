class_name SeatViewModel
extends RefCounted

## Pure presentation snapshot built only from recipient-safe public state.
var valid: bool = false
var error: String = ""
var seat: int = Table.NO_SEAT
var display_name: String = ""
var avatar_path: String = ""
var stack_text: String = ""
var stack_value_text: String = ""
var wager_text: String = ""
var markers: String = ""
var is_dealer: bool = false
var is_small_blind: bool = false
var is_big_blind: bool = false
var badge_text: String = ""
var token_badge_text: String = ""
var acting: bool = false
var folded: bool = false
var all_in: bool = false
var busted: bool = false
var is_hero: bool = false
var cards: CardRowViewModel
var status_text: String = ""
var status_full: String = ""
var status_compact: String = ""
var status_inline: String = ""
var latest_action_text: String = ""
var compact_action_text: String = ""
var compact_action_exact_text: String = ""
var winner_emphasis: bool = false
var main_pot_winner: bool = false
var pre_showdown_winner: bool = false


static func build(
	player: PlayerView,
	view: GameView,
	names: Dictionary[int, String],
	avatars: Dictionary[int, String],
	latest: PublicActionRecord = null,
	retained_fold: PublicActionRecord = null,
	density: GuiFitCandidate.Density = GuiFitCandidate.Density.FULL
) -> SeatViewModel:
	var result := SeatViewModel.new()
	result.cards = CardRowViewModel.for_seat(view, player.seat if player != null else Table.NO_SEAT)
	if player == null or view == null:
		result.error = "Seat presentation requires a player and recipient-safe game view."
		return result
	result.valid = true
	result.seat = player.seat
	result.display_name = (
		NameAssignmentService.HUMAN_LABEL
		if player.is_human
		else names.get(player.seat, player.display_name)
	)
	result.avatar_path = avatars.get(player.seat, "")
	result.stack_value_text = str(player.stack)
	result.stack_text = str(player.stack) if player.stack >= 100000 else "%d chips" % player.stack
	result.wager_text = "Bet %d" % player.bet_this_round
	result.acting = player.seat == view.acting_seat
	result.folded = player.folded
	result.all_in = player.all_in
	result.busted = player.busted
	result.is_hero = player.seat == view.hero_seat
	result.is_dealer = player.seat == view.button_seat
	result.is_small_blind = player.seat == view.small_blind_seat
	result.is_big_blind = player.seat == view.big_blind_seat
	var positions: Array[String] = []
	if result.is_dealer:
		positions.append("D")
	if result.is_small_blind:
		positions.append("SB")
	if result.is_big_blind:
		positions.append("BB")
	result.markers = " ".join(positions)
	result._build_badges()
	var record: PublicActionRecord = (
		latest if latest != null and latest.seat == player.seat else null
	)
	if record == null and retained_fold != null and retained_fold.seat == player.seat:
		record = retained_fold
	result.latest_action_text = format_action(record, density)
	var active: PublicActionRecord = (
		latest if latest != null and latest.seat == player.seat else null
	)
	result.compact_action_text = format_compact_action(active)
	result.compact_action_exact_text = format_compact_action(active, false)
	result.pre_showdown_winner = (
		view.hand_complete
		and view.hand_winner_seat == player.seat
		and view.hand_winner_seat != Table.NO_SEAT
		and view.showdown_results.is_empty()
	)
	var hand: ShowdownResult = view.showdown_results.get(player.seat)
	result.status_full = ShowdownHandFormatter.format(hand)
	result.status_compact = ShowdownHandFormatter.format_compact(hand)
	result.status_inline = ShowdownHandFormatter.format_inline(hand)
	result.status_text = (
		result.status_full
		if density == GuiFitCandidate.Density.FULL
		else (
			result.status_compact
			if density == GuiFitCandidate.Density.COMPACT
			else result.status_inline
		)
	)
	if result.status_text.is_empty():
		result.status_text = "Winner" if result.pre_showdown_winner else result.latest_action_text
	result.winner_emphasis = result.pre_showdown_winner
	for award: PotAward in view.pot_awards:
		if player.seat in award.winner_seats:
			result.winner_emphasis = true
			if award.pot_index == 0 and hand != null:
				result.main_pot_winner = true
	if view.pot_awards.is_empty() and view.hand_winner_seat == player.seat:
		result.winner_emphasis = true
	return result


static func format_action(
	record: PublicActionRecord, density: GuiFitCandidate.Density = GuiFitCandidate.Density.FULL
) -> String:
	if record == null:
		return ""
	var text: String = ""
	if record.record_kind == PublicActionRecord.Kind.SMALL_BLIND:
		text = "Small blind %d" % record.amount
	elif record.record_kind == PublicActionRecord.Kind.BIG_BLIND:
		text = "Big blind %d" % record.amount
	else:
		match record.kind:
			PlayerAction.Kind.FOLD:
				text = "Fold"
			PlayerAction.Kind.CHECK:
				text = "Check"
			PlayerAction.Kind.CALL:
				text = "Call to %d" % record.amount
			PlayerAction.Kind.BET:
				text = "Bet to %d" % record.amount
			PlayerAction.Kind.RAISE:
				text = "Raise to %d" % record.amount
			PlayerAction.Kind.ALL_IN:
				text = "All-in to %d" % record.amount
	if record.amount >= 100000 and density != GuiFitCandidate.Density.FULL:
		text = text.replace(" to ", " ")
	return text


static func format_compact_action(
	record: PublicActionRecord, abbreviate_exact_thousands: bool = true
) -> String:
	if record == null or record.record_kind != PublicActionRecord.Kind.ACTION:
		return ""
	match record.kind:
		PlayerAction.Kind.FOLD:
			return "F"
		PlayerAction.Kind.CHECK:
			return "Chk"
		PlayerAction.Kind.CALL:
			return "C%d" % record.amount
		PlayerAction.Kind.BET:
			return "B%d" % record.amount
		PlayerAction.Kind.RAISE:
			return "R%d" % record.amount
		PlayerAction.Kind.ALL_IN:
			return (
				"A%dk" % (record.amount / 1000)
				if (
					abbreviate_exact_thousands
					and record.amount >= 1000
					and record.amount % 1000 == 0
				)
				else "A%d" % record.amount
			)
	return ""


func _build_badges() -> void:
	var detail: Array[String] = []
	if not markers.is_empty():
		detail.append(markers)
	if acting:
		detail.append("Turn")
	var token: Array[String] = []
	if not markers.is_empty() and not busted:
		token.append(markers.replace(" ", ""))
	if folded:
		detail.append("Fold")
		token.append("F")
	elif all_in:
		detail.append("AI")
		token.append("AI")
	elif busted:
		detail.append("Out")
		token.append("Out")
	elif acting:
		token.append("T")
	badge_text = " ".join(detail)
	token_badge_text = "".join(token) if all_in else " ".join(token)
