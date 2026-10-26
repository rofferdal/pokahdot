class_name SimulationMatchCreationResult
extends RefCounted

## Result of constructing one non-interactive simulation match.

var match_instance: TournamentMatch
var errors: PackedStringArray
var effective_seed: int
var stream_seeds: Dictionary[String, int]
var rng_algorithm_version: String


func _init(
	created_match: TournamentMatch = null,
	creation_errors: PackedStringArray = [],
	match_effective_seed: int = 0,
	match_stream_seeds: Dictionary[String, int] = {},
	match_rng_algorithm_version: String = RngStreamFactory.ALGORITHM_VERSION,
) -> void:
	match_instance = created_match
	errors = creation_errors.duplicate()
	effective_seed = match_effective_seed
	stream_seeds = match_stream_seeds.duplicate()
	rng_algorithm_version = match_rng_algorithm_version


func is_ok() -> bool:
	return match_instance != null and errors.is_empty()
