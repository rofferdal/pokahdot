class_name SimulationTournamentMetrics
extends RefCounted

## Event-derived metrics for one completed tournament.
##
## Inputs are public action records, public stack snapshots, and domain events;
## the collector never receives hole cards, a deck, or a mutable core object.

const SEAT_METRICS_SCRIPT := preload("res://scripts/simulation/simulation_seat_metrics.gd")

var _by_seat: Dictionary = {}


func _init(seat_profiles: Dictionary[int, StringName], starting_stacks: Dictionary[int, int]) -> void:
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
	var actions := _actions_by_event_phase(public_actions, events)
	for action_data: Dictionary in actions:
		var seat: int = action_data.seat
		if not _by_seat.has(seat):
			continue
		var metric = _by_seat[seat]
		if action_data.invalid:
			metric.invalid_action_fallbacks += 1
		if not action_data.preflop or action_data.record == null:
			continue
		var action: PublicActionRecord = action_data.record
		if action.kind in [PlayerAction.Kind.CALL, PlayerAction.Kind.BET, PlayerAction.Kind.RAISE, PlayerAction.Kind.ALL_IN]:
			metric.vpip_hands += 1
		if action.kind in [PlayerAction.Kind.RAISE, PlayerAction.Kind.BET]:
			metric.pfr_hands += 1
		if action.kind in [PlayerAction.Kind.BET, PlayerAction.Kind.RAISE]:
			metric.aggressive_actions += 1
		elif action.kind == PlayerAction.Kind.CALL:
			metric.calls += 1


func finish(final_stacks: Dictionary[int, int], winner_seat: int, hand_count: int) -> void:
	var ordered_seats: Array = _by_seat.keys()
	ordered_seats.sort_custom(func(left: int, right: int) -> bool:
		if final_stacks[left] == final_stacks[right]:
			return left < right
		return final_stacks[left] > final_stacks[right]
	)
	for index: int in range(ordered_seats.size()):
		var seat: int = ordered_seats[index]
		_by_seat[seat].finish(final_stacks[seat], index + 1, seat == winner_seat, _by_seat.size(), hand_count)


func get_seat_metrics() -> Dictionary:
	return _by_seat.duplicate()


func _actions_by_event_phase(
	public_actions: Array[PublicActionRecord], events: Array[DomainEvent]
) -> Array[Dictionary]:
	var applied: Array[PublicActionRecord] = []
	for action: PublicActionRecord in public_actions:
		if action.record_kind == PublicActionRecord.Kind.ACTION:
			applied.append(action)
	var output: Array[Dictionary] = []
	var action_index: int = 0
	var preflop: bool = true
	for event: DomainEvent in events:
		if event.kind == DomainEvent.Kind.STREET_CHANGED:
			preflop = false
		elif event.kind == DomainEvent.Kind.ACTION_REJECTED:
			output.append({"seat": event.seat, "record": null, "preflop": preflop, "invalid": true})
		elif event.kind == DomainEvent.Kind.ACTION_APPLIED and action_index < applied.size():
			output.append({"seat": event.seat, "record": applied[action_index], "preflop": preflop, "invalid": false})
			action_index += 1
	return output
