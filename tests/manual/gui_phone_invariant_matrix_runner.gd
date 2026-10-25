extends "res://tests/support/poker_gut_test.gd"

## Strict Milestone 4 phone matrix. Kept separate from the historical M3 gate.

const GuiInvariantAssertionsScript := preload("res://tests/support/gui_invariant_assertions.gd")
const GuiSceneHarnessScript := preload("res://tests/support/gui_scene_harness.gd")
const CaptureManifestScript := preload("res://tests/support/gui_visual_capture_manifest.gd")
const GuiPhoneSeatLayoutScript := preload("res://scripts/gui/gui_phone_seat_layout.gd")


func test_phone_visual_matrix_satisfies_gui_invariants() -> void:
	var failures := PackedStringArray()
	for case: Dictionary in CaptureManifestScript.phone_cases():
		var viewport: Dictionary = case.viewport
		var descriptor: Dictionary = case.descriptor
		var harness: Node = GuiSceneHarnessScript.new()
		add_child(harness)
		var view_signature: String = _view_signature(descriptor.view)
		var rendered: Dictionary = harness.render(
			descriptor, viewport.size, viewport.profile_override
		)
		var settled: bool = await harness.settle_layout()
		var context := "%s / p%d / %s" % [viewport.key, descriptor.player_count, descriptor.id]
		if not settled:
			failures.append("%s: layout did not settle" % context)
		for failure: String in GuiInvariantAssertionsScript.validate(rendered):
			failures.append("%s: %s" % [context, failure])
		_validate_phone_contract(rendered, context, failures)
		if _view_signature(descriptor.view) != view_signature:
			failures.append("%s: presentation render changed the core view" % context)
		if descriptor.id == &"human-turn-preflop":
			var rotated_size := (
				Vector2i(844, 390) if viewport.size.y > viewport.size.x else Vector2i(390, 844)
			)
			harness.resize_viewport(rotated_size)
			if not await harness.settle_layout():
				failures.append("%s: rotated layout did not settle" % context)
			harness.resize_viewport(viewport.size)
			if not await harness.settle_layout():
				failures.append("%s: restored layout did not settle" % context)
			for failure: String in GuiInvariantAssertionsScript.validate(rendered):
				failures.append("%s after resize cycle: %s" % [context, failure])
			if _view_signature(descriptor.view) != view_signature:
				failures.append("%s: resize cycle changed the core view" % context)
		harness.free()
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))


func _validate_phone_contract(
	rendered: Dictionary, context: String, failures: PackedStringArray
) -> void:
	var table: PokerTableController = rendered.table
	if table == null:
		return
	var view: GameView = rendered.descriptor.view
	var surface := table.get_node("TableMargin/Felt/TableSurface") as Control
	var expected_rects: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(
		surface.size, view.seats.size()
	)
	var found_long_name: bool = false
	for player_view: PlayerView in view.seats:
		if player_view.seat == view.hero_seat:
			continue
		var visual_seat: int = posmod(player_view.seat - view.hero_seat, view.seats.size())
		var panel := surface.get_node("Seats/Seat%d" % player_view.seat) as PanelContainer
		var expected_rect: Rect2 = expected_rects[visual_seat]
		var actual_rect: Rect2 = panel.get_rect()
		if not (
			actual_rect.position.is_equal_approx(expected_rect.position)
			and actual_rect.size.is_equal_approx(expected_rect.size)
		):
			failures.append(
				(
					"%s: density-tier rectangle mismatch for seat %d: %s != %s"
					% [context, player_view.seat, actual_rect, expected_rect]
				)
			)
		var name_label := panel.find_child("Name", true, false) as Label
		if name_label == null or name_label.text.is_empty():
			failures.append(
				"%s: seat %d has no assigned display name" % [context, player_view.seat]
			)
			continue
		found_long_name = found_long_name or name_label.text.length() >= 8
		if _rendered_width(name_label) > name_label.size.x:
			failures.append("%s: seat %d display name is clipped" % [context, player_view.seat])
		var stack_label := panel.find_child("Stack", true, false) as Label
		if stack_label == null or not stack_label.text.is_valid_int():
			failures.append("%s: seat %d has no numeric stack" % [context, player_view.seat])
		elif _rendered_width(stack_label) > stack_label.size.x:
			failures.append("%s: seat %d stack is clipped" % [context, player_view.seat])
		var detail_button := panel.find_child("DetailsButton", true, false) as Button
		if detail_button == null or name_label.text not in detail_button.tooltip_text:
			failures.append(
				"%s: seat %d detail does not retain its full name" % [context, player_view.seat]
			)
		var hole_cards := panel.find_child("HoleCards", true, false) as Control
		if hole_cards == null or hole_cards.get_child_count() != 2:
			failures.append(
				"%s: seat %d does not show two hole-card fields" % [context, player_view.seat]
			)
			continue
		var action_badge := panel.find_child("ActionBadge", true, false) as Label
		if action_badge != null and action_badge.visible:
			for required_field: Control in [name_label, stack_label, hole_cards]:
				if (
					required_field != null
					and action_badge.get_global_rect().intersects(required_field.get_global_rect())
				):
					failures.append(
						(
							"%s: seat %d action badge covers %s"
							% [context, player_view.seat, required_field.name]
						)
					)
		if player_view.folded or player_view.busted:
			if panel.find_child("HoleCardField1", true, false) == null:
				failures.append("%s: seat %d omits empty card fields" % [context, player_view.seat])
			continue
		var has_revealed_cards: bool = view.revealed_hole_cards.has(player_view.seat)
		var card_back := panel.find_child("CardBack1", true, false)
		var card_face := panel.find_child("ShowdownCard1", true, false)
		if has_revealed_cards and (card_face == null or card_back != null):
			failures.append(
				"%s: seat %d revealed-card presentation is incorrect" % [context, player_view.seat]
			)
		elif not has_revealed_cards and (card_back == null or card_face != null):
			failures.append(
				"%s: seat %d exposes or omits private cards" % [context, player_view.seat]
			)
	if (
		view.seats.size() == GuiPhoneSeatLayoutScript.MAX_SUPPORTED_PLAYER_COUNT
		and not found_long_name
	):
		failures.append(
			"%s: seven-player fixture does not exercise an eight-character name" % context
		)


func _rendered_width(label: Label) -> float:
	return (
		label
		. get_theme_font("font")
		. get_string_size(
			label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			label.get_theme_font_size("font_size"),
		)
		. x
	)


func _view_signature(view: GameView) -> String:
	if view == null:
		return "startup"
	var seats: Array[Dictionary] = []
	for player_view: PlayerView in view.seats:
		(
			seats
			. append(
				{
					"seat": player_view.seat,
					"stack": player_view.stack,
					"folded": player_view.folded,
					"all_in": player_view.all_in,
					"busted": player_view.busted,
				}
			)
		)
	return (
		JSON
		. stringify(
			{
				"street": String(view.street),
				"acting_seat": view.acting_seat,
				"pot": view.pot_amount,
				"call": view.call_amount,
				"minimum": view.minimum_wager_total,
				"maximum": view.maximum_wager_total,
				"legal_actions": Array(view.legal_actions),
				"active_seats": Array(view.active_seats),
				"eliminated_seats": Array(view.eliminated_seats),
				"seats": seats,
				"showdown_count": view.showdown_results.size(),
				"revealed_count": view.revealed_hole_cards.size(),
			}
		)
	)
