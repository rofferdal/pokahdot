class_name TightPassiveDecisionModel
extends DecisionModel

var _parameters: TightPassiveDecisionModelParameters
var _rng: RandomNumberGenerator


func configure(
	parameters: DecisionModelParameters, model_rng: RandomNumberGenerator
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not parameters is TightPassiveDecisionModelParameters:
		errors.append("TightPassiveDecisionModel requires TightPassiveDecisionModelParameters.")
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
		return _aggressive_or_check(view)
	if PlayerAction.Kind.CALL in view.legal_actions and _has_playable_hand(view):
		return PlayerAction.call_action()
	if PlayerAction.Kind.FOLD in view.legal_actions:
		return PlayerAction.fold_action()
	return _first_legal_action(view)


func _aggressive_or_check(view: GameView) -> PlayerAction:
	if _rng.randi_range(1, 100) <= _parameters.raise_frequency:
		if PlayerAction.Kind.BET in view.legal_actions:
			return PlayerAction.bet_to(view.minimum_wager_total)
		if PlayerAction.Kind.RAISE in view.legal_actions:
			return PlayerAction.raise_to(view.minimum_wager_total)
	return PlayerAction.check_action()


func _has_playable_hand(view: GameView) -> bool:
	for card: CardData in view.hero_hole_cards:
		if card.rank >= _parameters.minimum_preflop_high_rank:
			return true
	return false


func _first_legal_action(view: GameView) -> PlayerAction:
	match view.legal_actions[0]:
		PlayerAction.Kind.ALL_IN:
			return PlayerAction.all_in_action()
		PlayerAction.Kind.BET:
			return PlayerAction.bet_to(view.minimum_wager_total)
		PlayerAction.Kind.RAISE:
			return PlayerAction.raise_to(view.minimum_wager_total)
		PlayerAction.Kind.CALL:
			return PlayerAction.call_action()
		PlayerAction.Kind.CHECK:
			return PlayerAction.check_action()
	return PlayerAction.fold_action()
