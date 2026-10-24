class_name GuiMatchFactory
extends RefCounted

const GuiMatchCreationResultScript := preload("res://scripts/gui/gui_match_creation_result.gd")

## GUI composition root for the standard single-table tournament.
##
## This stays outside the core so the rule engine does not know how a GUI
## chooses concrete agents.

var creation_count: int = 0
var _roster: PlayableBotRoster
var _name_assignment_service: NameAssignmentService
var _avatar_assignment_service: AvatarAssignmentService
var _rng_stream_factory: RngStreamFactory


func _init(
	roster: PlayableBotRoster = null,
	name_assignment_service: NameAssignmentService = null,
	avatar_assignment_service: AvatarAssignmentService = null,
	rng_stream_factory: RngStreamFactory = null,
) -> void:
	_roster = roster if roster != null else PlayableBotRoster.new()
	_name_assignment_service = (
		NameAssignmentService.new() if name_assignment_service == null else name_assignment_service
	)
	_avatar_assignment_service = (
		AvatarAssignmentService.new()
		if avatar_assignment_service == null
		else avatar_assignment_service
	)
	_rng_stream_factory = (
		RngStreamFactory.new() if rng_stream_factory == null else rng_stream_factory
	)


func create(config: ResolvedTournamentConfig) -> GuiMatchCreationResultScript:
	assert(config != null, "A resolved configuration is required.")
	creation_count += 1
	var core_streams: RngStreams = _rng_stream_factory.create(config)
	var human_seat: int = _find_human_seat(config)
	if human_seat == Table.NO_SEAT:
		return (
			GuiMatchCreationResultScript
			. new(
				null,
				{},
				{},
				core_streams.effective_seed,
				"GUI tournament creation requires exactly one human seat.",
			)
		)

	var selection := (
		_roster
		. select(
			config.player_count - 1,
			core_streams.get_seat_profile_assignment_rng(),
			config.use_legacy_models,
		)
	)
	if not selection.is_ok():
		return (
			GuiMatchCreationResultScript
			. new(
				null,
				{},
				{},
				core_streams.effective_seed,
				"The playable bot roster could not be resolved: %s" % "; ".join(selection.errors),
			)
		)
	var profiles := selection.get_profiles()
	var agents: Dictionary[int, Agent] = {}
	var profile_index: int = 0
	for seat: int in range(config.player_count):
		if config.seat_agents[seat] == RngStreamFactory.HUMAN_AGENT_ID:
			agents[seat] = HumanAgent.new()
		else:
			var agent_creation := _roster.create_bot(
				profiles[profile_index], core_streams.get_bot_rng(seat)
			)
			if not agent_creation.is_ok():
				return (
					GuiMatchCreationResultScript
					. new(
						null,
						{},
						{},
						core_streams.effective_seed,
						(
							"The selected bot profile for seat %d could not be created: %s"
							% [seat, "; ".join(agent_creation.errors)]
						),
					)
				)
			agents[seat] = agent_creation.agent as BotAgent
			profile_index += 1

	var presentation_streams: RngStreams = (
		_rng_stream_factory
		. create_named(
			core_streams.effective_seed,
			PackedStringArray(
				[
					NameAssignmentService.RNG_STREAM_ID,
					AvatarAssignmentService.RNG_STREAM_ID,
				]
			),
		)
	)
	var name_result: NameAssignmentResult = (
		_name_assignment_service
		. assign_for_tournament(
			config.player_count,
			human_seat,
			presentation_streams.get_rng(NameAssignmentService.RNG_STREAM_ID),
		)
	)
	if not name_result.is_ok():
		return GuiMatchCreationResultScript.new(
			null, {}, {}, core_streams.effective_seed, name_result.error_message
		)
	var avatar_result: AvatarAssignmentResult = (
		_avatar_assignment_service
		. assign_for_tournament(
			config.player_count,
			presentation_streams.get_rng(AvatarAssignmentService.RNG_STREAM_ID),
		)
	)
	if not avatar_result.is_ok():
		return GuiMatchCreationResultScript.new(
			null, {}, {}, core_streams.effective_seed, avatar_result.error_message
		)

	var match_instance := TournamentMatch.new(config, agents, null, core_streams)
	return (
		GuiMatchCreationResultScript
		. new(
			match_instance,
			name_result.assignments,
			avatar_result.assignments,
			core_streams.effective_seed,
		)
	)


func _find_human_seat(config: ResolvedTournamentConfig) -> int:
	var human_seat: int = Table.NO_SEAT
	var seat_agents: Dictionary[int, StringName] = config.seat_agents
	for seat: int in range(config.player_count):
		if seat_agents.get(seat, &"") != RngStreamFactory.HUMAN_AGENT_ID:
			continue
		if human_seat != Table.NO_SEAT:
			return Table.NO_SEAT
		human_seat = seat
	return human_seat
