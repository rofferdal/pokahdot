extends "res://tests/support/poker_gut_test.gd"

const GuiViewportFixturesScript := preload("res://tests/support/gui_viewport_fixtures.gd")

const EXPECTED_VIEWPORTS: Dictionary = {
	&"phone_portrait_360x640": Vector2i(360, 640),
	&"phone_portrait_390x844": Vector2i(390, 844),
	&"phone_portrait_412x915": Vector2i(412, 915),
	&"phone_portrait_390x744_chrome": Vector2i(390, 744),
	&"phone_landscape_640x360": Vector2i(640, 360),
	&"phone_landscape_844x390": Vector2i(844, 390),
	&"phone_landscape_844x330_chrome": Vector2i(844, 330),
	&"ipad_portrait_768x1024": Vector2i(768, 1024),
	&"ipad_landscape_1024x768": Vector2i(1024, 768),
	&"ipad_landscape_2388x1450_observed": Vector2i(2388, 1450),
	&"small_desktop_950x532": Vector2i(950, 532),
	&"desktop_1280x720": Vector2i(1280, 720),
	&"desktop_1920x1080": Vector2i(1920, 1080),
}
const EXPECTED_PROFILES: Dictionary = {
	&"phone_portrait_360x640": &"phone_portrait",
	&"phone_portrait_390x844": &"phone_portrait",
	&"phone_portrait_412x915": &"phone_portrait",
	&"phone_portrait_390x744_chrome": &"phone_portrait",
	&"phone_landscape_640x360": &"phone_landscape",
	&"phone_landscape_844x390": &"phone_landscape",
	&"phone_landscape_844x330_chrome": &"phone_landscape",
	&"ipad_portrait_768x1024": &"tablet",
	&"ipad_landscape_1024x768": &"tablet",
	&"ipad_landscape_2388x1450_observed": &"tablet",
	&"small_desktop_950x532": &"small_desktop",
	&"desktop_1280x720": &"desktop",
	&"desktop_1920x1080": &"desktop",
}


func test_canonical_registry_has_unique_names_and_the_required_dimensions() -> void:
	var fixtures: Array[Dictionary] = GuiViewportFixturesScript.all()
	var fixtures_by_key: Dictionary = {}
	for fixture: Dictionary in fixtures:
		assert_false(fixtures_by_key.has(fixture.key), "duplicate fixture key: %s" % fixture.key)
		fixtures_by_key[fixture.key] = fixture

	assert_eq(fixtures_by_key.size(), EXPECTED_VIEWPORTS.size())
	for key: StringName in EXPECTED_VIEWPORTS:
		assert_true(fixtures_by_key.has(key), "missing fixture: %s" % key)
		assert_eq(fixtures_by_key[key].size, EXPECTED_VIEWPORTS[key], str(key))


func test_each_viewport_has_a_consistent_profile_and_orientation() -> void:
	var valid_profiles: Array[StringName] = [
		GuiViewportFixturesScript.PROFILE_PHONE_PORTRAIT,
		GuiViewportFixturesScript.PROFILE_PHONE_LANDSCAPE,
		GuiViewportFixturesScript.PROFILE_TABLET,
		GuiViewportFixturesScript.PROFILE_SMALL_DESKTOP,
		GuiViewportFixturesScript.PROFILE_DESKTOP,
	]
	for fixture: Dictionary in GuiViewportFixturesScript.all():
		var size: Vector2i = fixture.size
		var context: String = str(fixture.key)
		assert_gt(size.x, 0, context)
		assert_gt(size.y, 0, context)
		assert_true(fixture.profile in valid_profiles, context)
		assert_eq(fixture.profile, EXPECTED_PROFILES[fixture.key], context)
		if fixture.orientation == GuiViewportFixturesScript.ORIENTATION_PORTRAIT:
			assert_gt(size.y, size.x, context)
		else:
			assert_eq(fixture.orientation, GuiViewportFixturesScript.ORIENTATION_LANDSCAPE, context)
			assert_gt(size.x, size.y, context)
		if fixture.profile == GuiViewportFixturesScript.PROFILE_PHONE_PORTRAIT:
			assert_eq(fixture.orientation, GuiViewportFixturesScript.ORIENTATION_PORTRAIT, context)
		if fixture.profile == GuiViewportFixturesScript.PROFILE_PHONE_LANDSCAPE:
			assert_eq(fixture.orientation, GuiViewportFixturesScript.ORIENTATION_LANDSCAPE, context)


func test_browser_chrome_and_observed_regression_metadata_is_explicit() -> void:
	var reduced_height_keys: Array[StringName] = []
	var observed_regression_keys: Array[StringName] = []
	for fixture: Dictionary in GuiViewportFixturesScript.all():
		if fixture.reduced_height:
			reduced_height_keys.append(fixture.key)
		if fixture.observed_regression:
			observed_regression_keys.append(fixture.key)

	assert_eq(
		reduced_height_keys,
		[&"phone_portrait_390x744_chrome", &"phone_landscape_844x330_chrome"],
	)
	assert_eq(observed_regression_keys, [&"ipad_landscape_2388x1450_observed"])


func test_table_cases_cover_every_required_viewport_and_player_count() -> void:
	var fixtures: Array[Dictionary] = GuiViewportFixturesScript.all()
	var cases: Array[Dictionary] = GuiViewportFixturesScript.table_cases()
	var seen_case_keys: Dictionary = {}
	var coverage_by_viewport: Dictionary = {}
	for test_case: Dictionary in cases:
		assert_false(seen_case_keys.has(test_case.key), "duplicate matrix case: %s" % test_case.key)
		seen_case_keys[test_case.key] = true
		var viewport_key: StringName = test_case.viewport.key
		if not coverage_by_viewport.has(viewport_key):
			coverage_by_viewport[viewport_key] = [] as Array[int]
		coverage_by_viewport[viewport_key].append(test_case.player_count)

	assert_eq(cases.size(), fixtures.size() * GuiViewportFixturesScript.PLAYER_COUNTS.size())
	for fixture: Dictionary in fixtures:
		assert_eq(
			coverage_by_viewport.get(fixture.key, []),
			GuiViewportFixturesScript.PLAYER_COUNTS,
			str(fixture.key),
		)
