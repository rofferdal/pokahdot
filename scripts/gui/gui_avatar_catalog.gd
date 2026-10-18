class_name GuiAvatarCatalog
extends RefCounted

## Visual-only avatar paths owned by the GUI layer.

var _avatar_paths: PackedStringArray


static func default_avatar_paths() -> PackedStringArray:
	return PackedStringArray(
		[
			"res://assets/avatars/avatar_01.png",
			"res://assets/avatars/avatar_02.png",
			"res://assets/avatars/avatar_03.png",
			"res://assets/avatars/avatar_04.png",
			"res://assets/avatars/avatar_05.png",
			"res://assets/avatars/avatar_06.png",
			"res://assets/avatars/avatar_07.png",
			"res://assets/avatars/avatar_08.png",
			"res://assets/avatars/avatar_09.png",
			"res://assets/avatars/avatar_10.png",
			"res://assets/avatars/avatar_11.png",
			"res://assets/avatars/avatar_12.png",
			"res://assets/avatars/avatar_13.png",
			"res://assets/avatars/avatar_14.png",
			"res://assets/avatars/avatar_15.png",
			"res://assets/avatars/avatar_16.png",
		]
	)


func _init(avatar_paths: PackedStringArray = PackedStringArray()) -> void:
	_avatar_paths = default_avatar_paths() if avatar_paths.is_empty() else avatar_paths.duplicate()


func get_avatar_paths() -> PackedStringArray:
	return _avatar_paths.duplicate()


func validation_error_for(seat_count: int) -> String:
	if seat_count < 1:
		return "At least one seat requires an avatar."
	if _avatar_paths.size() < seat_count:
		return (
			"Avatar catalog has %d assets but %d seats require distinct avatars."
			% [
				_avatar_paths.size(),
				seat_count,
			]
		)
	var used_paths: Dictionary[String, bool] = {}
	for avatar_path: String in _avatar_paths:
		if avatar_path.is_empty():
			return "Avatar catalog contains an empty asset path."
		if used_paths.has(avatar_path):
			return "Avatar catalog contains duplicate asset path: %s." % avatar_path
		used_paths[avatar_path] = true
	return ""
