class_name DecisionModel
extends RefCounted

## Strategy contract used by BotAgent.

var is_configured: bool = false


func configure(
	parameters: DecisionModelParameters, model_rng: RandomNumberGenerator
) -> PackedStringArray:
	var errors: PackedStringArray = (
		parameters.validate() if parameters != null else ["Parameters are required."]
	)
	if model_rng == null:
		errors.append("A random number generator is required.")
	is_configured = errors.is_empty()
	return errors


func choose_action(_view: GameView) -> PlayerAction:
	return null


func observe(_record: PublicActionRecord) -> void:
	pass
