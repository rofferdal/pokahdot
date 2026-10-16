class_name HumanAgent
extends Agent

## Non-blocking mailbox for actions submitted by a presentation adapter.

var _pending_action: PlayerAction


func submit_action(action: PlayerAction) -> bool:
	if action == null or _pending_action != null:
		return false
	_pending_action = action
	return true


func has_pending_action() -> bool:
	return _pending_action != null


func choose_action(_view: GameView) -> PlayerAction:
	var action: PlayerAction = _pending_action
	_pending_action = null
	return action


func clear_pending_action() -> void:
	_pending_action = null
