extends SceneTree

## Standalone replacement-guidance preview; no match or legacy layout is loaded.
const Guidance := preload("res://scenes/gui/components/SpaceGuidance.tscn")
const CASES: Array[Dictionary] = [
	{"name": "capacity-portrait", "size": Vector2i(390, 844), "count": 9},
	{"name": "capacity-landscape", "size": Vector2i(844, 390), "count": 9},
	{"name": "space-portrait", "size": Vector2i(360, 640), "count": 7},
]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	var observations: Array[Dictionary] = []
	for fixture: Dictionary in CASES:
		var viewport := SubViewport.new()
		viewport.size = fixture.size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.color = Color("123c29")
		background.size = fixture.size
		viewport.add_child(background)
		var guidance: GuiSpaceGuidance = Guidance.instantiate()
		viewport.add_child(guidance)
		var ids := PackedInt32Array()
		for id: int in fixture.count:
			ids.append(id)
		var policy: GuiFitPolicy = GuiFitPolicy.resolve(
			GuiViewportGeometry.injected(fixture.size), ids, 0, []
		)
		if fixture.count == 7:
			# Illustrate the actual too-small result using explicitly primitive
			# content measurements; this does not certify table component fit.
			var metrics := GuiFitMetrics.new()
			metrics.opponent = Vector2(170, 120)
			metrics.board = Vector2(300, 100)
			metrics.hero = Vector2(300, 100)
			metrics.actions = Vector2(300, 104)
			metrics.gap = 4
			metrics.evidence = &"primitive_preview"
			var candidate: GuiFitCandidate = GuiFitCandidate.measure(
				GuiSizeClass.LayoutMode.PHONE, metrics, ids, 0
			)
			policy = GuiFitPolicy.resolve(
				GuiViewportGeometry.injected(fixture.size), ids, 0, [candidate]
			)
		guidance.render(policy)
		for frame: int in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var filename: String = "res://localtmp/gui-elements/rg12-%s.png" % fixture.name
		var error: Error = viewport.get_texture().get_image().save_png(filename)
		(
			observations
			. append(
				{
					"image": filename,
					"size": fixture.size,
					"status": policy.status,
					"guidance": policy.guidance,
					"save_error": error,
					"heading_rect": guidance.get_node("Center/Heading").get_global_rect(),
					"message_rect": guidance.get_node("Center/Message").get_global_rect(),
				}
			)
		)
		viewport.queue_free()
		await process_frame
	var file: FileAccess = FileAccess.open(
		"res://localtmp/gui-elements/rg12-guidance.json", FileAccess.WRITE
	)
	file.store_string(JSON.stringify(observations, "\t"))
	quit()
