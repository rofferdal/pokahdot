class_name Player
extends RefCounted

## Mutable runtime state for one tournament participant.

var player_id: StringName
var display_name: String
var seat: int
var agent: RefCounted
var folded: bool = false
var all_in: bool = false
var busted: bool = false
var bet_this_round: int = 0
var total_contribution: int = 0

var stack: int:
	get:
		return _stack.amount
var hole_cards: Array[CardData]:
	get:
		return _hole_cards.duplicate()

var _stack: ChipStack
var _hole_cards: Array[CardData] = []


func _init(
	participant_id: StringName,
	participant_name: String,
	seat_index: int,
	starting_stack: int,
	participant_agent: RefCounted = null,
) -> void:
	assert(not participant_id.is_empty(), "A player ID is required.")
	assert(not participant_name.is_empty(), "A player display name is required.")
	assert(seat_index >= 0, "A player seat cannot be negative.")
	player_id = participant_id
	display_name = participant_name
	seat = seat_index
	agent = participant_agent
	_stack = ChipStack.new(starting_stack)
	busted = starting_stack == 0


func commit_chips(requested_amount: int) -> int:
	var committed: int = _stack.debit(requested_amount)
	bet_this_round += committed
	total_contribution += committed
	all_in = _stack.amount == 0 and not busted
	return committed


func award_chips(amount: int) -> bool:
	return _stack.credit(amount)


func add_hole_card(card: CardData) -> bool:
	if card == null or _hole_cards.size() >= 2 or busted:
		return false
	_hole_cards.append(card)
	return true


func fold() -> void:
	folded = true


func reset_betting_round() -> void:
	bet_this_round = 0


func reset_for_hand() -> void:
	_hole_cards.clear()
	folded = false
	all_in = false
	bet_this_round = 0
	total_contribution = 0


func update_busted_status() -> void:
	busted = _stack.amount == 0
