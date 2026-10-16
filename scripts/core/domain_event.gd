class_name DomainEvent
extends RefCounted

enum Kind {
	HAND_STARTED,
	BLIND_POSTED,
	CARDS_DEALT,
	ACTION_APPLIED,
	ACTION_REJECTED,
	POT_AWARDED,
	HAND_COMPLETED,
	PLAYER_QUIT,
}

var kind: Kind
var seat: int
var amount: int
var message: String


func _init(event_kind: Kind, event_seat: int = Table.NO_SEAT, event_amount: int = 0) -> void:
	kind = event_kind
	seat = event_seat
	amount = event_amount
