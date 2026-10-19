class_name AgentFactory
extends RefCounted

## Creates independently configured agents without exposing a global registry.

var _registry: DecisionModelRegistry


func _init(registry: DecisionModelRegistry) -> void:
	assert(registry != null, "An agent factory requires a model registry.")
	_registry = registry


func create_human() -> AgentCreationResult:
	return AgentCreationResult.new(HumanAgent.new())


func create_bot(profile: BotProfile, rng: RandomNumberGenerator) -> AgentCreationResult:
	var errors := PackedStringArray()
	if profile == null:
		errors.append("A bot profile is required.")
		return AgentCreationResult.new(null, errors)
	if profile.profile_id.is_empty():
		errors.append("A bot profile ID is required.")
	if not _registry.has_model(profile.model_id):
		errors.append("Unknown decision model ID: %s" % profile.model_id)
		return AgentCreationResult.new(null, errors)
	if not _registry.accepts_parameters(profile.model_id, profile.parameters):
		errors.append("Profile parameters do not match model %s." % profile.model_id)
		return AgentCreationResult.new(null, errors)

	var copied_parameters := profile.parameters.duplicate(true) as DecisionModelParameters
	var model: DecisionModel = _registry.create_model(profile.model_id)
	errors.append_array(model.configure(copied_parameters, rng))
	if not errors.is_empty():
		return AgentCreationResult.new(null, errors)
	model.set_profile_id_for_testing(profile.profile_id)
	return AgentCreationResult.new(BotAgent.new(model, profile))
