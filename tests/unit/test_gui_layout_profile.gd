extends "res://tests/support/poker_gut_test.gd"

const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const GuiViewportFixturesScript := preload("res://tests/support/gui_viewport_fixtures.gd")

const EXPECTED_PROFILE_KINDS: Dictionary = {
	GuiViewportFixturesScript.PROFILE_PHONE_PORTRAIT: GuiLayoutProfileScript.Kind.PHONE_PORTRAIT,
	GuiViewportFixturesScript.PROFILE_PHONE_LANDSCAPE: GuiLayoutProfileScript.Kind.PHONE_LANDSCAPE,
	GuiViewportFixturesScript.PROFILE_TABLET: GuiLayoutProfileScript.Kind.TABLET,
	GuiViewportFixturesScript.PROFILE_SMALL_DESKTOP: GuiLayoutProfileScript.Kind.SMALL_DESKTOP,
	GuiViewportFixturesScript.PROFILE_DESKTOP: GuiLayoutProfileScript.Kind.DESKTOP,
}


func test_classifies_every_canonical_usable_viewport() -> void:
	for fixture: Dictionary in GuiViewportFixturesScript.all():
		assert_eq(
			GuiLayoutProfileScript.classify(Vector2(fixture.size), fixture.profile_override),
			EXPECTED_PROFILE_KINDS[fixture.profile],
			str(fixture.key),
		)


func test_observed_ipad_requires_its_explicit_tablet_override() -> void:
	var observed_size := Vector2(2388, 1450)
	assert_eq(
		GuiLayoutProfileScript.classify(observed_size),
		GuiLayoutProfileScript.Kind.DESKTOP,
		"geometry shared with a desktop window must remain desktop",
	)
	assert_eq(
		GuiLayoutProfileScript.classify(observed_size, GuiLayoutProfileScript.Kind.TABLET),
		GuiLayoutProfileScript.Kind.TABLET,
	)


func test_invalid_override_does_not_replace_geometry_classification() -> void:
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2(390, 844), 99),
		GuiLayoutProfileScript.Kind.PHONE_PORTRAIT,
	)


func test_phone_rotation_and_browser_chrome_remain_phone_profiles() -> void:
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2(390, 744)),
		GuiLayoutProfileScript.Kind.PHONE_PORTRAIT,
	)
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2(744, 390)),
		GuiLayoutProfileScript.Kind.PHONE_LANDSCAPE,
	)
	assert_true(GuiLayoutProfileScript.is_phone(GuiLayoutProfileScript.classify(Vector2(844, 330))))


func test_aspect_and_long_edge_prevent_small_desktop_from_becoming_phone() -> void:
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2(600, 600)),
		GuiLayoutProfileScript.Kind.SMALL_DESKTOP,
	)
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2(950, 532)),
		GuiLayoutProfileScript.Kind.SMALL_DESKTOP,
	)
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2(1280, 720)),
		GuiLayoutProfileScript.Kind.DESKTOP,
	)


func test_invalid_usable_size_falls_back_to_desktop_safely() -> void:
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2.ZERO),
		GuiLayoutProfileScript.Kind.DESKTOP,
	)
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2.ZERO, GuiLayoutProfileScript.Kind.PHONE_PORTRAIT),
		GuiLayoutProfileScript.Kind.DESKTOP,
		"an override must not turn invalid geometry into a usable layout",
	)
