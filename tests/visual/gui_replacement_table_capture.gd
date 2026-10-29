extends SceneTree

## Combined controller/composition review evidence from explicit safe fixtures.
const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	if OS.get_cmdline_user_args().has("--review2"):
		await _capture("review2-phone-landscape-3", 3, Vector2i(844, 390), &"human-turn-flop")
		await _capture(
			"review2-phone-landscape-safe-3",
			3,
			Vector2i(844, 390),
			&"human-turn-flop",
			&"",
			Rect2(44, 0, 756, 369)
		)
		await _capture("review2-phone-landscape-2", 2, Vector2i(1024, 768), &"human-turn-flop")
		await _capture("review2-phone-portrait-4", 4, Vector2i(390, 844), &"human-turn-flop")
		await _capture("review2-phone-portrait-6", 6, Vector2i(480, 1040), &"human-turn-flop")
		quit(1 if _failed else 0)
		return
	await _capture("wide-6", 6, Vector2i(1600, 1200), &"human-turn-flop")
	await _capture("wide-9", 9, Vector2i(1920, 1300), &"showdown-long")
	await _capture("phone-portrait-4", 4, Vector2i(390, 844), &"human-turn-flop")
	await _capture("phone-landscape-2", 2, Vector2i(844, 430), &"human-turn-flop")
	await _capture("phone-menu", 4, Vector2i(390, 844), &"human-turn-flop", &"menu")
	await _capture("phone-number", 4, Vector2i(390, 844), &"human-turn-flop", &"keypad")
	await _capture("phone-6-guidance", 6, Vector2i(390, 844), &"human-turn-flop")
	quit(1 if _failed else 0)


func _capture(
	label: String,
	count: int,
	allocation: Vector2i,
	state: StringName,
	modal: StringName = &"",
	usable: Rect2 = Rect2()
) -> void:
	var viewport := SubViewport.new()
	viewport.size = allocation
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("0b271b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.size = Vector2(allocation)
	viewport.add_child(background)
	var table: GuiReplacementTableController = TableScene.instantiate()
	table.touch_entry = label.contains("phone")
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(allocation)
	viewport.add_child(table)
	table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(allocation), usable))
	var fixture: Dictionary = (
		GuiVisualStateFixtures.replacement_flop(count)
		if state == &"human-turn-flop"
		else GuiVisualStateFixtures.by_id(state, count)
	)
	var names: Dictionary[int, String] = {}
	var avatars: Dictionary[int, String] = {}
	var labels: Array[String] = [
		"Human", "Emiliano", "Leilani", "Matteo", "Freya", "Sofia", "Khalil", "Yael", "Chidi"
	]
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	for id: int in count:
		names[id] = labels[id]
		avatars[id] = paths[id % paths.size()]
	var lines: Array[String] = []
	for index: int in 40:
		lines.append("Public event %d: player calls 10" % (index + 1))
	table.bind_view(fixture.view, avatars, names, lines)
	var failures := PackedStringArray()
	if not await _settle(table):
		failures.append("controller did not settle")
	if modal == &"menu":
		table.open_menu()
	elif modal == &"keypad" and table.get_composition() != null:
		table.get_composition().entry_requested.emit("20")
	for frame: int in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	var expected: Array[StringName] = []
	if not modal.is_empty():
		expected.append(modal)
	failures.append_array(Invariants.validate_snapshot(snapshot, expected))
	if label.ends_with("guidance"):
		if snapshot.ready or snapshot.fit_guidance.is_empty():
			failures.append("expected preserved-state guidance")
	elif not snapshot.ready:
		failures.append("expected supported composition")
	var path: String = "res://localtmp/gui-elements/rg53-" + label
	var save_error: Error = viewport.get_texture().get_image().save_png(path + ".png")
	if save_error != OK:
		failures.append("image save failed: " + str(save_error))
	var hashes: Dictionary = {}
	for source: String in [
		"scripts/gui/gui_replacement_table_controller.gd",
		"scripts/gui/gui_table_session.gd",
		"scenes/gui/ReplacementPokerTable.tscn",
		"scripts/gui/layout/gui_composition_host.gd",
		"scripts/gui/compositions/gui_wide_table_layout.gd",
		"scripts/gui/compositions/gui_phone_table_layout.gd",
		"scripts/gui/layout/gui_phone_table_plan.gd",
		"scripts/gui/layout/gui_phone_landscape_plan.gd",
		"scripts/gui/layout/gui_phone_landscape_container.gd",
		"scripts/gui/layout/gui_fit_policy.gd",
		"scripts/gui/layout/gui_seat_ring_container.gd",
		"scripts/gui/layout/gui_seat_ring_plan.gd",
		"scripts/gui/components/gui_overlay_host.gd",
		"scripts/gui/components/gui_numeric_keypad.gd",
		"scripts/gui/components/gui_card_ink.gd",
		"scripts/gui/components/gui_card_glyphs.gd",
		"scripts/gui/components/gui_card_back.gd",
		"scripts/gui/components/gui_seat_star.gd",
		"scenes/gui/components/CardBack.tscn",
		"assets/ui/club.svg",
		"assets/ui/diamond.svg",
		"assets/ui/heart.svg",
		"assets/ui/spade.svg",
		"assets/ui/winner_star.svg",
		"scripts/gui/view_models/number_entry_view_model.gd",
		"scripts/gui/components/gui_action_bar.gd",
		"scripts/gui/components/gui_center_board.gd",
		"scripts/gui/components/gui_event_log.gd",
		"scripts/gui/components/gui_seat_token.gd",
		"scenes/gui/layouts/WideTableLayout.tscn",
		"scenes/gui/layouts/PhoneTableLayout.tscn",
		"scenes/gui/layouts/PhoneLandscapeLayout.tscn",
		"resources/gui_table_logo_material.tres",
		"resources/gui_logo_texture.tres",
		"assets/images/Pokahdot_logo.png",
		"resources/gui_theme.tres",
		"resources/gui_typography_compact.tres",
		"resources/gui_typography_regular.tres",
		"tests/support/gui_visual_state_fixtures.gd",
		"tests/visual/gui_replacement_table_capture.gd"
	]:
		hashes[source] = FileAccess.get_sha256("res://" + source)
	var metadata := FileAccess.open(path + ".json", FileAccess.WRITE)
	if metadata == null:
		failures.append("metadata save failed")
	else:
		metadata.store_string(
			JSON.stringify(
				{
					"allocation": [allocation.x, allocation.y],
					"usable_rect":
					[
						snapshot.usable_rect.position.x,
						snapshot.usable_rect.position.y,
						snapshot.usable_rect.size.x,
						snapshot.usable_rect.size.y
					],
					"fixture": state,
					"player_count": count,
					"ready": snapshot.ready,
					"guidance": snapshot.fit_guidance,
					"mode": snapshot.layout_mode,
					"rows": snapshot.seat_rows,
					"modal": modal,
					"failures": failures,
					"save_error": save_error,
					"counters": table.get_render_counters(),
					"source_sha256": hashes,
					"synthetic_recipient_safe_fixture": true,
					"default_cutover": false,
					"device_acceptance": false
				},
				"\t"
			)
		)
	print(path, "; failures=", failures)
	_failed = _failed or not failures.is_empty()
	viewport.queue_free()
	await process_frame


func _settle(table: GuiReplacementTableController) -> bool:
	for frame: int in 180:
		await process_frame
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		if not snapshot.pending and (snapshot.ready or not snapshot.fit_guidance.is_empty()):
			return true
	return false
