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


func test_catalog_profiles_cover_the_roster_and_are_deeply_isolated() -> void:
	var roster := PlayableBotRoster.new()
	var first_catalog: Array[BotProfile] = roster.get_catalog_profiles()
	var second_catalog: Array[BotProfile] = roster.get_catalog_profiles()
	var roster_ids := roster.get_profile_ids()

	assert_eq(_profile_ids(first_catalog), roster_ids)
	assert_eq(_profile_ids(second_catalog), roster_ids)
	assert_eq(first_catalog.size(), roster_ids.size())
	assert_eq(second_catalog.size(), roster_ids.size())
	for profile_index: int in range(roster_ids.size()):
		var first_profile: BotProfile = first_catalog[profile_index]
		var second_profile: BotProfile = second_catalog[profile_index]
		assert_ne(first_profile, second_profile)
		assert_eq(first_profile.profile_id, second_profile.profile_id)
		assert_eq(first_profile.model_id, second_profile.model_id)
		assert_eq(first_profile.display_name, second_profile.display_name)
		assert_ne(first_profile.parameters, second_profile.parameters)

		# Mutating every returned profile must not change the other snapshot or roster.
		first_profile.profile_id = StringName("mutated_catalog_profile_%d" % profile_index)
		first_profile.display_name = "Mutated Catalog Profile %d" % profile_index
	assert_eq(_profile_ids(second_catalog), roster_ids)
	var first_parameters := first_catalog[0].parameters as RandomDecisionModelParameters
	first_parameters.fold_weight = 99

	var fresh_catalog: Array[BotProfile] = roster.get_catalog_profiles()
	var fresh_parameters := fresh_catalog[0].parameters as RandomDecisionModelParameters
	assert_eq(fresh_catalog[0].profile_id, &"random_default")
	assert_eq(fresh_catalog[0].display_name, "Random")
	assert_eq(fresh_parameters.fold_weight, 1)


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


func test_roster_accepts_twenty_five_strategic_profiles_regardless_of_legacy_profiles() -> void:
	var roster := _roster_with_strategic_profile_count(25)

	assert_eq(roster.validate(), PackedStringArray())
	for bot_count: int in range(1, PlayableBotRoster.MAX_PLAYABLE_BOT_COUNT + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + bot_count
		assert_true(roster.select(bot_count, rng).is_ok())


func test_roster_rejects_more_than_twenty_five_strategic_profiles() -> void:
	var roster := _roster_with_strategic_profile_count(26)

	assert_has(
		roster.validate(), "The playable bot roster cannot contain more than 25 strategic profiles."
	)


func _roster_with_strategic_profile_count(strategic_count: int) -> PlayableBotRoster:
	var profiles: Array[BotProfile] = []
	for profile: BotProfile in PlayableBotRoster.new().get_catalog_profiles():
		if profile.model_id != &"strategy_parameterized":
			profiles.append(profile)
	for index: int in range(strategic_count):
		var profile := BotProfile.new()
		profile.profile_id = StringName("strategic_capacity_%d" % index)
		profile.model_id = &"strategy_parameterized"
		profile.parameters = StrategyDecisionModelParameters.new()
		profiles.append(profile)
	return PlayableBotRoster.new(profiles, null, false)


func _profile_ids(profiles: Array[BotProfile]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for profile: BotProfile in profiles:
		ids.append(profile.profile_id)
	return ids
