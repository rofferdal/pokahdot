class_name GuiMatchFactory
extends RefCounted

## GUI composition root for the standard single-table tournament.
##
## This stays outside the core so the rule engine does not know how a GUI
## chooses concrete agents.

var creation_count: int = 0
var _roster: PlayableBotRoster


func _init(roster: PlayableBotRoster = null) -> void:
	_roster = roster if roster != null else PlayableBotRoster.new()


func create(config: ResolvedTournamentConfig) -> TournamentMatch:
	assert(config != null, "A resolved configuration is required.")
	creation_count += 1
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


func _create_bot(profile: BotProfile, rng: RandomNumberGenerator) -> BotAgent:
	var result := _roster.create_bot(profile, rng)
	assert(result.is_ok(), "The selected playable bot profile must be valid: %s" % result.errors)
	return result.agent as BotAgent
