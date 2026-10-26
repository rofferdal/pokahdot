class_name DomainEvent
extends RefCounted

enum Kind {
	HAND_STARTED,
	BLIND_POSTED,
	CARDS_DEALT,
	ACTION_APPLIED,
	ACTION_REJECTED,
	STREET_CHANGED,
	COMMUNITY_CARDS_DEALT,
	SHOWDOWN_STARTED,
	POT_AWARDED,
	HAND_COMPLETED,
	PLAYER_QUIT,
}

var kind: Kind
var seat: int
var amount: int
var message: String = ""
var requested_action_kind: int = -1
var requested_action_amount: int = 0
var applied_action_kind: int = -1
var applied_action_amount: int = 0
var rejection_code: int = -1
var fallback_applied: bool = false


func _init(event_kind: Kind, event_seat: int = Table.NO_SEAT, event_amount: int = 0) -> void:
	kind = event_kind
	seat = event_seat
	amount = event_amount


static func action_rejected(
	event_seat: int,
	requested_action: PlayerAction,
	rejection: ActionValidationResult,
	applied_action: PlayerAction = null,
	applied_public_amount: int = 0,
) -> DomainEvent:
	var event := DomainEvent.new(Kind.ACTION_REJECTED, event_seat)
	if requested_action != null:
		event.requested_action_kind = requested_action.kind
		event.requested_action_amount = requested_action.amount
	if rejection != null:
		event.rejection_code = rejection.code
		event.message = rejection.message
	if applied_action != null:
		event.applied_action_kind = applied_action.kind
		event.applied_action_amount = applied_public_amount
		event.fallback_applied = true
	return event
