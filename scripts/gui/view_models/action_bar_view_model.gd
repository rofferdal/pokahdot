class_name ActionBarViewModel
extends RefCounted

## Detached action copy and availability from the recipient-safe legal-action list.
var valid: bool = false
var error: String = ""
var legal_actions: Array[int] = []
var action_roles: Dictionary[int, Array] = {}
var is_human_turn: bool = false
var can_wager: bool = false
var can_continue: bool = false
var fold_enabled: bool = false
var check_call_enabled: bool = false
var minimum_enabled: bool = false
var pot_enabled: bool = false
var wager_enabled: bool = false
var all_in_enabled: bool = false
var fold_visible: bool = false
var check_call_visible: bool = false
var minimum_visible: bool = false
var pot_visible: bool = false
var wager_visible: bool = false
var all_in_visible: bool = false
var phone_fold_visible: bool = false
var phone_check_call_visible: bool = false
var phone_minimum_visible: bool = false
var phone_pot_visible: bool = false
var phone_wager_visible: bool = false
var phone_all_in_visible: bool = false
var check_call_text: String = "Check / Call"
var minimum_text: String = ""
var pot_text: String = ""
var wager_text: String = "Raise"
var all_in_text: String = "All-in"
var input_placeholder: String = "Wager total"
var minimum_total: int = 0
var maximum_total: int = 0
var pot_contribution: int = 0
var pot_total: int = 0
var pot_reason: StringName = PotWagerTarget.INVALID_INPUT
var status_text: String = ""
var phone_status_text: String = ""
var status_full: String = ""
var status_compact: String = ""
var reference_status_text: String = ""
var reference_status_full: String = ""
var reference_status_compact: String = ""


static func build(
	view: GameView,
	names: Dictionary[int, String] = {},
	density: GuiFitCandidate.Density = GuiFitCandidate.Density.FULL
) -> ActionBarViewModel:
	var result := ActionBarViewModel.new()
	if view == null:
		result.error = "An action model requires a recipient-safe view."
		return result
	result.valid = true
	result.can_continue = view.hand_complete and view.tournament_status != &"finished"
	result.is_human_turn = view.acting_seat == view.hero_seat
	var legal: Array[PlayerAction.Kind] = []
	if result.is_human_turn:
		legal = view.legal_actions
	for kind: PlayerAction.Kind in legal:
		result.legal_actions.append(kind)
		match kind:
			PlayerAction.Kind.FOLD:
				result.action_roles[kind] = [&"fold"]
			PlayerAction.Kind.CHECK, PlayerAction.Kind.CALL:
				result.action_roles[kind] = [&"check_call"]
			PlayerAction.Kind.BET, PlayerAction.Kind.RAISE:
				result.action_roles[kind] = [&"wager", &"minimum", &"pot"]
			PlayerAction.Kind.ALL_IN:
				result.action_roles[kind] = [&"all_in"]
	result.can_wager = PlayerAction.Kind.BET in legal or PlayerAction.Kind.RAISE in legal
	result.fold_enabled = PlayerAction.Kind.FOLD in legal
	result.check_call_enabled = PlayerAction.Kind.CHECK in legal or PlayerAction.Kind.CALL in legal
	result.minimum_enabled = result.can_wager
	result.wager_enabled = result.can_wager
	result.all_in_enabled = PlayerAction.Kind.ALL_IN in legal
	var pot: PotWagerTargetResult = resolve_pot_target(view)
	result.pot_enabled = result.can_wager and pot.available
	result.pot_contribution = pot.contribution
	result.pot_total = pot.wager_total
	result.pot_reason = pot.reason
	result.minimum_total = view.minimum_wager_total
	result.maximum_total = view.maximum_wager_total
	result.fold_visible = result.fold_enabled
	result.check_call_visible = result.check_call_enabled
	result.minimum_visible = result.can_wager
	result.pot_visible = result.can_wager
	result.wager_visible = result.can_wager
	result.all_in_visible = result.all_in_enabled
	result.phone_fold_visible = result.fold_visible
	result.phone_check_call_visible = result.check_call_visible
	result.phone_wager_visible = result.wager_visible
	result.phone_all_in_visible = result.all_in_visible
	var compact: bool = density != GuiFitCandidate.Density.FULL
	if PlayerAction.Kind.CHECK in legal:
		result.check_call_text = "Check"
	elif PlayerAction.Kind.CALL in legal:
		result.check_call_text = "Call %d" % view.call_amount
	else:
		result.check_call_text = "Call" if compact else "Check / Call"
	result.wager_text = "Bet" if PlayerAction.Kind.BET in legal else "Raise"
	result.minimum_text = (
		"Min %d" % result.minimum_total
		if compact
		else "Min %s %d" % [result.wager_text, result.minimum_total]
	)
	result.pot_text = "Pot %d" % result.pot_contribution
	result.input_placeholder = "Total" if compact else "Wager total"
	result.status_full = _status(view, names, false, false)
	result.status_compact = _status(view, names, true, false)
	result.reference_status_full = _status(view, names, false, true)
	result.reference_status_compact = _status(view, names, true, true)
	result.status_text = result.status_compact if compact else result.status_full
	result.reference_status_text = (
		result.reference_status_compact if compact else result.reference_status_full
	)
	result.phone_status_text = result.status_compact
	return result


static func resolve_pot_target(view: GameView) -> PotWagerTargetResult:
	if view == null:
		return PotWagerTarget.resolve(0, 0, 0, 1, 0)
	var existing_wager: int = -1
	for seat: PlayerView in view.seats:
		if seat.seat == view.hero_seat:
			existing_wager = seat.bet_this_round
			break
	return PotWagerTarget.resolve(
		view.pot_amount,
		existing_wager,
		view.call_amount,
		view.minimum_wager_total,
		view.maximum_wager_total
	)


static func _status(
	view: GameView, names: Dictionary[int, String], compact: bool, reference: bool
) -> String:
	if view.tournament_status == &"finished":
		if view.end_reason == &"winner":
			var winner: String = _name(view, names, view.tournament_winner_seat)
			return "%s wins" % winner if compact else "%s wins the tournament!" % winner
		return GuiTournamentStatusFormatter.format(view)
	var human_turn: bool = view.acting_seat == view.hero_seat
	var street: String = GuiEventFormatter.street_name(view)
	if human_turn:
		return "Your turn: %s" % street if compact else "Your turn — %s." % street
	if view.hand_complete:
		return "Hand complete" if compact else "Hand complete."
	var actor: String = (
		GuiEventFormatter.player_name_for(view, view.acting_seat)
		if reference
		else _name(view, names, view.acting_seat)
	)
	return "Act: %s" % actor if compact else "%s to act — %s" % [actor, street]


static func _name(view: GameView, names: Dictionary[int, String], seat: int) -> String:
	for player: PlayerView in view.seats:
		if player.seat == seat:
			return (
				NameAssignmentService.HUMAN_LABEL
				if player.is_human
				else names.get(seat, player.display_name)
			)
	return "Player %d" % (seat + 1)
