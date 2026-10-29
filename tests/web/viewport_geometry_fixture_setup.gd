extends RefCounted

## Finite, export-only geometry inputs chosen during fixture bootstrap.
## No runtime JavaScript input or geometry setter is exposed by the observer.
const Geometry := preload("res://scripts/gui/platform/gui_viewport_geometry.gd")


static func apply(main: StartupConfigController) -> void:
	if not OS.has_feature("web"):
		return
	var preset: String = _preset()
	if preset not in ["asymmetric", "asymmetric-keypad", "safe-and-visual"]:
		return
	var encoded: String = JavaScriptBridge.eval(
		(
			"JSON.stringify((()=>{const r=document.querySelector('canvas').getBoundingClientRect();"
			+ "return [r.x,r.y,r.width,r.height];})())"
		)
	)
	var values: Array = JSON.parse_string(encoded)
	var canvas := Rect2(values[0], values[1], values[2], values[3])
	var visual: Rect2 = canvas
	var insets := Vector4(11, 23, 17, 29)
	if preset == "safe-and-visual":
		insets = Vector4(0, 24, 0, 34)
		visual.size.y -= 144.0
	var window: Window = main.get_window()
	var geometry: GuiViewportGeometry = Geometry.from_web(
		DisplayServer.window_get_size(window.get_window_id()),
		canvas,
		canvas,
		visual,
		insets,
		DisplayServer.screen_get_scale(window.current_screen)
	)
	main.get_viewport_adapter().inject_geometry(geometry)


static func expected_overlays() -> Array[StringName]:
	var result: Array[StringName] = []
	if _preset() == "asymmetric-keypad":
		result.append(&"keypad")
	return result


static func open_initial_overlay(table: PokerTableController) -> void:
	if _preset() != "asymmetric-keypad":
		return
	for _frame: int in range(16):
		await table.get_tree().process_frame
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		if snapshot.ready and not snapshot.pending:
			table.show_wager_keypad()
			return
	push_error("Viewport geometry keypad fixture did not reach ready geometry.")


static func _preset() -> String:
	return JavaScriptBridge.eval(
		"new URL(location.href).searchParams.get('geometry') || 'ordinary'"
	)
