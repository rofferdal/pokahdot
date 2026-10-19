class_name StrategyDecisionTrace
extends RefCounted

## Test/simulation-only explanation of one StrategyDecisionModel decision.
##
## This value is deliberately not part of GameView, domain events, or any
## regular UI/CLI contract. It may contain private strategy diagnostics and
## therefore must remain in test and simulation code.

const UNKNOWN_BAND: StringName = &"unknown"
const WEAK_BAND: StringName = &"weak"
const MARGINAL_BAND: StringName = &"marginal"
const STRONG_BAND: StringName = &"strong"
const PREMIUM_BAND: StringName = &"premium"

var profile_id: StringName:
	get:
		return _profile_id
var hand_potential_band: StringName:
	get:
		return _hand_potential_band
var selected_branch: StringName:
	get:
		return _selected_branch
var legal_alternatives: Array[PlayerAction.Kind]:
	get:
		return _legal_alternatives.duplicate()
var requested_action: PlayerAction:
	get:
		return _copy_action(_requested_action)

var _profile_id: StringName
var _hand_potential_band: StringName
var _selected_branch: StringName
var _legal_alternatives: Array[PlayerAction.Kind] = []
var _requested_action: PlayerAction


func _init(
	trace_profile_id: StringName,
	trace_hand_potential_band: StringName,
	trace_selected_branch: StringName,
	trace_legal_alternatives: Array[PlayerAction.Kind],
	trace_requested_action: PlayerAction,
) -> void:
	_profile_id = trace_profile_id
	_hand_potential_band = trace_hand_potential_band
	_selected_branch = trace_selected_branch
	_legal_alternatives = trace_legal_alternatives.duplicate()
	_requested_action = _copy_action(trace_requested_action)


## Converts the estimator's bounded score into a stable, presentation-neutral
## band. The boundaries are intentionally centralized for future policy tests.
static func band_for_score(score: int) -> StringName:
	if score < 0 or score > 100:
		return UNKNOWN_BAND
	if score < 30:
		return WEAK_BAND
	if score < 60:
		return MARGINAL_BAND
	if score < 80:
		return STRONG_BAND
	return PREMIUM_BAND


func copy() -> RefCounted:
	return (
		get_script()
		. new(
			_profile_id,
			_hand_potential_band,
			_selected_branch,
			_legal_alternatives,
			_requested_action,
		)
	)


static func _copy_action(action: PlayerAction) -> PlayerAction:
	if action == null:
		return null
	match action.kind:
		PlayerAction.Kind.FOLD:
			return PlayerAction.fold_action()
		PlayerAction.Kind.CHECK:
			return PlayerAction.check_action()
		PlayerAction.Kind.CALL:
			return PlayerAction.call_action()
		PlayerAction.Kind.BET:
			return PlayerAction.bet_to(action.amount)
		PlayerAction.Kind.RAISE:
			return PlayerAction.raise_to(action.amount)
		PlayerAction.Kind.ALL_IN:
			return PlayerAction.all_in_action()
	return null
