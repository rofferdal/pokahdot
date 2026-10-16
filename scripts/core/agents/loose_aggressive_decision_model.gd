class_name LooseAggressiveDecisionModel
extends DecisionModel

var _parameters: LooseAggressiveDecisionModelParameters
var _rng: RandomNumberGenerator


func configure(
	parameters: DecisionModelParameters, model_rng: RandomNumberGenerator
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not parameters is LooseAggressiveDecisionModelParameters:
		errors.append(
			"LooseAggressiveDecisionModel requires LooseAggressiveDecisionModelParameters."
		)
	elif model_rng == null:
		errors.append("A random number generator is required.")
	else:
		errors = parameters.validate()
	if errors.is_empty():
		_parameters = parameters
		_rng = model_rng
		is_configured = true
	else:
		is_configured = false
	return errors


func choose_action(view: GameView) -> PlayerAction:
	if not is_configured or view == null or view.legal_actions.is_empty():
		return null
	var action := PlayerAction.fold_action()
	if _rng.randi_range(1, 100) <= _parameters.aggression_frequency:
		if PlayerAction.Kind.BET in view.legal_actions:
			action = PlayerAction.bet_to(view.maximum_wager_total)
		elif PlayerAction.Kind.RAISE in view.legal_actions:
			action = PlayerAction.raise_to(view.maximum_wager_total)
	if action.kind == PlayerAction.Kind.FOLD and PlayerAction.Kind.CALL in view.legal_actions:
		if _rng.randi_range(1, 100) > _parameters.fold_frequency:
			action = PlayerAction.call_action()
	elif action.kind == PlayerAction.Kind.FOLD and PlayerAction.Kind.CHECK in view.legal_actions:
		action = PlayerAction.check_action()
	elif action.kind == PlayerAction.Kind.FOLD and PlayerAction.Kind.ALL_IN in view.legal_actions:
		action = PlayerAction.all_in_action()
	return action
