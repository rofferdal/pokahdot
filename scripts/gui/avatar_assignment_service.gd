class_name AvatarAssignmentService
extends RefCounted

## Assigns visual avatars without touching tournament or poker RNG streams.

const RNG_STREAM_ID := "gui_avatars"

var _catalog: GuiAvatarCatalog


func _init(catalog: GuiAvatarCatalog = null) -> void:
	_catalog = (
		GuiAvatarCatalog.new(GuiAvatarCatalog.default_avatar_paths())
		if catalog == null
		else catalog
	)


func assign_for_tournament(
	seat_count: int,
	rng: RandomNumberGenerator,
) -> AvatarAssignmentResult:
	var validation_error: String = _catalog.validation_error_for(seat_count)
	if not validation_error.is_empty():
		return AvatarAssignmentResult.new({}, validation_error)
	if rng == null:
		return AvatarAssignmentResult.new({}, "The gui_avatars RNG stream is required.")

	var shuffled_paths: Array[String] = []
	for avatar_path: String in _catalog.get_avatar_paths():
		shuffled_paths.append(avatar_path)
	for index: int in range(shuffled_paths.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var swap_value: String = shuffled_paths[index]
		shuffled_paths[index] = shuffled_paths[swap_index]
		shuffled_paths[swap_index] = swap_value
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(seat_count):
		assignments[seat] = shuffled_paths[seat]
	return AvatarAssignmentResult.new(assignments)
