class_name TournamentConfig
extends Resource

## Mutable editor-facing template for tournament configuration.
##
## Never pass this Resource directly to a running tournament. Resolve it into a
## ResolvedTournamentConfig first so later edits cannot change live game state.

@export_range(2, 9, 1) var player_count: int = 6
@export var starting_stack: int = 1000
@export var small_blind: int = 5
@export var big_blind: int = 10
@export var rng_seed: int = 0
@export var tournament_mode: StringName = &"single_table"
@export var use_legacy_models: bool = false
@export var seat_agents: Dictionary[int, StringName] = {
	0: &"human",
	1: &"random",
	2: &"tight_passive",
	3: &"loose_aggressive",
	4: &"random",
	5: &"tight_passive",
	6: &"loose_aggressive",
	7: &"random",
	8: &"tight_passive",
}
