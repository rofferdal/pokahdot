class_name StrategyDecisionModel
extends DecisionModel

## Parameterized strategy foundation using only the recipient-safe GameView.
##
## Hand-strength estimation and bluff selection are added in later strategy
## milestones. Until then, this model makes a deterministic, legal baseline
## choice from the configured continuation and aggression preferences.

const StrategyParametersScript := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)

var _parameters: DecisionModelParameters
var _rng: RandomNumberGenerator


func configure(
	parameters: DecisionModelParameters, model_rng: RandomNumberGenerator
) -> PackedStringArray:
	var errors := PackedStringArray()
	is_configured = false
	if parameters == null or parameters.get_script() != StrategyParametersScript:
		errors.append("StrategyDecisionModel requires StrategyDecisionModelParameters.")
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
	if PlayerAction.Kind.CHECK in view.legal_actions:
		return PlayerAction.check_action()
	if PlayerAction.Kind.CALL in view.legal_actions:
		return PlayerAction.call_action()
	if PlayerAction.Kind.FOLD in view.legal_actions:
		return PlayerAction.fold_action()
	return _action_for(view.legal_actions[0], view)


func _action_for(kind: PlayerAction.Kind, view: GameView) -> PlayerAction:
	var action: PlayerAction
	match kind:
		PlayerAction.Kind.FOLD:
			action = PlayerAction.fold_action()
		PlayerAction.Kind.CHECK:
			action = PlayerAction.check_action()
		PlayerAction.Kind.CALL:
			action = PlayerAction.call_action()
		PlayerAction.Kind.BET:
			action = PlayerAction.bet_to(view.minimum_wager_total)
		PlayerAction.Kind.RAISE:
			action = PlayerAction.raise_to(view.minimum_wager_total)
		PlayerAction.Kind.ALL_IN:
			action = PlayerAction.all_in_action()
	return action
