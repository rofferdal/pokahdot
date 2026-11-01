class_name StrategyDecisionModel
extends DecisionModel

## Parameterized call/value/bluff policy using only the recipient-safe GameView.

const StrategyParametersScript := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)
const TraceScript := preload("res://scripts/core/agents/strategy_decision_trace.gd")
const HandPotentialContextScript := preload("res://scripts/core/agents/hand_potential_context.gd")
const HandPotentialEstimatorScript := preload(
	"res://scripts/core/agents/hand_potential_estimator.gd"
)
const PotWagerTargetScript := preload("res://scripts/core/pot_wager_target.gd")
const POLICY_VERSION: StringName = &"street_response_v3"
const CHEAP_CALL_PRICE_LIMIT: float = 0.25
const MAX_CALL_CREDIT: float = 4.0
const HALF_POT_DIVISOR: int = 2
const FULL_POT_DIVISOR: int = 1

var _parameters: DecisionModelParameters
var _rng: RandomNumberGenerator
var _profile_id: StringName
var _last_decision_trace: RefCounted
var _decision_diagnostics: StrategyDecisionDiagnostics


func configure(
	parameters: DecisionModelParameters, model_rng: RandomNumberGenerator
) -> PackedStringArray:
	var errors := PackedStringArray()
	is_configured = false
	_profile_id = &""
	_last_decision_trace = null
	_decision_diagnostics = null
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
	_decision_diagnostics = null
	if not is_configured or view == null or view.legal_actions.is_empty():
		var trace_legal: Array[PlayerAction.Kind] = []
		if view != null:
			trace_legal = view.legal_actions
		_last_decision_trace = (
			TraceScript
			. new(
				_profile_id,
				TraceScript.UNKNOWN_BAND,
				&"no_legal_action",
				trace_legal,
				null,
			)
		)
	else:
		action = _choose_legal_action(view)
	return action


func _choose_legal_action(view: GameView) -> PlayerAction:
	var estimate := _estimate(view)
	var band: StringName = _band_for(estimate)
	_decision_diagnostics = _explain_policy(view, estimate)
	var action: PlayerAction = null
	var bluff_action: PlayerAction = _eligible_bluff(view)
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
	elif PlayerAction.Kind.CALL in view.legal_actions and _decision_diagnostics.call_viable:
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
			_decision_diagnostics,
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
	if PlayerAction.Kind.BET in view.legal_actions and _decision_diagnostics.value_raise_eligible:
		aggressive_action = _aggressive_action(view, PlayerAction.Kind.BET, estimate)
	elif (
		PlayerAction.Kind.RAISE in view.legal_actions and _decision_diagnostics.value_raise_eligible
	):
		aggressive_action = _aggressive_action(view, PlayerAction.Kind.RAISE, estimate)

	if passive_action != null and aggressive_action != null:
		var parameters := _parameters as StrategyDecisionModelParameters
		var aggression_percentage: float = float(parameters.passive_vs_aggressive)
		if aggressive_action.kind == PlayerAction.Kind.RAISE:
			aggression_percentage = _decision_diagnostics.value_raise_percentage
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


func _percentage_roll(percentage: float) -> bool:
	if percentage <= 0:
		return false
	if percentage >= 100:
		return true
	return _rng.randf() < percentage / 100.0


func _eligible_bluff(view: GameView) -> PlayerAction:
	if not _decision_diagnostics.bluff_eligible:
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
		return true
	var context := StrategyStreetContext.from_view(view)
	return float(estimate.score) >= _continuation_threshold(view, context.call_price)


func _continuation_threshold(view: GameView, price: float) -> float:
	var parameters := _parameters as StrategyDecisionModelParameters
	var threshold: float = 75.0 - 0.45 * float(parameters.tight_vs_loose)
	return (
		threshold
		+ price * 8.0
		+ _stack_pressure(view) * 4.0
		- float(mini(_position_ordinal(view), 5))
	)


func _explain_policy(
	view: GameView, estimate: HandPotentialEstimate
) -> StrategyDecisionDiagnostics:
	var context := StrategyStreetContext.from_view(view)
	var result := StrategyDecisionDiagnostics.new()
	result.policy_version = POLICY_VERSION
	result.street = view.street
	result.score = estimate.score if estimate != null else -1
	result.call_amount = view.call_amount
	result.contestable_pot = context.contestable_pot_before_call
	result.pot_is_reliable = context.pot_is_reliable
	result.call_price = context.call_price
	result.raise_threshold = _continuation_threshold(view, context.call_price)
	result.call_threshold = result.raise_threshold
	result.aggression_count = context.aggression_count
	result.hero_action_count = context.hero_action_count
	result.hero_aggression_count = context.hero_aggression_count
	result.opponent_aggression_after_hero = context.opponent_aggression_after_hero
	if (
		estimate != null
		and estimate.score >= 30
		and context.pot_is_reliable
		and context.call_price < CHEAP_CALL_PRICE_LIMIT
	):
		# The score is a heuristic, not equity. The bounded credit applies only
		# to calling; extra live opponents reduce its size.
		var opponents: int = maxi(0, _active_opponent_count(view) - 1)
		var credit: float = (
			MAX_CALL_CREDIT
			* (1.0 - context.call_price / CHEAP_CALL_PRICE_LIMIT)
			/ (1.0 + 0.5 * float(opponents))
		)
		result.call_threshold -= credit
	result.call_viable = estimate == null or float(result.score) >= result.call_threshold
	result.value_raise_eligible = (
		(estimate == null or float(result.score) >= result.raise_threshold)
		and (
			PlayerAction.Kind.BET in view.legal_actions
			or PlayerAction.Kind.RAISE in view.legal_actions
		)
	)
	_explain_value_raise(view, context, result)
	result.bluff_reason = _bluff_eligibility_reason(view, estimate, context)
	result.bluff_eligible = result.bluff_reason == &"eligible"
	if result.bluff_eligible:
		if context.hero_action_count == 1:
			result.bluff_window = &"delayed"
		elif context.aggression_count >= 2:
			result.bluff_window = &"pressure_entry"
		else:
			result.bluff_window = &"initial"
	return result


func _explain_value_raise(
	view: GameView, context: StrategyStreetContext, result: StrategyDecisionDiagnostics
) -> void:
	if not result.value_raise_eligible:
		result.raise_reason = (
			&"below_value_threshold"
			if (
				PlayerAction.Kind.BET in view.legal_actions
				or PlayerAction.Kind.RAISE in view.legal_actions
			)
			else &"no_legal_wager"
		)
		return
	if PlayerAction.Kind.RAISE not in view.legal_actions:
		result.raise_reason = &"opening_value"
		return
	var parameters := _parameters as StrategyDecisionModelParameters
	if result.score < 60 and context.opponent_aggression_after_hero:
		result.resistance_factor = _marginal_resistance_factor(view, context, result.score)
		result.raise_reason = &"resistance_adjusted"
	else:
		result.raise_reason = &"value_eligible"
	result.value_raise_percentage = float(parameters.call_vs_raise) * result.resistance_factor


func _marginal_resistance_factor(
	view: GameView, context: StrategyStreetContext, score: int
) -> float:
	var scale: int = maxi(1, maxi(context.contestable_pot_before_call, view.big_blind))
	var size_pressure: float = float(context.latest_wager_increase) / float(scale)
	var opponents: int = maxi(0, _active_opponent_count(view) - 1)
	var additional_increases: int = maxi(0, context.aggression_count - 2)
	return clampf(
		(
			0.75
			+ 0.005 * float(score - 45)
			- 0.5 * context.call_price
			- 0.25 * size_pressure
			- 0.05 * float(opponents)
			- 0.05 * float(additional_increases)
		),
		0.15,
		0.85,
	)


func _bluff_eligibility_reason(
	view: GameView, estimate: HandPotentialEstimate, context: StrategyStreetContext
) -> StringName:
	if estimate == null or _band_for(estimate) != TraceScript.WEAK_BAND:
		return &"not_weak"
	if (
		PlayerAction.Kind.BET not in view.legal_actions
		and PlayerAction.Kind.RAISE not in view.legal_actions
	):
		return &"no_legal_wager"
	if context.hero_aggression_count > 0:
		return &"already_aggressive"
	if context.hero_action_count >= 2:
		return &"action_window_closed"
	if context.hero_action_count == 0 and context.aggression_count < 2:
		return &"eligible"
	return _selective_bluff_reason(view, estimate, context)


func _selective_bluff_reason(
	view: GameView, estimate: HandPotentialEstimate, context: StrategyStreetContext
) -> StringName:
	if (
		context.hero_action_count == 1
		and context.hero_last_action_kind not in [PlayerAction.Kind.CHECK, PlayerAction.Kind.CALL]
	):
		return &"unsupported_prior_action"
	if view.street != &"flop":
		return &"selective_street"
	# Direct draws usually score above the weak band. Backdoor quality supplies
	# a real weak-hand opportunity; generic pair-upgrade potential alone does not.
	if maxi(estimate.flush_draw_quality, estimate.straight_draw_quality) < 25:
		return &"insufficient_backdoor"
	if not context.pot_is_reliable:
		return &"unreliable_pot"
	if context.call_price > 0.20:
		return &"expensive_bluff"
	return _bluff_pressure_reason(view)


func _bluff_pressure_reason(view: GameView) -> StringName:
	if _active_opponent_count(view) > 2:
		return &"too_many_opponents"
	if (
		PlayerAction.Kind.CALL not in view.legal_actions
		or PlayerAction.Kind.RAISE not in view.legal_actions
	):
		return &"no_legal_reraise"
	return &"eligible"


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
