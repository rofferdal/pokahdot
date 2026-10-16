class_name TestDecisionModel
extends DecisionModel

var configured_value: int


func configure(
	parameters: DecisionModelParameters, model_rng: RandomNumberGenerator
) -> PackedStringArray:
	var errors: PackedStringArray = super(parameters, model_rng)
	if errors.is_empty():
		configured_value = (parameters as TestDecisionModelParameters).value
	return errors


func choose_action(_view: GameView) -> PlayerAction:
	return PlayerAction.check_action()
