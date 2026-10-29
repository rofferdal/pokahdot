extends "res://tests/support/poker_gut_test.gd"

const Geometry := preload("res://scripts/gui/platform/gui_viewport_geometry.gd")


func test_web_geometry_uses_actual_canvas_css_extent_at_every_dpr() -> void:
	for case: Dictionary in [
		{"backing": Vector2i(390, 844), "dpr": 1.0, "css": Vector2(390, 844)},
		{"backing": Vector2i(780, 1688), "dpr": 2.0, "css": Vector2(390, 844)},
		{"backing": Vector2i(1023, 2215), "dpr": 2.625, "css": Vector2(389, 843)},
		{"backing": Vector2i(1170, 2532), "dpr": 3.0, "css": Vector2(390, 844)},
	]:
		var css := Rect2(Vector2.ZERO, case.css)
		var geometry: Geometry = Geometry.from_web(
			case.backing, css, css, css, Vector4.ZERO, case.dpr
		)
		assert_true(geometry.valid)
		assert_eq(geometry.logical_size, Vector2i(case.css))
		assert_eq(geometry.full_rect, css)
		assert_eq(geometry.usable_rect, css)
		assert_eq(geometry.backing_size, case.backing)


func test_fractional_css_and_native_extents_round_down_to_preserve_output_floors() -> void:
	var css := Rect2(0, 0, 389.875, 843.5)
	var web: Geometry = Geometry.from_web(Vector2i(1023, 2215), css, css, css, Vector4.ZERO, 2.625)
	assert_eq(web.logical_size, Vector2i(389, 843))
	var native: Geometry = Geometry.from_native(Vector2i(1279, 719), 2.0)
	assert_eq(native.logical_size, Vector2i(639, 359))


func test_safe_area_and_visual_viewport_intersect_once() -> void:
	var canvas := Rect2(0, 0, 390, 844)
	var geometry: Geometry = Geometry.from_web(
		Vector2i(780, 1688), canvas, canvas, Rect2(0, 0, 390, 700), Vector4(0, 24, 0, 34), 2.0
	)
	assert_eq(geometry.usable_rect, Rect2(0, 24, 390, 676))
	assert_eq(geometry.full_rect, canvas)
	assert_eq(geometry.logical_size, Vector2i(390, 844))


func test_web_nonzero_canvas_origin_and_asymmetric_constraints_remain_local() -> void:
	var geometry: Geometry = Geometry.from_web(
		Vector2i(780, 1688),
		Rect2(20, 30, 390, 844),
		Rect2(0, 0, 430, 904),
		Rect2(0, 70, 430, 700),
		Vector4(33, 55, 27, 49),
		2.0
	)
	assert_true(geometry.valid)
	assert_eq(geometry.usable_rect, Rect2(13, 40, 370, 700))
	assert_eq(geometry.full_rect.position, Vector2.ZERO)


func test_native_global_safe_area_maps_through_client_origin_then_ui_scale() -> void:
	var geometry: Geometry = Geometry.from_native(
		Vector2i(1280, 720), 2.0, Vector2i(100, 200), Rect2i(140, 220, 1200, 660), true
	)
	assert_eq(geometry.logical_size, Vector2i(640, 360))
	assert_eq(geometry.usable_rect, Rect2(20, 10, 600, 330))
	var negative_monitor: Geometry = Geometry.from_native(
		Vector2i(1280, 720), 2.0, Vector2i(-1280, 0), Rect2i(-1260, 30, 1240, 680), true
	)
	assert_eq(negative_monitor.usable_rect, Rect2(10, 15, 620, 340))
	var desktop: Geometry = Geometry.from_native(
		Vector2i(1280, 720), 2.0, Vector2i(100, 200), Rect2i(140, 220, 1200, 660), false
	)
	assert_eq(desktop.usable_rect, desktop.full_rect)


func test_invalid_and_nonfinite_geometry_returns_explicit_nonready_values() -> void:
	for size: Vector2 in [
		Vector2.ZERO, Vector2(-1, 800), Vector2(390, 0), Vector2(NAN, 844), Vector2(INF, 844)
	]:
		var geometry: Geometry = Geometry.injected(size)
		assert_false(geometry.valid)
		assert_eq(geometry.logical_size, Vector2i.ZERO)
		assert_eq(geometry.usable_rect, Rect2())
	var canvas := Rect2(0, 0, 390, 844)
	assert_false(Geometry.from_web(Vector2i.ZERO, canvas, canvas, canvas, Vector4.ZERO).valid)
	assert_false(Geometry.from_native(Vector2i.ZERO, 2.0).valid)


func test_invalid_platform_ui_scale_falls_back_without_fabricating_geometry() -> void:
	for scale: float in [0.0, -2.0, NAN, INF]:
		var geometry: Geometry = Geometry.from_native(Vector2i(640, 360), scale)
		assert_true(geometry.valid)
		assert_eq(geometry.ui_scale, 1.0)
		assert_eq(geometry.logical_size, Vector2i(640, 360))
		assert_false(String(geometry.source).is_empty())


func test_injected_geometry_retains_usable_origin_and_detaches_returned_data() -> void:
	var geometry: Geometry = Geometry.injected(Vector2(390, 844), Rect2(11, 23, 362, 792))
	var data: Dictionary = geometry.get_data()
	assert_gt(data.size(), 0)
	data.clear()
	assert_gt(geometry.get_data().size(), 0)
	assert_eq(geometry.usable_rect, Rect2(11, 23, 362, 792))
	assert_eq(geometry.full_rect, Rect2(0, 0, 390, 844))
	assert_true(geometry.valid)


func test_subunit_extents_do_not_invent_a_larger_virtual_base() -> void:
	var css := Rect2(0, 0, 0.5, 844)
	var web: Geometry = Geometry.from_web(Vector2i(1, 1688), css, css, css, Vector4.ZERO, 2.0)
	assert_false(web.valid)
	assert_false(Geometry.from_native(Vector2i.ONE, 2.0).valid)
	assert_false(Geometry.injected(Vector2(0.5, 844)).valid)


func test_fractional_native_safe_edges_round_trip_through_actual_quantized_stretch() -> void:
	var backing := Vector2i(1023, 2215)
	var geometry: Geometry = Geometry.from_native(
		backing, 2.625, Vector2i(100, 200), Rect2i(123, 237, 977, 2140), true
	)
	assert_eq(geometry.logical_size, Vector2i(389, 843))
	var to_backing: Vector2 = Vector2(backing) / Vector2(geometry.logical_size)
	var actual := Rect2(
		geometry.usable_rect.position * to_backing, geometry.usable_rect.size * to_backing
	)
	var expected := Rect2(23, 37, 977, 2140)
	assert_almost_eq(actual.position.x, expected.position.x, 0.001)
	assert_almost_eq(actual.position.y, expected.position.y, 0.001)
	assert_almost_eq(actual.end.x, expected.end.x, 0.001)
	assert_almost_eq(actual.end.y, expected.end.y, 0.001)


func test_fractional_css_safe_edges_round_trip_after_conservative_base_quantization() -> void:
	var canvas := Rect2(0, 0, 389.875, 843.5)
	var geometry: Geometry = Geometry.from_web(
		Vector2i(1023, 2215),
		canvas,
		canvas,
		Rect2(0, 0, 389.875, 700.375),
		Vector4(11.25, 23.5, 17.5, 29.25),
		2.625
	)
	var to_css: Vector2 = canvas.size / Vector2(geometry.logical_size)
	var actual := Rect2(geometry.usable_rect.position * to_css, geometry.usable_rect.size * to_css)
	var expected := Rect2(11.25, 23.5, 361.125, 676.875)
	assert_almost_eq(actual.position.x, expected.position.x, 0.001)
	assert_almost_eq(actual.position.y, expected.position.y, 0.001)
	assert_almost_eq(actual.end.x, expected.end.x, 0.001)
	assert_almost_eq(actual.end.y, expected.end.y, 0.001)


func test_invalid_nominal_dpr_does_not_override_measured_web_css_geometry() -> void:
	var canvas := Rect2(0, 0, 389, 843)
	for dpr: float in [0.0, -1.0, NAN, INF]:
		var geometry: Geometry = Geometry.from_web(
			Vector2i(1023, 2215), canvas, canvas, canvas, Vector4.ZERO, dpr
		)
		assert_true(geometry.valid)
		assert_eq(geometry.logical_size, Vector2i(389, 843))
		assert_eq(geometry.usable_rect, canvas)
