class_name CliMatchFactory
extends RefCounted

## Composition root for the Milestone 1 CLI table: one human and random bots.


func create(config: ResolvedTournamentConfig) -> TournamentMatch:
	assert(config != null, "A resolved configuration is required.")
	var streams := RngStreamFactory.new().create(config)
	var agents: Dictionary[int, Agent] = {}
	var configured_agents: Dictionary[int, StringName] = config.seat_agents
	for seat: int in range(config.player_count):
		if configured_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			agents[seat] = HumanAgent.new()
		else:
			agents[seat] = RandomAgent.new(streams.get_bot_rng(seat))
	return TournamentMatch.new(config, agents)


func human_seat(config: ResolvedTournamentConfig) -> int:
	var configured_agents: Dictionary[int, StringName] = config.seat_agents
	for seat: int in range(config.player_count):
		if configured_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			return seat
	return Table.NO_SEAT
