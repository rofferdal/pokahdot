class_name GuiCompositionHost
extends Control

## Replacement routing boundary. Scene registrations come from the composition
## root; tournament, view models, overlays, input drafts and focus live outside.
signal policy_changed(state: GuiCompositionState)
signal measurements_invalidated

var state: GuiCompositionState
var _scenes: Dictionary[int, PackedScene] = {}
var _composition: GuiTableComposition
var _scene: PackedScene
var _mode: GuiSizeClass.LayoutMode = GuiSizeClass.LayoutMode.NOT_READY
var _applying: bool = false

@onready var _slot: MarginContainer = %LayoutSlot
@onready var _guidance: GuiSpaceGuidance = %SpaceGuidance


func _ready() -> void:
	_slot.minimum_size_changed.connect(_restore_allocation)


func register_composition(mode: GuiSizeClass.LayoutMode, scene: PackedScene) -> bool:
	if mode < GuiSizeClass.LayoutMode.PHONE or mode > GuiSizeClass.LayoutMode.WIDE:
		return false
	if scene == null:
		_scenes.erase(mode)
	else:
		_scenes[mode] = scene
	return true


func get_composition() -> GuiTableComposition:
	return _composition


func present(
	geometry: GuiViewportGeometry,
	ids: PackedInt32Array,
	recipient: int,
	candidates: Array[GuiFitCandidate],
	fixture_override: int = GuiSizeClass.AUTOMATIC
) -> GuiCompositionState:
	assert(is_node_ready(), "Mount the composition host before presenting.")
	_applying = true
	state = GuiCompositionState.from_fit(
		geometry, GuiFitPolicy.resolve(geometry, ids, recipient, candidates, fixture_override)
	)
	if geometry != null and geometry.valid:
		# The host is app-root-local; only this boundary applies the usable origin.
		size = geometry.full_rect.size
		_slot.position = geometry.usable_rect.position
		_slot.size = geometry.usable_rect.size
	if state.status == GuiCompositionState.Status.READY:
		_mount_selected()
	if state.status == GuiCompositionState.Status.READY:
		_composition.show()
		_composition.apply_policy(state)
		_verify_minimum()
	_publish()
	_applying = false
	return state


func _mount_selected() -> void:
	var selected_scene: PackedScene = _scenes.get(state.mode)
	if selected_scene == null:
		state.status = GuiCompositionState.Status.UNREGISTERED
		state.guidance = "This layout is not available yet."
		return
	if _composition != null and _scene == selected_scene and _mode == state.mode:
		return
	var instance: Node = selected_scene.instantiate() if selected_scene.can_instantiate() else null
	if not instance is GuiTableComposition:
		if instance != null:
			instance.free()
		state.status = GuiCompositionState.Status.INVALID_COMPOSITION
		state.guidance = "This layout could not be loaded."
		return
	if _composition != null:
		_slot.remove_child(_composition)
		_composition.queue_free()
	_composition = instance as GuiTableComposition
	_scene = selected_scene
	_mode = state.mode
	_slot.add_child(_composition)
	_composition.minimum_size_changed.connect(_on_minimum_size_changed)


func _verify_minimum() -> void:
	if state == null or state.status != GuiCompositionState.Status.READY:
		return
	var minimum: Vector2 = _composition.get_combined_minimum_size()
	var available: Vector2 = state.geometry.usable_rect.size
	if minimum.x <= available.x and minimum.y <= available.y:
		return
	state = GuiCompositionState.from_fit(state.geometry, state.fit)
	state.status = GuiCompositionState.Status.CONTENT_MINIMUM
	state.guidance = GuiFitPolicy.insufficient_space_message(state.mode)
	_composition.apply_policy(state)
	measurements_invalidated.emit()


func _on_minimum_size_changed() -> void:
	if not _applying:
		call_deferred("_refresh_minimum")


func _refresh_minimum() -> void:
	if state == null or _composition == null:
		return
	if state.status != GuiCompositionState.Status.READY:
		return
	_verify_minimum()
	_publish()


func _publish() -> void:
	if _composition != null:
		_composition.visible = state.status == GuiCompositionState.Status.READY
	_guidance.render_message(state.guidance)
	_restore_allocation()
	policy_changed.emit(state)


func _restore_allocation() -> void:
	if state == null:
		return
	if state.geometry != null and state.geometry.valid:
		# Hiding an obsolete composition releases its propagated minimum before
		# restoring the slot allocation for the new content/guidance.
		_slot.size = state.geometry.usable_rect.size
