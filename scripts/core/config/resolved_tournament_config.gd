class_name ResolvedTournamentConfig
extends RefCounted

## Immutable runtime snapshot produced by ConfigResolver.

var player_count: int:
	get:
		return _player_count

var starting_stack: int:
	get:
		return _starting_stack

var small_blind: int:
	get:
		return _small_blind

var big_blind: int:
	get:
		return _big_blind

var rng_seed: int:
	get:
		return _rng_seed

var tournament_mode: StringName:
	get:
		return _tournament_mode

var allow_experimental_models: bool:
	get:
		return _allow_experimental_models

var seat_agents: Dictionary[int, StringName]:
	get:
		return _copy_seat_agents()

var _player_count: int
var _starting_stack: int
var _small_blind: int
var _big_blind: int
var _rng_seed: int
var _tournament_mode: StringName
var _allow_experimental_models: bool
var _seat_agents: Dictionary[int, StringName]


func _init(
	config_player_count: int,
	config_starting_stack: int,
	config_small_blind: int,
	config_big_blind: int,
	config_rng_seed: int,
	config_tournament_mode: StringName,
	config_seat_agents: Dictionary[int, StringName],
	config_allow_experimental_models: bool = false,
) -> void:
	_player_count = config_player_count
	_starting_stack = config_starting_stack
	_small_blind = config_small_blind
	_big_blind = config_big_blind
	_rng_seed = config_rng_seed
	_tournament_mode = config_tournament_mode
	_allow_experimental_models = config_allow_experimental_models
	_seat_agents = config_seat_agents.duplicate(true)


func _copy_seat_agents() -> Dictionary[int, StringName]:
	var copied_agents: Dictionary[int, StringName] = {}
	for seat: int in _seat_agents:
		copied_agents[seat] = _seat_agents[seat]
	return copied_agents
