extends "res://tests/support/poker_gut_test.gd"

const Harness := preload("res://tests/support/gui_scene_harness.gd")
const Fixture := preload("res://tests/support/gui_browser_capture_fixture.gd")
const Contract := preload("res://tests/support/gui_phone_matrix_contract.gd")


class SnapshotRoot:
	extends RefCounted
	var snapshot: GuiLayoutSnapshot

	func get_layout_snapshot() -> GuiLayoutSnapshot:
		return snapshot


func test_partially_clipped_back_and_empty_fields_are_rejected_while_still_visible() -> void:
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	var rendered: Dictionary = harness.render(Fixture.descriptor(), Vector2i(390, 844))
	assert_true(await harness.settle_layout())
	var baseline := PackedStringArray()
	Contract.validate(rendered, "baseline", baseline)
	assert_eq(baseline, PackedStringArray())
	for kind: GuiCardSnapshot.Kind in [GuiCardSnapshot.Kind.BACK, GuiCardSnapshot.Kind.EMPTY]:
		var root := SnapshotRoot.new()
		root.snapshot = rendered.root.get_layout_snapshot()
		var target: GuiSeatSnapshot = _seat_with_kind(root.snapshot, kind)
		assert_not_null(target)
		if target == null:
			continue
		var card: GuiLayoutElement = target.cards[0].element
		assert_true(card.visible)
		card.rect.size.y += target.panel.rect.size.y
		var failures := PackedStringArray()
		Contract.validate({"root": root}, "clipped visible field", failures)
		assert_true("escapes its container or panel" in "\n".join(failures))


func test_visible_card_cannot_escape_its_semantic_field_even_inside_the_panel() -> void:
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	var rendered: Dictionary = harness.render(Fixture.descriptor(), Vector2i(390, 844))
	assert_true(await harness.settle_layout())
	var root := SnapshotRoot.new()
	root.snapshot = rendered.root.get_layout_snapshot()
	var seat: GuiSeatSnapshot = _seat_with_kind(root.snapshot, GuiCardSnapshot.Kind.BACK)
	assert_not_null(seat)
	if seat == null:
		return
	assert_true(seat.panel.rect.encloses(seat.cards[0].element.rect))
	seat.fields[&"cards"].rect.size.y = 1
	var failures := PackedStringArray()
	Contract.validate({"root": root}, "wrong card field allocation", failures)
	assert_true("escapes its container or panel" in "\n".join(failures))


func _seat_with_kind(snapshot: GuiLayoutSnapshot, kind: GuiCardSnapshot.Kind) -> GuiSeatSnapshot:
	for seat: GuiSeatSnapshot in snapshot.seats.values():
		if not seat.hero and seat.cards.size() == 2 and seat.cards[0].kind == kind:
			return seat
	return null
