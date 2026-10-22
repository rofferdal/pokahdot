class_name TournamentMatch
extends RefCounted

enum State {
	NOT_STARTED,
	RUNNING,
	FINISHED,
}

var state: State = State.NOT_STARTED
var end_reason: StringName
var winner_seat: int = Table.NO_SEAT
var hand_number: int = 0

var _config: ResolvedTournamentConfig
var _agents: Dictionary[int, Agent]
var _construction_contract: TournamentConstructionContract
var _streams: RngStreams
var _table: Table
var _hand: HandController
var _blind_progression: BlindLevelProgression
var _configuration_error: String
var _awaiting_next_hand: bool = false


func _init(
	config: ResolvedTournamentConfig,
	seat_agents: Dictionary[int, Agent],
	construction_contract: TournamentConstructionContract = null,
	rng_streams: RngStreams = null,
) -> void:
	_config = config
	_agents = seat_agents.duplicate()
	_construction_contract = (
		TournamentConstructionContract.product()
		if construction_contract == null
		else construction_contract
	)
	_configuration_error = _validate_configuration()
	if _configuration_error.is_empty():
		_streams = RngStreamFactory.new().create(config) if rng_streams == null else rng_streams
		_blind_progression = (
			BlindLevelProgression
			. new(
				config.small_blind,
				config.big_blind,
				config.player_count,
			)
		)


func start(max_transitions: int = 32) -> StepResult:
	if not _configuration_error.is_empty():
		return StepResult.new(StepResult.Status.ERROR, _configuration_error)
	if state != State.NOT_STARTED:
		return StepResult.new(StepResult.Status.ERROR, "The tournament has already started.")
	var players: Array[Player] = []
	for seat: int in range(_config.player_count):
		(
			players
			. append(
				(
					Player
					. new(
						StringName("player_%d" % seat),
						"Player %d" % (seat + 1),
						seat,
						_config.starting_stack,
						_agents[seat],
					)
				)
			)
		)
	_table = Table.new(players, _config.small_blind, _config.big_blind)
	state = State.RUNNING
	return _start_next_hand(max_transitions)


func advance_until_blocked(max_transitions: int = 32) -> StepResult:
	if state != State.RUNNING:
		return StepResult.new(StepResult.Status.ERROR, "The tournament is not running.")
	if _awaiting_next_hand:
		return _start_next_hand()
	return _handle_hand_result(_hand.advance_until_blocked(max_transitions))


func submit_human_action(action: PlayerAction) -> StepResult:
	if state != State.RUNNING:
		return StepResult.new(StepResult.Status.ERROR, "The tournament is not running.")
	return _handle_hand_result(_hand.submit_human_action(action))


func submit_human_action_without_advance(action: PlayerAction) -> StepResult:
	if state != State.RUNNING:
		return StepResult.new(StepResult.Status.ERROR, "The tournament is not running.")
	return _handle_hand_result(_hand.submit_human_action_without_advance(action))


func advance_one_action() -> StepResult:
	if state != State.RUNNING:
		return StepResult.new(StepResult.Status.ERROR, "The tournament is not running.")
	if _awaiting_next_hand:
		return _start_next_hand(1)
	return _handle_hand_result(_hand.advance_one_action())


func request_quit() -> StepResult:
	if state == State.FINISHED:
		return StepResult.new(StepResult.Status.TOURNAMENT_FINISHED)
	if _hand != null:
		_hand.abort()
	state = State.FINISHED
	end_reason = &"player_quit"
	winner_seat = Table.NO_SEAT
	return StepResult.new(StepResult.Status.TOURNAMENT_FINISHED)


func get_view_for(seat: int) -> GameView:
	if _hand == null:
		return null
	var view: GameView = _hand.get_view_for(seat)
	view.tournament_status = &"finished" if state == State.FINISHED else &"running"
	view.end_reason = end_reason
	view.tournament_winner_seat = winner_seat
	return view


func get_events() -> Array[DomainEvent]:
	return [] if _hand == null else _hand.events


func _validate_configuration() -> String:
	if _config == null:
		return "A resolved tournament configuration is required."
	if _agents.size() != _config.player_count:
		return "Every configured seat must have an agent."
	if _construction_contract == null:
		return "A tournament construction contract is required."
	return _construction_contract.validate_agents(_agents, _config.player_count)


func _handle_hand_result(result: StepResult) -> StepResult:
	if result.status != StepResult.Status.HAND_COMPLETED:
		return result
	_awaiting_next_hand = true
	return _finish_hand_or_start_next()


func _finish_hand_or_start_next() -> StepResult:
	_mark_eliminated_players()
	_blind_progression.record_completed_hand(_table.active_player_count())
	if _table.active_player_count() == 1:
		winner_seat = _table.active_seats()[0]
		end_reason = &"winner"
		state = State.FINISHED
		return StepResult.new(StepResult.Status.TOURNAMENT_FINISHED)
	return StepResult.new(StepResult.Status.HAND_COMPLETED)


func _start_next_hand(max_transitions: int = 32) -> StepResult:
	if _hand != null:
		_table.advance_button()
	_table.set_blinds(_blind_progression.small_blind, _blind_progression.big_blind)
	_awaiting_next_hand = false
	hand_number += 1
	_hand = (
		HandController
		. new(
			_table,
			Deck.new(),
			_streams.get_deck_rng(),
			_streams.get_initial_button_rng(),
			hand_number,
			_blind_progression,
		)
	)
	return _handle_hand_result(_hand.start(max_transitions))


func _mark_eliminated_players() -> void:
	for player: Player in _table.players:
		if player.stack == 0:
			player.busted = true
