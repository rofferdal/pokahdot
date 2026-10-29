class_name GuiLayoutSweep
extends RefCounted

## Deterministic injected-surface characterization. Pure plans receive the
## stated size directly; no display APIs, fonts, Controls or GUI corrections run.
## Candidate scope labels are diagnostic groups, not final support envelopes.
const Profiles := preload("res://scripts/gui/gui_layout_profile.gd")
const Pass := preload("res://scripts/gui/gui_table_layout_pass.gd")
const Geometry := preload("res://tests/support/gui_layout_sweep_geometry.gd")
const MIN_WIDTH: int = 320
const MAX_WIDTH: int = 2560
const MIN_HEIGHT: int = 320
const MAX_HEIGHT: int = 1600
const DIMENSION_BOUNDARIES: Array[int] = [480, 600, 680, 700, 760, 900, 920, 1100, 1200, 1300, 1600]
const BOUNDARY_CROSS_SECTIONS: Array[int] = [320, 480, 700, 900, 1200, 1600]
const RATIO_CROSS_SECTIONS: Array[int] = [
	320, 480, 600, 680, 760, 900, 1100, 1200, 1600, 1920, 2560
]
const ASPECT_BOUNDARIES: Array[float] = [1.2, 1.35, 1.8]


static func run(step: int = 80) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var cases: Array[Dictionary] = []
	if step <= 0:
		return {"cases": cases, "elapsed_ms": 0, "step": step, "error": "Step must be positive."}
	for size: Vector2i in sample_sizes(step):
		var profile: int = Profiles.classify(Vector2(size))
		for count: int in range(2, 10):
			cases.append(probe(size, count, false))
			# Large values select a different phone token height or six-seat plan.
			# Other wide counts would repeat the exact same primitive inputs.
			if Profiles.is_phone(profile) or count == 6:
				cases.append(probe(size, count, true))
	return {"cases": cases, "elapsed_ms": Time.get_ticks_msec() - started, "step": step}


static func sample_sizes(step: int = 80) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if step <= 0:
		return result
	var unique: Dictionary[Vector2i, bool] = {}
	for width: int in _axis(MIN_WIDTH, MAX_WIDTH, step):
		for height: int in _axis(MIN_HEIGHT, MAX_HEIGHT, step):
			_add(unique, Vector2i(width, height))
	for boundary: int in DIMENSION_BOUNDARIES:
		for delta: int in [-1, 0, 1]:
			for cross_section: int in BOUNDARY_CROSS_SECTIONS:
				_add(unique, Vector2i(boundary + delta, cross_section))
				_add(unique, Vector2i(cross_section, boundary + delta))
	for cross_section: int in RATIO_CROSS_SECTIONS:
		for delta: int in [-1, 0, 1]:
			_add(unique, Vector2i(cross_section, cross_section + delta))
			for ratio: float in ASPECT_BOUNDARIES:
				var edge: int = ceili(cross_section * ratio)
				_add(unique, Vector2i(cross_section, edge + delta))
				_add(unique, Vector2i(edge + delta, cross_section))
	_add(unique, Vector2i(650, 900))
	_add(unique, Vector2i(1250, 700))
	for delta: int in [-1, 0, 1]:
		_add(unique, Vector2i(1250, 760 + delta))
	result.assign(unique.keys())
	result.sort_custom(
		func(first: Vector2i, second: Vector2i) -> bool:
			return first.x < second.x if first.x != second.x else first.y < second.y
	)
	return result


static func probe(size: Vector2i, count: int, large: bool, override: int = -1) -> Dictionary:
	var layout := Pass.new()
	layout.configure(Vector2(size), Vector2(size), override, count, large)
	var variant: String = "large" if large else "ordinary"
	var failures: PackedStringArray = (
		Geometry.phone(Vector2(size), count, large)
		if layout.phone_layout
		else Geometry.wide(layout, large)
	)
	var unique: Dictionary[String, bool] = {}
	for failure: String in failures:
		unique[failure] = true
	failures = PackedStringArray(unique.keys())
	failures.sort()
	return {
		"id": "pure/%dx%d/p%d/%s/override%d" % [size.x, size.y, count, variant, override],
		"probe": "pure",
		"scope": _scope(layout.layout_profile, count),
		"input":
		{
			"width": size.x,
			"height": size.y,
			"player_count": count,
			"variant": variant,
			"override": override,
			"geometry_space": "injected_plan_surface",
			"phone_action_minimum": [280, 128],
			"phone_menu_minimum": [280, 316],
			"phone_detail_minimum": [280, 188],
			"phone_token_height": 86 if large else 60,
			"wide_grid_center_size": [280, 184],
			"wide_grid_cell_height": 88,
		},
		"failures": failures,
		"observations":
		{
			"geometry_evidence": "phone_plan" if layout.phone_layout else "wide_primitives",
			"profile": layout.layout_profile,
			"density": GuiPhoneSeatLayout.density_for(count),
			"phone": layout.phone_layout,
			"compact_desktop": layout.compact_desktop,
			"tablet": layout.tablet_layout,
			"mobile_portrait": layout.mobile_portrait_layout,
			"compact_tablet": layout.compact_tablet_layout,
			"small_desktop": layout.small_desktop_layout,
			"short_desktop_center": layout.short_desktop_center_layout,
			"full_ring_desktop": layout.full_ring_desktop_layout,
			"content_scale": layout.mobile_content_scale,
			"seat_content_scale": layout.seat_content_scale,
			"seat_visual_scale": layout.seat_visual_scale,
		},
	}


static func _scope(profile: int, count: int) -> String:
	if Profiles.is_phone(profile):
		if count > GuiPhoneSeatLayout.MAX_SUPPORTED_PLAYER_COUNT:
			return "unsupported_phone_count"
		if profile == Profiles.Kind.PHONE_LANDSCAPE:
			return "deferred_phone_landscape"
		return "candidate_phone_portrait"
	return "candidate_wide"


static func _axis(first: int, last: int, step: int) -> Array[int]:
	var result: Array[int] = []
	result.assign(range(first, last + 1, step))
	if result[-1] != last:
		result.append(last)
	return result


static func _add(unique: Dictionary[Vector2i, bool], size: Vector2i) -> void:
	if (
		size.x >= MIN_WIDTH
		and size.x <= MAX_WIDTH
		and size.y >= MIN_HEIGHT
		and size.y <= MAX_HEIGHT
	):
		unique[size] = true
