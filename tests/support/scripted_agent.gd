class_name ScriptedAgent
extends Agent

## Test agent that returns a predefined sequence without reading mutable core state.

var observed_records: Array[PublicActionRecord]:
	get:
		return _observed_records.duplicate()

var _actions: Array[PlayerAction] = []
var _observed_records: Array[PublicActionRecord] = []


func _init(actions: Array[PlayerAction] = []) -> void:
	_actions = actions.duplicate()


func choose_action(_view: GameView) -> PlayerAction:
	if _actions.is_empty():
		return null
	return _actions.pop_front()


func observe(record: PublicActionRecord) -> void:
	if record != null:
		_observed_records.append(record.copy())


func remaining_action_count() -> int:
	return _actions.size()
