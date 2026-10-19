class_name StrategyDecisionModelParameters
extends DecisionModelParameters

## Immutable-at-runtime style controls for StrategyDecisionModel.
##
## Each percentage is inclusive from 0 through 100. Configure a new profile
## before tournament construction; profiles are not changed during a tournament.

## Minimum hand strength required to continue voluntarily: 0 is tight, 100 is loose.
@export_range(0, 100) var tight_vs_loose: int = 50
## Desire to initiate or escalate wagers: 0 is passive, 100 is aggressive.
@export_range(0, 100) var passive_vs_aggressive: int = 55
## Continuation preference: 0 favors checking or calling, 100 favors betting or raising.
@export_range(0, 100) var call_vs_bet: int = 50
## Percentage probability of an eligible weak-hand bluff opportunity.
@export_range(0, 100) var bluff_rate: int = 12


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_percentage(errors, "Tight versus loose", tight_vs_loose)
	_validate_percentage(errors, "Passive versus aggressive", passive_vs_aggressive)
	_validate_percentage(errors, "Call versus bet", call_vs_bet)
	_validate_percentage(errors, "Bluff rate", bluff_rate)
	return errors


func _validate_percentage(errors: PackedStringArray, field_name: String, value: int) -> void:
	if value < 0 or value > 100:
		errors.append("%s must be between 0 and 100." % field_name)
