class_name PublicActionRecord
extends RefCounted

## Immutable public description of an applied player action.

enum Kind {
	ACTION,
	SMALL_BLIND,
	BIG_BLIND,
}

var record_kind: Kind:
	get:
		return _record_kind

var seat: int:
	get:
		return _seat
var kind: PlayerAction.Kind:
	get:
		return _kind
var amount: int:
	get:
		return _amount

var _seat: int
var _kind: PlayerAction.Kind
var _amount: int
var _record_kind: Kind


func _init(
	action_seat: int,
	action_kind: PlayerAction.Kind,
	public_amount: int = 0,
	public_record_kind: Kind = Kind.ACTION,
) -> void:
	_seat = action_seat
	_kind = action_kind
	_amount = public_amount
	_record_kind = public_record_kind


static func blind(action_seat: int, blind_amount: int, is_small_blind: bool) -> PublicActionRecord:
	return (
		PublicActionRecord
		. new(
			action_seat,
			PlayerAction.Kind.CALL,
			blind_amount,
			Kind.SMALL_BLIND if is_small_blind else Kind.BIG_BLIND,
		)
	)


func copy() -> PublicActionRecord:
	return PublicActionRecord.new(_seat, _kind, _amount, _record_kind)
