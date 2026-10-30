extends GutTest

const Host := preload("res://scenes/gui/CompositionHost.tscn")
const Phone := preload("res://tests/fixtures/gui_compositions/phone.tscn")
const Wide := preload("res://tests/fixtures/gui_compositions/wide.tscn")
const MODE := GuiSizeClass.LayoutMode


func test_snapshot_diagnostic_profiles_map_modes_without_geometry_classification() -> void:
	assert_eq(
		GuiSnapshotMeasurement.profile_for_mode(MODE.PHONE),
		GuiLayoutSnapshot.Profile.PHONE_PORTRAIT
	)
	assert_eq(
		GuiSnapshotMeasurement.profile_for_mode(MODE.PHONE_LANDSCAPE),
		GuiLayoutSnapshot.Profile.PHONE_LANDSCAPE
	)
	assert_eq(
		GuiSnapshotMeasurement.profile_for_mode(MODE.WIDE_COMPACT),
		GuiLayoutSnapshot.Profile.SMALL_DESKTOP
	)
	assert_eq(GuiSnapshotMeasurement.profile_for_mode(MODE.WIDE), GuiLayoutSnapshot.Profile.DESKTOP)
	assert_eq(GuiSnapshotMeasurement.profile_for_mode(MODE.NOT_READY), -1)


func test_selected_fit_routes_independent_phone_orientations_and_nine_player_wide() -> void:
	var host: GuiCompositionHost = _host()
	for fixture: Dictionary in [
		{"size": Vector2(390, 844), "mode": MODE.PHONE, "count": 7},
		{"size": Vector2(844, 390), "mode": MODE.PHONE_LANDSCAPE, "count": 7},
		{"size": Vector2(1280, 900), "mode": MODE.WIDE, "count": 9},
	]:
		var result: GuiCompositionState = host.present(
			GuiViewportGeometry.injected(fixture.size),
			_ids(fixture.count),
			0,
			[_candidate(fixture.mode, fixture.count)]
		)
		await wait_process_frames(4)
		assert_eq(result.status, GuiCompositionState.Status.READY)
		assert_same(host.get_composition().policy, result)
		assert_eq(result.seats.clockwise_ids.size(), fixture.count)
		assert_true(host.get_composition().visible)
		assert_eq(
			host.get_composition().name, "WideFixture" if fixture.count == 9 else "PhoneFixture"
		)


func test_fallback_uses_selected_mode_not_preferred_class() -> void:
	var host: GuiCompositionHost = _host()
	var candidate: GuiFitCandidate = _candidate(MODE.PHONE, 7)
	var result: GuiCompositionState = host.present(
		GuiViewportGeometry.injected(Vector2(650, 900)), _ids(7), 0, [candidate]
	)
	assert_eq(result.fit.size_class.mode, MODE.WIDE_COMPACT)
	assert_eq(result.mode, MODE.PHONE)
	assert_eq(host.get_composition().name, "PhoneFixture")
	assert_same(host.get_composition().policy, result)


func test_same_mode_reuses_scene_and_applies_origin_once_with_new_density_and_flow() -> void:
	var host: GuiCompositionHost = _host()
	var candidate: GuiFitCandidate = _candidate(MODE.PHONE, 7)
	var geometry: GuiViewportGeometry = GuiViewportGeometry.injected(
		Vector2(600, 1000), Rect2(17, 23, 390, 844)
	)
	var first: GuiCompositionState = host.present(geometry, _ids(7), 0, [candidate])
	var composition: GuiTableComposition = host.get_composition()
	await wait_process_frames(4)
	assert_eq(composition.position, Vector2.ZERO)
	assert_eq(composition.get_global_rect(), Rect2(17, 23, 390, 844))
	var next: GuiFitCandidate = _candidate(
		MODE.PHONE, 7, GuiFitCandidate.Density.MINIMAL, GuiFitCandidate.ActionFlow.KEYPAD
	)
	var second: GuiCompositionState = host.present(geometry, _ids(7), 0, [next])
	await wait_process_frames(4)
	assert_same(host.get_composition(), composition)
	assert_same(composition.policy, second)
	assert_ne(first, second)
	assert_eq(second.density, GuiFitCandidate.Density.MINIMAL)
	assert_eq(second.action_flow, GuiFitCandidate.ActionFlow.KEYPAD)
	assert_eq(composition.get_global_rect(), Rect2(17, 23, 390, 844))
	assert_eq(composition.get_node("Column/PolicyLabel").text, "MINIMAL · KEYPAD")


func test_mode_switch_removes_previous_scene_and_retains_core_ids_for_each_recipient() -> void:
	var host: GuiCompositionHost = _host()
	var ids := PackedInt32Array([3, 8, 11, 16, 21, 29, 40])
	for recipient: int in ids:
		var old: GuiTableComposition = null
		for fixture: Dictionary in [
			{"size": Vector2(390, 844), "mode": MODE.PHONE},
			{"size": Vector2(844, 390), "mode": MODE.PHONE_LANDSCAPE},
			{"size": Vector2(1280, 900), "mode": MODE.WIDE},
		]:
			var candidate: GuiFitCandidate = GuiFitCandidate.measure(
				fixture.mode, _metrics(), ids, recipient
			)
			var result: GuiCompositionState = host.present(
				GuiViewportGeometry.injected(fixture.size), ids, recipient, [candidate]
			)
			assert_eq(result.status, GuiCompositionState.Status.READY)
			assert_eq(result.seats.rows[-1], PackedInt32Array([recipient]))
			if old != null:
				assert_true(old.is_queued_for_deletion())
				assert_null(old.get_parent())
			old = host.get_composition()
		await wait_process_frames(2)


func test_unsupported_and_missing_registrations_have_distinct_states() -> void:
	var host: GuiCompositionHost = _host()
	var phone: GuiFitCandidate = _candidate(MODE.PHONE, 7)
	var geometry: GuiViewportGeometry = GuiViewportGeometry.injected(Vector2(390, 844))
	assert_eq(host.present(null, _ids(7), 0, []).fit.status, GuiFitPolicy.Status.NOT_READY)
	assert_eq(
		host.present(geometry, _ids(7), 0, []).fit.status, GuiFitPolicy.Status.NEEDS_MEASUREMENTS
	)
	assert_eq(host.present(geometry, _ids(9), 0, []).fit.status, GuiFitPolicy.Status.PHONE_CAPACITY)
	host.register_composition(MODE.PHONE, null)
	assert_eq(
		host.present(geometry, _ids(7), 0, [phone]).status, GuiCompositionState.Status.UNREGISTERED
	)
	var invalid := PackedScene.new()
	var node := Control.new()
	assert_eq(invalid.pack(node), OK)
	node.free()
	host.register_composition(MODE.PHONE, invalid)
	assert_eq(
		host.present(geometry, _ids(7), 0, [phone]).status,
		GuiCompositionState.Status.INVALID_COMPOSITION
	)
	assert_null(host.get_composition())
	assert_false(host.register_composition(MODE.NOT_READY, Phone))


func test_actual_minimum_invalidation_hides_content_and_recovers_without_clipping() -> void:
	var host: GuiCompositionHost = _host()
	var geometry: GuiViewportGeometry = GuiViewportGeometry.injected(Vector2(390, 844))
	var candidate: GuiFitCandidate = _candidate(MODE.PHONE, 7)
	host.present(geometry, _ids(7), 0, [candidate])
	var composition: GuiTableComposition = host.get_composition()
	watch_signals(host)
	composition.custom_minimum_size.x = 500
	await wait_process_frames(5)
	assert_eq(host.state.status, GuiCompositionState.Status.CONTENT_MINIMUM)
	assert_same(composition.policy, host.state)
	assert_signal_emitted(host, "measurements_invalidated")
	assert_false(composition.visible)
	assert_eq(host.get_node("LayoutSlot").size, Vector2(390, 844))
	composition.custom_minimum_size.x = 0
	host.present(geometry, _ids(7), 0, [candidate])
	await wait_process_frames(4)
	assert_eq(host.state.status, GuiCompositionState.Status.READY)
	assert_same(host.get_composition(), composition)
	assert_eq(composition.get_global_rect(), Rect2(0, 0, 390, 844))


func test_empty_scene_fails_without_exposing_old_content_and_can_recover() -> void:
	var host: GuiCompositionHost = _host()
	var geometry: GuiViewportGeometry = GuiViewportGeometry.injected(Vector2(390, 844))
	var candidate: GuiFitCandidate = _candidate(MODE.PHONE, 7)
	host.present(geometry, _ids(7), 0, [candidate])
	var original: GuiTableComposition = host.get_composition()
	host.register_composition(MODE.PHONE, PackedScene.new())
	assert_eq(
		host.present(geometry, _ids(7), 0, [candidate]).status,
		GuiCompositionState.Status.INVALID_COMPOSITION
	)
	assert_false(original.visible)
	host.register_composition(MODE.PHONE, Phone)
	assert_eq(
		host.present(geometry, _ids(7), 0, [candidate]).status, GuiCompositionState.Status.READY
	)
	assert_same(host.get_composition(), original)


func _host() -> GuiCompositionHost:
	var host: GuiCompositionHost = Host.instantiate()
	add_child_autofree(host)
	host.register_composition(MODE.PHONE, Phone)
	host.register_composition(MODE.PHONE_LANDSCAPE, Phone)
	host.register_composition(MODE.WIDE_COMPACT, Wide)
	host.register_composition(MODE.WIDE, Wide)
	return host


func _metrics() -> GuiFitMetrics:
	var result := GuiFitMetrics.new()
	result.opponent = Vector2(160, 84)
	result.board = Vector2(280, 84)
	result.hero = Vector2(180, 96)
	result.actions = Vector2(280, 104)
	result.event_log = Vector2(220, 104)
	result.gap = 4
	result.evidence = &"primitive_fixture"
	return result


func _candidate(
	mode: int,
	count: int,
	density: GuiFitCandidate.Density = GuiFitCandidate.Density.COMPACT,
	flow: GuiFitCandidate.ActionFlow = GuiFitCandidate.ActionFlow.TWO_ROWS
) -> GuiFitCandidate:
	return GuiFitCandidate.measure(mode, _metrics(), _ids(count), 0, density, flow)


func _ids(count: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for id: int in count:
		ids.append(id)
	return ids
