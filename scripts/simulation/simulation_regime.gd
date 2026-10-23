class_name SimulationRegime
extends RefCounted

## Immutable structural settings allowed to vary in simulation v1.
##
## Resolution delegates to the ordinary product ConfigResolver so the same
## player-count, stack, blind, overflow, and fixed-mode rules are enforced.

var regime_id: StringName
var player_count: int
var starting_stack: int
var starting_small_blind: int
var starting_big_blind: int
var blind_progression: StringName


func _init(
	id: StringName,
	players: int,
	stack: int,
	small_blind: int,
	big_blind: int,
	progression: StringName = &"normative_hand_based_v1",
) -> void:
	regime_id = id
	player_count = players
	starting_stack = stack
	starting_small_blind = small_blind
	starting_big_blind = big_blind
	blind_progression = progression


func resolve(seed: int) -> ConfigResolution:
	var config := TournamentConfig.new()
	config.player_count = player_count
	config.starting_stack = starting_stack
	config.small_blind = starting_small_blind
	config.big_blind = starting_big_blind
	config.rng_seed = seed
	config.tournament_mode = &"single_table"
	config.seat_agents = _product_validation_agents()
	return ConfigResolver.new().resolve(config, null)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if regime_id.is_empty():
		errors.append("A simulation regime ID is required.")
	var resolution := resolve(1)
	for error: ConfigError in resolution.get_errors():
		errors.append(error.message)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"regime_id": String(regime_id),
		"player_count": player_count,
		"starting_stack": starting_stack,
		"starting_small_blind": starting_small_blind,
		"starting_big_blind": starting_big_blind,
		"blind_progression": String(blind_progression),
	}


func _product_validation_agents() -> Dictionary[int, StringName]:
	var agents: Dictionary[int, StringName] = {}
	for seat: int in range(maxi(player_count, 0)):
		agents[seat] = &"human" if seat == 0 else &"random"
	return agents
