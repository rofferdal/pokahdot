extends SceneTree

## Standalone ring evidence; controller/composition cutover is a later task.
const RingScene := preload("res://scenes/gui/layouts/SeatRingContainer.tscn")
const SeatScene := preload("res://scenes/gui/components/SeatPanel.tscn")
const HeroScene := preload("res://scenes/gui/components/HeroPanel.tscn")
const BoardScene := preload("res://scenes/gui/components/CenterBoard.tscn")
const ActionScene := preload("res://scenes/gui/components/ActionBar.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")
var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	for count: int in [6, 9]:
		await _capture(count)
	quit(1 if _failed else 0)


func _capture(count: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1800, 1400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b271b")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(backdrop)
	var layer := Control.new()
	layer.theme = Palette
	viewport.add_child(layer)
	var heading := Label.new()
	heading.position = Vector2(24, 16)
	heading.theme_type_variation = &"HeadingText"
	heading.text = "RG-50 · %d seats · standalone container review" % count
	layer.add_child(heading)
	var ring: GuiSeatRingContainer = RingScene.instantiate()
	ring.position = Vector2(24, 64)
	layer.add_child(ring)
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
	var model: TableViewModel = TableViewModel.build(view, names, avatars, latest, {}, [])
	var seats: Dictionary[int, Control] = {}
	for index: int in range(model.seats.size() - 1, -1, -1):
		var seat_model: SeatViewModel = model.seats[index]
		var seat: GuiSeatPanel = (HeroScene if seat_model.is_hero else SeatScene).instantiate()
		ring.add_child(seat)
		seat.render(seat_model)
		seats[seat_model.seat] = seat
	var board: GuiCenterBoard = BoardScene.instantiate()
	ring.add_child(board)
	board.render(model.center)
	var actions: GuiActionBar = ActionScene.instantiate()
	actions.custom_minimum_size.x = 600.0
	ring.add_child(actions)
	actions.render(model.actions)
	actions.set_wager_draft("20")
	if not ring.bind(seats, model.hero_seat, board, actions):
		_failed = true
	for frame: int in 12:
		await process_frame
	var minimum: Vector2 = ring.get_combined_minimum_size()
	ring.size = minimum.max(Vector2(1360, 850))
	viewport.size = Vector2i(ring.size.ceil() + Vector2(48, 88))
	layer.size = Vector2(viewport.size)
	backdrop.size = Vector2(viewport.size)
	for frame: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var failures := PackedStringArray()
	var plan: GuiSeatRingPlan = ring.get_layout_plan()
	if not plan.feasible:
		failures.append("infeasible: " + plan.error)
	var observations: Array[Dictionary] = []
	for id: int in seats:
		var seat := seats[id] as GuiSeatPanel
		var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(layer)
		for field: GuiLayoutElement in snapshot.fields.values():
			Invariants.validate_element(field, failures)
		Invariants.validate_element(snapshot.status, failures)
		for card: GuiCardSnapshot in snapshot.cards:
			if card.kind == GuiCardSnapshot.Kind.FACE:
				if not card.authorized:
					failures.append("unauthorized face")
				Content.validate_card(card, "ring", failures)
		observations.append(
			{
				"id": id,
				"visual_slot": plan.visual_slots.get(id),
				"footprint": _rect(snapshot.footprint),
				"status": snapshot.status.text
			}
		)
	for node: Node in layer.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if not Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(control.get_global_rect()):
			failures.append("escaped: " + str(layer.get_path_to(control)))
		# Seat fields already have their semantic 18px role checks above.
		var seat_copy: bool = false
		for seat: Control in seats.values():
			seat_copy = seat_copy or seat.is_ancestor_of(control)
		if control is Label and seat_copy:
			continue
		if control is BaseButton or control is Label or control is LineEdit:
			Invariants.validate_element(
				GuiSnapshotMeasurement.element(control, layer, &"ring-copy"), failures
			)
	var path: String = "res://localtmp/gui-elements/rg50s-seat-ring-review2-%d" % count
	var error: Error = viewport.get_texture().get_image().save_png(path + ".png")
	if error != OK:
		failures.append("save error: %d" % error)
	var hashes: Dictionary = {}
	for source: String in [
		"scripts/gui/layout/gui_seat_ring_container.gd",
		"scripts/gui/layout/gui_seat_ring_plan.gd",
		"scripts/gui/layout/gui_seat_slot_template.gd",
		"scenes/gui/layouts/SeatRingContainer.tscn",
		"resources/gui_theme.tres",
		"resources/gui_typography_compact.tres",
		"resources/gui_typography_regular.tres",
		"scripts/gui/components/gui_action_bar.gd",
		"scenes/gui/components/ActionBar.tscn",
		"scenes/gui/components/SeatPanel.tscn",
		"scenes/gui/components/HeroPanel.tscn",
		"scripts/gui/components/gui_seat_panel.gd",
		"tests/visual/gui_seat_ring_capture.gd"
	]:
		hashes[source] = FileAccess.get_sha256("res://" + source)
	for template_count: int in range(2, 10):
		var source: String = "resources/gui_seat_slots/seats_%d.tres" % template_count
		hashes[source] = FileAccess.get_sha256("res://" + source)
	var metadata := FileAccess.open(path + ".json", FileAccess.WRITE)
	if metadata == null:
		failures.append("metadata unavailable")
	else:
		metadata.store_string(
			JSON.stringify(
				{
					"size": [viewport.size.x, viewport.size.y],
					"minimum": [minimum.x, minimum.y],
					"rows": plan.rows,
					"seats": observations,
					"failures": failures,
					"save_error": error,
					"source_sha256": hashes,
					"standalone_container_review": true,
					"controller_cutover": false,
					"device_acceptance": false
				},
				"\t"
			)
		)
	_failed = _failed or not failures.is_empty()
	print("Ring ", count, ": minimum ", minimum, "; ", failures.size(), " failures")
	viewport.queue_free()
	await process_frame


func _rect(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
