class_name TestDecisionModelParameters
extends DecisionModelParameters

@export var value: int = 1


func validate() -> PackedStringArray:
	if value <= 0:
		return PackedStringArray(["Value must be positive."])
	return PackedStringArray()
