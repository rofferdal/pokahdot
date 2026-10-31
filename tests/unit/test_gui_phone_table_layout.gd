extends GutTest

const Progress := preload("res://tests/support/gui_matrix_progress.gd")
const Portrait := preload("res://scenes/gui/layouts/PhoneTableLayout.tscn")
const Landscape := preload("res://scenes/gui/layouts/PhoneLandscapeLayout.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
var _root: Control


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(5000, 4000)
	_root.theme = Palette
	add_child_autofree(_root)


func test_counts_modes_densities_and_states_render_at_actual_native_minima() -> void:
	var progress := Progress.new("phone-unit/native-minima", 120)
	for landscape: bool in [false, true]:
		for density: GuiFitCandidate.Density in [
			GuiFitCandidate.Density.COMPACT, GuiFitCandidate.Density.FULL
		]:
			for count: int in range(2, 8):
				var layout: GuiPhoneTableLayout = _layout(landscape, density)
				for state: StringName in [
					&"human-turn-flop",
					&"all-in-runout",
					&"showdown-long",
					&"elimination",
					&"tournament-winner"
				]:
					progress.begin(
						"landscape=%s density=%d p%d %s" % [landscape, density, count, state]
					)
					assert_true(layout.render(_model(count, state, density)))
					await wait_process_frames(10)
					layout.size = layout.get_combined_minimum_size()
					await wait_process_frames(10)
					var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(_root)
					assert_true(snapshot.ready, "%d/%s/%s/%d" % [count, state, landscape, density])
					assert_eq(snapshot.seats.size(), count)
					assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
					for row: PackedInt32Array in snapshot.seat_rows:
						assert_lte(row.size(), 3 if landscape else 2)
					progress.finish(20)
				layout.free()


func test_actual_default_and_large_amount_phone_capability_is_reported_without_hiding_copy(
) -> void:
	var progress := Progress.new("phone-unit/capability", 24)
	var observations: Array[Dictionary] = []
	for landscape: bool in [false, true]:
		for large: bool in [false, true]:
			for count: int in range(2, 8):
				progress.begin("landscape=%s large=%s p%d" % [landscape, large, count])
				var layout: GuiPhoneTableLayout = _layout(landscape)
				var allocation := Vector2(844, 390) if landscape else Vector2(390, 844)
				layout.set_allocation_limit(allocation)
				layout.size = allocation
				assert_true(
					layout.render(
						_model(count, &"human-turn-flop", GuiFitCandidate.Density.COMPACT, large)
					)
				)
				await wait_process_frames(12)
				var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(_root)
				assert_eq(
					Invariants.validate_snapshot(snapshot),
					PackedStringArray(),
					"landscape=%s large=%s count=%d" % [landscape, large, count]
				)
				var minimum: Vector2 = layout.get_combined_minimum_size()
				observations.append(
					{
						"count": count,
						"landscape": landscape,
						"large_amounts": large,
						"available": [allocation.x, allocation.y],
						"minimum": [minimum.x, minimum.y],
						"fit": snapshot.ready,
						"guidance": snapshot.fit_guidance
					}
				)
				assert_eq(snapshot.ready, allocation.x >= minimum.x and allocation.y >= minimum.y)
				progress.finish(12)
				layout.free()
	DirAccess.make_dir_recursive_absolute("res://localtmp/restructure_rg52")
	var output := FileAccess.open(
		"res://localtmp/restructure_rg52/capability.json", FileAccess.WRITE
	)
	assert_not_null(output)
	output.store_string(JSON.stringify(observations, "\t"))


func test_fresh_small_and_grown_then_small_have_identical_native_envelopes() -> void:
	var progress := Progress.new("phone-unit/envelopes", 12)
	for landscape: bool in [false, true]:
		for count: int in range(2, 8):
			progress.begin("landscape=%s p%d" % [landscape, count])
			var allocation := Vector2(844, 390) if landscape else Vector2(390, 844)
			var fresh: GuiPhoneTableLayout = _layout(landscape)
			fresh.size = allocation
			fresh.set_allocation_limit(allocation)
			assert_true(fresh.render(_model(count)))
			var grown: GuiPhoneTableLayout = _layout(landscape)
			assert_true(grown.render(_model(count)))
			await wait_process_frames(12)
			grown.size = allocation
			grown.set_allocation_limit(allocation)
			await wait_process_frames(12)
			assert_eq(
				fresh.get_combined_minimum_size(),
				grown.get_combined_minimum_size(),
				"%s/%d" % [landscape, count]
			)
			assert_eq(
				fresh.get_layout_snapshot(_root).fit_guidance,
				grown.get_layout_snapshot(_root).fit_guidance
			)
			assert_eq(
				Invariants.validate_snapshot(fresh.get_layout_snapshot(_root)), PackedStringArray()
			)
			progress.finish(24)
			fresh.free()
			grown.free()


func test_resize_boundaries_and_grow_shrink_recover_minima_and_exact_drafts() -> void:
	for landscape: bool in [false, true]:
		var layout: GuiPhoneTableLayout = _layout(landscape)
		assert_true(layout.render(_model(6)))
		layout.set_wager_draft("001000000")
		await wait_process_frames(12)
		var minimum: Vector2 = layout.get_combined_minimum_size()
		layout.size = minimum
		await wait_process_frames(10)
		assert_true(layout.get_layout_snapshot(_root).ready)
		# A one-pixel reduction can now select a different valid row/preset flow.
		# Verify guidance at dimensions that cannot contain any complete control.
		for constrained: Vector2 in [Vector2(1, minimum.y), Vector2(minimum.x, 1)]:
			layout.set_allocation_limit(constrained)
			await wait_process_frames(8)
			var failed: GuiLayoutSnapshot = layout.get_layout_snapshot(_root)
			assert_false(failed.ready)
			assert_false(failed.fit_guidance.is_empty())
			assert_eq(Invariants.validate_snapshot(failed), PackedStringArray())
			assert_eq(layout.get_wager_draft(), "001000000")
		layout.set_allocation_limit(Vector2.ZERO)
		layout.size = minimum + Vector2(1000, 1000)
		await wait_process_frames(10)
		assert_eq(layout.get_combined_minimum_size(), minimum)
		layout.size = minimum
		await wait_process_frames(10)
		assert_true(layout.get_layout_snapshot(_root).ready)
		assert_eq(layout.get_combined_minimum_size(), minimum)
		layout.free()


func test_refresh_preserves_identity_draft_selection_and_explicit_modality() -> void:
	var layout: GuiPhoneTableLayout = _layout(false)
	layout.use_keypad(false)
	layout.set_wager_draft("001000000")
	assert_true(layout.render(_model(4)))
	await wait_process_frames(12)
	var first: Dictionary[int, Control] = layout.get_seat_controls()
	var field := layout.get_control(&"total") as LineEdit
	field.caret_column = 6
	field.select(1, 5)
	assert_true(layout.render(_model(4, &"human-turn-river")))
	for frame: int in 6:
		await get_tree().process_frame
		assert_true(layout.get_control(&"content").visible)
		assert_eq(layout.get_control(&"content").modulate.a, 1.0)
	await wait_process_frames(4)
	for id: int in first:
		assert_same(layout.get_seat_controls()[id], first[id])
	assert_eq(layout.get_wager_draft(), "001000000")
	assert_eq(field.caret_column, 6)
	assert_eq(field.get_selection_from_column(), 1)
	assert_eq(field.get_selection_to_column(), 5)
	assert_true(field.visible)
	layout.use_keypad(true)
	layout.size = Vector2(4000, 3000)
	await wait_process_frames(10)
	assert_false(field.visible)
	assert_eq(layout.get_wager_draft(), "001000000")


func test_scene_owned_seat_parents_and_identity_survive_reflow_and_refresh() -> void:
	for landscape: bool in [false, true]:
		var layout: GuiPhoneTableLayout = _layout(landscape)
		assert_true(layout.render(_model(6)))
		await wait_process_frames(12)
		var seats: Dictionary[int, Control] = layout.get_seat_controls()
		var parents: Dictionary[int, Node] = {}
		for id: int in seats:
			parents[id] = seats[id].get_parent()
		for allocation: Vector2 in [Vector2(600, 1000), Vector2(350, 900), Vector2(3000, 2500)]:
			assert_true(layout.set_allocation_limit(allocation))
			await wait_process_frames(8)
			assert_true(layout.render(_model(6, &"human-turn-river")))
			await wait_process_frames(8)
			for id: int in seats:
				assert_same(layout.get_seat_controls()[id], seats[id])
				assert_same(seats[id].get_parent(), parents[id])
		layout.free()


func test_native_keyboard_action_entry_menu_and_seat_detail_signals() -> void:
	var layout: GuiPhoneTableLayout = _layout(false)
	assert_true(layout.render(_model(4)))
	layout.set_wager_draft("75")
	await wait_process_frames(12)
	watch_signals(layout)
	for role: StringName in [&"fold", &"wager", &"more"]:
		layout.get_control(role).grab_focus()
		await _enter()
	assert_signal_emitted_with_parameters(layout, "action_requested", [&"fold"])
	assert_signal_emitted_with_parameters(layout, "entry_requested", ["75"])
	assert_signal_emit_count(layout, "menu_requested", 1)
	layout.get_seat_controls()[1].grab_focus()
	await _enter()
	assert_signal_emitted_with_parameters(layout, "seat_detail_requested", [1])


func test_capacity_guidance_keeps_match_copy_and_more_returns_after_supported_rebinding() -> void:
	var layout: GuiPhoneTableLayout = _layout(false)
	for count: int in [8, 9]:
		assert_true(layout.render(_model(count)))
		await wait_process_frames(10)
		var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(_root)
		assert_false(snapshot.ready)
		assert_string_contains(snapshot.fit_guidance, "larger layout")
		assert_eq(snapshot.seats.size(), count)
		assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	assert_true(layout.render(_model(4, &"showdown-long")))
	await wait_process_frames(12)
	assert_true(layout.get_layout_snapshot(_root).ready)
	assert_true(layout.get_control(&"more").is_visible_in_tree())
	assert_false((layout.get_control(&"more") as BaseButton).disabled)


func test_rebinding_pending_measurement_discards_stale_generation_and_candidates() -> void:
	var layout: GuiPhoneTableLayout = _layout(false)
	layout.set_wager_draft("0075")
	assert_true(layout.render(_model(7)))
	assert_true(layout.render(_model(7)))
	assert_true(layout.get_layout_snapshot(_root).pending)
	await wait_process_frames(1)
	assert_eq(layout.get_control(&"content").modulate.a, 0.0)
	assert_eq(
		layout.get_control(&"content").mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED
	)
	assert_eq(
		layout.get_control(&"content").focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED
	)
	assert_false(
		(
			layout
			. get_fit_candidate(
				GuiSizeClass.LayoutMode.PHONE,
				GuiFitCandidate.Density.COMPACT,
				GuiFitCandidate.ActionFlow.KEYPAD
			)
			. valid
		)
	)
	assert_true(layout.render(_model(2)))
	await wait_process_frames(12)
	var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(_root)
	assert_true(snapshot.ready)
	assert_false(snapshot.pending)
	assert_eq(snapshot.seats.size(), 2)
	assert_eq(layout.get_wager_draft(), "0075")
	assert_eq(Invariants.validate_snapshot(snapshot), PackedStringArray())
	assert_true(
		(
			layout
			. get_fit_candidate(
				GuiSizeClass.LayoutMode.PHONE,
				GuiFitCandidate.Density.COMPACT,
				GuiFitCandidate.ActionFlow.KEYPAD
			)
			. valid
		)
	)


func test_embossed_logo_and_translated_origin_do_not_change_minimum_or_intercept_input() -> void:
	var layout: GuiPhoneTableLayout = _layout(false)
	layout.position = Vector2(31, 47)
	assert_true(layout.render(_model(4)))
	await wait_process_frames(12)
	var minimum: Vector2 = layout.get_combined_minimum_size()
	var logo := layout.get_control(&"logo") as TextureRect
	assert_eq(logo.material.resource_path, "res://resources/gui_table_logo_material.tres")
	assert_true((logo.material as ShaderMaterial).get_shader_parameter("embossed"))
	assert_eq(logo.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(logo.focus_mode, Control.FOCUS_NONE)
	logo.hide()
	await wait_process_frames(6)
	assert_eq(layout.get_combined_minimum_size(), minimum)
	logo.show()
	layout.size = minimum
	await wait_process_frames(8)
	assert_eq(Invariants.validate_snapshot(layout.get_layout_snapshot(_root)), PackedStringArray())


func test_measured_solver_rejects_invalid_values_without_partial_rows() -> void:
	var ids := PackedInt32Array([0, 1])
	var minima: Dictionary[int, Vector2] = {0: Vector2(200, 150), 1: Vector2(200, 150)}
	for invalid: Vector2 in [Vector2.ZERO, Vector2(-1, 80), Vector2(NAN, 80), Vector2(40, INF)]:
		assert_false(
			(
				GuiPhoneTablePlan
				. resolve(ids, 0, minima, invalid, Vector2(200, 100), false, Vector2(1000, 1000))
				. valid
			)
		)
		assert_false(
			(
				GuiPhoneTablePlan
				. resolve(ids, 0, minima, Vector2(200, 100), invalid, false, Vector2(1000, 1000))
				. valid
			)
		)
	for invalid: float in [-1.0, NAN, INF]:
		assert_false(
			(
				GuiPhoneTablePlan
				. resolve(
					ids,
					0,
					minima,
					Vector2(200, 100),
					Vector2(200, 100),
					false,
					Vector2(1000, 1000),
					invalid
				)
				. valid
			)
		)
	var invalid_minima: Dictionary[int, Vector2] = minima.duplicate()
	invalid_minima[0] = Vector2.ZERO
	assert_false(
		(
			GuiPhoneTablePlan
			. resolve(
				ids,
				0,
				invalid_minima,
				Vector2(200, 100),
				Vector2(200, 100),
				false,
				Vector2(1000, 1000)
			)
			. valid
		)
	)
	assert_false(
		(
			GuiPhoneTablePlan
			. resolve(ids, 0, minima, Vector2(200, 100), Vector2(200, 100), false, Vector2(-1, 100))
			. valid
		)
	)


func _layout(
	landscape: bool, density: GuiFitCandidate.Density = GuiFitCandidate.Density.COMPACT
) -> GuiPhoneTableLayout:
	var layout: GuiPhoneTableLayout = (Landscape if landscape else Portrait).instantiate()
	layout.theme = GuiTypography.for_density(density)
	_root.add_child(layout)
	layout.size = Vector2(3000, 2500)
	return layout


func _model(
	count: int,
	state: StringName = &"human-turn-flop",
	density: GuiFitCandidate.Density = GuiFitCandidate.Density.COMPACT,
	large: bool = false
) -> TableViewModel:
	var fixture: Dictionary = GuiVisualStateFixtures.by_id(state, 9)
	var view: GameView = fixture.view
	var names: Dictionary[int, String] = {}
	var avatars: Dictionary[int, String] = {}
	for index: int in 9:
		names[index] = "Emiliano" if index > 0 else "You"
	var latest: Dictionary[int, PublicActionRecord] = {}
	for action: PublicActionRecord in view.action_history:
		latest[action.seat] = action
	var model: TableViewModel = TableViewModel.build(view, names, avatars, latest, {}, [], density)
	model.seats.resize(count)
	if large:
		for seat: SeatViewModel in model.seats:
			seat.stack_value_text = "9000000"
			seat.wager_text = "Bet 1000000"
		model.center.phone_pot_text = "Pot: 6000000"
		model.center.phone_wager_text = "Current wager: 1000000"
		model.center.blind_level_text = "Blinds 500000 / 1000000 · Level 3 · 8 hands to next level"
		model.actions.check_call_text = "Call 1000000"
		model.actions.minimum_text = "Min Raise 2000000"
		model.actions.pot_text = "Pot 3000000"
	return model


func _enter() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame
