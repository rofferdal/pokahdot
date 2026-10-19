class_name HandPotentialContext
extends RefCounted

## Explicit public information supplied to HandPotentialEstimator.
##
## This value object deliberately contains no Table, Player, Deck, GameView, or
## mutable match-state references. Values are copied at construction time.

var street: StringName
var position: int
var active_opponents: int
var pot_size: int
var call_amount: int
var effective_stack: int
var big_blind: int


func _init(
	context_street: StringName = &"preflop",
	context_position: int = 0,
	context_active_opponents: int = 0,
	context_pot_size: int = 0,
	context_call_amount: int = 0,
	context_effective_stack: int = 0,
	context_big_blind: int = 0,
) -> void:
	street = context_street
	position = context_position
	active_opponents = context_active_opponents
	pot_size = context_pot_size
	call_amount = context_call_amount
	effective_stack = context_effective_stack
	big_blind = context_big_blind


func is_valid() -> bool:
	return (
		not street.is_empty()
		and position >= 0
		and active_opponents >= 0
		and pot_size >= 0
		and call_amount >= 0
		and effective_stack >= 0
		and big_blind >= 0
	)
