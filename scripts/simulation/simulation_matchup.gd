class_name SimulationMatchup
extends RefCounted

## Immutable profile snapshots for one already-selected tournament matchup.

var matchup_id: StringName
var _profiles: Array[BotProfile] = []


func _init(id: StringName, profiles: Array[BotProfile]) -> void:
	matchup_id = id
	for profile: BotProfile in profiles:
		_profiles.append(profile.duplicate(true) as BotProfile if profile != null else null)


func get_profiles() -> Array[BotProfile]:
	var copied: Array[BotProfile] = []
	for profile: BotProfile in _profiles:
		copied.append(profile.duplicate(true) as BotProfile if profile != null else null)
	return copied


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if matchup_id.is_empty():
		errors.append("A simulation matchup ID is required.")
	if _profiles.is_empty():
		errors.append("A simulation matchup requires at least one profile.")
	for index: int in range(_profiles.size()):
		if _profiles[index] == null or _profiles[index].profile_id.is_empty():
			errors.append("Simulation matchup profile %d is invalid." % index)
	return errors
