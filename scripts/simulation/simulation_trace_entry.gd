class_name SimulationTraceEntry
extends RefCounted

## Recipient-safe trace payload. It intentionally contains no card values.

enum Kind { DECISION, HAND_OUTCOME, ERROR }

var kind: Kind
var tournament_index: int
var hand_number: int
var seat: int
var profile_id: StringName
var street: StringName
var selected_branch: StringName
var hand_potential_band: StringName
var action_kind: PlayerAction.Kind = PlayerAction.Kind.FOLD
var action_amount: int
var winner_seat: int = Table.NO_SEAT
var termination_reason: StringName
var message: String


static func decision(
	index: int,
	hand: int,
	decision_seat: int,
	decision_profile_id: StringName,
	decision_street: StringName,
	trace: RefCounted,
	decision_action: PlayerAction,
) -> SimulationTraceEntry:
	var entry := SimulationTraceEntry.new()
	entry.kind = Kind.DECISION
	entry.tournament_index = index
	entry.hand_number = hand
	entry.seat = decision_seat
	entry.profile_id = decision_profile_id
	entry.street = decision_street
	if trace != null:
		entry.selected_branch = trace.selected_branch
		entry.hand_potential_band = trace.hand_potential_band
	if decision_action != null:
		entry.action_kind = decision_action.kind
		entry.action_amount = decision_action.amount
	return entry


static func hand_outcome(
	index: int, hand: int, hand_winner: int, reason: StringName
) -> SimulationTraceEntry:
	var entry := SimulationTraceEntry.new()
	entry.kind = Kind.HAND_OUTCOME
	entry.tournament_index = index
	entry.hand_number = hand
	entry.winner_seat = hand_winner
	entry.termination_reason = reason
	return entry


static func error(index: int, diagnostic: String) -> SimulationTraceEntry:
	var entry := SimulationTraceEntry.new()
	entry.kind = Kind.ERROR
	entry.tournament_index = index
	entry.message = diagnostic
	return entry


func copy() -> SimulationTraceEntry:
	var copied := SimulationTraceEntry.new()
	for property: StringName in [
		"kind",
		"tournament_index",
		"hand_number",
		"seat",
		"profile_id",
		"street",
		"selected_branch",
		"hand_potential_band",
		"action_kind",
		"action_amount",
		"winner_seat",
		"termination_reason",
		"message",
	]:
		copied.set(property, get(property))
	return copied
