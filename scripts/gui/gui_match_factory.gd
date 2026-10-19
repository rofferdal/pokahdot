class_name GuiMatchFactory
extends RefCounted

## GUI composition root for the standard single-table tournament.
##
## This stays outside the core so the rule engine does not know how a GUI
## chooses concrete agents.

const STRATEGY_MODEL_SCRIPT := preload("res://scripts/core/agents/strategy_decision_model.gd")
const STRATEGY_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)
const EXPERIMENTAL_BOT_AGENT_IDS: Array[StringName] = [
	&"nit_caller",
	&"tight_aggressive",
	&"loose_passive",
	&"strategy_loose_aggressive",
	&"balanced",
]

var creation_count: int = 0


func create(config: ResolvedTournamentConfig) -> TournamentMatch:
	assert(config != null, "A resolved configuration is required.")
	creation_count += 1
	var streams := RngStreamFactory.new().create(config)
	var agents: Dictionary[int, Agent] = {}
	for seat: int in range(config.player_count):
		var agent_id := _agent_id_for(config, seat)
		if agent_id == RngStreamFactory.HUMAN_AGENT_ID:
			agents[seat] = HumanAgent.new()
		else:
			agents[seat] = _create_bot(agent_id, streams.get_bot_rng(seat))
	return TournamentMatch.new(config, agents)


func _agent_id_for(config: ResolvedTournamentConfig, seat: int) -> StringName:
	if seat == 0 or not config.allow_experimental_models:
		return config.seat_agents[seat]
	return EXPERIMENTAL_BOT_AGENT_IDS[(seat - 1) % EXPERIMENTAL_BOT_AGENT_IDS.size()]


func _create_bot(agent_id: StringName, rng: RandomNumberGenerator) -> BotAgent:
	match agent_id:
		&"tight_passive":
			return TightPassiveAgent.new(rng)
		&"loose_aggressive":
			return LooseAggressiveAgent.new(rng)
		&"nit_caller", &"tight_aggressive", &"loose_passive", &"balanced":
			return _create_strategy_bot(agent_id, rng)
		&"strategy_loose_aggressive":
			return _create_strategy_bot(&"loose_aggressive", rng)
		_:
			return RandomAgent.new(rng)


func _create_strategy_bot(profile_id: StringName, rng: RandomNumberGenerator) -> BotAgent:
	var profile := load("res://resources/bot_profiles/%s.tres" % profile_id) as BotProfile
	var registry := DecisionModelRegistry.new()
	registry.register_model(
		&"strategy_parameterized", STRATEGY_MODEL_SCRIPT, STRATEGY_PARAMETERS_SCRIPT
	)
	var result := AgentFactory.new(registry).create_bot(profile, rng)
	assert(result.is_ok(), "The default strategy profile must be valid.")
	return result.agent as BotAgent
