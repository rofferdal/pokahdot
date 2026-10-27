class_name GuiInvariantMatrixSuites
extends RefCounted

## Declarative suite coverage shared by diagnostic gates and capture manifests.
## Case order, viewport IDs and fixture IDs preserve the established matrices.
enum Suite { MILESTONE_THREE, PHONE, IPAD, DESKTOP }

const Viewports := preload("res://tests/support/gui_viewport_fixtures.gd")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")

const MILESTONE_3_VIEWPORT_IDS: Array[StringName] = [
	&"ipad_portrait_768x1024",
	&"ipad_landscape_1024x768",
	&"ipad_landscape_2388x1450_observed",
	&"small_desktop_950x532",
	&"desktop_1280x720",
	&"desktop_1920x1080",
]
const PHONE_VIEWPORT_IDS: Array[StringName] = [
	&"phone_portrait_360x640",
	&"phone_portrait_390x844",
	&"phone_portrait_412x915",
	&"phone_portrait_390x744_chrome",
	&"phone_landscape_640x360",
	&"phone_landscape_844x390",
	&"phone_landscape_844x330_chrome",
]
const IPAD_VIEWPORT_IDS: Array[StringName] = [
	&"ipad_portrait_768x1024",
	&"ipad_landscape_1024x768",
	&"ipad_landscape_1194x696_chrome",
	&"ipad_landscape_2388x1450_observed",
]
const DESKTOP_VIEWPORT_IDS: Array[StringName] = [
	&"small_desktop_950x532",
	&"desktop_1280x720",
	&"desktop_1853x916_observed_raster",
	&"desktop_1920x1080",
]
const MILESTONE_3_PLAYER_COUNTS: Array[int] = [2, 4, 6, 9]
const PHONE_PLAYER_COUNTS: Array[int] = [2, 4, 6, 7]
const IPAD_PLAYER_COUNTS: Array[int] = [2, 4, 6, 7, 9]
const PHONE_EXCLUDED_STATE_IDS: Array[StringName] = [&"event-history-full"]


static func definition(suite: Suite) -> Definition:
	var value := Definition.new()
	value.player_counts.assign(MILESTONE_3_PLAYER_COUNTS)
	value.excluded_state_ids.assign(States.PHONE_ONLY_STATE_IDS)
	match suite:
		Suite.MILESTONE_THREE:
			value.viewport_ids.assign(MILESTONE_3_VIEWPORT_IDS)
		Suite.PHONE:
			value.viewport_ids.assign(PHONE_VIEWPORT_IDS)
			value.player_counts.assign(PHONE_PLAYER_COUNTS)
			value.excluded_state_ids.assign(PHONE_EXCLUDED_STATE_IDS)
			value.phone_contract = true
		Suite.IPAD:
			value.viewport_ids.assign(IPAD_VIEWPORT_IDS)
			value.player_counts.assign(IPAD_PLAYER_COUNTS)
		Suite.DESKTOP:
			value.viewport_ids.assign(DESKTOP_VIEWPORT_IDS)
	return value


static func cases(
	suite: Suite,
	viewport_id: StringName = &"",
	state_id: StringName = &"",
	player_count: int = -1,
	allow_explicit_viewport: bool = false,
) -> Array[Dictionary]:
	var selected := definition(suite)
	var result: Array[Dictionary] = []
	for viewport: Dictionary in Viewports.all():
		if (
			viewport.key not in selected.viewport_ids
			and not (allow_explicit_viewport and viewport.key == viewport_id)
		):
			continue
		if not viewport_id.is_empty() and viewport.key != viewport_id:
			continue
		for count: int in selected.player_counts:
			for descriptor: Dictionary in States.all(count):
				if descriptor.id in selected.excluded_state_ids:
					continue
				if descriptor.player_count == 0 and count != 2:
					continue
				if player_count >= 0 and descriptor.player_count != player_count:
					continue
				if not state_id.is_empty() and descriptor.id != state_id:
					continue
				result.append({"viewport": viewport, "descriptor": descriptor})
	return result


class Definition:
	extends RefCounted
	var viewport_ids: Array[StringName] = []
	var player_counts: Array[int] = []
	var excluded_state_ids: Array[StringName] = []
	var phone_contract: bool = false
