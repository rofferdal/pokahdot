class_name GuiReplacementCaptureCases
extends RefCounted

## Capture identities mirror the supported-layout, wide-state, and phone-state
## loops in the 99-case native replacement matrix.
const Fixtures := preload("res://tests/support/gui_visual_state_fixtures.gd")
const SizeClass := preload("res://scripts/gui/layout/gui_size_class.gd")

const WIDE_STATES: Array[StringName] = [
	&"human-turn-preflop",
	&"human-turn-river",
	&"bot-turn",
	&"status-blank",
	&"status-retained-fold",
	&"all-in-runout",
	&"showdown-long",
	&"elimination",
	&"tournament-winner",
	&"event-history-full",
]
const PHONE_STATES: Array[StringName] = [
	&"human-turn-preflop",
	&"human-turn-river",
	&"bot-turn",
	&"status-retained-fold",
	&"all-in-runout",
	&"showdown-long",
	&"elimination",
	&"tournament-winner",
]


static func all_cases() -> Array[Dictionary]:
	var result := supported_layout_cases()
	result.append_array(wide_state_cases())
	result.append_array(phone_state_cases())
	return result


static func supported_layout_cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	for item: Dictionary in [
		{"size": Vector2i(390, 844), "count": 2, "ready": true},
		{"size": Vector2i(390, 844), "count": 4, "ready": true},
		{"size": Vector2i(1200, 590), "count": 2, "ready": true},
		{"size": Vector2i(1600, 1200), "count": 2, "ready": true},
		{"size": Vector2i(1600, 1200), "count": 6, "ready": true},
		{"size": Vector2i(1920, 1300), "count": 9, "ready": true},
		{"size": Vector2i(390, 844), "count": 6, "ready": true},
		{"size": Vector2i(390, 844), "count": 9, "ready": false},
		{"size": Vector2i(640, 360), "count": 2, "ready": true},
	]:
		cases.append(_layout_case(item.size, item.count, item.ready, "initial"))
	for count: int in [2, 3]:
		cases.append(_layout_case(Vector2i(1200, 590), count, true, "compact-sweep"))
	for count: int in range(2, 10):
		cases.append(_layout_case(Vector2i(1920, 1300), count, true, "wide-sweep"))
	for count: int in range(2, 8):
		cases.append(_layout_case(Vector2i(480, 1200), count, true, "phone-sweep"))
	for count: int in [8, 9]:
		cases.append(_layout_case(Vector2i(480, 1200), count, false, "phone-guidance"))
	return cases


static func wide_state_cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	for count: int in [2, 4, 6, 9]:
		for state: StringName in WIDE_STATES:
			cases.append(_state_case("m3", Vector2i(1920, 1300), count, state))
	return cases


static func phone_state_cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	for count: int in [2, 4, 6, 7]:
		for state: StringName in PHONE_STATES:
			cases.append(_state_case("phone", Vector2i(390, 844), count, state))
	return cases


static func cases_for_category(category: StringName) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	match category:
		&"m3":
			cases = all_cases()
		&"phone":
			for item: Dictionary in supported_layout_cases():
				if item.category == &"phone":
					cases.append(item)
			cases.append_array(phone_state_cases())
			for item: Dictionary in [
				{"size": Vector2i(390, 744), "count": 6},
				{"size": Vector2i(390, 744), "count": 7},
				{"size": Vector2i(844, 390), "count": 6},
				{"size": Vector2i(932, 430), "count": 7},
			]:
				cases.append(_layout_case(item.size, item.count, true, "browser-correction"))
		&"ipad":
			for size: Vector2i in [
				Vector2i(768, 1024),
				Vector2i(1024, 768),
				Vector2i(1194, 696),
				Vector2i(1194, 676),
				Vector2i(834, 1030),
				Vector2i(2388, 1450),
			]:
				for count: int in [2, 4, 6, 9]:
					cases.append(_state_case("ipad", size, count, &"human-turn-river"))
		&"desktop":
			for item: Dictionary in supported_layout_cases():
				if item.category == &"desktop":
					cases.append(item)
			cases.append_array(wide_state_cases())
			for count: int in [6, 9]:
				cases.append(_layout_case(Vector2i(1280, 720), count, true, "browser-correction"))
	return cases


static func fixture(case: Dictionary) -> Dictionary:
	if case.state_id == &"layout":
		return Fixtures.replacement_flop(case.player_count)
	return Fixtures.by_id(case.state_id, case.player_count)


static func _layout_case(
	size: Vector2i, count: int, expected_ready: bool, identity: String
) -> Dictionary:
	var category: StringName = _category_for_size(size)
	return {
		"case_id": "%s/%s-%dx%d/p%d" % [category, identity, size.x, size.y, count],
		"category": category,
		"state_id": &"layout",
		"size": size,
		"player_count": count,
		"expected_ready": expected_ready,
		"expects_readiness": true,
		"layout_mode_override": _layout_mode_override(size),
	}


static func _state_case(
	category: StringName, size: Vector2i, count: int, state: StringName
) -> Dictionary:
	return {
		"case_id": "%s/%dx%d/p%d/%s" % [category, size.x, size.y, count, state],
		"category": category,
		"state_id": state,
		"size": size,
		"player_count": count,
		"expected_ready": true,
		"expects_readiness": false,
		"layout_mode_override": _layout_mode_override(size),
	}


static func _category_for_size(size: Vector2i) -> StringName:
	if size.x < 600 or size.y < 500:
		return &"phone"
	if size.x >= 1400 or size.y >= 1000:
		return &"ipad" if size.x == 1600 else &"desktop"
	return &"desktop"


static func _layout_mode_override(size: Vector2i) -> int:
	if size == Vector2i(2388, 1450):
		return SizeClass.LayoutMode.WIDE
	return SizeClass.AUTOMATIC
