extends "res://tests/support/poker_gut_test.gd"

const Sweep := preload("res://tests/support/gui_layout_sweep.gd")
const Geometry := preload("res://tests/support/gui_layout_sweep_geometry.gd")
const Profiles := preload("res://scripts/gui/gui_layout_profile.gd")


func test_sampling_includes_grid_endpoints_boundaries_and_named_intermediate_sizes() -> void:
	var sizes: Array[Vector2i] = Sweep.sample_sizes(80)
	var included: Dictionary[Vector2i, bool] = {}
	var unique: bool = true
	for size: Vector2i in sizes:
		unique = unique and not included.has(size)
		included[size] = true
	var complete: bool = true
	for width: int in range(320, 2561, 80):
		for height: int in range(320, 1601, 80):
			complete = complete and included.has(Vector2i(width, height))
	assert_true(complete, "Every inclusive coarse grid pair must be sampled")
	assert_true(unique)
	assert_eq(sizes[0], Vector2i(320, 320))
	assert_eq(sizes[-1], Vector2i(2560, 1600))
	for size: Vector2i in [
		Vector2i(650, 900),
		Vector2i(1250, 700),
		Vector2i(599, 900),
		Vector2i(600, 900),
		Vector2i(601, 900),
		Vector2i(900, 759),
		Vector2i(900, 760),
		Vector2i(900, 761),
		Vector2i(600, 809),
		Vector2i(600, 810),
		Vector2i(600, 811),
		Vector2i(680, 679),
		Vector2i(680, 680),
		Vector2i(680, 681),
	]:
		assert_true(included.has(size), "Boundary %s must be included" % size)
	assert_eq(Sweep.sample_sizes(0), [])
	assert_true(Sweep.run(0).has("error"))


func test_run_has_unique_deterministic_ids_all_counts_and_detached_policy_observations() -> void:
	var result: Dictionary = Sweep.run(80)
	var ids: Dictionary[String, bool] = {}
	var grid_counts: Dictionary[Vector2i, Dictionary] = {}
	var valid: bool = true
	for case: Dictionary in result.cases:
		valid = valid and not ids.has(case.id) and case.probe == "pure"
		ids[case.id] = true
		var input: Dictionary = case.input
		var size := Vector2i(input.width, input.height)
		if input.variant == "ordinary":
			if not grid_counts.has(size):
				grid_counts[size] = {}
			grid_counts[size][input.player_count] = true
		valid = (
			valid
			and case.observations.has("profile")
			and case.observations.has("seat_visual_scale")
		)
	var complete: bool = true
	for size: Vector2i in Sweep.sample_sizes(80):
		complete = complete and grid_counts.get(size, {}).size() == 8
	assert_true(valid, "Case IDs and policy observations must be complete and unique")
	assert_true(complete, "Every sampled size needs actual geometry probes for all counts 2–9")
	assert_gte(result.elapsed_ms, 0)
	assert_eq(result.step, 80)
	var first: Dictionary = Sweep.probe(Vector2i(650, 900), 6, false)
	var second: Dictionary = Sweep.probe(Vector2i(650, 900), 6, false)
	assert_eq(first, second)
	assert_eq(first.id, "pure/650x900/p6/ordinary/override-1")
	print("Pure layout sweep: %d cases in %d ms" % [result.cases.size(), result.elapsed_ms])


func test_policy_boundaries_have_explicit_current_classification_expectations() -> void:
	var cases: Array[Array] = [
		[Vector2i(599, 900), Profiles.Kind.PHONE_PORTRAIT],
		[Vector2i(600, 900), Profiles.Kind.PHONE_PORTRAIT],
		[Vector2i(601, 900), Profiles.Kind.DESKTOP],
		[Vector2i(600, 809), Profiles.Kind.DESKTOP],
		[Vector2i(600, 810), Profiles.Kind.PHONE_PORTRAIT],
		[Vector2i(600, 811), Profiles.Kind.PHONE_PORTRAIT],
		[Vector2i(900, 599), Profiles.Kind.PHONE_LANDSCAPE],
		[Vector2i(900, 600), Profiles.Kind.PHONE_LANDSCAPE],
		[Vector2i(900, 601), Profiles.Kind.SMALL_DESKTOP],
		[Vector2i(679, 900), Profiles.Kind.DESKTOP],
		[Vector2i(680, 900), Profiles.Kind.TABLET],
		[Vector2i(681, 900), Profiles.Kind.TABLET],
		[Vector2i(600, 919), Profiles.Kind.PHONE_PORTRAIT],
		[Vector2i(600, 920), Profiles.Kind.PHONE_PORTRAIT],
		[Vector2i(600, 921), Profiles.Kind.DESKTOP],
		[Vector2i(899, 1200), Profiles.Kind.TABLET],
		[Vector2i(900, 1200), Profiles.Kind.TABLET],
		[Vector2i(901, 1200), Profiles.Kind.DESKTOP],
		[Vector2i(680, 1223), Profiles.Kind.TABLET],
		[Vector2i(680, 1224), Profiles.Kind.DESKTOP],
		[Vector2i(680, 1225), Profiles.Kind.DESKTOP],
		[Vector2i(1099, 320), Profiles.Kind.SMALL_DESKTOP],
		[Vector2i(1100, 320), Profiles.Kind.DESKTOP],
		[Vector2i(1101, 320), Profiles.Kind.DESKTOP],
		[Vector2i(1100, 759), Profiles.Kind.TABLET],
		[Vector2i(1201, 759), Profiles.Kind.DESKTOP],
		[Vector2i(650, 900), Profiles.Kind.DESKTOP],
		[Vector2i(1250, 700), Profiles.Kind.DESKTOP],
	]
	for case: Array in cases:
		assert_eq(Sweep.probe(case[0], 6, false).observations.profile, case[1], str(case[0]))
	for delta: int in [-1, 0, 1]:
		assert_eq(
			Sweep.probe(Vector2i(1250, 760 + delta), 5, false).observations.small_desktop,
			delta < 0,
			"The internal height breakpoint is independent of the global profile"
		)
		assert_eq(
			Sweep.probe(Vector2i(1300 + delta, 700), 5, false).observations.small_desktop,
			delta < 0,
			"The internal width breakpoint differs from the global small-desktop threshold"
		)
		assert_eq(
			Sweep.probe(Vector2i(900, 1080 + delta), 5, false).observations.mobile_portrait,
			delta >= 0,
			"The internal portrait ratio differs from the phone classifier"
		)
	assert_eq(Sweep.probe(Vector2i(390, 844), 7, false).scope, "candidate_phone_portrait")
	assert_eq(Sweep.probe(Vector2i(390, 844), 8, false).scope, "unsupported_phone_count")
	assert_eq(Sweep.probe(Vector2i(844, 390), 6, false).scope, "deferred_phone_landscape")


func test_geometry_assertions_reject_overlap_escape_and_invalid_allocations() -> void:
	var bounds := Rect2(0, 0, 100, 100)
	var regions: Dictionary[StringName, Rect2] = {
		&"seat/1": Rect2(0, 0, 40, 40),
		&"seat/2": Rect2(60, 60, 40, 40),
	}
	assert_eq(Geometry.rectangles(bounds, regions), PackedStringArray())
	regions[&"seat/2"] = Rect2(20, 20, 40, 40)
	assert_eq(
		Geometry.rectangles(bounds, regions), PackedStringArray(["intersection:seat/1:seat/2"])
	)
	regions[&"seat/2"] = Rect2(90, 90, 40, 40)
	assert_eq(Geometry.rectangles(bounds, regions), PackedStringArray(["containment:seat/2"]))
	regions[&"seat/2"] = Rect2(60, 60, 0, 40)
	assert_eq(Geometry.rectangles(bounds, regions), PackedStringArray(["nonpositive:seat/2"]))
	regions[&"seat/2"] = Rect2(Vector2(INF, 60), Vector2(40, 40))
	assert_has(Geometry.rectangles(bounds, regions), "nonfinite:seat/2")


func test_real_phone_and_wide_primitive_failures_preserve_exact_semantic_roles() -> void:
	var supported: Dictionary = Sweep.probe(Vector2i(390, 844), 6, false)
	assert_eq(supported.failures, PackedStringArray())
	var insufficient: Dictionary = Sweep.probe(Vector2i(320, 480), 7, true)
	assert_has(insufficient.failures, "intersection:phone/center:phone/seat/1")
	var ordinary: Dictionary = Sweep.probe(Vector2i(1250, 700), 6, false)
	assert_eq(ordinary.scope, "candidate_wide")
	assert_true(ordinary.observations.compact_desktop)
	assert_false(ordinary.observations.small_desktop)
	assert_false(ordinary.input.geometry_space.is_empty())
