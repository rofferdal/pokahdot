extends "res://tests/support/poker_gut_test.gd"

const EXPECTED_PROMOTED_PROFILE_IDS: Array[StringName] = [
	&"candidate_campaign_mut_0002_e71136bb11dc8118__20261101_r2",
	&"candidate_campaign_mut_0001_16a0d5cb77701d29__20261101_r2",
	&"candidate_campaign_mut_0008_dcb88cbf0bf7e5dc__20261101_r2",
	&"candidate_campaign_mut_0003_60068c2f18cd352f__20261101_r2",
	&"candidate_g1_mut_0002_e856eeb3b2a832ed__20261024_r3b0",
	&"candidate_g0_0003_8ff30e87c04596e9__20261101_r2",
	&"candidate_campaign_mut_0005_22f01c7c062f5b68__20261101_r2",
	&"candidate_g0_0004_3683f0bcf5541341__20261101_r2",
	&"candidate_g0_0006_d319bbb79e4935d8__20261101_r2",
	&"candidate_g0_0000_8c87829890bd1a11__20261101_r2",
	&"candidate_g0_0009_292e08a42fe29566__20261024_r3b0",
	&"candidate_campaign_mut_0009_1957546ecfb4a5cf__20261101_r2",
	&"candidate_g1_mut_0004_23c4aa0775d54bec__20261024_r3b0",
	&"candidate_campaign_mut_0004_7c710eccf0688d55__20261101_r2",
	&"candidate_g0_0008_28cda20c09a12235__20261024_r3b0",
	&"candidate_g0_0002_ca41c8c26ecf41cf__20261024_r3b0",
	&"candidate_g0_0005_13cce589f42b0696__20261101_r2",
	&"candidate_g1_mut_0003_a92c427e3ea36b4a__20261024_r3b0",
	&"candidate_campaign_mut_0000_2f02d51fac35ab34__20261101_r2",
	&"candidate_g0_0002_3dd6bffeba52fcc1__20261101_r2",
]


func test_curated_roster_resolves_every_model_profile_and_has_stable_unique_ids() -> void:
	var roster := PlayableBotRoster.new()

	assert_eq(roster.validate(), PackedStringArray())
	assert_eq(roster.get_roster_version(), &"curated_v3")
	var profile_ids := roster.get_profile_ids()
	assert_eq(profile_ids.size(), 28)
	var unique_ids: Dictionary[StringName, bool] = {}
	for profile_id: StringName in profile_ids:
		unique_ids[profile_id] = true
	assert_eq(unique_ids.size(), profile_ids.size())
	for promoted_id: StringName in EXPECTED_PROMOTED_PROFILE_IDS:
		assert_has(profile_ids, promoted_id)
	assert_eq(_family_count(roster, false), 3)
	assert_eq(_family_count(roster, true), 25)


func test_campaign_membership_keeps_approved_names_and_excludes_rejected_profiles() -> void:
	var roster := PlayableBotRoster.new()
	var expected_names: Dictionary[StringName, String] = {
		&"candidate_campaign_mut_0002_e71136bb11dc8118__20261101_r2": "Crimson Beacon",
		&"candidate_campaign_mut_0001_16a0d5cb77701d29__20261101_r2": "Phantom-Copper Ripple",
		&"candidate_campaign_mut_0008_dcb88cbf0bf7e5dc__20261101_r2": "Wild Crest",
		&"candidate_campaign_mut_0003_60068c2f18cd352f__20261101_r2": "Copper-Blaze Ember",
		&"candidate_g1_mut_0002_e856eeb3b2a832ed__20261024_r3b0": "Copper-Blaze Surge",
		&"candidate_g0_0003_8ff30e87c04596e9__20261101_r2": "Midnight Pulse",
		&"candidate_campaign_mut_0005_22f01c7c062f5b68__20261101_r2": "Scarlet Torrent",
		&"candidate_g0_0004_3683f0bcf5541341__20261101_r2": "Ivory Tempest",
		&"candidate_g0_0006_d319bbb79e4935d8__20261101_r2": "Indigo Spark",
		&"candidate_g0_0000_8c87829890bd1a11__20261101_r2": "Azure Current",
		&"candidate_g0_0009_292e08a42fe29566__20261024_r3b0": "Copper Counter",
		&"candidate_campaign_mut_0009_1957546ecfb4a5cf__20261101_r2": "River Reverie",
		&"candidate_g1_mut_0004_23c4aa0775d54bec__20261024_r3b0": "Phantom-Copper Inferno",
		&"candidate_campaign_mut_0004_7c710eccf0688d55__20261101_r2": "Copper Cadence",
		&"candidate_g0_0008_28cda20c09a12235__20261024_r3b0": "Wild Mirage",
		&"candidate_g0_0002_ca41c8c26ecf41cf__20261024_r3b0": "River Velvet",
		&"candidate_g0_0005_13cce589f42b0696__20261101_r2": "Jade Undertow",
		&"candidate_g1_mut_0003_a92c427e3ea36b4a__20261024_r3b0": "Copper-Blaze Counter",
		&"candidate_campaign_mut_0000_2f02d51fac35ab34__20261101_r2": "Phantom Orbit",
		&"candidate_g0_0002_3dd6bffeba52fcc1__20261101_r2": "Amber Horizon",
	}
	var names_seen: Dictionary[String, bool] = {}
	var catalog_ids := roster.get_profile_ids()
	for profile: BotProfile in roster.get_catalog_profiles():
		assert_false(names_seen.has(profile.display_name), profile.display_name)
		names_seen[profile.display_name] = true
		if expected_names.has(profile.profile_id):
			assert_eq(profile.display_name, expected_names[profile.profile_id])
		assert_ne(profile.display_name, "Copper-Blaze Venture")
		assert_ne(profile.display_name, "Crimson Surge")
		assert_ne(profile.display_name, "Golden Veil")
		assert_ne(profile.display_name, "Silver Compass")
		assert_ne(profile.display_name, "Saffron Echo")
		assert_ne(profile.display_name, "Phantom Blaze")
		assert_ne(profile.display_name, "Scarlet Charge")
		assert_ne(profile.display_name, "Copper-Blaze Drift")
		assert_ne(profile.display_name, "Copper-Blaze Glimmer")
		assert_ne(profile.display_name, "Obsidian Tide")
	for protected_id: StringName in [
		&"nit_caller", &"tight_aggressive", &"loose_passive", &"loose_aggressive", &"balanced"
	]:
		assert_has(catalog_ids, protected_id)
	assert_true(names_seen.has("Amber Horizon"))


func test_default_selection_is_strategic_deterministic_and_returns_snapshots() -> void:
	var roster := PlayableBotRoster.new()
	for bot_count: int in range(1, PlayableBotRoster.MAX_PLAYABLE_BOT_COUNT + 1):
		var first_rng := RandomNumberGenerator.new()
		first_rng.seed = 718 + bot_count
		var second_rng := RandomNumberGenerator.new()
		second_rng.seed = 718 + bot_count
		var first := roster.select(bot_count, first_rng)
		var second := roster.select(bot_count, second_rng)
		assert_true(first.is_ok())
		assert_eq(_profile_ids(first.get_profiles()), _profile_ids(second.get_profiles()))
		for profile: BotProfile in first.get_profiles():
			assert_true(roster.is_strategic_profile(profile))
		_assert_unique_until_exhausted(first.get_profiles(), roster, true)
	var snapshots := roster.select(1, _rng(91)).get_profiles()
	snapshots[0].profile_id = &"mutated"
	assert_ne(roster.select(1, _rng(91)).get_profiles()[0].profile_id, &"mutated")


func test_legacy_selection_uses_exact_family_counts_and_repeats_only_after_exhaustion() -> void:
	var roster := PlayableBotRoster.new()
	for bot_count: int in range(1, PlayableBotRoster.MAX_PLAYABLE_BOT_COUNT + 1):
		var selection := roster.select(bot_count, _rng(100 + bot_count), true)
		assert_true(selection.is_ok())
		var profiles := selection.get_profiles()
		var legacy_count := 0
		var strategic_count := 0
		for profile: BotProfile in profiles:
			if roster.is_strategic_profile(profile):
				strategic_count += 1
			else:
				legacy_count += 1
		assert_eq(legacy_count, (bot_count + 1) / 2)
		assert_eq(strategic_count, bot_count - legacy_count)
		_assert_unique_until_exhausted(profiles, roster, false)
		_assert_unique_until_exhausted(profiles, roster, true)


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
	var has_profile_error: bool = false
	for error: String in selection.errors:
		has_profile_error = has_profile_error or error.contains("profile")
	assert_true(has_profile_error)


func test_roster_requires_strategic_profiles_and_legacy_profiles_only_when_enabled() -> void:
	var legacy_only: Array[BotProfile] = []
	for profile: BotProfile in PlayableBotRoster.new().get_catalog_profiles():
		if profile.model_id != &"strategy_parameterized":
			legacy_only.append(profile)
	var roster := PlayableBotRoster.new(legacy_only, null, false)
	assert_has(
		roster.validate(), "The playable bot roster must contain at least one strategic profile."
	)

	var strategic_only: Array[BotProfile] = []
	for profile: BotProfile in PlayableBotRoster.new().get_catalog_profiles():
		if profile.model_id == &"strategy_parameterized":
			strategic_only.append(profile)
	var strategic_roster := PlayableBotRoster.new(strategic_only, null, false)
	assert_true(strategic_roster.select(1, _rng(12)).is_ok())
	assert_has(
		strategic_roster.select(1, _rng(12), true).errors,
		"Legacy models were enabled, but the playable bot roster has no legacy heuristic profiles."
	)


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


func _family_count(roster: PlayableBotRoster, strategic: bool) -> int:
	var count := 0
	for profile: BotProfile in roster.get_catalog_profiles():
		if roster.is_strategic_profile(profile) == strategic:
			count += 1
	return count


func _assert_unique_until_exhausted(
	profiles: Array[BotProfile], roster: PlayableBotRoster, strategic: bool
) -> void:
	var family_ids: Array[StringName] = []
	for profile: BotProfile in profiles:
		if roster.is_strategic_profile(profile) == strategic:
			family_ids.append(profile.profile_id)
	var unique_ids: Dictionary[StringName, bool] = {}
	var expected_unique_count := mini(family_ids.size(), _family_count(roster, strategic))
	for profile_id: StringName in family_ids:
		unique_ids[profile_id] = true
	assert_eq(unique_ids.size(), expected_unique_count)


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
