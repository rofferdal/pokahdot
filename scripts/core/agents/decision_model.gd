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


## Optional test/simulation-only metadata hook. Product adapters must not call
## this method when building recipient-facing views or regular UI state.
func set_profile_id_for_testing(_profile_id: StringName) -> void:
	pass


## Returns a model-specific, private diagnostic value for tests/simulations.
## The production decision contract remains choose_action() -> PlayerAction.
func get_last_decision_trace_for_testing() -> RefCounted:
	return null


func observe(_record: PublicActionRecord) -> void:
	pass
