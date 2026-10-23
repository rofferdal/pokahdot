class_name CliMatchFactory
extends RefCounted

## Composition root for the standard CLI table: one human and configured bot profiles.

var _roster: PlayableBotRoster


func _init(roster: PlayableBotRoster = null) -> void:
	_roster = roster if roster != null else PlayableBotRoster.new()


func create(config: ResolvedTournamentConfig) -> TournamentMatch:
	assert(config != null, "A resolved configuration is required.")
	var streams := RngStreamFactory.new().create(config)
	var selection := _roster.select(
		config.player_count - 1, streams.get_seat_profile_assignment_rng()
	)
	assert(selection.is_ok(), "The playable bot roster must resolve: %s" % selection.errors)
	var profiles := selection.get_profiles()
	var agents: Dictionary[int, Agent] = {}
	var profile_index: int = 0
	for seat: int in range(config.player_count):
		if config.seat_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			agents[seat] = HumanAgent.new()
		else:
			agents[seat] = _create_bot(profiles[profile_index], streams.get_bot_rng(seat))
			profile_index += 1
	return TournamentMatch.new(config, agents, null, streams)


func human_seat(config: ResolvedTournamentConfig) -> int:
	for seat: int in range(config.player_count):
		if config.seat_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			return seat
	return Table.NO_SEAT


func diagnostics(config: ResolvedTournamentConfig) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(
		"Bot roster: %s" % ("experimental" if config.allow_experimental_models else "production")
	)
	lines.append("Bot roster version: %s" % _roster.get_roster_version())
	var streams := RngStreamFactory.new().create(config)
	var selection := _roster.select(
		config.player_count - 1, streams.get_seat_profile_assignment_rng()
	)
	assert(selection.is_ok(), "The playable bot roster must resolve: %s" % selection.errors)
	var profiles := selection.get_profiles()
	var selected_profile_ids := PackedStringArray()
	for profile: BotProfile in profiles:
		selected_profile_ids.append(String(profile.profile_id))
	lines.append("Selected bot profile IDs: %s" % ",".join(selected_profile_ids))
	var profile_index: int = 0
	for seat: int in range(config.player_count):
		if config.seat_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			lines.append("Seat %d: human" % seat)
		else:
			var profile: BotProfile = profiles[profile_index]
			profile_index += 1
			lines.append(
				"Seat %d: model=%s profile=%s" % [seat, profile.model_id, profile.profile_id]
			)
	return lines


func _create_bot(profile: BotProfile, rng: RandomNumberGenerator) -> BotAgent:
	var result := _roster.create_bot(profile, rng)
	assert(result.is_ok(), "The selected playable bot profile must be valid: %s" % result.errors)
	return result.agent as BotAgent
