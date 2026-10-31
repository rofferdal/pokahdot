extends SceneTree

## Native real-pointer previews; synthetic recipient-safe state, no device acceptance.
const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")
var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	await _capture("desktop", Vector2i(1600, 1200), Rect2(16, 20, 1568, 1160), false)
	await _capture("compact-edge-long", Vector2i(390, 844), Rect2(12, 24, 366, 790), true)
	quit(1 if _failed else 0)


func _capture(label: String, allocation: Vector2i, usable: Rect2, long_name: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = allocation
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("0b271b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.size = Vector2(allocation)
	viewport.add_child(background)
	var table := TableScene.instantiate() as GuiReplacementTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	viewport.add_child(table)
	table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(allocation), usable))
	var names: Dictionary[int, String] = {0: "Human", 1: "Amina", 2: "Leilani", 3: "Haruto"}
	var profile: String = (
		"Deliberately Long Public Strategic Profile Name With An Unambiguous Identity"
		if long_name
		else "Tight Passive"
	)
	var profiles: Dictionary[int, String] = {1: profile, 2: "Loose Aggressive"}
	var avatars: Dictionary[int, String] = {}
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	for seat: int in 4:
		avatars[seat] = paths[seat]
	var view: GameView = GuiVisualStateFixtures.replacement_flop(4).view
	table.bind_view(view, avatars, names, [], profiles)
	var ready: bool = false
	for frame: int in 180:
		await process_frame
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		if snapshot.ready and not snapshot.pending:
			ready = true
			break
	if not ready:
		push_error("Profile hover preview did not settle: " + label)
		_failed = true
		viewport.queue_free()
		return
	var seat: Control = table.get_composition().get_seat_controls()[1]
	var name: Control = seat.get_field(&"name")
	var point: Vector2 = name.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.device = 0
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion)
	await create_timer(0.65).timeout
	for frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var popup: GuiBotProfileTooltip = table.get_profile_tooltip()
	var contained: bool = popup.visible and usable.encloses(popup.get_global_rect())
	if not contained or popup.get_text() != "Bot profile: " + profile:
		push_error("Profile hover preview failed popup checks: " + label)
		_failed = true
	var stem: String = "res://localtmp/gui-elements/gph-" + label
	var save_error: Error = viewport.get_texture().get_image().save_png(stem + ".png")
	if save_error != OK:
		_failed = true
	var popup_rect: Rect2 = popup.get_global_rect()
	var tooltip_label: Label = popup.get_node("Text")
	var metadata := FileAccess.open(stem + ".json", FileAccess.WRITE)
	metadata.store_string(
		JSON.stringify(
			{
				"viewport": [allocation.x, allocation.y],
				"usable_rect": [usable.position.x, usable.position.y, usable.size.x, usable.size.y],
				"input_mode": "real-pointer InputEventMouseMotion device=0",
				"pointer": [point.x, point.y],
				"profile_text": popup.get_text(),
				"popup_rect":
				[
					popup_rect.position.x,
					popup_rect.position.y,
					popup_rect.size.x,
					popup_rect.size.y
				],
				"font_size": tooltip_label.get_theme_font_size("font_size"),
				"built_in_font": tooltip_label.get_theme_font("font").resource_path.is_empty(),
				"contained": contained,
				"synthetic_recipient_safe_fixture": true,
				"device_acceptance": false,
				"source_sha256":
				{
					"tooltip":
					FileAccess.get_sha256(
						"res://scripts/gui/components/gui_bot_profile_tooltip.gd"
					),
					"controller":
					FileAccess.get_sha256("res://scripts/gui/gui_replacement_table_controller.gd"),
					"capture":
					FileAccess.get_sha256("res://tests/visual/gui_bot_profile_hover_capture.gd")
				}
			},
			"\t"
		)
	)
	table.teardown()
	viewport.queue_free()
	await process_frame
