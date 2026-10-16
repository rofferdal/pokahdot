class_name RandomDecisionModel
extends DecisionModel

var _parameters: RandomDecisionModelParameters
var _rng: RandomNumberGenerator


func configure(
	parameters: DecisionModelParameters, model_rng: RandomNumberGenerator
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not parameters is RandomDecisionModelParameters:
		errors.append("RandomDecisionModel requires RandomDecisionModelParameters.")
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
	var weighted_kinds: Array[PlayerAction.Kind] = []
	var weights: Array[int] = []
	var total_weight: int = 0
	for kind: PlayerAction.Kind in view.legal_actions:
		var weight: int = _weight_for(kind)
		if weight > 0:
			weighted_kinds.append(kind)
			weights.append(weight)
			total_weight += weight
	if weighted_kinds.is_empty():
		return _action_for(view.legal_actions[0], view)

	var roll: int = _rng.randi_range(1, total_weight)
	for index: int in range(weighted_kinds.size()):
		roll -= weights[index]
		if roll <= 0:
			return _action_for(weighted_kinds[index], view)
	return _action_for(weighted_kinds.back(), view)


func _weight_for(kind: PlayerAction.Kind) -> int:
	match kind:
		PlayerAction.Kind.FOLD:
			return _parameters.fold_weight
		PlayerAction.Kind.CHECK, PlayerAction.Kind.CALL:
			return _parameters.passive_weight
		PlayerAction.Kind.BET, PlayerAction.Kind.RAISE, PlayerAction.Kind.ALL_IN:
			return _parameters.aggressive_weight
	return 0


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
			action = PlayerAction.bet_to(_random_wager_total(view))
		PlayerAction.Kind.RAISE:
			action = PlayerAction.raise_to(_random_wager_total(view))
		PlayerAction.Kind.ALL_IN:
			action = PlayerAction.all_in_action()
	return action


func _random_wager_total(view: GameView) -> int:
	if view.maximum_wager_total <= view.minimum_wager_total:
		return view.maximum_wager_total
	return _rng.randi_range(view.minimum_wager_total, view.maximum_wager_total)
