extends SceneTree

## Internal measured phone evidence; physical-device acceptance remains separate.
const Portrait := preload("res://scenes/gui/layouts/PhoneTableLayout.tscn")
const Landscape := preload("res://scenes/gui/layouts/PhoneLandscapeLayout.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
var _failed: bool = false
var _review2: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	_review2 = OS.get_cmdline_user_args().has("--review2")
	if _review2:
		await _capture(4, false, true, Vector2(480, 1000))
		quit(1 if _failed else 0)
		return
	await _capture(4, false, false, Vector2(390, 844))
	await _capture(6, false, false, Vector2(390, 1100))
	await _capture(3, true, false, Vector2(844, 390))
	await _capture(4, false, true, Vector2(480, 1000))
	quit(1 if _failed else 0)


func _capture(count: int, landscape: bool, large: bool, allocation: Vector2) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(allocation + Vector2(0, 40))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("0b271b")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var layer := Control.new()
	layer.theme = Palette
	layer.size = Vector2(viewport.size)
	viewport.add_child(layer)
	var title := Label.new()
	title.theme_type_variation = &"BodyText"
	title.text = "RG-52 · %d seats · %s" % [count, "large values" if large else "measured fit"]
	title.position = Vector2(8, 6)
	layer.add_child(title)
	var layout: GuiPhoneTableLayout = (Landscape if landscape else Portrait).instantiate()
	layout.theme = GuiTypography.Compact
	layout.position = Vector2(0, 40)
	layer.add_child(layout)
	layout.size = allocation
	layout.set_allocation_limit(allocation)
	layout.render(_model(count, large))
	layout.set_wager_draft("1000000" if large else "20")
	for frame: int in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var snapshot: GuiLayoutSnapshot = layout.get_layout_snapshot(layer)
	var failures: PackedStringArray = Invariants.validate_snapshot(snapshot)
	if not snapshot.ready:
		failures.append("expected measured-fit preview")
	var path: String = (
		"res://localtmp/gui-elements/rg52-%sphone-%s-%d%s"
		% [
			"review2-" if _review2 else "",
			"landscape" if landscape else "portrait",
			count,
			"-large" if large else ""
		]
	)
	var save_error: Error = viewport.get_texture().get_image().save_png(path + ".png")
	if save_error != OK:
		failures.append("save error: " + str(save_error))
	var hashes: Dictionary = {}
	for source: String in [
		"scenes/gui/layouts/PhoneTableLayout.tscn",
		"scenes/gui/layouts/PhoneLandscapeLayout.tscn",
		"scripts/gui/compositions/gui_phone_table_layout.gd",
		"scripts/gui/layout/gui_phone_table_plan.gd",
		"scripts/gui/layout/gui_phone_landscape_plan.gd",
		"scripts/gui/layout/gui_phone_landscape_container.gd",
		"tests/support/gui_visual_state_fixtures.gd",
		"scripts/gui/layout/gui_table_composition.gd",
		"scripts/gui/gui_layout_snapshot.gd",
		"scenes/gui/components/SeatToken.tscn",
		"scripts/gui/components/gui_seat_token.gd",
		"scenes/gui/components/CenterBoard.tscn",
		"scripts/gui/components/gui_center_board.gd",
		"scenes/gui/components/ActionBar.tscn",
		"scripts/gui/components/gui_action_bar.gd",
		"scenes/gui/components/BrandLogo.tscn",
		"resources/gui_table_logo_material.tres",
		"resources/gui_logo_texture.tres",
		"assets/images/Pokahdot_logo.png",
		"resources/gui_theme.tres",
		"resources/gui_typography_compact.tres",
		"resources/gui_typography_regular.tres",
		"tests/visual/gui_phone_table_capture.gd"
	]:
		hashes[source] = FileAccess.get_sha256("res://" + source)
	var minimum: Vector2 = layout.get_combined_minimum_size()
	var output := FileAccess.open(path + ".json", FileAccess.WRITE)
	if output == null:
		failures.append("unable to save metadata")
	else:
		output.store_string(
			JSON.stringify(
				{
					"size": [viewport.size.x, viewport.size.y],
					"usable_size": [allocation.x, allocation.y],
					"minimum": [minimum.x, minimum.y],
					"rows": snapshot.seat_rows,
					"seats": snapshot.seats.size(),
					"large_amounts": large,
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
	print(path, " min=", minimum, "; failures=", failures)
	_failed = _failed or not failures.is_empty()
	viewport.queue_free()
	await process_frame


func _model(count: int, large: bool) -> TableViewModel:
	var fixture: Dictionary = GuiVisualStateFixtures.replacement_flop(count)
	var view: GameView = fixture.view
	var names: Dictionary[int, String] = {}
	var bot_names: Array[String] = ["Emiliano", "Leilani", "Matteo", "Freya", "Sofia", "Khalil"]
	for id: int in 9:
		names[id] = "You" if id == 0 else bot_names[mini(id - 1, bot_names.size() - 1)]
	var latest: Dictionary[int, PublicActionRecord] = {}
	for action: PublicActionRecord in view.action_history:
		latest[action.seat] = action
	var model: TableViewModel = TableViewModel.build(
		view, names, {}, latest, {}, [], GuiFitCandidate.Density.COMPACT
	)
	model.seats.resize(count)
	if large:
		for seat: SeatViewModel in model.seats:
			seat.stack_value_text = "9000000"
			seat.wager_text = "Bet 1000000"
		model.center.phone_pot_text = "Pot: 6000000"
		model.center.phone_wager_text = "Current wager: 1000000"
		model.center.blind_level_text = "Blinds 500000 / 1000000 · Level 3 · 8 hands to next level"
		model.actions.check_call_text = "Call 1000000"
		model.actions.minimum_text = "Min Raise 2000000"
		model.actions.pot_text = "Pot 3000000"
	return model
