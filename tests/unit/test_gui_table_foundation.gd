extends "res://tests/support/poker_gut_test.gd"

const AvatarAssignmentServiceScript := preload("res://scripts/gui/avatar_assignment_service.gd")
const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")


func test_default_avatar_catalog_has_sixteen_distinct_loadable_pixel_portraits() -> void:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var distinct_paths: Dictionary = {}

	assert_eq(paths.size(), 16)
	for avatar_path: String in paths:
		distinct_paths[avatar_path] = true
		var avatar_texture := load(avatar_path) as Texture2D
		assert_not_null(avatar_texture, avatar_path)
		assert_eq(avatar_texture.get_width(), 64, avatar_path)
		assert_eq(avatar_texture.get_height(), 64, avatar_path)
	assert_eq(distinct_paths.size(), 16)


func test_avatar_assignment_is_seeded_and_unique() -> void:
	var catalog := GuiAvatarCatalogScript.new(PackedStringArray(["a", "b", "c", "d"]))
	var service = AvatarAssignmentServiceScript.new(catalog)

	var first = service.assign_for_tournament(4, _avatar_rng(7331))
	var second = service.assign_for_tournament(4, _avatar_rng(7331))

	assert_true(first.is_ok())
	assert_eq(first.assignments, second.assignments)
	assert_eq(first.assignments.values().size(), 4)
	var distinct_assignments: Dictionary = {}
	for avatar_path: String in first.assignments.values():
		distinct_assignments[avatar_path] = true
	assert_eq(distinct_assignments.size(), 4)


func test_avatar_assignment_rejects_an_insufficient_catalog() -> void:
	var catalog := GuiAvatarCatalogScript.new(PackedStringArray(["a", "b"]))
	var result = AvatarAssignmentServiceScript.new(catalog).assign_for_tournament(3, _avatar_rng(1))

	assert_false(result.is_ok())
	assert_eq(result.assignments, {})
	assert_eq(
		result.error_message, "Avatar catalog has 2 assets but 3 seats require distinct avatars."
	)


func _avatar_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
