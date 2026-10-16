class_name CliMatchFactory
extends RefCounted

## Composition root for the standard CLI table: one human and configured bot profiles.


func create(config: ResolvedTournamentConfig) -> TournamentMatch:
	assert(config != null, "A resolved configuration is required.")
	var streams := RngStreamFactory.new().create(config)
	var agents: Dictionary[int, Agent] = {}
	var configured_agents: Dictionary[int, StringName] = config.seat_agents
	for seat: int in range(config.player_count):
		if configured_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			agents[seat] = HumanAgent.new()
		else:
			agents[seat] = _create_bot(configured_agents[seat], streams.get_bot_rng(seat))
	return TournamentMatch.new(config, agents)


func human_seat(config: ResolvedTournamentConfig) -> int:
	var configured_agents: Dictionary[int, StringName] = config.seat_agents
	for seat: int in range(config.player_count):
		if configured_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			return seat
	return Table.NO_SEAT


func diagnostics(config: ResolvedTournamentConfig) -> PackedStringArray:
	var lines := PackedStringArray()
	var configured_agents: Dictionary[int, StringName] = config.seat_agents
	for seat: int in range(config.player_count):
		var agent_id: StringName = configured_agents[seat]
		if agent_id == RngStreamFactory.HUMAN_AGENT_ID:
			lines.append("Seat %d: human" % seat)
		else:
			var agent: BotAgent = _create_bot(agent_id, _diagnostic_rng(seat))
			lines.append("Seat %d: model=%s profile=%s" % [seat, agent.model_id, agent.profile_id])
	return lines


func _create_bot(agent_id: StringName, rng: RandomNumberGenerator) -> BotAgent:
	match agent_id:
		&"tight_passive":
			return TightPassiveAgent.new(rng)
		&"loose_aggressive":
			return LooseAggressiveAgent.new(rng)
		_:
			return RandomAgent.new(rng)


func _diagnostic_rng(seat: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seat + 1
	return rng
