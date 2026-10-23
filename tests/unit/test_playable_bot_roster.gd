extends "res://tests/support/poker_gut_test.gd"


func test_curated_roster_resolves_every_model_profile_and_has_stable_unique_ids() -> void:
	var roster := PlayableBotRoster.new()

	assert_eq(roster.validate(), PackedStringArray())
	assert_eq(roster.get_roster_version(), &"curated_v1")
	var profile_ids := roster.get_profile_ids()
	assert_eq(profile_ids.size(), PlayableBotRoster.MAX_PLAYABLE_BOT_COUNT)
	var unique_ids: Dictionary[StringName, bool] = {}
	for profile_id: StringName in profile_ids:
		unique_ids[profile_id] = true
	assert_eq(unique_ids.size(), profile_ids.size())
	for legacy_id: StringName in PlayableBotRoster.REQUIRED_LEGACY_PROFILE_IDS:
		assert_true(legacy_id in unique_ids, "Curated roster must retain %s." % legacy_id)


func test_seeded_selection_is_deterministic_without_replacement_and_returns_snapshots() -> void:
	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 718
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 718
	var roster := PlayableBotRoster.new()

	var first := roster.select(5, first_rng)
	var second := roster.select(5, second_rng)

	assert_true(first.is_ok())
	assert_true(second.is_ok())
	var first_profiles := first.get_profiles()
	var second_profiles := second.get_profiles()
	assert_eq(_profile_ids(first_profiles), _profile_ids(second_profiles))
	var unique_ids: Dictionary[StringName, bool] = {}
	for profile: BotProfile in first_profiles:
		unique_ids[profile.profile_id] = true
	assert_eq(unique_ids.size(), first_profiles.size())
	first_profiles[0].profile_id = &"mutated"
	assert_ne(first.get_profiles()[0].profile_id, &"mutated")


func test_roster_rejects_invalid_profiles_and_selection_larger_than_catalog() -> void:
	var invalid := BotProfile.new()
	invalid.profile_id = &"duplicate"
	invalid.model_id = &"missing"
	invalid.parameters = DecisionModelParameters.new()
	var duplicate := invalid.duplicate(true) as BotProfile
	var roster := PlayableBotRoster.new([invalid, duplicate], null, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	assert_false(roster.validate().is_empty())
	var selection := roster.select(3, rng)
	assert_false(selection.is_ok())
	var has_size_error: bool = false
	for error: String in selection.errors:
		has_size_error = has_size_error or error.contains("requested")
	assert_true(has_size_error)


func _profile_ids(profiles: Array[BotProfile]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for profile: BotProfile in profiles:
		ids.append(profile.profile_id)
	return ids
