class_name StartupOverrides
extends RefCounted

## Optional user-provided startup values.
##
## Presence flags distinguish an omitted value from an explicitly supplied 0,
## which must be rejected by validation rather than interpreted as a default.

var has_player_count: bool = false
var player_count: int = 0
var has_starting_stack: bool = false
var starting_stack: int = 0
var has_small_blind: bool = false
var small_blind: int = 0
var has_big_blind: bool = false
var big_blind: int = 0
var has_use_legacy_models: bool = false
var use_legacy_models: bool = false


func set_player_count(value: int) -> StartupOverrides:
	has_player_count = true
	player_count = value
	return self


func set_starting_stack(value: int) -> StartupOverrides:
	has_starting_stack = true
	starting_stack = value
	return self


func set_small_blind(value: int) -> StartupOverrides:
	has_small_blind = true
	small_blind = value
	return self


func set_big_blind(value: int) -> StartupOverrides:
	has_big_blind = true
	big_blind = value
	return self


func set_use_legacy_models(value: bool) -> StartupOverrides:
	has_use_legacy_models = true
	use_legacy_models = value
	return self
