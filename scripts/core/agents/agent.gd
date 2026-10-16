class_name Agent
extends RefCounted

## Stable decision boundary shared by human and automated agents.


func choose_action(_view: GameView) -> PlayerAction:
	return null


func observe(_record: PublicActionRecord) -> void:
	pass
