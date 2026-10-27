class_name SimulationTournamentInput
extends RefCounted

## Typed adapter input after scheduling and profile-seat assignment.

var tournament_index: int
var effective_seed: int
var matchup: SimulationMatchup
var matchup_occurrence: int
var rotation: int
var regime_id: StringName
var plan_id: StringName
var plan_tournament_index: int
var regime: SimulationRegime
var _seat_profiles: Dictionary[int, BotProfile] = {}


func _init(
	index: int,
	seed: int,
	selected_matchup: SimulationMatchup,
	seat_profiles: Dictionary[int, BotProfile],
	selected_matchup_occurrence: int = 0,
	selected_rotation: int = 0,
	selected_regime_id: StringName = &"",
	selected_plan_id: StringName = &"",
	selected_plan_tournament_index: int = -1,
	selected_regime: SimulationRegime = null,
) -> void:
	tournament_index = index
	effective_seed = seed
	matchup = selected_matchup
	matchup_occurrence = selected_matchup_occurrence
	rotation = selected_rotation
	regime_id = selected_regime_id
	plan_id = selected_plan_id
	plan_tournament_index = selected_plan_tournament_index
	regime = selected_regime
	for seat: int in seat_profiles:
		var profile: BotProfile = seat_profiles[seat]
		_seat_profiles[seat] = profile.duplicate(true) as BotProfile if profile != null else null


func get_seat_profiles() -> Dictionary[int, BotProfile]:
	var copied: Dictionary[int, BotProfile] = {}
	for seat: int in _seat_profiles:
		var profile: BotProfile = _seat_profiles[seat]
		copied[seat] = profile.duplicate(true) as BotProfile if profile != null else null
	return copied


## Identity consumers do not need expensive Resource snapshots.
func get_seat_profile_ids() -> Dictionary[int, StringName]:
	var ids: Dictionary[int, StringName] = {}
	for seat: int in _seat_profiles:
		var profile: BotProfile = _seat_profiles[seat]
		ids[seat] = profile.profile_id if profile != null else &""
	return ids


func validate(player_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	var configured_player_count := player_count if regime == null else regime.player_count
	if tournament_index < 0:
		errors.append("Tournament index must be non-negative.")
	if matchup_occurrence < 0:
		errors.append("Matchup occurrence must be non-negative.")
	if rotation < 0 or rotation >= configured_player_count:
		errors.append("Simulation rotation must select a configured seat.")
	if effective_seed == 0:
		errors.append("Simulation effective seed must be non-zero.")
	if matchup == null:
		errors.append("A simulation matchup is required.")
	else:
		errors.append_array(matchup.validate())
	if _seat_profiles.size() != configured_player_count:
		errors.append("Every simulation seat must have one bot profile.")
	for seat: int in range(configured_player_count):
		if not _seat_profiles.has(seat) or _seat_profiles[seat] == null:
			errors.append("Simulation seat %d has no bot profile." % seat)
	return errors
