extends "res://tests/support/poker_gut_test.gd"

const MODEL_SCRIPT := preload("res://tests/support/test_decision_model.gd")
const PARAMETERS_SCRIPT := preload("res://tests/support/test_decision_model_parameters.gd")


func test_registry_rejects_duplicate_ids_and_constructs_fresh_models() -> void:
	var registry := DecisionModelRegistry.new()

	assert_true(registry.register_model(&"test", MODEL_SCRIPT, PARAMETERS_SCRIPT))
	assert_false(registry.register_model(&"test", MODEL_SCRIPT, PARAMETERS_SCRIPT))
	assert_ne(registry.create_model(&"test"), registry.create_model(&"test"))


func test_factory_creates_human_agent() -> void:
	var result: AgentCreationResult = AgentFactory.new(DecisionModelRegistry.new()).create_human()

	assert_true(result.is_ok())
	assert_true(result.agent is HumanAgent)


func test_factory_rejects_unknown_model_and_mismatched_parameters() -> void:
	var registry := DecisionModelRegistry.new()
	registry.register_model(&"test", MODEL_SCRIPT, PARAMETERS_SCRIPT)
	var factory := AgentFactory.new(registry)
	var unknown := BotProfile.new()
	unknown.profile_id = &"unknown_profile"
	unknown.model_id = &"missing"
	unknown.parameters = TestDecisionModelParameters.new()
	var mismatched := BotProfile.new()
	mismatched.profile_id = &"wrong_parameters"
	mismatched.model_id = &"test"
	mismatched.parameters = DecisionModelParameters.new()

	assert_false(factory.create_bot(unknown, _rng()).is_ok())
	assert_false(factory.create_bot(mismatched, _rng()).is_ok())


func test_factory_reports_parameter_validation_errors() -> void:
	var factory := AgentFactory.new(_registry())
	var profile := _profile()
	(profile.parameters as TestDecisionModelParameters).value = 0

	var result: AgentCreationResult = factory.create_bot(profile, _rng())

	assert_false(result.is_ok())
	assert_has(result.errors, "Value must be positive.")


func test_factory_deep_copies_parameters_before_model_configuration() -> void:
	var factory := AgentFactory.new(_registry())
	var profile := _profile()
	var result: AgentCreationResult = factory.create_bot(profile, _rng())
	(profile.parameters as TestDecisionModelParameters).value = 99

	assert_true(result.is_ok())
	assert_eq(result.agent.choose_action(null).kind, PlayerAction.Kind.CHECK)


func _registry() -> DecisionModelRegistry:
	var registry := DecisionModelRegistry.new()
	registry.register_model(&"test", MODEL_SCRIPT, PARAMETERS_SCRIPT)
	return registry


func _profile() -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = &"test_profile"
	profile.model_id = &"test"
	profile.parameters = TestDecisionModelParameters.new()
	return profile


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	return rng
