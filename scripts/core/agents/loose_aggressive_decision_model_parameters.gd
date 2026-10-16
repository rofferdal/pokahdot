class_name LooseAggressiveDecisionModelParameters
extends DecisionModelParameters

## Broad continuation and frequent maximum-wager aggression.

@export_range(0, 100) var fold_frequency: int = 10
@export_range(0, 100) var aggression_frequency: int = 55


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if fold_frequency < 0 or fold_frequency > 100:
		errors.append("Fold frequency must be between 0 and 100.")
	if aggression_frequency < 0 or aggression_frequency > 100:
		errors.append("Aggression frequency must be between 0 and 100.")
	return errors
