class_name SimulationRosterManifestSettings
extends RefCounted

## Typed planning settings for a manifest generated from the playable roster.
##
## This simulation-layer value deliberately has no command-line, filesystem,
## or terminal concerns. An empty batch ID requests roster-version derivation.

const DEFAULT_SEED_START: int = 71001
## 2520 is divisible by every single-table size (2 through 9) and the curated
## 18-profile catalog, keeping the default cyclic roster schedule balanced.
const DEFAULT_TOURNAMENT_COUNT: int = 2520
const DEFAULT_STARTING_STACK: int = 1000
const DEFAULT_SMALL_BLIND: int = 5
const DEFAULT_BIG_BLIND: int = 10
const DEFAULT_MINIMUM_PROFILE_SAMPLES: int = 100

var batch_id: StringName
var seed_start: int = DEFAULT_SEED_START
var tournament_count: int = DEFAULT_TOURNAMENT_COUNT
var regime_preset: StringName = &"standard"
var starting_stack: int = DEFAULT_STARTING_STACK
var starting_small_blind: int = DEFAULT_SMALL_BLIND
var starting_big_blind: int = DEFAULT_BIG_BLIND
var minimum_profile_samples: int = DEFAULT_MINIMUM_PROFILE_SAMPLES


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if seed_start == 0:
		errors.append("Roster manifest seed_start must be non-zero.")
	if tournament_count <= 0:
		errors.append("Roster manifest tournament count must be positive.")
	if regime_preset != &"standard":
		errors.append("Roster manifest regime preset must be standard.")
	if starting_stack <= 0:
		errors.append("Roster manifest starting stack must be positive.")
	if starting_small_blind <= 0 or starting_big_blind <= 0:
		errors.append("Roster manifest starting blinds must be positive.")
	elif starting_small_blind > starting_big_blind:
		errors.append("Roster manifest starting small blind cannot exceed the big blind.")
	if minimum_profile_samples <= 0:
		errors.append("Roster manifest minimum profile samples must be positive.")
	return errors
