class_name GuiMatchFactory
extends RefCounted

## GUI composition root for the standard single-table tournament.
##
## This stays outside the core so the rule engine does not know how a GUI
## chooses concrete agents.

var creation_count: int = 0


func create(config: ResolvedTournamentConfig) -> TournamentMatch:
	assert(config != null, "A resolved configuration is required.")
	creation_count += 1
	var streams := RngStreamFactory.new().create(config)
	var agents: Dictionary[int, Agent] = {}
	var configured_agents: Dictionary[int, StringName] = config.seat_agents
	for seat: int in range(config.player_count):
		if configured_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			agents[seat] = HumanAgent.new()
		else:
			agents[seat] = _create_bot(configured_agents[seat], streams.get_bot_rng(seat))
	return TournamentMatch.new(config, agents)


func _create_bot(agent_id: StringName, rng: RandomNumberGenerator) -> BotAgent:
	match agent_id:
		&"tight_passive":
			return TightPassiveAgent.new(rng)
		&"loose_aggressive":
			return LooseAggressiveAgent.new(rng)
		_:
			return RandomAgent.new(rng)
