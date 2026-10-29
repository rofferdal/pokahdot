class_name GuiStartupSnapshotProducer
extends RefCounted

const Measure := preload("res://scripts/gui/gui_snapshot_measurement.gd")


static func capture(
	root: Control, form: Control, controls: Dictionary[StringName, Control], keypad: Window
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
		if child is PokerTableController and not (child as Control).is_visible_in_tree():
			excluded_roots.append(child)
	Measure.descendants(root, root, &"startup", result.measured, [], false, excluded_roots)
	result.overlays.append(Measure.overlay(keypad, root, &"keypad"))
	result.ready = root.is_node_ready() and root.size.x > 0.0 and root.size.y > 0.0
	return result
