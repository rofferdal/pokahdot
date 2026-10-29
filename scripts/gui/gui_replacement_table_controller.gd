# gdlint: disable=max-public-methods
class_name GuiReplacementTableController
extends Control
# Public startup, diagnostic and profiling boundaries share this scene adapter.

## Replacement orchestration: session and overlays outlive measured compositions.
signal tournament_quit_confirmed
signal return_to_startup_requested
signal frame_tick
const WideScene := preload("res://scenes/gui/layouts/WideTableLayout.tscn")
const PhoneScene := preload("res://scenes/gui/layouts/PhoneTableLayout.tscn")
const LandscapeScene := preload("res://scenes/gui/layouts/PhoneLandscapeLayout.tscn")
@export var action_timing_config: Resource
@export var touch_entry: bool = false
var _session := GuiTableSession.new()
var _geometry: GuiViewportGeometry
var _geometry_pending: bool = false
var _bound: bool = false
var _pending: bool = false
var _draft: String = ""
var _model_generation: int = 0
var _layout_generation: int = 0
var _mounts: int = 0
var _probes: int = 0
var _active_probes: int = 0
var _peak_probes: int = 0
var _mode_override: int = GuiSizeClass.AUTOMATIC
var _keypad: bool = false
var _models: Dictionary[int, TableViewModel] = {}
var _candidates: Array[GuiFitCandidate] = []
var _candidate_generation: int = -1
var _complete_candidates: bool = false
var _resolution_epoch: int = 0
var _requested: bool = false
var _scheduled: bool = false
var _resolving: bool = false
var _connected_composition: GuiTableComposition
var _pending_advance: Callable
var _detail_seat: int = -1
var _detail_authorization: Array[bool] = []
var _draft_initialized: bool = false
var _ever_visible: bool = false
var _restore_focus_after_layout: bool = false
var _input_caret: int = -1
var _input_selection := Vector2i(-1, -1)
var _focus_intent: StringName = &""


func _ready() -> void:
	_keypad = touch_entry or DisplayServer.is_touchscreen_available()
	_session.configure(get_tree(), action_timing_config, _hold_advance, _input_blocked)
	_session.changed.connect(_on_session_changed)
	resized.connect(_request_resolution)
	visibility_changed.connect(_on_visibility_changed)
	_ever_visible = is_visible_in_tree()
	for mode: GuiSizeClass.LayoutMode in [
		GuiSizeClass.LayoutMode.WIDE_COMPACT, GuiSizeClass.LayoutMode.WIDE
	]:
		_host().register_composition(mode, WideScene)
	_host().register_composition(GuiSizeClass.LayoutMode.PHONE, PhoneScene)
	_host().register_composition(GuiSizeClass.LayoutMode.PHONE_LANDSCAPE, LandscapeScene)
	_host().measurements_invalidated.connect(_request_resolution)
	_overlay().number_committed.connect(_on_number_committed)
	_overlay().quit_confirmed.connect(_on_quit_confirmed)
	(get_node("GuidanceRail/Row/More") as Button).pressed.connect(open_menu)
	if _bound:
		_on_session_changed()


func uses_full_viewport_root() -> bool:
	return true


func bind_match(
	match_instance: TournamentMatch,
	recipient: int,
	avatars: Dictionary[int, String],
	names: Dictionary[int, String] = {}
) -> bool:
	_prepare_binding()
	_bound = true
	_draft = ""
	_draft_initialized = false
	var accepted: bool = _session.bind_match(match_instance, recipient, avatars, names)
	_bound = accepted
	if not accepted:
		_pending = false
		_requested = false
		_pending_advance = Callable()
		_resolution_epoch += 1
		if is_node_ready():
			_host().hide()
	return accepted


func bind_view(
	view: GameView,
	avatars: Dictionary[int, String],
	names: Dictionary[int, String] = {},
	event_lines: Array[String] = []
) -> bool:
	_prepare_binding()
	_bound = true
	_draft = ""
	_draft_initialized = false
	var accepted: bool = _session.bind_view(view, avatars, names, event_lines)
	_bound = accepted
	if not accepted:
		_pending = false
		_requested = false
		_pending_advance = Callable()
		_resolution_epoch += 1
		if is_node_ready():
			_host().hide()
	return accepted


func refresh_from_match() -> bool:
	return _session.refresh()


func submit_intent(intent: StringName, raw_draft: String = "") -> StepResult:
	if _input_blocked():
		return StepResult.new(
			StepResult.Status.ERROR,
			"Actions are unavailable while the table is settling or a dialog is open."
		)
	return _session.submit_intent(intent, _draft if raw_draft.is_empty() else raw_draft)


func advance_one_action() -> StepResult:
	return _session.advance_one_action()


func get_table_view_model() -> TableViewModel:
	var density: GuiFitCandidate.Density = (
		_host().state.density
		if is_node_ready() and _host().state != null
		else GuiFitCandidate.Density.FULL
	)
	if not _models.has(density):
		_models[density] = _session.get_model(density)
	return _models[density]


func get_composition() -> GuiTableComposition:
	return _host().get_composition() if is_node_ready() else null


func get_render_counters() -> Dictionary:
	return {
		"mounts": _mounts,
		"probes": _probes,
		"active_probes": _active_probes,
		"peak_probes": _peak_probes,
		"model_generation": _model_generation,
		"layout_generation": _layout_generation
	}


func get_layout_snapshot() -> GuiLayoutSnapshot:
	if not is_node_ready() or not _bound:
		return GuiLayoutSnapshot.new()
	var composition: GuiTableComposition = get_composition()
	var state: GuiCompositionState = _host().state
	var full_fit: bool = (
		composition != null and state != null and state.status == GuiCompositionState.Status.READY
	)
	var snapshot: GuiLayoutSnapshot = (
		composition.get_layout_snapshot(self) if full_fit else _guidance_snapshot()
	)
	snapshot.pending = snapshot.pending or _pending or _geometry_pending
	snapshot.ready = snapshot.ready and not snapshot.pending
	snapshot.generation = _layout_generation
	if _geometry != null and _geometry.valid:
		snapshot.root_rect = _geometry.full_rect
		snapshot.viewport_rect = _geometry.full_rect
		snapshot.usable_rect = _geometry.usable_rect
	_capture_overlay(snapshot)
	return snapshot


func set_viewport_geometry(
	geometry: GuiViewportGeometry, _to_viewport: Transform2D = Transform2D.IDENTITY
) -> void:
	_geometry = geometry
	if geometry != null and geometry.valid:
		size = geometry.full_rect.size
		if is_node_ready():
			_overlay().set_usable_rect(geometry.usable_rect)
	_request_resolution()


func set_viewport_geometry_pending(pending: bool) -> void:
	_geometry_pending = pending


func set_layout_profile_override(profile: int) -> void:
	# Compatibility fixture boundary: diagnostic profile IDs do not classify UI.
	var modes: Dictionary[int, int] = {
		0: GuiSizeClass.LayoutMode.PHONE,
		1: GuiSizeClass.LayoutMode.PHONE_LANDSCAPE,
		2: GuiSizeClass.LayoutMode.WIDE_COMPACT,
		3: GuiSizeClass.LayoutMode.WIDE_COMPACT,
		4: GuiSizeClass.LayoutMode.WIDE
	}
	set_layout_mode_override(modes.get(profile, GuiSizeClass.AUTOMATIC))


func get_layout_profile() -> int:
	return (
		GuiSnapshotMeasurement.profile_for_mode(_host().state.mode)
		if is_node_ready() and _host().state != null
		else -1
	)


func set_action_timing_config(timing: Resource) -> void:
	action_timing_config = timing
	if is_node_ready():
		_session.configure(get_tree(), timing, _hold_advance, _input_blocked)


func use_keypad(enabled: bool) -> void:
	_keypad = enabled
	_candidate_generation = -1
	if is_node_ready():
		if get_composition() != null:
			get_composition().use_keypad(enabled)
		_overlay().on_layout_mode_changed()
	_request_resolution()


func open_menu() -> void:
	if _bound and is_node_ready():
		_overlay().set_fallback_focus(_fallback_control())
		_overlay().open_menu()


func teardown() -> void:
	_bound = false
	_model_generation += 1
	_resolution_epoch += 1
	_session.stop()
	_requested = false
	_pending = false
	_pending_advance = Callable()
	_models.clear()
	_candidates.clear()
	_candidate_generation = -1
	if is_node_ready():
		_overlay().cancel_advance()
		_overlay().close()
		_host().hide()


func _on_session_changed() -> void:
	_model_generation += 1
	_models.clear()
	_candidate_generation = -1
	if is_node_ready() and _bound:
		_pending = true
		_refresh_model()
		_request_resolution()


func _refresh_model() -> void:
	var model: TableViewModel = get_table_view_model()
	if not model.valid:
		return
	if not _draft_initialized:
		_draft = str(model.actions.minimum_total) if model.actions.can_wager else ""
		_draft_initialized = true
	var composition: GuiTableComposition = get_composition()
	if composition != null:
		composition.render(model)
		composition.set_wager_draft(_draft)
	_overlay().render_log(model.history)
	_overlay().render_summary(model.summary)
	var view: GameView = _session.get_view()
	var finished: bool = view != null and view.tournament_status == &"finished"
	_overlay().set_quit_confirmation_required(not finished)
	(_overlay().get_control(&"menu_quit") as Button).text = (
		"Return to Start" if finished else "Quit"
	)
	if _overlay().get_active_kind() == &"seat" and model.seat_for(_detail_seat) != null:
		_render_detail(model.seat_for(_detail_seat))


func _hold_advance(callback: Callable) -> bool:
	if is_node_ready() and _overlay().hold_advance(callback):
		return true
	if _pending:
		_pending_advance = callback
		return true
	return false


func _input_blocked() -> bool:
	return (
		not _bound
		or _pending
		or _geometry_pending
		or (
			is_node_ready()
			and (
				_overlay().is_active()
				or _host().state == null
				or _host().state.status != GuiCompositionState.Status.READY
			)
		)
	)


func _request_resolution() -> void:
	_resolution_epoch += 1
	_requested = true
	_pending = _bound
	if is_inside_tree() and is_node_ready() and _bound and not _resolving and not _scheduled:
		_scheduled = true
		call_deferred("_resolve_layout")


func _on_number_committed(value: String) -> void:
	_draft = value
	_draft_initialized = true
	if get_composition() != null:
		get_composition().set_wager_draft(value)
	submit_intent(&"wager", value)


func _on_quit_confirmed() -> void:
	var view: GameView = _session.get_view()
	if view != null and view.tournament_status == &"finished":
		teardown()
		return_to_startup_requested.emit()
	else:
		_session.request_quit()
		teardown()
		tournament_quit_confirmed.emit()


func _host() -> GuiCompositionHost:
	return get_node("CompositionHost") as GuiCompositionHost


func _overlay() -> GuiOverlayHost:
	return get_node("OverlayHost") as GuiOverlayHost


func _exit_tree() -> void:
	teardown()


func set_layout_mode_override(mode: int) -> void:
	_mode_override = (
		mode
		if mode >= GuiSizeClass.LayoutMode.PHONE and mode <= GuiSizeClass.LayoutMode.WIDE
		else GuiSizeClass.AUTOMATIC
	)
	_request_resolution()


func get_overlay_host() -> GuiOverlayHost:
	return _overlay()


func is_action_advance_pending() -> bool:
	return _session.is_advance_pending() or _pending_advance.is_valid()


func set_wager_draft(text: String) -> void:
	_draft = text
	_draft_initialized = true
	if get_composition() != null:
		get_composition().set_wager_draft(text)


func get_wager_draft() -> String:
	return _draft


func _resolve_layout() -> void:
	_scheduled = false
	if not _bound or not is_inside_tree():
		return
	_resolving = true
	_requested = false
	var epoch: int = _resolution_epoch
	if _geometry == null:
		_geometry = GuiViewportGeometry.injected(size)
	if not _geometry.valid:
		_end_resolution()
		return
	var model: TableViewModel = get_table_view_model()
	var ids: PackedInt32Array = _model_ids(model)
	var preference: GuiFitPolicy = GuiFitPolicy.resolve(
		_geometry, ids, model.hero_seat, [], _mode_override
	)
	if _candidate_generation != _model_generation:
		var generation: int = _model_generation
		var active: GuiTableComposition = get_composition()
		var active_state: GuiCompositionState = _host().state
		var active_candidate: GuiFitCandidate
		if (
			active != null
			and active_state != null
			and active_state.mode == preference.size_class.mode
		):
			for frame: int in 12:
				await frame_tick
				if not is_inside_tree() or generation != _model_generation or not _bound:
					break
				if not active.get_layout_snapshot(self).pending:
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
		if not is_inside_tree() or not _bound:
			_end_resolution()
			return
		if generation == _model_generation and modality == _keypad:
			_candidates = measured
			_candidate_generation = generation
			_complete_candidates = true
	if epoch != _resolution_epoch:
		_end_resolution()
		return
	var previous: GuiTableComposition = get_composition()
	var previous_mode: int = (
		_host().state.mode if _host().state != null else GuiSizeClass.LayoutMode.NOT_READY
	)
	var previous_density: int = _host().state.density if _host().state != null else -1
	_remember_input_state(previous)
	var policy: GuiFitPolicy = GuiFitPolicy.resolve(
		_geometry, ids, model.hero_seat, _candidates, _mode_override
	)
	if previous != null and (policy.selected == null or previous_mode != policy.selected.mode):
		_restore_focus_after_layout = (
			_restore_focus_after_layout or _overlay().get_keypad().is_active()
		)
		_overlay().on_layout_mode_changed()
	var state: GuiCompositionState = _host().present(
		_geometry, ids, model.hero_seat, _candidates, _mode_override
	)
	var composition: GuiTableComposition = get_composition()
	if state.status == GuiCompositionState.Status.READY and composition != null:
		if composition != previous:
			_mounts += 1
			_connect_composition(composition)
		var selected_model: TableViewModel = _model_for_density(state.density)
		if (
			composition != previous
			or previous_mode != state.mode
			or previous_density != state.density
		):
			composition.use_keypad(_keypad)
			composition.render(selected_model)
			composition.set_wager_draft(_draft)
		_host().show()
		for frame: int in 12:
			await frame_tick
			if epoch != _resolution_epoch or not is_inside_tree():
				_end_resolution()
				return
			var observed: GuiLayoutSnapshot = composition.get_layout_snapshot(self)
			if not observed.pending and observed.ready:
				break
	else:
		_host().show()
	if composition != previous:
		_restore_input_state(composition)
	_update_guidance_rail()
	var fallback: Control = _fallback_control()
	_overlay().set_fallback_focus(fallback)
	_overlay().set_usable_rect(_geometry.usable_rect)
	if (
		_restore_focus_after_layout
		and not _overlay().is_active()
		and is_instance_valid(fallback)
		and fallback.is_visible_in_tree()
	):
		fallback.grab_focus()
		_restore_focus_after_layout = false
	_layout_generation += 1
	_end_resolution()


func _end_resolution() -> void:
	_resolving = false
	if _requested and _bound and is_inside_tree():
		if not _scheduled:
			_scheduled = true
			call_deferred("_resolve_layout")
	else:
		_pending = false
		if _pending_advance.is_valid():
			call_deferred("_resume_advance")


func _resume_advance() -> void:
	if _pending or not _bound or not _pending_advance.is_valid():
		return
	var callback: Callable = _pending_advance
	_pending_advance = Callable()
	callback.call()


func _measure_candidates(generation: int) -> Array[GuiFitCandidate]:
	var modality: bool = _keypad
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Isolated measurement workspace, never a device/profile threshold.
	viewport.size = Vector2i(4096, 4096)
	add_child(viewport)
	var layer := Control.new()
	layer.theme = theme
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
				WideScene
				if mode == GuiSizeClass.LayoutMode.WIDE
				else PhoneScene if mode == GuiSizeClass.LayoutMode.PHONE else LandscapeScene
			)
			var probe: GuiTableComposition = scene.instantiate()
			probe.theme = GuiTypography.for_density(density)
			layer.add_child(probe)
			probe.size = Vector2(viewport.size)
			probe.use_keypad(modality)
			probe.render(_model_for_density(density))
			probes.append(probe)
			modes.append(mode)
			densities.append(density)
			_probes += 1
			_active_probes += 1
			_peak_probes = maxi(_peak_probes, _active_probes)
	for frame: int in 10:
		await frame_tick
		if (
			not is_inside_tree()
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
		await frame_tick
		if (
			not is_inside_tree()
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


func _model_for_density(density: GuiFitCandidate.Density) -> TableViewModel:
	if not _models.has(density):
		_models[density] = _session.get_model(density)
	return _models[density]


func _connect_composition(composition: GuiTableComposition) -> void:
	if composition == _connected_composition:
		return
	_connected_composition = composition
	composition.action_requested.connect(func(intent: StringName) -> void: submit_intent(intent))
	composition.wager_edited.connect(func(value: String) -> void: _draft = value)
	composition.wager_submitted.connect(func(value: String) -> void: submit_intent(&"wager", value))
	composition.entry_requested.connect(_open_number)
	composition.menu_requested.connect(open_menu)
	composition.seat_detail_requested.connect(_open_seat)


func _open_number(value: String) -> void:
	if _input_blocked():
		return
	var actions: ActionBarViewModel = get_table_view_model().actions
	if not actions.wager_enabled:
		return
	_draft = value
	var model := NumberEntryViewModel.new()
	model.title = actions.wager_text + " total"
	model.value = _draft
	model.minimum = actions.minimum_total
	model.maximum = actions.maximum_total
	model.show_presets = true
	model.minimum_preset = str(actions.minimum_total)
	model.pot_preset = str(actions.pot_total)
	model.pot_display_value = str(actions.pot_contribution)
	model.pot_enabled = actions.pot_enabled
	_overlay().set_fallback_focus(_fallback_control())
	_overlay().open_number(model)


func _open_seat(id: int) -> void:
	if _input_blocked():
		return
	var model: SeatViewModel = get_table_view_model().seat_for(id)
	if model != null:
		_detail_seat = id
		_render_detail(model)


func _render_detail(model: SeatViewModel) -> void:
	_detail_authorization.clear()
	for card: CardViewModel in model.cards.cards:
		_detail_authorization.append(card != null and card.state == CardViewModel.State.FACE)
	_overlay().open_seat(model)


func _fallback_control() -> Control:
	var composition: GuiTableComposition = get_composition()
	if (
		composition != null
		and composition.is_visible_in_tree()
		and _host().state != null
		and _host().state.status == GuiCompositionState.Status.READY
	):
		return composition.get_control(&"more")
	return get_node("GuidanceRail/Row/More") as Control


func _update_guidance_rail() -> void:
	var rail: MarginContainer = get_node("GuidanceRail")
	rail.visible = _host().state == null or _host().state.status != GuiCompositionState.Status.READY
	rail.position = _geometry.usable_rect.position
	rail.size = Vector2(_geometry.usable_rect.size.x, rail.get_combined_minimum_size().y)


func _guidance_snapshot() -> GuiLayoutSnapshot:
	var snapshot := GuiLayoutSnapshot.new()
	snapshot.schema_version = 2
	snapshot.root_rect = Rect2(Vector2.ZERO, size)
	snapshot.viewport_rect = snapshot.root_rect
	snapshot.usable_rect = (
		_geometry.usable_rect if _geometry != null and _geometry.valid else snapshot.root_rect
	)
	snapshot.surface_rect = snapshot.usable_rect
	snapshot.surface_size = snapshot.usable_rect.size
	var state: GuiCompositionState = _host().state
	snapshot.layout_mode = (
		state.fit.size_class.mode
		if state != null and state.fit != null
		else GuiSizeClass.LayoutMode.WIDE
	)
	snapshot.profile = GuiSnapshotMeasurement.profile_for_mode(snapshot.layout_mode)
	snapshot.fit_guidance = (
		state.guidance
		if state != null and not state.guidance.is_empty()
		else "Waiting for table measurements."
	)
	var message: Control = _host().get_node("LayoutSlot/SpaceGuidance/Center/Message")
	var observed: GuiLayoutElement = GuiSnapshotMeasurement.element(message, self, &"guidance")
	snapshot.elements[&"guidance"] = observed
	snapshot.measured.append(observed)
	var more: GuiLayoutElement = GuiSnapshotMeasurement.element(
		get_node("GuidanceRail/Row/More"), self, &"action/more"
	)
	snapshot.elements[&"action/more"] = more
	snapshot.measured.append(more)
	snapshot.menu_routes = {&"quit": &"more", &"event": &"more"}
	return snapshot


func _capture_overlay(snapshot: GuiLayoutSnapshot) -> void:
	if not _overlay().is_active():
		return
	var active: Control = _overlay().get_control(&"active")
	var kind: StringName = _overlay().get_active_kind()
	kind = &"keypad" if kind == &"number" else &"seat_detail" if kind == &"seat" else kind
	var value := GuiOverlaySnapshot.new()
	value.kind = kind
	value.element = GuiSnapshotMeasurement.element(active, self, StringName("overlay/" + str(kind)))
	var redacted: Array[Node] = []
	if kind == &"seat_detail":
		value.selected_seat = _detail_seat
		var pair := _overlay().get_control(&"seat_cards") as GuiHoleCards
		for index: int in pair.cards.size():
			var authorized: bool = (
				index < _detail_authorization.size() and _detail_authorization[index]
			)
			if not authorized:
				redacted.append(pair.cards[index])
			value.cards.append(
				pair.cards[index].get_card_snapshot(
					self, StringName("overlay/seat_detail/cards/%d" % index), authorized
				)
			)
	var semantic: Dictionary[Node, StringName] = {_overlay().get_log().get_body(): &"event"}
	GuiSnapshotMeasurement.descendants(
		active, self, value.element.role, value.measured, redacted, false, [], semantic
	)
	if kind == &"keypad":
		for role: StringName in [
			&"clear", &"back", &"done", &"cancel", &"value", &"title", &"limits", &"minimum", &"pot"
		]:
			value.elements[role] = GuiSnapshotMeasurement.element(
				_overlay().get_keypad().get_control(role),
				self,
				StringName("overlay/keypad/" + str(role))
			)
		for digit: int in 10:
			var role := StringName("key/%d" % digit)
			value.elements[role] = GuiSnapshotMeasurement.element(
				_overlay().get_keypad().get_control(StringName(str(digit))),
				self,
				StringName("overlay/keypad/" + str(role))
			)
	snapshot.overlays.append(value)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _bound or _overlay().is_active():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		open_menu()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_ever_visible = true
		if _bound:
			_request_resolution()
	elif _ever_visible and _bound:
		teardown()


func _prepare_binding() -> void:
	_input_caret = -1
	_input_selection = Vector2i(-1, -1)
	_focus_intent = &""
	_restore_focus_after_layout = false
	_resolution_epoch += 1
	_pending_advance = Callable()
	if is_node_ready():
		_overlay().cancel_advance()
		_overlay().close()
		_host().hide()


func _model_ids(model: TableViewModel) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for seat: SeatViewModel in model.seats:
		ids.append(seat.seat)
	ids.sort()
	return ids


func _action_flow() -> GuiFitCandidate.ActionFlow:
	return GuiFitCandidate.ActionFlow.KEYPAD if _keypad else GuiFitCandidate.ActionFlow.TWO_ROWS


func _contains(available: Vector2, minimum: Vector2) -> bool:
	return available.x >= minimum.x and available.y >= minimum.y


func _process(_delta: float) -> void:
	# Await an instance-owned signal: freeing this controller disconnects pending
	# continuations instead of resuming a dead script from SceneTree signals.
	frame_tick.emit()


func _remember_input_state(composition: GuiTableComposition) -> void:
	if composition == null or not composition.is_visible_in_tree():
		return
	var field := composition.get_control(&"total") as LineEdit
	if field != null and field.is_visible_in_tree():
		_input_caret = field.caret_column
		_input_selection = (
			Vector2i(field.get_selection_from_column(), field.get_selection_to_column())
			if field.has_selection()
			else Vector2i(-1, -1)
		)
	if _overlay().is_active():
		return
	for role: StringName in [
		&"total",
		&"fold",
		&"check_call",
		&"minimum",
		&"pot",
		&"wager",
		&"all_in",
		&"continue",
		&"more"
	]:
		var control: Control = composition.get_control(role)
		if control != null and control.has_focus():
			_focus_intent = role
			break


func _restore_input_state(composition: GuiTableComposition) -> void:
	if composition == null:
		return
	var field := composition.get_control(&"total") as LineEdit
	if field != null and _input_caret >= 0:
		field.caret_column = mini(_input_caret, field.text.length())
		if _input_selection.x >= 0:
			field.select(_input_selection.x, _input_selection.y)
	if not _focus_intent.is_empty() and not _overlay().is_active():
		var control: Control = composition.get_control(_focus_intent)
		if (
			control != null
			and control.is_visible_in_tree()
			and control.focus_mode != Control.FOCUS_NONE
			and not (control is BaseButton and (control as BaseButton).disabled)
		):
			control.grab_focus()
		_focus_intent = &""
