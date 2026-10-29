class_name GuiSceneHarness
extends Node

## Mounts deterministic fixtures through an implementation-specific driver.
## Settling observes only the public semantic snapshot contract.

const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const ReferenceDriver := preload("res://tests/support/gui_reference_fixture_driver.gd")

var _viewport: SubViewport
var _rendered: Dictionary = {}
var _fixture_driver: RefCounted = ReferenceDriver.new()


func set_fixture_driver(driver: RefCounted) -> void:
	assert(_viewport == null, "Choose a fixture driver before rendering.")
	assert(driver != null, "A fixture driver is required.")
	_fixture_driver = driver


func render(
	descriptor: Dictionary,
	viewport_size: Vector2i,
	profile_override: int = GuiLayoutProfileScript.AUTOMATIC,
) -> Dictionary:
	assert(_viewport == null, "A GUI scene harness renders one fixture.")
	_viewport = SubViewport.new()
	_viewport.name = "FixtureViewport"
	_viewport.size = viewport_size
	_viewport.disable_3d = true
	_viewport.gui_embed_subwindows = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_rendered = _fixture_driver.call(
		"render", _viewport, descriptor, viewport_size, profile_override
	)
	return _rendered


func resize_viewport(viewport_size: Vector2i) -> void:
	assert(not _rendered.is_empty(), "Render a GUI fixture before resizing it.")
	_viewport.size = viewport_size
	_fixture_driver.call("resize", _rendered, viewport_size)


func rerender(descriptor: Dictionary) -> Dictionary:
	assert(not _rendered.is_empty(), "Render a GUI fixture before rebinding it.")
	_rendered = _fixture_driver.call("rerender", _rendered, descriptor)
	return _rendered


func settle_layout(max_frames: int = 16) -> bool:
	assert(not _rendered.is_empty(), "Render a GUI fixture before settling it.")
	var previous_signature: String = ""
	var stable_frames: int = 0
	for _frame: int in range(max_frames):
		await get_tree().process_frame
		var snapshot: GuiLayoutSnapshot = _rendered.root.get_layout_snapshot()
		var signature: String = snapshot.geometry_signature()
		if snapshot.ready and not snapshot.pending and signature == previous_signature:
			stable_frames += 1
		else:
			stable_frames = 0
		previous_signature = signature
		if stable_frames >= 2:
			return true
	return false
