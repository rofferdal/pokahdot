class_name BotAgent
extends Agent

## Agent adapter that delegates decisions and observations to one private model.

var profile_id: StringName
var model_id: StringName
var _model: DecisionModel


func _init(model: DecisionModel, profile: BotProfile) -> void:
	assert(model != null, "A bot agent requires a decision model.")
	assert(profile != null, "A bot agent requires a profile.")
	_model = model
	profile_id = profile.profile_id
	model_id = profile.model_id


func choose_action(view: GameView) -> PlayerAction:
	return _model.choose_action(view)


## Test/simulation-only hook. It is intentionally separate from GameView and
## is never consumed by CLI or GUI rendering.
func get_last_decision_trace_for_testing() -> RefCounted:
	return _model.get_last_decision_trace_for_testing()


func observe(record: PublicActionRecord) -> void:
	_model.observe(record)
