extends SceneTree

## Independent theme-role gallery. It is not a finished poker-table composition.
const Gallery := preload("res://tests/visual/gui_theme_gallery.tscn")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 980)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var gallery: Control = Gallery.instantiate()
	viewport.add_child(gallery)
	var theme: Theme = gallery.theme
	# Simulated states use the authored resources so they can be compared in
	# one image without depending on a moving pointer or a single focus owner.
	for state: String in ["hover", "pressed"]:
		var button: Button = gallery.get_node("Margin/Gallery/Actions/" + state.capitalize())
		button.add_theme_stylebox_override("normal", theme.get_stylebox(state, "ActionButton"))
	_simulate_focus(gallery.get_node("Margin/Gallery/Actions/Focus"), "ActionButton", theme)
	_simulate_focus(gallery.get_node("Margin/Gallery/Fields/Name"), "InputField", theme)
	_simulate_focus(gallery.get_node("Margin/Gallery/Fields/TotalFocus"), "WagerTotalField", theme)
	for frame: int in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var escaped := PackedStringArray()
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	for node: Node in gallery.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and not bounds.encloses(control.get_global_rect()):
			escaped.append(str(gallery.get_path_to(control)))
	var card_observations: Array[Dictionary] = []
	for name: String in ["Face", "RedFace", "Back"]:
		var card: PanelContainer = gallery.get_node("Margin/Gallery/Lower/Cards/" + name)
		var observation: Dictionary = {
			"sample": name,
			"rect": [card.global_position.x, card.global_position.y, card.size.x, card.size.y],
			"size": [card.size.x, card.size.y],
			"width_height_ratio": card.size.x / card.size.y,
		}
		if name != "Back":
			observation["value_font"] = card.get_node("Glyphs/Value").font_size
			observation["suit_font"] = card.get_node("Glyphs/Suit").font_size
		card_observations.append(observation)
	var seat_observations: Array[Dictionary] = []
	for index: int in 5:
		var panel: PanelContainer = gallery.get_node("Margin/Gallery/Seats/Seat%d/Panel" % index)
		var rect: Rect2 = panel.get_global_rect()
		var observation: Dictionary = {
			"sample": index,
			"panel": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		}
		var avatar: TextureRect = panel.get_node_or_null("Identity/Avatar")
		if avatar != null:
			var avatar_rect: Rect2 = avatar.get_global_rect()
			observation["avatar"] = [
				avatar_rect.position.x,
				avatar_rect.position.y,
				avatar_rect.size.x,
				avatar_rect.size.y
			]
		seat_observations.append(observation)
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	var path: String = "res://localtmp/gui-elements/rg31-markers-winners-review3-1280x980.png"
	var error: Error = viewport.get_texture().get_image().save_png(path)
	var metadata: FileAccess = FileAccess.open(
		"res://localtmp/gui-elements/rg31-markers-winners-review3.json", FileAccess.WRITE
	)
	if metadata == null:
		push_error("Cannot save theme-gallery metadata.")
		quit(1)
		return
	(
		metadata
		. store_string(
			(
				JSON
				. stringify(
					{
						"image": path,
						"size": [1280, 980],
						"save_error": error,
						"escaped_controls": escaped,
						"cards": card_observations,
						"seats": seat_observations,
						"grayscale_shader_sha256":
						FileAccess.get_sha256("res://resources/gui_grayscale.gdshader"),
						"grayscale_material_sha256":
						FileAccess.get_sha256("res://resources/gui_grayscale_material.tres"),
						"glyph_script_sha256":
						FileAccess.get_sha256("res://tests/visual/gui_card_glyph_sample.gd"),
						"gallery_script_sha256":
						FileAccess.get_sha256("res://tests/visual/gui_theme_gallery.gd"),
						"capture_script_sha256":
						FileAccess.get_sha256("res://tests/visual/gui_theme_capture.gd"),
						"theme_sha256": FileAccess.get_sha256("res://resources/gui_theme.tres"),
						"gallery_sha256":
						FileAccess.get_sha256("res://tests/visual/gui_theme_gallery.tscn"),
						"states":
						"authored normal/hover/pressed/focus/disabled with simulated simultaneous focus",
						"device_acceptance": false,
					},
					"\t"
				)
			)
		)
	)
	viewport.queue_free()
	quit(0 if error == OK and escaped.is_empty() else 1)


func _simulate_focus(control: Control, variation: String, theme: Theme) -> void:
	var normal: StyleBoxFlat = theme.get_stylebox("normal", variation).duplicate()
	var focus: StyleBoxFlat = theme.get_stylebox("focus", variation)
	normal.border_color = focus.border_color
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		normal.set_border_width(edge, focus.get_border_width(edge))
	control.add_theme_stylebox_override("normal", normal)
