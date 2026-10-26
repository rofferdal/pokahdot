class_name SimulationTournamentMetrics
extends RefCounted

## Event-derived metrics for one completed tournament.
##
## Inputs are public action records, public stack snapshots, and domain events;
## the collector never receives hole cards, a deck, or a mutable core object.

const SEAT_METRICS_SCRIPT := preload("res://scripts/simulation/simulation_seat_metrics.gd")

var _by_seat: Dictionary = {}
var _elimination_cohorts: Array = []
var _eliminated_seats: Dictionary = {}


func _init(
	seat_profiles: Dictionary[int, StringName], starting_stacks: Dictionary[int, int]
) -> void:
	for seat: int in seat_profiles:
		_by_seat[seat] = SEAT_METRICS_SCRIPT.new(seat_profiles[seat], seat, starting_stacks[seat])


func observe_hand(
	active_at_start: Array[int],
	stacks_before: Dictionary[int, int],
	stacks_after: Dictionary[int, int],
	big_blind_at_start: int,
	public_actions: Array[PublicActionRecord],
	events: Array[DomainEvent],
) -> void:
	_record_eliminations(active_at_start, stacks_before, stacks_after)
	if big_blind_at_start <= 0:
		return
	for seat: int in active_at_start:
		if not _by_seat.has(seat) or not stacks_before.has(seat) or not stacks_after.has(seat):
			continue
		var metric = _by_seat[seat]
		metric.hands_survived += 1
		metric.hands_observed += 1
		metric.blind_normalized_chip_sum += (
			float(stacks_after[seat] - stacks_before[seat]) / float(big_blind_at_start)
		)
	var voluntary_seats: Dictionary = {}
	var preflop_raiser_seats: Dictionary = {}
	var actions := _actions_by_event_phase(public_actions, events)
	for action_data: Dictionary in actions:
		var seat: int = action_data.seat
		if not _by_seat.has(seat):
			continue
		var metric = _by_seat[seat]
		if action_data.invalid:
			metric.invalid_action_fallbacks += 1
		if action_data.record == null:
			continue
		var action: PublicActionRecord = action_data.record
		if action_data.opening_aggressive:
			metric.bet_actions += 1
			metric.aggressive_actions += 1
		elif action_data.aggressive:
			metric.raise_actions += 1
			metric.aggressive_actions += 1
		elif action_data.passive_call:
			metric.call_actions += 1
		if not action_data.preflop:
			continue
		if (
			action.kind
			in [
				PlayerAction.Kind.CALL,
				PlayerAction.Kind.BET,
				PlayerAction.Kind.RAISE,
				PlayerAction.Kind.ALL_IN,
			]
		):
			voluntary_seats[seat] = true
		if action_data.aggressive:
			preflop_raiser_seats[seat] = true
	for seat: int in voluntary_seats:
		_by_seat[seat].vpip_hands += 1
	for seat: int in preflop_raiser_seats:
		_by_seat[seat].pfr_hands += 1


func observe_decision(
	seat: int,
	legal_actions: Array[PlayerAction.Kind],
	action: PlayerAction,
	trace: RefCounted = null,
	all_in_aggression_kind: int = -1,
) -> void:
	if not _by_seat.has(seat) or action == null:
		return
	var metric = _by_seat[seat]
	var has_full_bet: bool = PlayerAction.Kind.BET in legal_actions
	var has_full_raise: bool = PlayerAction.Kind.RAISE in legal_actions
	var has_bet: bool = has_full_bet or all_in_aggression_kind == PlayerAction.Kind.BET
	var has_raise: bool = has_full_raise or all_in_aggression_kind == PlayerAction.Kind.RAISE
	var selected_bet: bool = (
		action.kind == PlayerAction.Kind.BET
		or (action.kind == PlayerAction.Kind.ALL_IN and has_bet)
	)
	var selected_raise: bool = (
		action.kind == PlayerAction.Kind.RAISE
		or (action.kind == PlayerAction.Kind.ALL_IN and has_raise)
	)
	var selected_call: bool = (
		action.kind == PlayerAction.Kind.CALL
		or (
			action.kind == PlayerAction.Kind.ALL_IN
			and PlayerAction.Kind.CALL in legal_actions
			and not has_raise
		)
	)
	if has_bet or has_raise:
		metric.bet_raise_opportunities += 1
	if has_bet and PlayerAction.Kind.CHECK in legal_actions:
		metric.check_bet_opportunities += 1
		if selected_bet:
			metric.bets_at_check_bet_opportunity += 1
	if has_raise and PlayerAction.Kind.CALL in legal_actions:
		metric.call_raise_opportunities += 1
		if selected_call:
			metric.calls_at_call_raise_opportunity += 1
		elif selected_raise:
			metric.raises_at_call_raise_opportunity += 1
	if trace == null:
		return
	if (
		trace.hand_potential_band == StrategyDecisionTrace.WEAK_BAND
		and (has_full_bet or has_full_raise)
	):
		metric.eligible_bluff_opportunities += 1
		if trace.selected_branch in [&"bluff_bet", &"bluff_raise"]:
			metric.bluff_actions += 1


func finish(final_stacks: Dictionary[int, int], winner_seat: int, hand_count: int) -> void:
	var positions: Dictionary[int, int] = {}
	var has_winner: bool = winner_seat != Table.NO_SEAT and _by_seat.has(winner_seat)
	if has_winner:
		positions[winner_seat] = 1
	var next_position: int = 2 if has_winner else 1
	for cohort_index: int in range(_elimination_cohorts.size() - 1, -1, -1):
		var cohort: Array = _elimination_cohorts[cohort_index]
		var ranked_in_cohort: int = 0
		for seat: int in cohort:
			if seat == winner_seat or positions.has(seat) or not _by_seat.has(seat):
				continue
			positions[seat] = next_position
			ranked_in_cohort += 1
		next_position += ranked_in_cohort
	var untracked_seats: Array = []
	for seat: int in _by_seat:
		if not positions.has(seat):
			untracked_seats.append(seat)
	for seat: int in untracked_seats:
		positions[seat] = next_position
	for seat: int in _by_seat:
		(
			_by_seat[seat]
			. finish(
				final_stacks.get(seat, 0),
				positions[seat],
				seat == winner_seat,
				_by_seat.size(),
				hand_count,
			)
		)


func get_seat_metrics() -> Dictionary:
	return _by_seat.duplicate()


func _record_eliminations(
	active_at_start: Array[int],
	stacks_before: Dictionary[int, int],
	stacks_after: Dictionary[int, int],
) -> void:
	var cohort: Array[int] = []
	for seat: int in active_at_start:
		if _eliminated_seats.has(seat):
			continue
		if stacks_before.get(seat, 0) > 0 and stacks_after.get(seat, 0) == 0:
			cohort.append(seat)
			_eliminated_seats[seat] = true
	if not cohort.is_empty():
		_elimination_cohorts.append(cohort)


func _actions_by_event_phase(
	public_actions: Array[PublicActionRecord], events: Array[DomainEvent]
) -> Array[Dictionary]:
	var applied: Array[PublicActionRecord] = []
	var current_bet: int = 0
	for action: PublicActionRecord in public_actions:
		if action.record_kind == PublicActionRecord.Kind.ACTION:
			applied.append(action)
		else:
			current_bet = maxi(current_bet, action.amount)
	var output: Array[Dictionary] = []
	var action_index: int = 0
	var preflop: bool = true
	for event: DomainEvent in events:
		if event.kind == DomainEvent.Kind.STREET_CHANGED:
			preflop = false
			current_bet = 0
		elif event.kind == DomainEvent.Kind.ACTION_REJECTED:
			output.append({"seat": event.seat, "record": null, "preflop": preflop, "invalid": true})
		elif event.kind == DomainEvent.Kind.ACTION_APPLIED and action_index < applied.size():
			var action: PublicActionRecord = applied[action_index]
			var aggressive: bool = action.kind in [PlayerAction.Kind.BET, PlayerAction.Kind.RAISE]
			if action.kind == PlayerAction.Kind.ALL_IN:
				aggressive = action.amount > current_bet
			var opening_aggressive: bool = aggressive and current_bet == 0
			(
				output
				. append(
					{
						"seat": event.seat,
						"record": action,
						"preflop": preflop,
						"invalid": false,
						"aggressive": aggressive,
						"opening_aggressive": opening_aggressive,
						"passive_call":
						(
							action.kind == PlayerAction.Kind.CALL
							or (action.kind == PlayerAction.Kind.ALL_IN and not aggressive)
						),
					}
				)
			)
			current_bet = maxi(current_bet, action.amount)
			action_index += 1
	return output
