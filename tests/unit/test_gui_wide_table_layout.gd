extends GutTest

const WideScene := preload("res://scenes/gui/layouts/WideTableLayout.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
var _root: Control


func before_each() -> void:
	_root = Control.new()
	_root.theme = Palette
	_root.size = Vector2(5000, 4000)
	add_child_autofree(_root)


func test_all_counts_and_states_have_complete_native_minima_in_both_densities() -> void:
	for density: GuiFitCandidate.Density in [
		GuiFitCandidate.Density.COMPACT, GuiFitCandidate.Density.FULL
	]:
		for count: int in range(2, 10):
			var layout: GuiWideTableLayout = _layout(density)
			for state: StringName in [
				&"human-turn-flop",
				&"all-in-runout",
				&"showdown-long",
				&"elimination",
				&"tournament-winner"
			]:
				assert_true(layout.render(_model(count, state, density)))
				await wait_process_frames(8)
				layout.size = layout.get_combined_minimum_size()
				await wait_process_frames(8)
				var ring := layout.get_control(&"ring") as GuiSeatRingContainer
				assert_true(ring.get_layout_plan().feasible, "%d/%s/%d" % [count, state, density])
				assert_eq(layout.get_seat_controls().size(), count)
				_assert_geometry(layout)
				var candidate: GuiFitCandidate = layout.get_fit_candidate(
					GuiSizeClass.LayoutMode.WIDE, density, GuiFitCandidate.ActionFlow.TWO_ROWS
				)
				assert_true(candidate.valid)
				assert_eq(candidate.minimum, layout.get_combined_minimum_size())
				for row: PackedInt32Array in candidate.seats.rows:
					assert_lte(row.size(), 3)
			layout.free()


func test_small_desktop_and_wide_modes_share_the_measured_native_envelope() -> void:
	var layout: GuiWideTableLayout = _layout()
	assert_true(layout.render(_model(6)))
	await wait_process_frames(10)
	for mode: GuiSizeClass.LayoutMode in [
		GuiSizeClass.LayoutMode.WIDE_COMPACT, GuiSizeClass.LayoutMode.WIDE
	]:
		var candidate: GuiFitCandidate = layout.get_fit_candidate(
			mode, GuiFitCandidate.Density.COMPACT, GuiFitCandidate.ActionFlow.TWO_ROWS
		)
		assert_true(candidate.valid)
		assert_eq(candidate.mode, mode)
		assert_eq(candidate.minimum, layout.get_combined_minimum_size())
		assert_eq(candidate.seats.clockwise_ids.size(), 6)
	var unsupported: GuiFitCandidate = layout.get_fit_candidate(
		GuiSizeClass.LayoutMode.PHONE,
		GuiFitCandidate.Density.COMPACT,
		GuiFitCandidate.ActionFlow.TWO_ROWS
	)
	assert_false(unsupported.valid)


func test_dock_uses_external_column_and_exact_hero_action_span_then_shrinks_without_latching(
) -> void:
	var layout: GuiWideTableLayout = _layout()
	var model: TableViewModel = _model(6, &"human-turn-flop")
	var lines: Array[String] = []
	for index: int in 120:
		lines.append("Public event %d: player raises to 1000000" % index)
	model.history = EventLogViewModel.from_lines(lines)
	assert_true(layout.render(model))
	await wait_process_frames(10)
	var minimum: Vector2 = layout.get_combined_minimum_size()
	layout.size = minimum
	await wait_process_frames(8)
	assert_false(layout.get_control(&"dock").visible)
	var log := layout.get_control(&"log") as GuiEventLog
	assert_eq(log.get_log_text(), model.history.text)
	layout.size = minimum + Vector2(800, 200)
	await wait_process_frames(10)
	assert_true(layout.get_control(&"dock").visible)
	assert_eq(layout.get_combined_minimum_size(), minimum)
	var hero: Control = layout.get_control(&"hero")
	var actions: Control = layout.get_control(&"actions")
	assert_almost_eq(log.get_body().global_position.y, hero.global_position.y, 1.0)
	assert_almost_eq(log.get_body().get_global_rect().end.y, actions.get_global_rect().end.y, 1.0)
	for seat: Control in layout.get_seat_controls().values():
		assert_false(seat.get_global_rect().intersects(log.get_global_rect()))
	var bar: VScrollBar = log.get_body().get_v_scroll_bar()
	bar.value = 60.0
	layout.size = minimum
	await wait_process_frames(10)
	assert_false(layout.get_control(&"dock").visible)
	assert_eq(layout.get_combined_minimum_size(), minimum)
	layout.size = minimum + Vector2(800, 200)
	await wait_process_frames(10)
	assert_true(layout.get_control(&"dock").visible)
	assert_almost_eq(bar.value, 60.0, 0.5)
	assert_eq(log.get_log_text(), model.history.text)


func test_threshold_and_short_allocation_show_guidance_without_partial_copy() -> void:
	var layout: GuiWideTableLayout = _layout()
	assert_true(layout.render(_model(9)))
	await wait_process_frames(10)
	var minimum: Vector2 = layout.get_combined_minimum_size()
	layout.size = minimum
	await wait_process_frames(8)
	assert_true(layout.get_control(&"ring").visible)
	for missing: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
		assert_true(layout.set_allocation_limit(minimum - missing))
		await wait_process_frames(6)
		assert_false(layout.get_control(&"ring").visible)
		assert_true(layout.get_control(&"guidance").visible)
		assert_eq(
			Invariants.validate_snapshot(layout.get_layout_snapshot(_root)), PackedStringArray()
		)
		assert_false(layout.get_control(&"dock").visible)
		assert_eq(layout.get_combined_minimum_size(), minimum)
	assert_true(layout.set_allocation_limit(Vector2.ZERO))
	await wait_process_frames(8)
	assert_true(layout.get_control(&"ring").visible)
	assert_false(layout.get_control(&"guidance").visible)
	_assert_geometry(layout)


func test_refresh_preserves_seat_identity_draft_and_explicit_input_modality() -> void:
	var layout: GuiWideTableLayout = _layout()
	assert_true(layout.render(_model(6)))
	layout.set_wager_draft("001000000")
	layout.use_keypad(true)
	await wait_process_frames(8)
	var field := layout.get_control(&"total") as LineEdit
	field.caret_column = 6
	field.select(1, 5)
	var first: Dictionary[int, Control] = layout.get_seat_controls()
	assert_true(layout.render(_model(6, &"human-turn-river")))
	await wait_process_frames(8)
	for id: int in first:
		assert_same(layout.get_seat_controls()[id], first[id])
	assert_eq(layout.get_wager_draft(), "001000000")
	assert_eq(field.caret_column, 6)
	assert_eq(field.get_selection_from_column(), 1)
	assert_eq(field.get_selection_to_column(), 5)
	assert_false(layout.get_control(&"total").visible)
	layout.size = Vector2(4500, 3000)
	await wait_process_frames(8)
	assert_false(layout.get_control(&"total").visible)
	layout.use_keypad(false)
	await wait_process_frames(8)
	assert_true(layout.get_control(&"total").visible)
	assert_eq(layout.get_wager_draft(), "001000000")


func test_translated_composition_keeps_local_alignment_and_more_reachable_at_hand_completion(
) -> void:
	var layout: GuiWideTableLayout = _layout()
	layout.position = Vector2(31, 47)
	assert_true(layout.render(_model(9, &"showdown-long")))
	await wait_process_frames(10)
	layout.size = layout.get_combined_minimum_size() + Vector2(600, 100)
	await wait_process_frames(10)
	_assert_geometry(layout)
	var actions := layout.get_control(&"actions") as GuiActionBar
	var hero: Control = layout.get_control(&"hero")
	assert_almost_eq(actions.get_control(&"status").global_position.x, hero.global_position.x, 1.0)
	assert_gt(actions.global_position.y, hero.get_global_rect().end.y)
	assert_true(layout.get_control(&"more").is_visible_in_tree())
	assert_false((layout.get_control(&"more") as BaseButton).disabled)
	watch_signals(layout)
	(layout.get_control(&"more") as GuiActionButton)._pressed()
	assert_signal_emit_count(layout, "menu_requested", 1)
	(layout.get_control(&"continue") as GuiActionButton)._pressed()
	assert_signal_emitted_with_parameters(layout, "action_requested", [&"continue"])


func test_native_keyboard_activation_forwards_action_entry_and_menu_once() -> void:
	var layout: GuiWideTableLayout = _layout()
	assert_true(layout.render(_model(6)))
	layout.use_keypad(true)
	layout.set_wager_draft("001000000")
	await wait_process_frames(10)
	watch_signals(layout)
	for role: StringName in [&"fold", &"wager", &"more"]:
		layout.get_control(role).grab_focus()
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = pressed
			get_viewport().push_input(event)
			await get_tree().process_frame
	assert_signal_emit_count(layout, "action_requested", 1)
	assert_signal_emitted_with_parameters(layout, "action_requested", [&"fold"])
	assert_signal_emit_count(layout, "entry_requested", 1)
	assert_signal_emitted_with_parameters(layout, "entry_requested", ["001000000"])
	assert_signal_emit_count(layout, "menu_requested", 1)


func test_snapshot_detaches_binding_metadata_and_observes_hidden_history_truthfully() -> void:
	var layout: GuiWideTableLayout = _layout()
	var model: TableViewModel = _model(6)
	var legal: Array[int] = model.actions.legal_actions.duplicate()
	var model_ref: WeakRef = weakref(model)
	assert_true(layout.render(model))
	model.actions.legal_actions.clear()
	model.actions.action_roles.clear()
	model.seats[0].display_name = "Mutated caller"
	model = null
	assert_null(model_ref.get_ref())
	await wait_process_frames(10)
	layout.size = layout.get_combined_minimum_size()
	await wait_process_frames(8)
	var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(_root)
	assert_true(snapshot.ready)
	assert_eq(snapshot.schema_version, 2)
	assert_eq(snapshot.legal_actions, legal)
	assert_false(snapshot.actions.is_empty())
	assert_false(snapshot.elements[&"event"].visible)
	assert_eq(snapshot.menu_routes[&"event"], &"more")
	assert_eq(snapshot.menu_routes[&"quit"], &"more")
	assert_ne(snapshot.seats[0].fields[&"name"].text, "Mutated caller")
	var old_seat_count: int = snapshot.seats.size()
	assert_true(layout.render(_model(2)))
	await wait_process_frames(10)
	assert_eq(snapshot.seats.size(), old_seat_count)
	assert_eq(snapshot.legal_actions, legal)


func test_table_logo_reuses_embossed_asset_without_input_or_minimum_ownership() -> void:
	var layout: GuiWideTableLayout = _layout()
	assert_true(layout.render(_model(6)))
	await wait_process_frames(10)
	var logo := layout.get_control(&"logo") as TextureRect
	assert_not_null(logo)
	assert_eq(logo.scene_file_path, "res://scenes/gui/components/BrandLogo.tscn")
	assert_eq(logo.texture.resource_path, "res://resources/gui_logo_texture.tres")
	assert_eq(logo.material.resource_path, "res://resources/gui_table_logo_material.tres")
	assert_true((logo.material as ShaderMaterial).get_shader_parameter("embossed"))
	assert_eq(logo.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(logo.focus_mode, Control.FOCUS_NONE)
	assert_eq(logo.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	var minimum: Vector2 = layout.get_combined_minimum_size()
	logo.hide()
	await wait_process_frames(6)
	assert_eq(layout.get_combined_minimum_size(), minimum)
	logo.show()
	await wait_process_frames(6)
	assert_eq(layout.get_combined_minimum_size(), minimum)
	assert_true(layout.get_control(&"ring").get_global_rect().encloses(logo.get_global_rect()))
	assert_lt(logo.get_index(), layout.get_control(&"hero").get_index())


func test_invalid_model_and_allocation_fail_explicitly_then_recover() -> void:
	var layout: GuiWideTableLayout = _layout()
	assert_false(layout.render(null))
	assert_push_error_count(1)
	assert_false(layout.set_allocation_limit(Vector2(NAN, 4)))
	assert_push_error_count(2)
	assert_true(layout.render(_model(2)))
	await wait_process_frames(10)
	layout.size = layout.get_combined_minimum_size()
	await wait_process_frames(8)
	_assert_geometry(layout)
	var duplicate: TableViewModel = _model(2)
	duplicate.seats.append(duplicate.seats[0])
	assert_false(layout.render(duplicate))
	assert_push_error_count(3)
	await wait_process_frames(6)
	assert_false(layout.get_control(&"ring").visible)
	assert_true(layout.get_control(&"guidance").visible)
	assert_false(layout.get_layout_snapshot(_root).ready)


func _assert_geometry(layout: GuiWideTableLayout) -> void:
	assert_eq(Invariants.validate_snapshot(layout.get_layout_snapshot(_root)), PackedStringArray())
	var ring := layout.get_control(&"ring") as GuiSeatRingContainer
	var plan: GuiSeatRingPlan = ring.get_layout_plan()
	assert_true(plan.feasible)
	for id: int in layout.get_seat_controls():
		var seat := layout.get_seat_controls()[id] as GuiSeatPanel
		var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(_root)
		assert_true(ring.get_global_rect().encloses(snapshot.footprint))
		for element: GuiLayoutElement in snapshot.fields.values():
			var failures := PackedStringArray()
			Invariants.validate_element(element, failures)
			assert_eq(failures, PackedStringArray(), "%s" % element.role)
		assert_true(snapshot.panel.rect.encloses(snapshot.cards[0].element.rect))
		assert_true(snapshot.panel.rect.encloses(snapshot.cards[1].element.rect))
	assert_true(layout.get_global_rect().encloses(ring.get_global_rect()))


func _layout(
	density: GuiFitCandidate.Density = GuiFitCandidate.Density.COMPACT
) -> GuiWideTableLayout:
	var layout: GuiWideTableLayout = WideScene.instantiate()
	layout.theme = GuiTypography.for_density(density)
	_root.add_child(layout)
	layout.size = Vector2(3000, 2500)
	return layout


func _model(
	count: int,
	state: StringName = &"human-turn-flop",
	density: GuiFitCandidate.Density = GuiFitCandidate.Density.COMPACT
) -> TableViewModel:
	var fixture: Dictionary = GuiVisualStateFixtures.by_id(state, 9)
	var view: GameView = fixture.view
	var names: Dictionary[int, String] = {}
	var avatars: Dictionary[int, String] = {}
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	for index: int in count:
		names[index] = "Emiliano" if index > 0 else "Human"
		avatars[index] = paths[index]
	var latest: Dictionary[int, PublicActionRecord] = {}
	for action: PublicActionRecord in view.action_history:
		latest[action.seat] = action
	var model: TableViewModel = TableViewModel.build(view, names, avatars, latest, {}, [], density)
	model.seats.resize(count)
	return model
