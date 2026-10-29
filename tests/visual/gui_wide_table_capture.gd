extends SceneTree

## Internal RG-51 evidence; activation and combined design review follow RG-53.
const WideScene := preload("res://scenes/gui/layouts/WideTableLayout.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	for count: int in [2, 6, 9]:
		await _capture(count, true)
	await _capture(6, false)
	quit(1 if _failed else 0)


func _capture(count: int, docked: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2600, 1600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("0b271b")
	background.size = Vector2(viewport.size)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var layer := Control.new()
	layer.theme = Palette
	layer.size = Vector2(viewport.size)
	viewport.add_child(layer)
	var title := Label.new()
	title.theme_type_variation = &"HeadingText"
	title.position = Vector2(20, 12)
	title.text = (
		"RG-51 · %d seats · %s history" % [count, "docked" if docked else "overlay-accessible"]
	)
	layer.add_child(title)
	var layout: GuiWideTableLayout = WideScene.instantiate()
	layout.position = Vector2(20, 56)
	layout.size = Vector2(2400, 1400)
	layout.theme = GuiTypography.Compact
	layer.add_child(layout)
	layout.render(_model(count))
	layout.set_wager_draft("20")
	for frame: int in 16:
		await process_frame
	var minimum: Vector2 = layout.get_combined_minimum_size()
	layout.size = minimum + (Vector2(600, 80) if docked else Vector2.ZERO)
	viewport.size = Vector2i(layout.size.ceil() + Vector2(40, 76))
	layer.size = Vector2(viewport.size)
	background.size = Vector2(viewport.size)
	for frame: int in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(layer)
	var failures := PackedStringArray()
	if not snapshot.ready or snapshot.pending:
		failures.append("unsettled layout")
	if layout.get_control(&"dock").visible != docked:
		failures.append("unexpected dock availability")
	for element: GuiLayoutElement in snapshot.measured:
		Invariants.validate_element(element, failures)
		if element.visible and not snapshot.root_rect.encloses(element.rect):
			failures.append("escaped: " + str(element.role))
	for seat: GuiSeatSnapshot in snapshot.seats.values():
		for field: GuiLayoutElement in seat.fields.values():
			Invariants.validate_element(field, failures)
		Invariants.validate_element(seat.status, failures)
	var path: String = (
		"res://localtmp/gui-elements/rg51-wide-%d-%s"
		% [count, "docked" if docked else "hidden-log"]
	)
	var save_error: Error = viewport.get_texture().get_image().save_png(path + ".png")
	if save_error != OK:
		failures.append("save error: " + str(save_error))
	var hashes: Dictionary = {}
	for source: String in [
		"scenes/gui/layouts/WideTableLayout.tscn",
		"scripts/gui/compositions/gui_wide_table_layout.gd",
		"scripts/gui/layout/gui_table_composition.gd",
		"scripts/gui/layout/gui_seat_ring_container.gd",
		"scripts/gui/layout/gui_seat_ring_plan.gd",
		"scenes/gui/components/SeatPanel.tscn",
		"scenes/gui/components/HeroPanel.tscn",
		"scripts/gui/components/gui_seat_panel.gd",
		"scenes/gui/components/ActionBar.tscn",
		"scripts/gui/components/gui_action_bar.gd",
		"scenes/gui/components/EventLog.tscn",
		"scripts/gui/components/gui_event_log.gd",
		"scenes/gui/components/BrandLogo.tscn",
		"resources/gui_table_logo_material.tres",
		"resources/gui_logo_texture.tres",
		"assets/images/Pokahdot_logo.png",
		"resources/gui_theme.tres",
		"resources/gui_typography_compact.tres",
		"resources/gui_typography_regular.tres",
		"tests/visual/gui_wide_table_capture.gd"
	]:
		if FileAccess.file_exists("res://" + source):
			hashes[source] = FileAccess.get_sha256("res://" + source)
	var output := FileAccess.open(path + ".json", FileAccess.WRITE)
	if output == null:
		failures.append("unable to write metadata")
	else:
		output.store_string(
			JSON.stringify(
				{
					"size": [viewport.size.x, viewport.size.y],
					"minimum": [minimum.x, minimum.y],
					"docked": docked,
					"seats": snapshot.seats.size(),
					"rows": snapshot.seat_rows,
					"failures": failures,
					"save_error": save_error,
					"source_sha256": hashes,
					"controller_cutover": false,
					"device_acceptance": false,
					"internal_batch_preview": true
				},
				"\t"
			)
		)
	_failed = _failed or not failures.is_empty()
	print(path, ": minimum ", minimum, "; ", failures)
	viewport.queue_free()
	await process_frame


func _model(count: int) -> TableViewModel:
	var fixture: Dictionary = GuiVisualStateFixtures.by_id(
		&"showdown-long" if count == 9 else &"human-turn-flop", count
	)
	var view: GameView = fixture.view
	var names: Dictionary[int, String] = {}
	var avatars: Dictionary[int, String] = {}
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	var bot_names: Array[String] = [
		"Emiliano", "Leilani", "Matteo", "Freya", "Sofia", "Khalil", "Yael", "Chidi"
	]
	for id: int in count:
		names[id] = bot_names[maxi(0, id - 1)]
		avatars[id] = paths[id]
	var latest: Dictionary[int, PublicActionRecord] = {}
	for action: PublicActionRecord in view.action_history:
		latest[action.seat] = action
	var lines: Array[String] = []
	for index: int in 30:
		lines.append("Public event %d: player raises to 1000000" % index)
	return TableViewModel.build(
		view, names, avatars, latest, {}, lines, GuiFitCandidate.Density.COMPACT
	)
