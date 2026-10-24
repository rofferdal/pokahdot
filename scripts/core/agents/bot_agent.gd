class_name BotAgent
extends Agent

## Agent adapter that delegates decisions and observations to one private model.

var profile_id: StringName
var model_id: StringName
var _model: DecisionModel
var _decision_history: Array[Dictionary] = []


func _init(model: DecisionModel, profile: BotProfile) -> void:
	assert(model != null, "A bot agent requires a decision model.")
	assert(profile != null, "A bot agent requires a profile.")
	_model = model
	profile_id = profile.profile_id
	model_id = profile.model_id


func choose_action(view: GameView) -> PlayerAction:
	var action := _model.choose_action(view)
	var trace := _model.get_last_decision_trace_for_testing()
	(
		_decision_history
		. append(
			{
				"trace": trace.copy() if trace != null else null,
				"street": view.street if view != null else &"unknown",
				"legal_actions": view.legal_actions if view != null else [],
				"all_in_aggression_kind": _all_in_aggression_kind(view),
				"action": action,
			}
		)
	)
	return action


## Test/simulation-only hook. It is intentionally separate from GameView and
## is never consumed by CLI or GUI rendering.
func get_last_decision_trace_for_testing() -> RefCounted:
	return _model.get_last_decision_trace_for_testing()


## Simulation-only history used to correlate rejected and applied decisions.
func get_decision_history_for_simulation() -> Array[Dictionary]:
	return _decision_history.duplicate()


func observe(record: PublicActionRecord) -> void:
	_model.observe(record)


func _all_in_aggression_kind(view: GameView) -> int:
	if view == null or PlayerAction.Kind.ALL_IN not in view.legal_actions:
		return -1
	if PlayerAction.Kind.BET in view.legal_actions or PlayerAction.Kind.RAISE in view.legal_actions:
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
