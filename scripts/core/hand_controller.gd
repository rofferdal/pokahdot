class_name HandController
extends RefCounted

enum State {
	NOT_STARTED,
	PREFLOP,
	COMPLETE,
	ABORTED,
}

var state: State = State.NOT_STARTED
var winner_seat: int = Table.NO_SEAT
var events: Array[DomainEvent]:
	get:
		return _events.duplicate()

var _table: Table
var _deck: Deck
var _deck_rng: RandomNumberGenerator
var _button_rng: RandomNumberGenerator
var _pots := PotManager.new()
var _betting: BettingRound
var _history: Array[PublicActionRecord] = []
var _events: Array[DomainEvent] = []


func _init(
	table: Table,
	deck: Deck,
	deck_rng: RandomNumberGenerator,
	button_rng: RandomNumberGenerator,
) -> void:
	_table = table
	_deck = deck
	_deck_rng = deck_rng
	_button_rng = button_rng


func start() -> StepResult:
	if state != State.NOT_STARTED:
		return StepResult.new(StepResult.Status.ERROR, "The hand has already started.")
	if _table.button_seat == Table.NO_SEAT:
		_table.choose_initial_button(_button_rng)
	for player: Player in _table.players:
		player.reset_for_hand()
	_deck.reset()
	_deck.shuffle(_deck_rng)
	_events.append(DomainEvent.new(DomainEvent.Kind.HAND_STARTED))
	_post_blind(_table.small_blind_seat(), _table.small_blind)
	_post_blind(_table.big_blind_seat(), _table.big_blind)
	_deal_hole_cards()
	_betting = BettingRound.new(_table, _table.first_to_act_preflop(), _largest_round_bet())
	state = State.PREFLOP
	return advance_until_blocked()


func advance_until_blocked(max_transitions: int = 32) -> StepResult:
	if state == State.COMPLETE:
		return StepResult.new(StepResult.Status.HAND_COMPLETED)
	if state != State.PREFLOP:
		return StepResult.new(StepResult.Status.ERROR, "The hand is not active.")
	for _transition: int in range(maxi(1, max_transitions)):
		if _betting.is_complete():
			return _finish_preflop()
		var player: Player = _table.get_player(_betting.acting_seat)
		var agent := player.agent as Agent
		if agent == null:
			return StepResult.new(StepResult.Status.ERROR, "The acting player has no agent.")
		var view: GameView = get_view_for(player.seat)
		if agent is HumanAgent and not (agent as HumanAgent).has_pending_action():
			return StepResult.new(StepResult.Status.WAITING_FOR_HUMAN)
		var action: PlayerAction = agent.choose_action(view)
		_apply_with_fallback(player.seat, action)
	return StepResult.new(StepResult.Status.YIELDED)


func submit_human_action(action: PlayerAction) -> StepResult:
	if state != State.PREFLOP:
		return StepResult.new(StepResult.Status.ERROR, "The hand is not accepting actions.")
	var player: Player = _table.get_player(_betting.acting_seat)
	if player == null or not player.agent is HumanAgent:
		return StepResult.new(StepResult.Status.ERROR, "It is not a human player's turn.")
	var result: ActionValidationResult = _betting.apply_action(player.seat, action)
	if not result.is_ok():
		_events.append(DomainEvent.new(DomainEvent.Kind.ACTION_REJECTED, player.seat))
		return StepResult.new(StepResult.Status.WAITING_FOR_HUMAN, result.message)
	_record_action(player.seat, action, result.chips_committed)
	return advance_until_blocked()


func get_view_for(seat: int) -> GameView:
	var view := GameView.for_preflop(_table, seat, _betting, _pots, _history)
	view.hand_complete = state == State.COMPLETE
	view.hand_winner_seat = winner_seat
	return view


func abort() -> void:
	state = State.ABORTED


func _post_blind(seat: int, blind: int) -> void:
	var committed: int = _table.get_player(seat).commit_chips(blind)
	_pots.record_contribution(seat, committed)
	_history.append(PublicActionRecord.blind(seat, committed, seat == _table.small_blind_seat()))
	_events.append(DomainEvent.new(DomainEvent.Kind.BLIND_POSTED, seat, committed))


func _deal_hole_cards() -> void:
	var seat: int = _table.first_to_receive_card()
	for _card_index: int in range(2):
		for _player_index: int in range(_table.active_player_count()):
			_table.get_player(seat).add_hole_card(_deck.draw())
			seat = _table.next_active_seat(seat)
	_events.append(DomainEvent.new(DomainEvent.Kind.CARDS_DEALT))


func _apply_with_fallback(seat: int, action: PlayerAction) -> void:
	var result: ActionValidationResult = _betting.apply_action(seat, action)
	if not result.is_ok():
		_events.append(DomainEvent.new(DomainEvent.Kind.ACTION_REJECTED, seat))
		action = _fallback_action(seat)
		result = _betting.apply_action(seat, action)
	_record_action(seat, action, result.chips_committed)


func _fallback_action(seat: int) -> PlayerAction:
	var legal: Array[PlayerAction.Kind] = _betting.legal_actions(seat)
	if PlayerAction.Kind.CHECK in legal:
		return PlayerAction.check_action()
	if PlayerAction.Kind.CALL in legal:
		return PlayerAction.call_action()
	return PlayerAction.fold_action()


func _record_action(seat: int, action: PlayerAction, committed: int) -> void:
	_pots.record_contribution(seat, committed)
	var public_amount: int = _table.get_player(seat).bet_this_round
	var record := PublicActionRecord.new(seat, action.kind, public_amount)
	_history.append(record)
	_events.append(DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, seat, public_amount))
	for player: Player in _table.players:
		var observer := player.agent as Agent
		if observer != null:
			observer.observe(record)


func _finish_preflop() -> StepResult:
	var remaining: Array[int] = []
	for seat: int in _table.active_seats():
		if not _table.get_player(seat).folded:
			remaining.append(seat)
	if remaining.size() != 1:
		return StepResult.new(StepResult.Status.PREFLOP_COMPLETE)
	winner_seat = remaining[0]
	var awarded: int = _pots.award_single_winner(_table.get_player(winner_seat))
	_events.append(DomainEvent.new(DomainEvent.Kind.POT_AWARDED, winner_seat, awarded))
	_events.append(DomainEvent.new(DomainEvent.Kind.HAND_COMPLETED, winner_seat))
	state = State.COMPLETE
	return StepResult.new(StepResult.Status.HAND_COMPLETED)


func _largest_round_bet() -> int:
	var largest: int = 0
	for player: Player in _table.players:
		largest = maxi(largest, player.bet_this_round)
	return largest
