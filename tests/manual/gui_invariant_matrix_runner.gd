extends "res://tests/support/poker_gut_test.gd"

## Strict, explicitly invoked diagnostic for the complete Milestone 3 GUI matrix.
## This intentionally remains outside GUT's auto-discovered unit/integration dirs
## until production geometry satisfies every invariant.

const GuiInvariantAssertionsScript := preload("res://tests/support/gui_invariant_assertions.gd")
const GuiSceneHarnessScript := preload("res://tests/support/gui_scene_harness.gd")
const GuiViewportFixturesScript := preload("res://tests/support/gui_viewport_fixtures.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")

const MILESTONE_3_VIEWPORT_IDS: Array[StringName] = [
	&"ipad_portrait_768x1024",
	&"ipad_landscape_1024x768",
	&"ipad_landscape_2388x1450_observed",
	&"small_desktop_950x532",
	&"desktop_1280x720",
	&"desktop_1920x1080",
]
const MILESTONE_3_PLAYER_COUNTS: Array[int] = [2, 4, 6, 9]


func test_milestone_three_visual_matrix_satisfies_gui_invariants() -> void:
	var failures := PackedStringArray()
	for viewport_fixture: Dictionary in GuiViewportFixturesScript.all():
		if viewport_fixture.key not in MILESTONE_3_VIEWPORT_IDS:
			continue
		for player_count: int in MILESTONE_3_PLAYER_COUNTS:
			for descriptor: Dictionary in GuiVisualStateFixturesScript.all(player_count):
				if descriptor.id in GuiVisualStateFixturesScript.PHONE_ONLY_STATE_IDS:
					continue
				if descriptor.player_count == 0 and player_count != 2:
					continue
				var harness: Node = GuiSceneHarnessScript.new()
				add_child(harness)
				var rendered: Dictionary = harness.render(
					descriptor, viewport_fixture.size, viewport_fixture.profile_override
				)
				var settled: bool = await harness.settle_layout()
				var context := (
					"%s / p%d / %s" % [viewport_fixture.key, descriptor.player_count, descriptor.id]
				)
				if not settled:
					failures.append("%s: layout did not settle" % context)
				for failure: String in GuiInvariantAssertionsScript.validate(rendered):
					failures.append("%s: %s" % [context, failure])
				harness.free()
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))
