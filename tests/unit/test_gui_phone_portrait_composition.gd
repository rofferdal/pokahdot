extends "res://tests/support/poker_gut_test.gd"

const Harness := preload("res://tests/support/gui_scene_harness.gd")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const TokenPlan := preload("res://scripts/gui/gui_phone_portrait_token_plan.gd")


func test_portrait_tokens_pack_all_required_fields_without_overlaps() -> void:
	var widths: Dictionary[String, float] = {
		"Name": 90.0,
		"Stack": 102.0,
		"Badge": 32.0,
		"HoleCards": 40.0,
	}
	for comfortable: bool in [true, false]:
		var plan := TokenPlan.new()
		assert_true(plan.configure(184.0, widths, comfortable))
		var bounds := Rect2(0, 0, 184, plan.height)
		var placed: Array[Rect2] = []
		for role: String in widths:
			var rect: Rect2 = plan.rects[role]
			assert_true(bounds.encloses(rect), role)
			for other: Rect2 in placed:
				assert_false(rect.intersects(other), role)
			placed.append(rect)
		if comfortable:
			assert_gt(plan.rects.HoleCards.position.y, plan.rects.Stack.position.y)
	var invalid := TokenPlan.new()
	assert_false(invalid.configure(109.0, widths))
	var revealed: Dictionary[String, float] = {
		"Name": 83.0,
		"Stack": 84.0,
		"Badge": 29.0,
		"HoleCards": 94.0,
	}
	var tight := TokenPlan.new()
	assert_true(tight.configure(172.0, revealed, false, 26.0, true))
	assert_eq(tight.rects.HoleCards.size, Vector2(46, 60))
	assert_lte(tight.height, 64.0)
	for role: String in ["Name", "Stack", "Badge"]:
		assert_false(tight.rects[role].intersects(tight.rects.HoleCards))
	var too_wide := TokenPlan.new()
	revealed.Name = 120.0
	assert_true(too_wide.configure(172.0, revealed, false, 26.0, true))
	assert_eq(too_wide.rects.HoleCards.size.y, 30.0, "A tight column must not clip a long name")


func test_supported_portraits_reserve_whole_seat_bands_and_anchor_community_above_hero() -> void:
	for count: int in range(2, 8):
		for extent: Vector2i in [Vector2i(360, 640), Vector2i(390, 844)]:
			for state: StringName in [&"human-turn-preflop", &"showdown-long"]:
				var descriptor: Dictionary = _descriptor(state, count)
				var harness: Node = Harness.new()
				add_child(harness)
				var rendered: Dictionary = harness.render(descriptor, extent)
				assert_true(await harness.settle_layout())
				var snapshot: GuiLayoutSnapshot = rendered.table.get_layout_snapshot()
				assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
				assert_eq(snapshot.surface_rect, snapshot.root_rect)
				assert_almost_eq(
					snapshot.elements[&"center"].rect.end.y + 4.0,
					snapshot.elements[&"action"].rect.position.y,
					0.01
				)
				for seat: GuiSeatSnapshot in snapshot.seats.values():
					if seat.hero:
						continue
					assert_true(seat.status.visible, "Even an empty band keeps reserved space")
					assert_gte(seat.status.rect.position.y, seat.panel.rect.end.y + 3.99)
					assert_gte(seat.status.rect.size.y, seat.status.font_size * 2.0)
					assert_lte(
						seat.status.line_count, 2, "Status copy uses at most two complete lines"
					)
					var hand: ShowdownResult = descriptor.view.showdown_results.get(seat.seat_id)
					if hand != null:
						assert_true(
							(
								seat.status.text
								in [
									ShowdownHandFormatter.format_compact(hand),
									ShowdownHandFormatter.format_inline(hand)
								]
							)
						)
					assert_true(seat.footprint.encloses(seat.status.rect))
					assert_true(seat.footprint.encloses(seat.panel.rect))
					assert_false(
						seat.footprint.intersects(snapshot.elements[&"center"].rect),
						(
							"%s p%d %s seat%d font%d panel%s band%s: %s vs center %s"
							% [
								state,
								count,
								extent,
								seat.seat_id,
								seat.status.font_size,
								seat.panel.rect.size,
								seat.status.rect.size,
								seat.footprint,
								snapshot.elements[&"center"].rect
							]
						)
					)
					assert_false(seat.footprint.intersects(snapshot.elements[&"action"].rect))
					for other: GuiSeatSnapshot in snapshot.seats.values():
						if not other.hero and other.seat_id != seat.seat_id:
							assert_false(seat.footprint.intersects(other.footprint))
					var action: GuiLayoutElement = seat.fields[&"action"]
					if action.visible:
						assert_lte(action.line_count, 2)
						assert_true(seat.status.rect.encloses(action.rect))
					for card: GuiCardSnapshot in seat.cards:
						assert_true(
							seat.panel.rect.encloses(card.element.rect),
							"Every back, empty field and face fits"
						)
						assert_true(seat.fields[&"cards"].rect.encloses(card.element.rect))
				harness.free()


func test_every_award_recipient_and_fallback_hand_winner_get_bold_yellow_status() -> void:
	for awards: bool in [false, true]:
		var descriptor: Dictionary = _descriptor(&"showdown-long", 7)
		if awards:
			var pot_awards: Array[PotAward] = [
				PotAward.new(0, 20, [4, 5], {4: 10, 5: 10}), PotAward.new(1, 10, [6], {6: 10})
			]
			descriptor.view._pot_awards = pot_awards
		var harness: Node = Harness.new()
		add_child(harness)
		var rendered: Dictionary = harness.render(descriptor, Vector2i(390, 844))
		assert_true(await harness.settle_layout())
		for seat: int in [4, 5, 6] if awards else [6]:
			var label := rendered.table.get_node("%Seats").get_node("Seat%dStatus" % seat) as Label
			assert_eq(label.get_theme_color("font_color"), Color.YELLOW)
			var font := label.get_theme_font("font") as FontVariation
			assert_not_null(font)
			if font != null:
				assert_gt(font.variation_embolden, 0.0)
		harness.free()


func test_unregistered_name_label_cannot_receive_the_seat_copy_font_floor() -> void:
	var harness: Node = Harness.new()
	add_child(harness)
	var rendered: Dictionary = harness.render(
		_descriptor(&"human-turn-preflop", 7), Vector2i(390, 844)
	)
	assert_true(await harness.settle_layout())
	var fake := Label.new()
	fake.name = "Name"
	fake.text = "Unregistered copy"
	fake.add_theme_font_size_override("font_size", 18)
	rendered.table.get_node("TableMargin/Felt/TableSurface").add_child(fake)
	var snapshot: GuiLayoutSnapshot = rendered.table.get_layout_snapshot()
	var found: bool = false
	for value: GuiLayoutElement in snapshot.measured:
		if value.text == fake.text:
			found = true
			assert_true(String(value.role).begins_with("surface/child/"))
			assert_true(
				"font-floor: %s" % value.role in "\n".join(Invariants.validate_snapshot(snapshot))
			)
	assert_true(found)
	harness.free()


func _descriptor(state: StringName, count: int) -> Dictionary:
	var result: Dictionary = States.by_id(state, count if count in [2, 4, 6, 7] else 7)
	if count in [3, 5]:
		result.player_count = count
		result.view._seats.resize(count)
	return result
