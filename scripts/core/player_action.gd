class_name PlayerAction
extends RefCounted

## A request to perform one poker action. Bet and raise amounts are target totals.

enum Kind {
	FOLD,
	CHECK,
	CALL,
	BET,
	RAISE,
	ALL_IN,
}

var kind: Kind:
	get:
		return _kind
var amount: int:
	get:
		return _amount

var _kind: Kind
var _amount: int


func _init(action_kind: Kind, target_amount: int = 0) -> void:
	_kind = action_kind
	_amount = target_amount


func has_wager_amount() -> bool:
	return _kind == Kind.BET or _kind == Kind.RAISE


func has_valid_shape() -> bool:
	if has_wager_amount():
		return _amount > 0
	return _amount == 0


static func fold_action() -> PlayerAction:
	return PlayerAction.new(Kind.FOLD)


static func check_action() -> PlayerAction:
	return PlayerAction.new(Kind.CHECK)


static func call_action() -> PlayerAction:
	return PlayerAction.new(Kind.CALL)


static func bet_to(target_amount: int) -> PlayerAction:
	return PlayerAction.new(Kind.BET, target_amount)


static func raise_to(target_amount: int) -> PlayerAction:
	return PlayerAction.new(Kind.RAISE, target_amount)


static func all_in_action() -> PlayerAction:
	return PlayerAction.new(Kind.ALL_IN)
