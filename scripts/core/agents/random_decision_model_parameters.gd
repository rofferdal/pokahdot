class_name RandomDecisionModelParameters
extends DecisionModelParameters

## Relative weights used when choosing among currently legal action kinds.

@export_range(0, 100) var fold_weight: int = 1
@export_range(0, 100) var passive_weight: int = 4
@export_range(0, 100) var aggressive_weight: int = 2


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if fold_weight < 0 or fold_weight > 100:
		errors.append("Fold weight must be between 0 and 100.")
	if passive_weight < 0 or passive_weight > 100:
		errors.append("Passive weight must be between 0 and 100.")
	if aggressive_weight < 0 or aggressive_weight > 100:
		errors.append("Aggressive weight must be between 0 and 100.")
	if fold_weight + passive_weight + aggressive_weight == 0:
		errors.append("At least one random action weight must be positive.")
	return errors
