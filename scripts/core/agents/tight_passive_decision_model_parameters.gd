class_name TightPassiveDecisionModelParameters
extends DecisionModelParameters

## Conservative preflop threshold and rare minimum-wager aggression.

@export_range(2, 14) var minimum_preflop_high_rank: int = 10
@export_range(0, 100) var raise_frequency: int = 5


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if minimum_preflop_high_rank < 2 or minimum_preflop_high_rank > 14:
		errors.append("Minimum preflop high rank must be between 2 and 14.")
	if raise_frequency < 0 or raise_frequency > 100:
		errors.append("Raise frequency must be between 0 and 100.")
	return errors
