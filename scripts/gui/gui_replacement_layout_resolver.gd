class_name GuiReplacementLayoutResolver
extends RefCounted

# Owns layout requests, measurement caches, probe lifetime and resolution counters.
var _root: GuiReplacementTableController
var _session: GuiTableSession
var _input: GuiReplacementInputState
var _host: GuiCompositionHost
var _overlay: GuiOverlayHost
var _model_for_density: Callable
var _connect_composition: Callable
var _fallback_control: Callable
var _update_guidance: Callable
var _settled: Callable
var _geometry: GuiViewportGeometry
var _bound: bool = false
var _keypad: bool = false
var _mode_override: int = GuiSizeClass.AUTOMATIC
var _model_generation: int = 0
var _layout_generation: int = 0
var _mounts: int = 0
var _probes: int = 0
var _active_probes: int = 0
var _peak_probes: int = 0
var _candidates: Array[GuiFitCandidate] = []
var _candidate_generation: int = -1
var _complete_candidates: bool = false
var _resolution_epoch: int = 0
var _requested: bool = false
var _scheduled: bool = false
var _resolving: bool = false
var _restore_focus_after_layout: bool = false


func _init(
	root: GuiReplacementTableController, session: GuiTableSession, input: GuiReplacementInputState
) -> void:
	_root = root
	_session = session
	_input = input


func configure(
	host: GuiCompositionHost,
	overlay: GuiOverlayHost,
	model_for_density: Callable,
	connect_composition: Callable,
	fallback_control: Callable,
	update_guidance: Callable,
	settled: Callable
) -> void:
	_host = host
	_overlay = overlay
	_model_for_density = model_for_density
	_connect_composition = connect_composition
	_fallback_control = fallback_control
	_update_guidance = update_guidance
	_settled = settled


func set_bound(bound: bool) -> void:
	_bound = bound
	if not bound:
		_requested = false
		_resolution_epoch += 1


func set_geometry(geometry: GuiViewportGeometry) -> void:
	_geometry = geometry


func get_geometry() -> GuiViewportGeometry:
	return _geometry


func set_keypad(keypad: bool) -> void:
	_keypad = keypad
	_candidate_generation = -1


func set_mode_override(mode: int) -> void:
	_mode_override = mode


func invalidate_model() -> void:
	_model_generation += 1
	_candidate_generation = -1


func prepare_binding() -> void:
	_restore_focus_after_layout = false
	_resolution_epoch += 1


func teardown() -> void:
	_bound = false
	_model_generation += 1
	_resolution_epoch += 1
	_requested = false
	_candidates.clear()
	_candidate_generation = -1


func request_resolution() -> void:
	_resolution_epoch += 1
	_requested = true
	if (
		_root.is_inside_tree()
		and _root.is_node_ready()
		and _bound
		and not _resolving
		and not _scheduled
	):
		_scheduled = true
		call_deferred("_resolve_layout")


func get_render_counters() -> Dictionary:
	return {
		"mounts": _mounts,
		"probes": _probes,
		"active_probes": _active_probes,
		"peak_probes": _peak_probes,
		"model_generation": _model_generation,
		"layout_generation": _layout_generation
	}


func get_layout_generation() -> int:
	return _layout_generation


func _end_resolution() -> void:
	_resolving = false
	if _requested and _bound and _root.is_inside_tree():
		if not _scheduled:
			_scheduled = true
			call_deferred("_resolve_layout")
	elif _settled.is_valid():
		_settled.call()


func _model_ids(model: TableViewModel) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for seat: SeatViewModel in model.seats:
		ids.append(seat.seat)
	ids.sort()
	return ids


func _action_flow() -> GuiFitCandidate.ActionFlow:
	return GuiFitCandidate.ActionFlow.KEYPAD if _keypad else GuiFitCandidate.ActionFlow.TWO_ROWS


func _resolve_layout() -> void:
	_scheduled = false
	if not _bound or not _root.is_inside_tree():
		return
	_resolving = true
	_requested = false
	var epoch: int = _resolution_epoch
	if _geometry == null:
		_geometry = GuiViewportGeometry.injected(_root.size)
	if not _geometry.valid:
		_end_resolution()
		return
	var model: TableViewModel = _root.get_table_view_model()
	var ids: PackedInt32Array = _model_ids(model)
	var preference: GuiFitPolicy = GuiFitPolicy.resolve(
		_geometry, ids, model.hero_seat, [], _mode_override
	)
	if _candidate_generation != _model_generation:
		var generation: int = _model_generation
		var active: GuiTableComposition = _root.get_composition()
		var active_state: GuiCompositionState = _host.state
		var active_candidate: GuiFitCandidate
		if (
			active != null
			and active_state != null
			and active_state.mode == preference.size_class.mode
		):
			for frame: int in 12:
				await _root.frame_tick
				if not _root.is_inside_tree() or generation != _model_generation or not _bound:
					break
				if not active.get_layout_snapshot(_root).pending:
					active_candidate = active.get_fit_candidate(
						active_state.mode, active_state.density, _action_flow()
					)
					break
		if (
			generation == _model_generation
			and active_candidate != null
			and active_candidate.valid
			and _contains(_geometry.usable_rect.size, active_candidate.minimum)
		):
			_candidates = [active_candidate]
			_candidate_generation = generation
			_complete_candidates = false
	if _candidate_generation == _model_generation and not _complete_candidates:
		var known: GuiFitPolicy = GuiFitPolicy.resolve(
			_geometry, ids, model.hero_seat, _candidates, _mode_override
		)
		if (
			known.status != GuiFitPolicy.Status.FIT
			or known.selected.mode != preference.size_class.mode
		):
			_candidate_generation = -1
	if _candidate_generation != _model_generation:
		var generation: int = _model_generation
		var modality: bool = _keypad
		var measured: Array[GuiFitCandidate] = await _measure_candidates(generation)
		if not _root.is_inside_tree() or not _bound:
			_end_resolution()
			return
		if generation == _model_generation and modality == _keypad:
			_candidates = measured
			_candidate_generation = generation
			_complete_candidates = true
	if epoch != _resolution_epoch:
		_end_resolution()
		return
	var previous: GuiTableComposition = _root.get_composition()
	var previous_mode: int = (
		_host.state.mode if _host.state != null else GuiSizeClass.LayoutMode.NOT_READY
	)
	var previous_density: int = _host.state.density if _host.state != null else -1
	_input.remember(previous, _overlay.is_active())
	var policy: GuiFitPolicy = GuiFitPolicy.resolve(
		_geometry, ids, model.hero_seat, _candidates, _mode_override
	)
	if previous != null and (policy.selected == null or previous_mode != policy.selected.mode):
		_restore_focus_after_layout = (
			_restore_focus_after_layout or _overlay.get_keypad().is_active()
		)
		_overlay.on_layout_mode_changed()
	var state: GuiCompositionState = _host.present(
		_geometry, ids, model.hero_seat, _candidates, _mode_override
	)
	var composition: GuiTableComposition = _root.get_composition()
	if state.status == GuiCompositionState.Status.READY and composition != null:
		if composition != previous:
			_mounts += 1
			_connect_composition.call(composition)
		var selected_model: TableViewModel = _model_for_density.call(state.density)
		if (
			composition != previous
			or previous_mode != state.mode
			or previous_density != state.density
		):
			composition.use_keypad(_keypad)
			composition.render(selected_model)
			composition.set_wager_draft(_root.get_wager_draft())
		_host.show()
		for frame: int in 12:
			await _root.frame_tick
			if epoch != _resolution_epoch or not _root.is_inside_tree():
				_end_resolution()
				return
			var observed: GuiLayoutSnapshot = composition.get_layout_snapshot(_root)
			if not observed.pending and observed.ready:
				break
	else:
		_host.show()
	if composition != previous:
		_input.restore(composition, _overlay.is_active())
	_update_guidance.call()
	var fallback: Control = _fallback_control.call()
	_overlay.set_fallback_focus(fallback)
	_overlay.set_usable_rect(_geometry.usable_rect)
	if (
		_restore_focus_after_layout
		and not _overlay.is_active()
		and is_instance_valid(fallback)
		and fallback.is_visible_in_tree()
	):
		fallback.grab_focus()
		_restore_focus_after_layout = false
	_layout_generation += 1
	_end_resolution()


func _measure_candidates(generation: int) -> Array[GuiFitCandidate]:
	var modality: bool = _keypad
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Non-presentational workspace: every success or stale-generation path frees it.
	# The child viewport also dies with the controller if a pending probe is interrupted.
	viewport.size = Vector2i(4096, 4096)
	_root.add_child(viewport)
	var layer := Control.new()
	layer.theme = _root.theme
	layer.size = Vector2(viewport.size)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(layer)
	var probes: Array[GuiTableComposition] = []
	var modes: Array[GuiSizeClass.LayoutMode] = []
	var densities: Array[GuiFitCandidate.Density] = []
	for density: GuiFitCandidate.Density in [
		GuiFitCandidate.Density.FULL, GuiFitCandidate.Density.COMPACT
	]:
		for mode: GuiSizeClass.LayoutMode in [
			GuiSizeClass.LayoutMode.WIDE,
			GuiSizeClass.LayoutMode.PHONE,
			GuiSizeClass.LayoutMode.PHONE_LANDSCAPE
		]:
			if mode != GuiSizeClass.LayoutMode.WIDE and _session.get_view().seats.size() > 7:
				continue
			var scene: PackedScene = (
				_root.WideScene
				if mode == GuiSizeClass.LayoutMode.WIDE
				else (
					_root.PhoneScene
					if mode == GuiSizeClass.LayoutMode.PHONE
					else _root.LandscapeScene
				)
			)
			var probe: GuiTableComposition = scene.instantiate()
			probe.theme = GuiTypography.for_density(density)
			layer.add_child(probe)
			probe.size = Vector2(viewport.size)
			probe.use_keypad(modality)
			probe.render(_model_for_density.call(density))
			probes.append(probe)
			modes.append(mode)
			densities.append(density)
			_probes += 1
			_active_probes += 1
			_peak_probes = maxi(_peak_probes, _active_probes)
	for frame: int in 10:
		await _root.frame_tick
		if (
			not _root.is_inside_tree()
			or generation != _model_generation
			or modality != _keypad
			or not _bound
		):
			_discard_probes(viewport, probes.size())
			return []
	var values: Array[GuiFitCandidate] = []
	var flow: GuiFitCandidate.ActionFlow = (
		GuiFitCandidate.ActionFlow.KEYPAD if modality else GuiFitCandidate.ActionFlow.TWO_ROWS
	)
	for index: int in probes.size():
		var candidate: GuiFitCandidate = probes[index].get_fit_candidate(
			modes[index], densities[index], flow
		)
		if candidate.valid:
			values.append(candidate)
		if modes[index] == GuiSizeClass.LayoutMode.WIDE:
			values.append(
				probes[index].get_fit_candidate(
					GuiSizeClass.LayoutMode.WIDE_COMPACT, densities[index], flow
				)
			)
		elif candidate.valid:
			(probes[index] as GuiPhoneTableLayout).set_allocation_limit(
				Vector2(candidate.minimum.x - 1.0, viewport.size.y)
			)
	for frame: int in 6:
		await _root.frame_tick
		if (
			not _root.is_inside_tree()
			or generation != _model_generation
			or modality != _keypad
			or not _bound
		):
			_discard_probes(viewport, probes.size())
			return []
	for index: int in probes.size():
		if modes[index] == GuiSizeClass.LayoutMode.WIDE:
			continue
		var alternate: GuiFitCandidate = probes[index].get_fit_candidate(
			modes[index], densities[index], flow
		)
		if alternate.valid:
			values.append(alternate)
	_discard_probes(viewport, probes.size())
	return values


func _discard_probes(viewport: SubViewport, count: int) -> void:
	_active_probes -= count
	if is_instance_valid(viewport):
		viewport.free()


func _contains(available: Vector2, minimum: Vector2) -> bool:
	return available.x >= minimum.x and available.y >= minimum.y
