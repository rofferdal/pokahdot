class_name AvatarAssignmentService
extends RefCounted

## Assigns visual avatars without touching tournament or poker RNG streams.

var _catalog: GuiAvatarCatalog


func _init(catalog: GuiAvatarCatalog = null) -> void:
	_catalog = (
		GuiAvatarCatalog.new(GuiAvatarCatalog.default_avatar_paths())
		if catalog == null
		else catalog
	)


func assign_for_tournament(seat_count: int, seed: int) -> AvatarAssignmentResult:
	var result := AvatarAssignmentResult.new()
	var validation_error: String = _catalog.validation_error_for(seat_count)
	if not validation_error.is_empty():
		result.error_message = validation_error
		return result

	var shuffled_paths: Array[String] = []
	for avatar_path: String in _catalog.get_avatar_paths():
		shuffled_paths.append(avatar_path)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index: int in range(shuffled_paths.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var swap_value: String = shuffled_paths[index]
		shuffled_paths[index] = shuffled_paths[swap_index]
		shuffled_paths[swap_index] = swap_value
	for seat: int in range(seat_count):
		result.assignments[seat] = shuffled_paths[seat]
	return result
