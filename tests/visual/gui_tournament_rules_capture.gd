extends SceneTree
# gdlint: disable=max-returns

## Development previews of the production Start/Rules scenes; never device acceptance.
const MainScene := preload("res://scenes/main.tscn")
const CASES: Array[Dictionary] = [
	{"id": "phone-portrait", "size": Vector2i(390, 744)},
	{"id": "phone-landscape", "size": Vector2i(780, 360)},
	{"id": "desktop-landscape", "size": Vector2i(1920, 1080)},
	{"id": "large-portrait", "size": Vector2i(1080, 1920)},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Supply one new output directory under localtmp/gui-elements/.")
		quit(2)
		return
	var relative: String = args[0].simplify_path().trim_suffix("/")
	if not relative.begins_with("localtmp/gui-elements/") or ".." in relative.split("/"):
		printerr("Output must be a new directory beneath localtmp/gui-elements/.")
		quit(2)
		return
	var output: String = ProjectSettings.globalize_path("res://" + relative)
	if DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		printerr("Refusing to overwrite an existing capture directory.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		printerr("Rules previews require a rendered display.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("Could not create capture directory.")
		quit(2)
		return
	var records: Array[Dictionary] = []
	for fixture: Dictionary in CASES:
		var viewport := SubViewport.new()
		viewport.size = fixture.size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var main := MainScene.instantiate() as StartupConfigController
		main.set_anchors_preset(Control.PRESET_TOP_LEFT)
		main.size = Vector2(fixture.size)
		viewport.add_child(main)
		for surface: String in ["start", "rules", "rules-ending"]:
			if surface == "rules":
				(main.get_node("%RulesButton") as Button).pressed.emit()
			var page := main.get_node("RulesPage") as GuiTournamentRulesPage
			if surface == "rules-ending":
				page.get_body().get_v_scroll_bar().value = (
					page.get_body().get_v_scroll_bar().max_value
				)
			for frame: int in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			var filename: String = "%s-%s.png" % [fixture.id, surface]
			var picture: Image = viewport.get_texture().get_image()
			if picture == null or picture.save_png(output.path_join(filename)) != OK:
				printerr("Failed to save " + filename)
				quit(1)
				return
			(
				records
				. append(
					{
						"file": filename,
						"size": [fixture.size.x, fixture.size.y],
						"surface": surface,
						"match_created": main.startup_adapter.match_instance != null,
						"rules_scroll": page.get_body().get_v_scroll_bar().value,
					}
				)
			)
		viewport.queue_free()
		await process_frame
	var manifest := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if manifest == null:
		printerr("Could not write capture manifest.")
		quit(1)
		return
	(
		manifest
		. store_string(
			(
				(
					JSON
					. stringify(
						{
							"purpose":
							"RIG-02 development visual review; pending user/device acceptance",
							"godot": Engine.get_version_info().string,
							"renderer": RenderingServer.get_current_rendering_method(),
							"display": DisplayServer.get_name(),
							"captures": records,
						},
						"\t"
					)
				)
				+ "\n"
			)
		)
	)
	print("Saved %d Start/Rules previews to %s" % [records.size(), relative])
	quit(0)
