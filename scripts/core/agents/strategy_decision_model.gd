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
const TraceScript := preload("res://scripts/core/agents/strategy_decision_trace.gd")
const HandPotentialContextScript := preload("res://scripts/core/agents/hand_potential_context.gd")
const HandPotentialEstimatorScript := preload(
	"res://scripts/core/agents/hand_potential_estimator.gd"
)
const PotWagerTargetScript := preload("res://scripts/core/pot_wager_target.gd")
const HALF_POT_DIVISOR: int = 2
const FULL_POT_DIVISOR: int = 1

var _parameters: DecisionModelParameters
var _rng: RandomNumberGenerator
var _profile_id: StringName
var _last_decision_trace: RefCounted


func configure(
	parameters: DecisionModelParameters, model_rng: RandomNumberGenerator
) -> PackedStringArray:
	var errors := PackedStringArray()
	is_configured = false
	_profile_id = &""
	_last_decision_trace = null
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


func set_profile_id_for_testing(profile_id: StringName) -> void:
	_profile_id = profile_id


func get_last_decision_trace_for_testing() -> RefCounted:
	if _last_decision_trace == null:
		return null
	return _last_decision_trace.copy()


func choose_action(view: GameView) -> PlayerAction:
	var action: PlayerAction = null
	if not is_configured or view == null or view.legal_actions.is_empty():
		_last_decision_trace = (
			TraceScript
			. new(
				_profile_id,
				TraceScript.UNKNOWN_BAND,
				&"no_legal_action",
				view.legal_actions if view != null else [],
				null,
			)
		)
	else:
		action = _choose_legal_action(view)
	return action


func _choose_legal_action(view: GameView) -> PlayerAction:
	var estimate := _estimate(view)
	var band: StringName = _band_for(estimate)
	var action: PlayerAction = null
	var bluff_action: PlayerAction = _eligible_bluff(view, estimate)
	if bluff_action != null:
		var bluff_branch: StringName = (
			&"bluff_bet" if bluff_action.kind == PlayerAction.Kind.BET else &"bluff_raise"
		)
		action = _recorded_action(view, bluff_branch, bluff_action, band)
	elif PlayerAction.Kind.CHECK in view.legal_actions:
		if (
			PlayerAction.Kind.BET in view.legal_actions
			and estimate != null
			and _should_continue(view, estimate)
		):
			var check_continuation := _choose_continuation(view, estimate, band)
			if check_continuation != null:
				action = check_continuation
		if action == null:
			action = _recorded_action(view, &"free_check", PlayerAction.check_action(), band)
	elif PlayerAction.Kind.CALL in view.legal_actions and _should_continue(view, estimate):
		var call_continuation := _choose_continuation(view, estimate, band)
		if call_continuation != null:
			action = call_continuation
	if (
		action == null
		and (
			estimate != null
			and _should_continue(view, estimate)
			and (
				PlayerAction.Kind.BET in view.legal_actions
				or PlayerAction.Kind.RAISE in view.legal_actions
			)
		)
	):
		var aggressive_continuation := _choose_continuation(view, estimate, band)
		if aggressive_continuation != null:
			action = aggressive_continuation
	if action == null:
		if PlayerAction.Kind.FOLD in view.legal_actions:
			action = _recorded_action(view, &"fold", PlayerAction.fold_action(), band)
		else:
			action = _recorded_action(
				view,
				&"fallback",
				_action_for(view.legal_actions[0], view),
				band,
			)
	return action


func _recorded_action(
	view: GameView,
	selected_branch: StringName,
	action: PlayerAction,
	hand_potential_band: StringName,
) -> PlayerAction:
	_last_decision_trace = (
		TraceScript
		. new(
			_profile_id,
			hand_potential_band,
			selected_branch,
			view.legal_actions,
			action,
		)
	)
	return action


func _estimate(view: GameView) -> HandPotentialEstimate:
	var context := (
		HandPotentialContextScript
		. new(
			view.street,
			_position_ordinal(view),
			_active_opponent_count(view),
			view.pot_amount,
			view.call_amount,
			_effective_stack(view),
			view.big_blind,
		)
	)
	return HandPotentialEstimatorScript.new().estimate(
		view.hero_hole_cards, view.community_cards, context
	)


func _band_for(estimate: HandPotentialEstimate) -> StringName:
	if estimate == null:
		return TraceScript.UNKNOWN_BAND
	return TraceScript.band_for_score(estimate.score)


func _aggressive_action(
	view: GameView, kind: PlayerAction.Kind, estimate: HandPotentialEstimate
) -> PlayerAction:
	var target_total: int = _wager_target_for_estimate(view, estimate)
	if kind == PlayerAction.Kind.BET:
		return PlayerAction.bet_to(target_total)
	if kind == PlayerAction.Kind.RAISE:
		return PlayerAction.raise_to(target_total)
	return null


func _wager_target_for_estimate(view: GameView, estimate: HandPotentialEstimate) -> int:
	var minimum_total: int = mini(maxi(0, view.minimum_wager_total), view.maximum_wager_total)
	if estimate == null:
		return _clamped_wager_target(view, minimum_total)
	var band: StringName = _band_for(estimate)
	var target_total: int = minimum_total
	var pot_fraction: PotWagerTargetResult
	var existing_wager: int = _hero_existing_wager(view)
	match band:
		TraceScript.MARGINAL_BAND:
			pot_fraction = PotWagerTargetScript.calculate_fraction(
				view.pot_amount, existing_wager, view.call_amount, HALF_POT_DIVISOR
			)
		TraceScript.STRONG_BAND:
			pot_fraction = PotWagerTargetScript.calculate_fraction(
				view.pot_amount, existing_wager, view.call_amount, FULL_POT_DIVISOR
			)
		TraceScript.PREMIUM_BAND:
			target_total = view.maximum_wager_total
	if pot_fraction != null and pot_fraction.available:
		target_total = pot_fraction.wager_total
	return _clamped_wager_target(view, target_total)


func _hero_existing_wager(view: GameView) -> int:
	for seat: PlayerView in view.seats:
		if seat.seat == view.hero_seat:
			return seat.bet_this_round
	return 0


func _clamped_wager_target(view: GameView, target_total: int) -> int:
	var maximum_total: int = maxi(0, view.maximum_wager_total)
	var minimum_total: int = mini(maxi(0, view.minimum_wager_total), maximum_total)
	return clampi(target_total, minimum_total, maximum_total)


func _choose_continuation(
	view: GameView, estimate: HandPotentialEstimate, hand_potential_band: StringName
) -> PlayerAction:
	var passive_action: PlayerAction
	if PlayerAction.Kind.CHECK in view.legal_actions:
		passive_action = PlayerAction.check_action()
	elif PlayerAction.Kind.CALL in view.legal_actions:
		passive_action = PlayerAction.call_action()

	var aggressive_action: PlayerAction
	if PlayerAction.Kind.BET in view.legal_actions:
		aggressive_action = _aggressive_action(view, PlayerAction.Kind.BET, estimate)
	elif PlayerAction.Kind.RAISE in view.legal_actions:
		aggressive_action = _aggressive_action(view, PlayerAction.Kind.RAISE, estimate)

	if passive_action != null and aggressive_action != null:
		var parameters := _parameters as StrategyDecisionModelParameters
		var aggression_percentage: int = parameters.passive_vs_aggressive
		if aggressive_action.kind == PlayerAction.Kind.RAISE:
			aggression_percentage = parameters.call_vs_raise
		if _percentage_roll(aggression_percentage):
			return _recorded_action(
				view, &"continue_aggressive", aggressive_action, hand_potential_band
			)
		return _recorded_action(view, &"continue_passive", passive_action, hand_potential_band)
	if passive_action != null:
		return _recorded_action(view, &"passive_only", passive_action, hand_potential_band)
	if aggressive_action != null:
		return _recorded_action(view, &"aggressive_only", aggressive_action, hand_potential_band)
	return null


func _percentage_roll(percentage: int) -> bool:
	if percentage <= 0:
		return false
	if percentage >= 100:
		return true
	return _rng.randf() < float(percentage) / 100.0


func _eligible_bluff(view: GameView, estimate: HandPotentialEstimate) -> PlayerAction:
	if estimate == null or _band_for(estimate) != TraceScript.WEAK_BAND:
		return null
	var wager_kind: PlayerAction.Kind
	if PlayerAction.Kind.BET in view.legal_actions:
		wager_kind = PlayerAction.Kind.BET
	elif PlayerAction.Kind.RAISE in view.legal_actions:
		wager_kind = PlayerAction.Kind.RAISE
	else:
		return null
	var parameters := _parameters as StrategyDecisionModelParameters
	if not _bluff_roll_succeeds(parameters.bluff_rate):
		return null
	return _action_for(wager_kind, view)


func _bluff_roll_succeeds(bluff_rate: int) -> bool:
	if bluff_rate <= 0:
		return false
	if bluff_rate >= 100:
		return true
	return _rng.randf() < float(bluff_rate) / 100.0


func _should_continue(view: GameView, estimate: HandPotentialEstimate) -> bool:
	if estimate == null:
		# A malformed or test-only snapshot must retain the safe check/call
		# baseline. Production GameViews always contain two hero cards.
		return true
	var parameters := _parameters as StrategyDecisionModelParameters
	var threshold: float = 75.0 - 0.45 * float(parameters.tight_vs_loose)
	var call_price: float = _call_price(view)
	var stack_pressure: float = _stack_pressure(view)
	var position_credit: float = float(mini(_position_ordinal(view), 5))
	# Expensive calls and short effective stacks require extra strength. Later
	# position earns a small credit; the estimator also includes position in its
	# public score, so this remains deliberately conservative and bounded.
	threshold += call_price * 8.0 + stack_pressure * 4.0 - position_credit
	return float(estimate.score) >= threshold


func _call_price(view: GameView) -> float:
	if view.call_amount <= 0:
		return 0.0
	var pot_after_call: int = view.pot_amount + view.call_amount
	if pot_after_call <= 0:
		return 1.0
	return clampf(float(view.call_amount) / float(pot_after_call), 0.0, 1.0)


func _stack_pressure(view: GameView) -> float:
	var stack: int = _hero_stack(view)
	var chips_at_risk: int = stack + view.call_amount
	if chips_at_risk <= 0:
		return 1.0
	return clampf(float(view.call_amount) / float(chips_at_risk), 0.0, 1.0)


func _hero_stack(view: GameView) -> int:
	for seat: PlayerView in view.seats:
		if seat.seat == view.hero_seat:
			return seat.stack
	return 0


func _position_ordinal(view: GameView) -> int:
	var contenders: Array[int] = _contender_seats(view)
	if contenders.is_empty() or view.hero_seat not in contenders:
		return 0
	var first_seat: int
	if view.street == &"preflop" and view.small_blind_seat == view.button_seat:
		first_seat = view.button_seat
	elif view.street == &"preflop":
		first_seat = _next_contender_after(contenders, view.big_blind_seat)
	else:
		first_seat = _next_contender_after(contenders, view.button_seat)
	var first_index: int = contenders.find(first_seat)
	var hero_index: int = contenders.find(view.hero_seat)
	if first_index < 0 or hero_index < 0:
		return 0
	return posmod(hero_index - first_index, contenders.size())


func _active_opponent_count(view: GameView) -> int:
	return maxi(0, _contender_seats(view).size() - 1)


func _effective_stack(view: GameView) -> int:
	var hero_stack: int = _hero_stack(view)
	var largest_opponent_stack: int = 0
	for seat: PlayerView in view.seats:
		if seat.seat != view.hero_seat and not seat.busted and not seat.folded:
			largest_opponent_stack = maxi(largest_opponent_stack, seat.stack)
	return mini(hero_stack, largest_opponent_stack)


func _contender_seats(view: GameView) -> Array[int]:
	var contenders: Array[int] = []
	for seat: PlayerView in view.seats:
		if not seat.busted and not seat.folded:
			contenders.append(seat.seat)
	contenders.sort()
	return contenders


func _next_contender_after(contenders: Array[int], anchor_seat: int) -> int:
	if contenders.is_empty():
		return Table.NO_SEAT
	for seat: int in contenders:
		if seat > anchor_seat:
			return seat
	return contenders[0]


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
			action = PlayerAction.bet_to(_legal_wager_target(view))
		PlayerAction.Kind.RAISE:
			action = PlayerAction.raise_to(_legal_wager_target(view))
		PlayerAction.Kind.ALL_IN:
			action = PlayerAction.all_in_action()
	return action


func _legal_wager_target(view: GameView) -> int:
	return _clamped_wager_target(view, view.minimum_wager_total)
