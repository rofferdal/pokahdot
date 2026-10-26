class_name BlindLevelProgression
extends RefCounted

## Core-owned hand-based blind schedule.
##
## The active-player count captured when a level begins determines that level's
## interval. It is not recalculated until the next level starts.

const MAX_BIG_BLIND: int = ConfigResolver.MAX_STARTUP_CHIPS

var small_blind: int:
	get:
		return _small_blind
var big_blind: int:
	get:
		return _big_blind
var blind_level: int:
	get:
		return _blind_level
var completed_hands_in_level: int:
	get:
		return _completed_hands_in_level
var hands_until_next_level: int:
	get:
		return _level_interval - _completed_hands_in_level
var active_player_count_at_level_start: int:
	get:
		return _active_player_count_at_level_start

var _small_blind: int
var _big_blind: int
var _blind_level: int = 1
var _completed_hands_in_level: int = 0
var _active_player_count_at_level_start: int
var _level_interval: int


func _init(
	initial_small_blind: int,
	initial_big_blind: int,
	initial_active_player_count: int,
) -> void:
	assert(initial_small_blind > 0, "The initial small blind must be positive.")
	assert(
		initial_big_blind >= initial_small_blind,
		"The initial big blind must be at least the small blind."
	)
	assert(initial_big_blind <= MAX_BIG_BLIND, "The initial big blind exceeds the limit.")
	assert(initial_small_blind <= MAX_BIG_BLIND, "The initial small blind exceeds the limit.")
	assert(initial_active_player_count >= 1, "A blind level requires an active player count.")
	_small_blind = initial_small_blind
	_big_blind = initial_big_blind
	_active_player_count_at_level_start = initial_active_player_count
	_level_interval = _interval_for(initial_active_player_count)


func record_completed_hand(active_player_count: int) -> bool:
	## Records one settled hand and returns whether a new level began.
	assert(active_player_count >= 1, "A completed hand must leave an active player count.")
	_completed_hands_in_level += 1
	if _completed_hands_in_level < _level_interval:
		return false
	_begin_next_level(active_player_count)
	return true


func copy() -> BlindLevelProgression:
	var copied := (
		BlindLevelProgression
		. new(
			_small_blind,
			_big_blind,
			_active_player_count_at_level_start,
		)
	)
	copied._blind_level = _blind_level
	copied._completed_hands_in_level = _completed_hands_in_level
	copied._level_interval = _level_interval
	return copied


func _begin_next_level(active_player_count: int) -> void:
	_blind_level += 1
	_completed_hands_in_level = 0
	_active_player_count_at_level_start = active_player_count
	_level_interval = _interval_for(active_player_count)
	_big_blind = _next_big_blind(_big_blind)
	_small_blind = _big_blind / 2


func _interval_for(active_player_count: int) -> int:
	return active_player_count * 2 if active_player_count >= 5 else 10


func _next_big_blind(current_big_blind: int) -> int:
	# ceil(current * 1.25), then move to the next even integer if needed.
	if current_big_blind >= MAX_BIG_BLIND:
		return MAX_BIG_BLIND
	# The cap is checked before multiplication so malformed large inputs cannot
	# wrap before the result is clamped.
	if current_big_blind > (MAX_BIG_BLIND * 4 - 3) / 5:
		return MAX_BIG_BLIND
	var rounded_up: int = (current_big_blind * 5 + 3) / 4
	if rounded_up % 2 != 0:
		rounded_up += 1
	return mini(rounded_up, MAX_BIG_BLIND)
