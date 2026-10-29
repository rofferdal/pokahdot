extends "res://tests/support/poker_gut_test.gd"

const Harness := preload("res://tests/support/gui_scene_harness.gd")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")


func test_horizontal_band_count_cannot_be_bypassed_with_slight_vertical_stagger() -> void:
	var staggered: Array[Rect2] = [
		Rect2(0, 0, 100, 50),
		Rect2(110, 1, 100, 50),
		Rect2(220, 2, 100, 50),
		Rect2(330, 3, 100, 50),
	]
	assert_eq(_maximum_band_population(staggered), 4)
	var separate_rows: Array[Rect2] = [
		Rect2(0, 0, 100, 50),
		Rect2(110, 0, 100, 50),
		Rect2(220, 0, 100, 50),
		Rect2(0, 50, 100, 50),
		Rect2(110, 50, 100, 50),
		Rect2(220, 50, 100, 50),
	]
	assert_eq(_maximum_band_population(separate_rows), 3)


func test_reviewed_six_seat_compact_table_keeps_at_most_three_complete_seats_per_band() -> void:
	# This bounded regression does not certify unconverted legacy layouts.
	for state: StringName in [&"human-turn-preflop", &"showdown-long"]:
		var harness: Node = Harness.new()
		add_child_autofree(harness)
		var rendered: Dictionary = harness.render(States.by_id(state, 6), Vector2i(1280, 720))
		assert_true(await harness.settle_layout())
		var snapshot: GuiLayoutSnapshot = rendered.table.get_layout_snapshot()
		var footprints: Array[Rect2] = []
		for seat: GuiSeatSnapshot in snapshot.seats.values():
			if seat.panel.visible:
				footprints.append(seat.footprint)
		assert_eq(footprints.size(), 6)
		assert_lte(_maximum_band_population(footprints), 3, String(state))


func _maximum_band_population(footprints: Array[Rect2]) -> int:
	var boundaries: Array[float] = []
	for rect: Rect2 in footprints:
		boundaries.append(rect.position.y)
		boundaries.append(rect.end.y)
	boundaries.sort()
	var maximum: int = 0
	for index: int in range(boundaries.size() - 1):
		if boundaries[index] == boundaries[index + 1]:
			continue
		var y: float = (boundaries[index] + boundaries[index + 1]) * 0.5
		var population: int = 0
		for rect: Rect2 in footprints:
			if rect.size.x > 0 and rect.position.y < y and rect.end.y > y:
				population += 1
		maximum = maxi(maximum, population)
	return maximum
