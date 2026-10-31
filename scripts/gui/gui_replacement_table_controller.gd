# gdlint: disable=max-public-methods
class_name GuiReplacementTableController
extends Control
# Public startup, diagnostic and profiling boundaries share this scene adapter.

## Replacement orchestration: session and overlays outlive measured compositions.
signal tournament_quit_confirmed
signal return_to_startup_requested
signal frame_tick
const WideScene := preload("res://scenes/gui/layouts/WideTableLayout.tscn")
const TabletScene := preload("res://scenes/gui/layouts/TabletTableLayout.tscn")
const PhoneScene := preload("res://scenes/gui/layouts/PhoneTableLayout.tscn")
const LandscapeScene := preload("res://scenes/gui/layouts/PhoneLandscapeLayout.tscn")
@export var action_timing_config: Resource
@export var touch_entry: bool = false
var _snapshot_capture := GuiReplacementSnapshotCapture.new()
var _input_state := GuiReplacementInputState.new()
var _overlay_actions := GuiReplacementOverlayActions.new()
var _session := GuiTableSession.new()
var _layout_resolver := GuiReplacementLayoutResolver.new(self, _session, _input_state)
var _geometry_to_viewport := Transform2D.IDENTITY
var _geometry_pending: bool = false
var _bound: bool = false
var _pending: bool = false
var _draft: String = ""
var _mode_override: int = GuiSizeClass.AUTOMATIC
var _keypad: bool = false
var _models: Dictionary[int, TableViewModel] = {}
var _connected_composition: GuiTableComposition
var _pending_advance: Callable
var _draft_initialized: bool = false
var _ever_visible: bool = false


func _ready() -> void:
	_layout_resolver.configure(
		_host(),
		_overlay(),
		_model_for_density,
		_connect_composition,
		_fallback_control,
		_update_guidance_rail,
		_on_layout_settled
	)
	_keypad = touch_entry or DisplayServer.is_touchscreen_available()
	_layout_resolver.set_keypad(_keypad)
	_session.configure(get_tree(), action_timing_config, _hold_advance, _input_blocked)
	_session.changed.connect(_on_session_changed)
	resized.connect(_request_resolution)
	visibility_changed.connect(_on_visibility_changed)
	_ever_visible = is_visible_in_tree()
	_host().register_composition(GuiSizeClass.LayoutMode.WIDE, WideScene)
	_host().register_composition(GuiSizeClass.LayoutMode.WIDE_COMPACT, TabletScene)
	_host().register_composition(GuiSizeClass.LayoutMode.PHONE, PhoneScene)
	_host().register_composition(GuiSizeClass.LayoutMode.PHONE_LANDSCAPE, LandscapeScene)
	_host().measurements_invalidated.connect(_request_resolution)
	_overlay().number_committed.connect(_on_number_committed)
	_overlay().quit_confirmed.connect(_on_quit_confirmed)
	(get_node("GuidanceRail/Row/More") as Button).pressed.connect(open_menu)
	if _bound:
		_on_session_changed()


func bind_match(
	match_instance: TournamentMatch,
	recipient: int,
	avatars: Dictionary[int, String],
	names: Dictionary[int, String] = {}
) -> bool:
	_prepare_binding()
	_bound = true
	_layout_resolver.set_bound(true)
	_draft = ""
	_draft_initialized = false
	var accepted: bool = _session.bind_match(match_instance, recipient, avatars, names)
	_bound = accepted
	_layout_resolver.set_bound(accepted)
	if not accepted:
		_pending = false
		_pending_advance = Callable()
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
	_layout_resolver.set_bound(true)
	_draft = ""
	_draft_initialized = false
	var accepted: bool = _session.bind_view(view, avatars, names, event_lines)
	_bound = accepted
	_layout_resolver.set_bound(accepted)
	if not accepted:
		_pending = false
		_pending_advance = Callable()
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
	return _layout_resolver.get_render_counters()


func get_layout_snapshot() -> GuiLayoutSnapshot:
	if not is_node_ready() or not _bound:
		return GuiLayoutSnapshot.new()
	var composition: GuiTableComposition = get_composition()
	var state: GuiCompositionState = _host().state
	var full_fit: bool = (
		composition != null and state != null and state.status == GuiCompositionState.Status.READY
	)
	var snapshot: GuiLayoutSnapshot = (
		composition.get_layout_snapshot(self)
		if full_fit
		else _snapshot_capture.guidance_snapshot(
			self, _host(), _layout_resolver.get_geometry(), _geometry_to_viewport
		)
	)
	snapshot.pending = snapshot.pending or _pending or _geometry_pending
	snapshot.ready = snapshot.ready and not snapshot.pending
	snapshot.generation = _layout_resolver.get_layout_generation()
	var geometry: GuiViewportGeometry = _layout_resolver.get_geometry()
	if geometry != null and geometry.valid:
		snapshot.root_rect = _geometry_to_viewport * geometry.full_rect
		snapshot.viewport_rect = snapshot.root_rect
		snapshot.usable_rect = _geometry_to_viewport * geometry.usable_rect
	_snapshot_capture.capture_overlay(
		snapshot,
		self,
		_overlay(),
		_overlay_actions.detail_seat,
		_overlay_actions.detail_authorization
	)
	return snapshot


func set_viewport_geometry(
	geometry: GuiViewportGeometry, to_viewport: Transform2D = Transform2D.IDENTITY
) -> void:
	_layout_resolver.set_geometry(geometry)
	_geometry_to_viewport = to_viewport
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


func set_action_timing_config(timing: Resource) -> void:
	action_timing_config = timing
	if is_node_ready():
		_session.configure(get_tree(), timing, _hold_advance, _input_blocked)


func use_keypad(enabled: bool) -> void:
	_keypad = enabled
	_layout_resolver.set_keypad(enabled)
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
	_layout_resolver.teardown()
	_session.stop()
	_pending = false
	_pending_advance = Callable()
	_models.clear()
	if is_node_ready():
		_overlay().cancel_advance()
		_overlay().close()
		_host().hide()


func _on_session_changed() -> void:
	_layout_resolver.invalidate_model()
	_models.clear()
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
	if (
		_overlay().get_active_kind() == &"seat"
		and model.seat_for(_overlay_actions.detail_seat) != null
	):
		_overlay_actions.render_detail(_overlay(), model.seat_for(_overlay_actions.detail_seat))


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
	_pending = _bound
	_layout_resolver.request_resolution()


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
	_layout_resolver.set_mode_override(_mode_override)
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


func _on_layout_settled() -> void:
	_pending = false
	if _pending_advance.is_valid():
		call_deferred("_resume_advance")


func _resume_advance() -> void:
	if _pending or not _bound or not _pending_advance.is_valid():
		return
	var callback: Callable = _pending_advance
	_pending_advance = Callable()
	callback.call()


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
	if _input_blocked() or not get_table_view_model().actions.wager_enabled:
		return
	_draft = value
	_overlay_actions.open_number(
		_overlay(), _fallback_control(), get_table_view_model().actions, value
	)


func _open_seat(id: int) -> void:
	if not _input_blocked():
		var model: SeatViewModel = get_table_view_model().seat_for(id)
		if model != null:
			_overlay_actions.detail_seat = id
			_overlay_actions.render_detail(_overlay(), model)


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
	var geometry: GuiViewportGeometry = _layout_resolver.get_geometry()
	rail.position = geometry.usable_rect.position
	rail.size = Vector2(geometry.usable_rect.size.x, rail.get_combined_minimum_size().y)


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
	_models.clear()
	_input_state.reset()
	_layout_resolver.prepare_binding()
	_pending_advance = Callable()
	if is_node_ready():
		_overlay().cancel_advance()
		_overlay().close()
		_host().hide()


func _process(_delta: float) -> void:
	# Await an instance-owned signal: freeing this controller disconnects pending
	# continuations instead of resuming a dead script from SceneTree signals.
	frame_tick.emit()
