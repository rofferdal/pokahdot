extends GutTest

const Wide := preload("res://scenes/gui/layouts/WideTableLayout.tscn")
const Phone := preload("res://scenes/gui/layouts/PhoneTableLayout.tscn")
const Token := preload("res://scenes/gui/components/SeatToken.tscn")
const Palette := preload("res://resources/gui_theme.tres")


func test_freed_native_scenes_cancel_pending_frame_callbacks_without_retained_children() -> void:
	var root := Control.new()
	root.theme = Palette
	root.size = Vector2(5000, 4000)
	add_child_autofree(root)
	var fixture: Dictionary = GuiVisualStateFixtures.by_id(&"human-turn-flop", 6)
	var model: TableViewModel = TableViewModel.build(
		fixture.view, {0: "Human", 1: "Emiliano"}, {}, {}, {}, [], GuiFitCandidate.Density.COMPACT
	)
	assert_true(model.valid)
	for scene: PackedScene in [Wide, Phone, Token]:
		for frames: int in range(4):
			var control: Control = scene.instantiate()
			control.theme = GuiTypography.Compact
			root.add_child(control)
			control.size = Vector2(3000, 2500)
			if control is GuiSeatToken:
				(control as GuiSeatToken).render(model.seats[1])
			else:
				assert_true((control as GuiTableComposition).render(model))
			if frames > 0:
				await wait_process_frames(frames)
			var references: Array[WeakRef] = _references(control)
			root.remove_child(control)
			control.free()
			await wait_process_frames(8)
			for reference: WeakRef in references:
				assert_null(
					reference.get_ref(), "%s/free at frame %d" % [scene.resource_path, frames]
				)


func _references(node: Node) -> Array[WeakRef]:
	var result: Array[WeakRef] = [weakref(node)]
	for child: Node in node.get_children():
		result.append_array(_references(child))
	return result
