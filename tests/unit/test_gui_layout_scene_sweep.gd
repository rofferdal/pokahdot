extends "res://tests/support/poker_gut_test.gd"

const Sweep := preload("res://tests/support/gui_layout_scene_sweep.gd")


func test_bounded_scene_definitions_cover_every_count_and_required_fit_probes() -> void:
	var selected: Array[Dictionary] = Sweep.definitions()
	assert_lt(selected.size(), 100, "Rendered characterization must remain bounded")
	var ids: Dictionary[String, bool] = {}
	for definition: Dictionary in selected:
		var key := (
			"%s/%d/%s/%s"
			% [definition.size, definition.player_count, definition.state, definition.variant]
		)
		assert_false(ids.has(key), "Scene definitions must be unique: %s" % key)
		ids[key] = true
	for count: int in range(2, 10):
		for size: Vector2i in [Vector2i(650, 900), Vector2i(1250, 700)]:
			for state: StringName in [&"human-turn-preflop", &"showdown-long"]:
				assert_true(ids.has("%s/%d/%s/ordinary" % [size, count, state]))


func test_numeric_geometry_is_normalized_without_losing_semantic_roles() -> void:
	assert_eq(
		Sweep.normalize_failure("text-clipping: seat/3/name needs 103.0 px but has 99.0 px"),
		"text-clipping: seat/3/name"
	)
	assert_eq(
		Sweep.normalize_failure("touch-target: action/fold has size (47.0, 48.0)"),
		"touch-target: action/fold"
	)
	assert_eq(
		Sweep.normalize_failure(
			"containment: seat/8 [P: (-10, 20), S: (100, 100)] is outside [P: (0, 0), S: (90, 90)]"
		),
		"containment: seat/8"
	)
	assert_ne(
		Sweep.normalize_failure("text-clipping: seat/3/name needs 103 px but has 99 px"),
		Sweep.normalize_failure("text-clipping: seat/8/name needs 103 px but has 99 px")
	)


func test_scene_probe_renders_counts_three_five_and_eight_with_public_snapshots() -> void:
	for count: int in [3, 5, 8]:
		var record: Dictionary = await (
			Sweep
			. run_case(
				self,
				{
					"size": Vector2i(1920, 1080),
					"player_count": count,
					"state": &"human-turn-preflop",
					"variant": &"ordinary",
				}
			)
		)
		assert_eq(record.probe, "scene")
		assert_eq(record.scope, "candidate_wide")
		assert_eq(record.input.player_count, count)
		assert_false("seat-identity:" in "\n".join(record.failures))
		assert_false("view-mutation:" in "\n".join(record.failures))
		assert_false("privacy:" in "\n".join(record.failures))
		assert_true(record.details.has("root_minimum"))


func test_large_phone_fixture_geometry_uses_explicit_live_and_completed_row_contracts() -> void:
	for state: StringName in [&"human-turn-preflop", &"showdown-long"]:
		var record: Dictionary = await (
			Sweep
			. run_case(
				self,
				{
					"size": Vector2i(390, 844),
					"player_count": 7,
					"state": state,
					"variant": &"large",
				}
			)
		)
		assert_eq(record.failures, PackedStringArray(), String(state))
