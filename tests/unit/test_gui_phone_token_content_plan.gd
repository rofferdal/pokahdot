extends "res://tests/support/poker_gut_test.gd"

const ContentPlan := preload("res://scripts/gui/gui_phone_token_content_plan.gd")


func test_measured_active_and_revealed_fields_fit_without_intersections() -> void:
	for revealed: bool in [false, true]:
		var widths: Dictionary[String, float] = {
			"Name": 84.0,
			"Stack": 84.0,
			"HoleCards": 94.0 if revealed else 40.0,
			"Badge": 19.0,
			"BadgeRow2": 29.0,
			"BadgeRow3": 16.0,
		}
		if not revealed:
			widths["ActionBadge"] = 94.0
		var plan := ContentPlan.new()
		assert_true(plan.configure(136.0, widths, revealed))
		assert_eq(plan.rects.size(), widths.size(), "Every public field retains a cell")
		assert_eq(plan.rects["Name"].position.y, 0.0)
		assert_eq(plan.rects["Stack"].position.y, 28.0)
		if revealed:
			assert_eq(plan.rects["HoleCards"].position.y, 56.0)
		for field: String in plan.rects:
			var cell: Rect2 = plan.rects[field]
			assert_eq(cell.size.x, widths[field], "Measured field width is preserved")
			assert_true(Rect2(0, 0, 136, 86).encloses(cell))
			for other: String in plan.rects:
				if field != other:
					assert_false(cell.intersects(plan.rects[other]), field + " / " + other)
		var original: Dictionary[String, Rect2] = plan.rects.duplicate()
		assert_true(plan.configure(136.0, widths, revealed))
		assert_eq(plan.rects, original, "Repeated configuration has the same result")


func test_impossible_plan_rejects_without_publishing_partial_rectangles() -> void:
	var plan := ContentPlan.new()
	var widths: Dictionary[String, float] = {
		"Name": 84.0,
		"Stack": 84.0,
		"HoleCards": 94.0,
	}
	assert_true(plan.configure(136.0, widths, true))
	widths["Name"] = 200.0
	assert_false(plan.configure(136.0, widths, true))
	assert_true(plan.rects.is_empty(), "An impossible plan must not retain an old layout")
	widths["Name"] = 84.0
	widths["ActionBadge"] = 200.0
	assert_false(plan.configure(136.0, widths, false))
	assert_true(plan.rects.is_empty(), "Failed finite packing must not publish partial cells")
