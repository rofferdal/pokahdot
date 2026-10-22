class_name SimulationTournamentInput
extends RefCounted

## Typed adapter input after scheduling and profile-seat assignment.

var tournament_index: int
var effective_seed: int
var matchup: SimulationMatchup
var matchup_occurrence: int
var rotation: int
var regime_id: StringName
var _seat_profiles: Dictionary[int, BotProfile] = {}


func _init(
	index: int,
	seed: int,
	selected_matchup: SimulationMatchup,
	seat_profiles: Dictionary[int, BotProfile],
	selected_matchup_occurrence: int = 0,
	selected_rotation: int = 0,
	selected_regime_id: StringName = &"",
) -> void:
	tournament_index = index
	effective_seed = seed
	matchup = selected_matchup
	matchup_occurrence = selected_matchup_occurrence
	rotation = selected_rotation
	regime_id = selected_regime_id
	for seat: int in seat_profiles:
		var profile: BotProfile = seat_profiles[seat]
		_seat_profiles[seat] = profile.duplicate(true) as BotProfile if profile != null else null


func get_seat_profiles() -> Dictionary[int, BotProfile]:
	var copied: Dictionary[int, BotProfile] = {}
	for seat: int in _seat_profiles:
		var profile: BotProfile = _seat_profiles[seat]
		copied[seat] = profile.duplicate(true) as BotProfile if profile != null else null
	return copied


func validate(player_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if tournament_index < 0:
		errors.append("Tournament index must be non-negative.")
	if matchup_occurrence < 0:
		errors.append("Matchup occurrence must be non-negative.")
	if rotation < 0 or rotation >= player_count:
		errors.append("Simulation rotation must select a configured seat.")
	if effective_seed == 0:
		errors.append("Simulation effective seed must be non-zero.")
	if matchup == null:
		errors.append("A simulation matchup is required.")
	else:
		errors.append_array(matchup.validate())
	if _seat_profiles.size() != player_count:
		errors.append("Every simulation seat must have one bot profile.")
	for seat: int in range(player_count):
		if not _seat_profiles.has(seat) or _seat_profiles[seat] == null:
			errors.append("Simulation seat %d has no bot profile." % seat)
	return errors
