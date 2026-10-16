class_name BotProfile
extends Resource

## Static binding between a profile ID, decision model ID, and typed parameters.

@export var profile_id: StringName
@export var model_id: StringName
@export var display_name: String
@export var parameters: DecisionModelParameters
