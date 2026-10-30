class_name GuiStartupSnapshotProducer
extends RefCounted

const Measure := preload("res://scripts/gui/gui_snapshot_measurement.gd")


static func capture(
	root: Control, form: Control, controls: Dictionary[StringName, Control], overlay: GuiOverlayHost
) -> GuiLayoutSnapshot:
	var result := GuiLayoutSnapshot.new()
	result.root_rect = Measure.rect(root, root)
	result.viewport_rect = root.get_viewport().get_visible_rect()
	result.surface_rect = result.root_rect
	result.surface_size = root.size
	result.surface_transform = root.get_global_transform_with_canvas()
	result.usable_rect = result.root_rect
	result.startup = GuiStartupSnapshot.new()
	result.startup.visible = form.is_visible_in_tree()
	for role: StringName in controls:
		var value := Measure.element(controls[role], root, StringName("startup/%s" % role))
		result.startup.fields[role] = value
		result.elements[value.role] = value
	var excluded_roots: Array[Node] = []
	for child: Node in root.get_children():
		if child.has_method("bind_match") and child is Control and not child.is_visible_in_tree():
			excluded_roots.append(child)
	Measure.descendants(root, root, &"startup", result.measured, [], false, excluded_roots)
	if overlay.is_active() and overlay.get_active_kind() == &"number":
		var popup := GuiOverlaySnapshot.new()
		popup.kind = &"keypad"
		var keypad: GuiNumericKeypad = overlay.get_keypad()
		popup.element = Measure.element(overlay.get_control(&"active"), root, &"overlay/keypad")
		Measure.descendants(overlay.get_control(&"active"), root, &"overlay/keypad", popup.measured)
		for role: StringName in [
			&"clear", &"back", &"done", &"cancel", &"value", &"title", &"limits"
		]:
			popup.elements[role] = Measure.element(keypad.get_control(role), root, role)
		for digit: int in 10:
			var role := StringName("key/%d" % digit)
			popup.elements[role] = Measure.element(
				keypad.get_control(StringName(str(digit))), root, role
			)
		result.overlays.append(popup)
	result.ready = root.is_node_ready() and root.size.x > 0.0 and root.size.y > 0.0
	return result
