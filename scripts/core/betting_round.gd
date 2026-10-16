class_name BettingRound
extends RefCounted

## Validates and applies action for one betting street.

var acting_seat: int = Table.NO_SEAT
var current_bet: int

var _table: Table
var _pending_action: Dictionary[int, bool] = {}
var _raise_rights: Dictionary[int, bool] = {}
var _complete: bool = false


func _init(
	table: Table,
	first_seat: int,
	initial_current_bet: int = 0,
) -> void:
	assert(table != null, "A betting round requires a table.")
	assert(initial_current_bet >= 0, "The current bet cannot be negative.")
	_table = table
	current_bet = initial_current_bet
	for seat: int in table.active_seats():
		var player: Player = table.get_player(seat)
		if _can_act(player):
			_pending_action[seat] = true
			_raise_rights[seat] = true
	_refresh_completion()
	if not _complete:
		acting_seat = _next_pending_seat(first_seat - 1)


func is_complete() -> bool:
	return _complete


func pending_seats() -> Array[int]:
	var seats: Array[int] = []
	for seat: int in _pending_action:
		seats.append(seat)
	seats.sort()
	return seats


func can_raise(seat: int) -> bool:
	return _raise_rights.has(seat) and _can_act(_table.get_player(seat))


func call_amount(seat: int) -> int:
	var player: Player = _table.get_player(seat)
	if player == null:
		return 0
	return mini(player.stack, maxi(0, current_bet - player.bet_this_round))


func minimum_wager_total() -> int:
	if current_bet == 0:
		return _table.big_blind
	return current_bet + _table.big_blind


func maximum_wager_total(seat: int) -> int:
	var player: Player = _table.get_player(seat)
	if player == null:
		return 0
	return player.bet_this_round + player.stack


func legal_actions(seat: int) -> Array[PlayerAction.Kind]:
	var result: Array[PlayerAction.Kind] = []
	if _complete or seat != acting_seat:
		return result
	var player: Player = _table.get_player(seat)
	if not _can_act(player):
		return result

	result.append(PlayerAction.Kind.FOLD)
	if player.bet_this_round == current_bet:
		result.append(PlayerAction.Kind.CHECK)
	else:
		result.append(PlayerAction.Kind.CALL)

	var maximum: int = maximum_wager_total(seat)
	if maximum > current_bet and can_raise(seat):
		if current_bet == 0:
			result.append(PlayerAction.Kind.BET)
		else:
			result.append(PlayerAction.Kind.RAISE)
	if player.stack > 0:
		result.append(PlayerAction.Kind.ALL_IN)
	return result


func apply_action(seat: int, action: PlayerAction) -> ActionValidationResult:
	var validation: ActionValidationResult = _validate_action(seat, action)
	if not validation.is_ok():
		return validation

	var player: Player = _table.get_player(seat)
	var previous_current_bet: int = current_bet
	var target_total: int = _target_total(player, action)
	var committed: int = 0

	match action.kind:
		PlayerAction.Kind.FOLD:
			player.fold()
		PlayerAction.Kind.CHECK:
			pass
		PlayerAction.Kind.CALL:
			committed = player.commit_chips(call_amount(seat))
		PlayerAction.Kind.BET, PlayerAction.Kind.RAISE, PlayerAction.Kind.ALL_IN:
			committed = player.commit_chips(target_total - player.bet_this_round)

	_pending_action.erase(seat)
	_raise_rights.erase(seat)
	if target_total > previous_current_bet:
		var raise_size: int = target_total - previous_current_bet
		current_bet = target_total
		if raise_size >= _table.big_blind:
			_reopen_after_full_raise(seat)
		else:
			_require_calls_after_short_raise(seat)

	_refresh_completion()
	if not _complete:
		acting_seat = _next_pending_seat(seat)
	return ActionValidationResult.accepted(committed)


func _validate_action(seat: int, action: PlayerAction) -> ActionValidationResult:
	var result: ActionValidationResult = null
	if _complete:
		result = _reject(
			ActionValidationResult.Code.ROUND_COMPLETE, "The betting round is complete."
		)
	elif seat != acting_seat:
		result = _reject(
			ActionValidationResult.Code.NOT_ACTING_PLAYER, "It is not this seat's turn."
		)
	var player: Player = _table.get_player(seat)
	if result == null and not _can_act(player):
		result = _reject(ActionValidationResult.Code.PLAYER_CANNOT_ACT, "This player cannot act.")
	if result == null and (action == null or not action.has_valid_shape()):
		result = _reject(
			ActionValidationResult.Code.INVALID_AMOUNT, "The action amount is invalid."
		)
	if result == null and action.kind not in legal_actions(seat):
		if action.kind == PlayerAction.Kind.RAISE and not can_raise(seat):
			result = _reject(
				ActionValidationResult.Code.RAISE_NOT_REOPENED,
				"A short all-in did not reopen raising for this player.",
			)
		else:
			result = _reject(
				ActionValidationResult.Code.ACTION_NOT_AVAILABLE,
				"That action is not currently available.",
			)
	if (
		result == null
		and (action.kind == PlayerAction.Kind.BET or action.kind == PlayerAction.Kind.RAISE)
	):
		var maximum: int = maximum_wager_total(seat)
		if action.amount > maximum:
			result = _reject(
				ActionValidationResult.Code.ABOVE_MAXIMUM, "The wager exceeds the stack."
			)
		elif action.amount < minimum_wager_total():
			result = _reject(
				ActionValidationResult.Code.BELOW_MINIMUM,
				"The wager is below the minimum full bet or raise.",
			)
	return result if result != null else ActionValidationResult.accepted()


func _target_total(player: Player, action: PlayerAction) -> int:
	match action.kind:
		PlayerAction.Kind.CALL:
			return player.bet_this_round + call_amount(player.seat)
		PlayerAction.Kind.BET, PlayerAction.Kind.RAISE:
			return action.amount
		PlayerAction.Kind.ALL_IN:
			return player.bet_this_round + player.stack
	return player.bet_this_round


func _reopen_after_full_raise(raising_seat: int) -> void:
	_pending_action.clear()
	_raise_rights.clear()
	for seat: int in _table.active_seats():
		var player: Player = _table.get_player(seat)
		if seat != raising_seat and _can_act(player):
			_pending_action[seat] = true
			_raise_rights[seat] = true


func _require_calls_after_short_raise(raising_seat: int) -> void:
	for seat: int in _table.active_seats():
		var player: Player = _table.get_player(seat)
		if seat != raising_seat and _can_act(player) and player.bet_this_round < current_bet:
			_pending_action[seat] = true


func _refresh_completion() -> void:
	for seat: int in _pending_action.keys():
		if not _can_act(_table.get_player(seat)):
			_pending_action.erase(seat)
			_raise_rights.erase(seat)
	_complete = _remaining_player_count() <= 1 or _pending_action.is_empty()
	if _complete:
		acting_seat = Table.NO_SEAT


func _remaining_player_count() -> int:
	var count: int = 0
	for seat: int in _table.active_seats():
		if not _table.get_player(seat).folded:
			count += 1
	return count


func _next_pending_seat(from_seat: int) -> int:
	var candidate: int = from_seat
	for _offset: int in range(_table.players.size()):
		candidate = _table.next_active_seat(candidate)
		if _pending_action.has(candidate):
			return candidate
	return Table.NO_SEAT


func _can_act(player: Player) -> bool:
	return player != null and not player.busted and not player.folded and not player.all_in


func _reject(code: ActionValidationResult.Code, message: String) -> ActionValidationResult:
	return ActionValidationResult.rejected(code, message)
