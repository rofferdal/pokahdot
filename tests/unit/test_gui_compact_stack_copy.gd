extends "res://tests/support/poker_gut_test.gd"

const Fixtures := preload("res://tests/support/gui_browser_capture_fixture.gd")
const Harness := preload("res://tests/support/gui_scene_harness.gd")


func test_compact_stack_copy_uses_stable_seat_ids_after_source_reordering_and_resize() -> void:
	var descriptor: Dictionary = Fixtures.descriptor()
	for player: PlayerView in descriptor.view._seats:
		player.stack = 1000 + player.seat
	descriptor.view._seats.reverse()
	var harness: Node = Harness.new()
	add_child(harness)
	var rendered: Dictionary = harness.render(descriptor, Vector2i(768, 1024))
	assert_true(await harness.settle_layout())
	for dimensions: Vector2i in [
		Vector2i(768, 1024), Vector2i(950, 532), Vector2i(1855, 918), Vector2i(768, 1024)
	]:
		harness.resize_viewport(dimensions)
		assert_true(await harness.settle_layout())
		var table: PokerTableController = rendered.table
		for seat: int in table._seat_widgets:
			var stack := table._seat_widgets[seat].find_child("Stack", true, false) as Label
			var expected: String = str(1000 + seat)
			if dimensions == Vector2i(1855, 918):
				expected += " chips"
			assert_eq(stack.text, expected)
	harness.queue_free()
