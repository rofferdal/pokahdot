class_name CliMatchFactory
extends RefCounted

## Composition root for the standard CLI table: one human and configured bot profiles.

const CliMatchCreationResultScript := preload("res://scripts/cli/cli_match_creation_result.gd")

var _roster: PlayableBotRoster


func _init(roster: PlayableBotRoster = null) -> void:
	_roster = roster if roster != null else PlayableBotRoster.new()


func create(config: ResolvedTournamentConfig) -> TournamentMatch:
	return create_with_diagnostics(config).match_instance


func create_with_diagnostics(config: ResolvedTournamentConfig) -> CliMatchCreationResultScript:
	assert(config != null, "A resolved configuration is required.")
	var streams := RngStreamFactory.new().create(config)
	var selection := _roster.select(
		config.player_count - 1, streams.get_seat_profile_assignment_rng(), config.use_legacy_models
	)
	assert(selection.is_ok(), "The playable bot roster must resolve: %s" % selection.errors)
	var profiles := selection.get_profiles()
	var agents: Dictionary[int, Agent] = {}
	var lines := _roster_diagnostics(config, profiles)
	var profile_index: int = 0
	var resolved_human_seat: int = Table.NO_SEAT
	for seat: int in range(config.player_count):
		if config.seat_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			agents[seat] = HumanAgent.new()
			resolved_human_seat = seat
			lines.append("Seat %d: human" % seat)
		else:
			var profile: BotProfile = profiles[profile_index]
			agents[seat] = _create_bot(profile, streams.get_bot_rng(seat))
			lines.append(
				(
					"Seat %d: model=%s profile=%s name=%s"
					% [seat, profile.model_id, profile.profile_id, profile.display_name]
				)
			)
			profile_index += 1
	return CliMatchCreationResultScript.new(
		TournamentMatch.new(config, agents, null, streams), resolved_human_seat, lines
	)


func human_seat(config: ResolvedTournamentConfig) -> int:
	for seat: int in range(config.player_count):
		if config.seat_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			return seat
	return Table.NO_SEAT


func diagnostics(config: ResolvedTournamentConfig) -> PackedStringArray:
	return create_with_diagnostics(config).diagnostics


func _roster_diagnostics(
	config: ResolvedTournamentConfig, profiles: Array[BotProfile]
) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(
		"Legacy heuristic models: %s" % ("included" if config.use_legacy_models else "not included")
	)
	lines.append("Bot roster version: %s" % _roster.get_roster_version())
	var selected_profile_ids := PackedStringArray()
	for profile: BotProfile in profiles:
		selected_profile_ids.append(String(profile.profile_id))
	lines.append("Selected bot profile IDs: %s" % ",".join(selected_profile_ids))
	var selected_model_families := PackedStringArray()
	for profile: BotProfile in profiles:
		selected_model_families.append(String(profile.model_id))
	lines.append("Selected bot model families: %s" % ",".join(selected_model_families))
	return lines


func _create_bot(profile: BotProfile, rng: RandomNumberGenerator) -> BotAgent:
	var result := _roster.create_bot(profile, rng)
	assert(result.is_ok(), "The selected playable bot profile must be valid: %s" % result.errors)
	return result.agent as BotAgent
