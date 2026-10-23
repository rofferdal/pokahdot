class_name PlayableBotRosterSelection
extends RefCounted

## Immutable result of drawing curated bot profile snapshots for one match.

var profiles: Array[BotProfile] = []
var errors: PackedStringArray = []


func _init(
	selected_profiles: Array[BotProfile] = [], selection_errors: PackedStringArray = []
) -> void:
	for profile: BotProfile in selected_profiles:
		profiles.append(profile.duplicate(true) as BotProfile if profile != null else null)
	errors = selection_errors.duplicate()


func is_ok() -> bool:
	return errors.is_empty()


func get_profiles() -> Array[BotProfile]:
	var copied: Array[BotProfile] = []
	for profile: BotProfile in profiles:
		copied.append(profile.duplicate(true) as BotProfile if profile != null else null)
	return copied
