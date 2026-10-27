class_name BotAgent
extends Agent

## Agent adapter that delegates decisions and observations to one private model.

var profile_id: StringName
var model_id: StringName
var _model: DecisionModel
var _decision_history: Array[Dictionary] = []
var _simulation_diagnostics_enabled: bool = false


func _init(model: DecisionModel, profile: BotProfile) -> void:
	assert(model != null, "A bot agent requires a decision model.")
	assert(profile != null, "A bot agent requires a profile.")
	_model = model
	profile_id = profile.profile_id
	model_id = profile.model_id


func choose_action(view: GameView) -> PlayerAction:
	var action := _model.choose_action(view)
	if not _simulation_diagnostics_enabled:
		return action
	var trace := _model.get_last_decision_trace_for_testing()
	var legal_actions: Array[PlayerAction.Kind] = []
	if view != null:
		legal_actions = view.legal_actions
	(
		_decision_history
		. append(
			{
				"trace": trace.copy() if trace != null else null,
				"street": view.street if view != null else &"unknown",
				"legal_actions": legal_actions,
				"all_in_aggression_kind": _all_in_aggression_kind(view, legal_actions),
				"action": PlayerAction.new(action.kind, action.amount) if action != null else null,
			}
		)
	)
	return action


## Test/simulation-only hook. It is intentionally separate from GameView and
## is never consumed by CLI or GUI rendering.
func get_last_decision_trace_for_testing() -> RefCounted:
	return _model.get_last_decision_trace_for_testing()


## Product games leave diagnostics disabled. Disabling releases pending records.
func set_simulation_diagnostics_enabled(enabled: bool) -> void:
	_simulation_diagnostics_enabled = enabled
	if not enabled:
		_decision_history.clear()


## Transfers ownership of captured snapshots; the agent retains no returned data.
## Simulation drivers drain after every bounded advancement, not after a tournament.
func drain_decisions_for_simulation() -> Array[Dictionary]:
	var pending := _decision_history
	_decision_history = []
	return pending


func observe(record: PublicActionRecord) -> void:
	_model.observe(record)


func _all_in_aggression_kind(view: GameView, legal_actions: Array[PlayerAction.Kind]) -> int:
	if view == null or PlayerAction.Kind.ALL_IN not in legal_actions:
		return -1
	if PlayerAction.Kind.BET in legal_actions or PlayerAction.Kind.RAISE in legal_actions:
		return -1
	var wager_before_call: int = 0
	for player: PlayerView in view.seats:
		if player.seat == view.hero_seat:
			wager_before_call = player.bet_this_round
			break
	var current_bet: int = wager_before_call + view.call_amount
	if view.maximum_wager_total <= current_bet:
		return -1
	return PlayerAction.Kind.BET if current_bet == 0 else PlayerAction.Kind.RAISE
