class_name ConfigResolver
extends RefCounted

const MAX_INT_64: int = 9223372036854775807
const MIN_PLAYER_COUNT: int = 2
const MAX_PLAYER_COUNT: int = 9
const HUMAN_AGENT_ID: StringName = &"human"
const SINGLE_TABLE_MODE: StringName = &"single_table"


func resolve(defaults: TournamentConfig, overrides: StartupOverrides) -> ConfigResolution:
	if defaults == null:
		var missing_defaults_errors: Array[ConfigError] = []
		_add_error(
			missing_defaults_errors,
			ConfigError.Code.MISSING_DEFAULTS,
			&"defaults",
			"Tournament configuration defaults are required.",
		)
		return ConfigResolution.new(null, missing_defaults_errors)

	var applied_overrides: StartupOverrides = overrides
	if applied_overrides == null:
		applied_overrides = StartupOverrides.new()

	var player_count: int = defaults.player_count
	if applied_overrides.has_player_count:
		player_count = applied_overrides.player_count
	var starting_stack: int = (
		applied_overrides.starting_stack
		if applied_overrides.has_starting_stack
		else defaults.starting_stack
	)
	var small_blind: int = (
		applied_overrides.small_blind if applied_overrides.has_small_blind else defaults.small_blind
	)
	var big_blind: int = (
		applied_overrides.big_blind if applied_overrides.has_big_blind else defaults.big_blind
	)
	var use_legacy_models: bool = (
		applied_overrides.use_legacy_models
		if applied_overrides.has_use_legacy_models
		else defaults.use_legacy_models
	)

	var errors: Array[ConfigError] = []
	_validate_scalars(
		player_count,
		starting_stack,
		small_blind,
		big_blind,
		defaults.tournament_mode,
		errors,
	)

	var seat_agents: Dictionary[int, StringName] = {}
	if player_count >= MIN_PLAYER_COUNT and player_count <= MAX_PLAYER_COUNT:
		seat_agents = _build_seat_agents(defaults.seat_agents, player_count, errors)

	if not errors.is_empty():
		return ConfigResolution.new(null, errors)

	var resolved_config := (
		ResolvedTournamentConfig
		. new(
			player_count,
			starting_stack,
			small_blind,
			big_blind,
			defaults.rng_seed,
			defaults.tournament_mode,
			seat_agents,
			use_legacy_models,
		)
	)
	return ConfigResolution.new(resolved_config)


func _validate_scalars(
	player_count: int,
	starting_stack: int,
	small_blind: int,
	big_blind: int,
	tournament_mode: StringName,
	errors: Array[ConfigError],
) -> void:
	if player_count < MIN_PLAYER_COUNT or player_count > MAX_PLAYER_COUNT:
		_add_error(
			errors,
			ConfigError.Code.PLAYER_COUNT_OUT_OF_RANGE,
			&"player_count",
			"Player count must be between 2 and 9.",
		)
	if starting_stack <= 0:
		_add_error(
			errors,
			ConfigError.Code.STARTING_STACK_NOT_POSITIVE,
			&"starting_stack",
			"Starting stack must be a positive integer.",
		)
	if small_blind <= 0:
		_add_error(
			errors,
			ConfigError.Code.SMALL_BLIND_NOT_POSITIVE,
			&"small_blind",
			"Small blind must be a positive integer.",
		)
	if big_blind <= 0:
		_add_error(
			errors,
			ConfigError.Code.BIG_BLIND_NOT_POSITIVE,
			&"big_blind",
			"Big blind must be a positive integer.",
		)
	if small_blind > 0 and big_blind > 0 and small_blind > big_blind:
		_add_error(
			errors,
			ConfigError.Code.SMALL_BLIND_EXCEEDS_BIG_BLIND,
			&"small_blind",
			"Small blind cannot exceed big blind.",
		)
	var has_chip_total_overflow := (
		player_count > 0 and starting_stack > 0 and starting_stack > MAX_INT_64 / player_count
	)
	if has_chip_total_overflow:
		_add_error(
			errors,
			ConfigError.Code.TOTAL_CHIPS_OVERFLOW,
			&"starting_stack",
			"Player count multiplied by starting stack exceeds the integer limit.",
		)
	if tournament_mode != SINGLE_TABLE_MODE:
		_add_error(
			errors,
			ConfigError.Code.UNSUPPORTED_TOURNAMENT_MODE,
			&"tournament_mode",
			"Tournament mode must be single_table in v1.",
		)


func _build_seat_agents(
	configured_agents: Dictionary[int, StringName],
	player_count: int,
	errors: Array[ConfigError],
) -> Dictionary[int, StringName]:
	var seat_agents: Dictionary[int, StringName] = {}
	var human_count: int = 0
	for seat: int in range(player_count):
		if not configured_agents.has(seat):
			_add_error(
				errors,
				ConfigError.Code.INVALID_SEAT_AGENTS,
				&"seat_agents",
				"Active seat %d has no agent ID." % seat,
			)
			continue

		var agent_id: StringName = configured_agents[seat]
		if agent_id.is_empty():
			_add_error(
				errors,
				ConfigError.Code.INVALID_SEAT_AGENTS,
				&"seat_agents",
				"Active seat %d has no agent ID." % seat,
			)
			continue
		seat_agents[seat] = agent_id
		if agent_id == HUMAN_AGENT_ID:
			human_count += 1

	if seat_agents.get(0, &"") != HUMAN_AGENT_ID or human_count != 1:
		_add_error(
			errors,
			ConfigError.Code.INVALID_SEAT_AGENTS,
			&"seat_agents",
			"Seat 0 must be the only human agent in v1.",
		)

	return seat_agents


func _add_error(
	errors: Array[ConfigError],
	code: ConfigError.Code,
	field: StringName,
	message: String,
) -> void:
	errors.append(ConfigError.new(code, field, message))
