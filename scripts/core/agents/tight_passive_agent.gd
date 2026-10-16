class_name TightPassiveAgent
extends BotAgent

const DEFAULT_PROFILE_PATH := "res://resources/bot_profiles/tight_passive_default.tres"


func _init(rng: RandomNumberGenerator) -> void:
	super(_configured_model(rng), load(DEFAULT_PROFILE_PATH) as BotProfile)


static func _configured_model(rng: RandomNumberGenerator) -> TightPassiveDecisionModel:
	var profile := load(DEFAULT_PROFILE_PATH) as BotProfile
	var model := TightPassiveDecisionModel.new()
	var errors: PackedStringArray = model.configure(profile.parameters.duplicate(true), rng)
	assert(errors.is_empty(), "The default tight-passive profile must be valid.")
	return model
