class_name StrategyDecisionDiagnostics
extends RefCounted

## Private policy explanation copied only through test/simulation trace hooks.
## No cards or mutable game objects are retained.

var policy_version: StringName = &"street_response_v4"
var street: StringName = &"unknown"
var score: int = -1
var call_amount: int = 0
var contestable_pot: int = 0
var pot_is_reliable: bool = false
var call_price: float = 0.0
var call_threshold: float = 0.0
var raise_threshold: float = 0.0
var call_viable: bool = false
var value_raise_eligible: bool = false
var value_raise_percentage: float = 0.0
var resistance_factor: float = 1.0
var raise_reason: StringName = &"not_evaluated"
var bluff_eligible: bool = false
var bluff_reason: StringName = &"not_evaluated"
var bluff_window: StringName = &"none"
var aggression_count: int = 0
var hero_action_count: int = 0
var hero_aggression_count: int = 0
var opponent_aggression_after_hero: bool = false


func copy() -> StrategyDecisionDiagnostics:
	var result := StrategyDecisionDiagnostics.new()
	result.policy_version = policy_version
	result.street = street
	result.score = score
	result.call_amount = call_amount
	result.contestable_pot = contestable_pot
	result.pot_is_reliable = pot_is_reliable
	result.call_price = call_price
	result.call_threshold = call_threshold
	result.raise_threshold = raise_threshold
	result.call_viable = call_viable
	result.value_raise_eligible = value_raise_eligible
	result.value_raise_percentage = value_raise_percentage
	result.resistance_factor = resistance_factor
	result.raise_reason = raise_reason
	result.bluff_eligible = bluff_eligible
	result.bluff_reason = bluff_reason
	result.bluff_window = bluff_window
	result.aggression_count = aggression_count
	result.hero_action_count = hero_action_count
	result.hero_aggression_count = hero_aggression_count
	result.opponent_aggression_after_hero = opponent_aggression_after_hero
	return result
