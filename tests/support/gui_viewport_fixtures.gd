class_name GuiViewportFixtures
extends RefCounted

## Canonical logical viewport inputs shared by GUI matrix and visual tests.
##
## Sizes describe the usable Godot canvas rather than physical device pixels.
## The observed iPad landscape case is retained as a regression surface in
## addition to the canonical logical iPad orientations.

const PROFILE_PHONE_PORTRAIT: StringName = &"phone_portrait"
const PROFILE_PHONE_LANDSCAPE: StringName = &"phone_landscape"
const PROFILE_TABLET: StringName = &"tablet"
const PROFILE_SMALL_DESKTOP: StringName = &"small_desktop"
const PROFILE_DESKTOP: StringName = &"desktop"

const ORIENTATION_PORTRAIT: StringName = &"portrait"
const ORIENTATION_LANDSCAPE: StringName = &"landscape"

const PLAYER_COUNTS: Array[int] = [2, 4, 6, 9]


static func all() -> Array[Dictionary]:
	return [
		_fixture(&"phone_portrait_360x640", Vector2i(360, 640), PROFILE_PHONE_PORTRAIT),
		_fixture(&"phone_portrait_390x844", Vector2i(390, 844), PROFILE_PHONE_PORTRAIT),
		_fixture(&"phone_portrait_412x915", Vector2i(412, 915), PROFILE_PHONE_PORTRAIT),
		_fixture(
			&"phone_portrait_390x744_chrome",
			Vector2i(390, 744),
			PROFILE_PHONE_PORTRAIT,
			true,
		),
		_fixture(&"phone_landscape_640x360", Vector2i(640, 360), PROFILE_PHONE_LANDSCAPE),
		_fixture(&"phone_landscape_844x390", Vector2i(844, 390), PROFILE_PHONE_LANDSCAPE),
		_fixture(
			&"phone_landscape_844x330_chrome",
			Vector2i(844, 330),
			PROFILE_PHONE_LANDSCAPE,
			true,
		),
		_fixture(&"ipad_portrait_768x1024", Vector2i(768, 1024), PROFILE_TABLET),
		_fixture(&"ipad_landscape_1024x768", Vector2i(1024, 768), PROFILE_TABLET),
		_fixture(
			&"ipad_landscape_2388x1450_observed",
			Vector2i(2388, 1450),
			PROFILE_TABLET,
			false,
			true,
		),
		_fixture(&"small_desktop_950x532", Vector2i(950, 532), PROFILE_SMALL_DESKTOP),
		_fixture(&"desktop_1280x720", Vector2i(1280, 720), PROFILE_DESKTOP),
		_fixture(&"desktop_1920x1080", Vector2i(1920, 1080), PROFILE_DESKTOP),
	]


static func table_cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	for viewport: Dictionary in all():
		for player_count: int in PLAYER_COUNTS:
			(
				cases
				. append(
					{
						"key": "%s_%d_players" % [viewport.key, player_count],
						"viewport": viewport,
						"player_count": player_count,
					}
				)
			)
	return cases


static func _fixture(
	key: StringName,
	size: Vector2i,
	profile: StringName,
	reduced_height: bool = false,
	observed_regression: bool = false,
) -> Dictionary:
	return {
		"key": key,
		"size": size,
		"profile": profile,
		"orientation": ORIENTATION_PORTRAIT if size.y > size.x else ORIENTATION_LANDSCAPE,
		"reduced_height": reduced_height,
		"observed_regression": observed_regression,
	}
