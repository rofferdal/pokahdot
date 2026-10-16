class_name RandomAgent
extends BotAgent

const DEFAULT_PROFILE_PATH := "res://resources/bot_profiles/random_default.tres"


func _init(rng: RandomNumberGenerator) -> void:
	super(_configured_model(rng), load(DEFAULT_PROFILE_PATH) as BotProfile)


static func _configured_model(rng: RandomNumberGenerator) -> RandomDecisionModel:
	var profile := load(DEFAULT_PROFILE_PATH) as BotProfile
	var model := RandomDecisionModel.new()
	var errors: PackedStringArray = model.configure(profile.parameters.duplicate(true), rng)
	assert(errors.is_empty(), "The default random profile must be valid.")
	return model
