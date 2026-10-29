extends SceneTree

## Isolated component review; this fixture does not represent a table layout.
const Palette := preload("res://resources/gui_theme.tres")
const TokenScene := preload("res://scenes/gui/components/SeatToken.tscn")
const BarScene := preload("res://scenes/gui/components/ActionBar.tscn")
const LogScene := preload("res://scenes/gui/components/EventLog.tscn")
const HostScene := preload("res://scenes/gui/components/OverlayHost.tscn")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const CardAssertions := preload("res://tests/support/gui_snapshot_content_assertions.gd")
const OUTPUT: String = "res://localtmp/gui-elements/rg42-rg45-review4-"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	var gallery: SubViewport = _surface(Vector2i(1600, 1300))
	var layer: Control = gallery.get_node("Layer")
	var stack := VBoxContainer.new()
	stack.position = Vector2(32, 24)
	stack.size = Vector2(1536, 1252)
	stack.add_theme_constant_override("separation", 20)
	layer.add_child(stack)
	_label(stack, "RG-42–RG-45 · component review", &"HeadingText")
	_label(
		stack, "Phone tokens, action controls and public history; overlays are shown separately."
	)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	stack.add_child(columns)
	var phone := VBoxContainer.new()
	phone.custom_minimum_size.x = 480
	phone.theme = GuiTypography.Compact
	phone.add_theme_constant_override("separation", 12)
	columns.add_child(phone)
	_label(phone, "Phone components · six opponents", &"HeadingText")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	phone.add_child(grid)
	for index: int in 6:
		var token: GuiSeatToken = TokenScene.instantiate()
		token.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(token)
		token.render(_seat(index))
	_label(phone, "Your cards and touch actions")
	var compact: GuiActionBar = BarScene.instantiate()
	compact.compact_controls = true
	phone.add_child(compact)
	compact.use_keypad(true)
	compact.render(_actions(true))
	compact.render_hero(_seat(6))
	var wide := VBoxContainer.new()
	wide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wide.theme = GuiTypography.Regular
	wide.add_theme_constant_override("separation", 16)
	columns.add_child(wide)
	_label(wide, "Keyboard actions · inline wager total", &"HeadingText")
	var keyboard: GuiActionBar = BarScene.instantiate()
	wide.add_child(keyboard)
	keyboard.set_wager_draft("1000000")
	keyboard.render(_actions(false))
	_label(wide, "Docked event log · the same history opens from More")
	var log: GuiEventLog = LogScene.instantiate()
	wide.add_child(log)
	log.render(_history())
	_label(wide, "More opens Log, Pots / Summary and Quit.")
	_label(wide, "Number entry keeps a local draft until Done.")
	_label(
		stack,
		"Component review only. Table composition, gameplay and device acceptance follow later."
	)
	await _save(gallery, "components")
	await _history_resize_preview()
	for kind: StringName in [
		&"menu", &"summary", &"portrait-number", &"landscape-number", &"compact-landscape-number"
	]:
		var dimensions := Vector2i(390, 844)
		if kind == &"landscape-number":
			dimensions = Vector2i(844, 330)
		elif kind == &"compact-landscape-number":
			dimensions = Vector2i(568, 330)
		var viewport: SubViewport = _surface(dimensions)
		var backdrop: Control = viewport.get_node("Layer")
		_label(backdrop, "RG-45 · %s preview" % str(kind))
		var host: GuiOverlayHost = HostScene.instantiate()
		backdrop.add_child(host)
		host.set_usable_rect(Rect2(Vector2.ZERO, Vector2(dimensions)))
		host.render_log(_history())
		host.render_summary(_summary_model())
		match kind:
			&"menu":
				host.open_menu()
			&"summary":
				host.open_summary(_summary_model())
			_:
				var number := NumberEntryViewModel.new()
				number.title = "Raise total"
				number.value = "1000000"
				number.minimum = 1000000
				number.maximum = 9000000
				number.show_presets = true
				number.minimum_preset = "1000000"
				number.pot_preset = "3000000"
				number.minimum_label = "Min"
				number.pot_label = "Pot"
				number.pot_enabled = true
				host.open_number(number)
		await _save(viewport, str(kind))
	quit(0 if _failures.is_empty() else 1)


func _history_resize_preview() -> void:
	var viewport: SubViewport = _surface(Vector2i(1120, 640))
	var layer: Control = viewport.get_node("Layer")
	var heading := Label.new()
	heading.position = Vector2(24, 16)
	heading.text = "Event history · same public copy, different box allocations"
	heading.theme_type_variation = &"HeadingText"
	layer.add_child(heading)
	for index: int in 2:
		var slot := VBoxContainer.new()
		slot.position = Vector2(24, 72) if index == 0 else Vector2(420, 72)
		slot.size = Vector2(360, 260) if index == 0 else Vector2(676, 530)
		layer.add_child(slot)
		var log: GuiEventLog = LogScene.instantiate()
		slot.add_child(log)
		log.render(_history())
	await _save(viewport, "history-resize")


func _surface(dimensions: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("0b271b")
	background.size = Vector2(dimensions)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var layer := Control.new()
	layer.name = "Layer"
	layer.theme = Palette
	layer.size = Vector2(dimensions)
	viewport.add_child(layer)
	return viewport


func _save(viewport: SubViewport, title: String) -> void:
	for frame: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var failures := PackedStringArray()
	var controls: Array[Dictionary] = []
	var cards: Array[Dictionary] = []
	var layer: Control = viewport.get_node("Layer")
	for node: Node in layer.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		var path: String = str(layer.get_path_to(control))
		if not bounds.encloses(control.get_global_rect()):
			failures.append("escaped: " + path)
		var font_size: int = 0
		if control is BaseButton:
			if control.size.x < 48.0 or control.size.y < 48.0:
				failures.append("target below 48: " + path)
			font_size = control.get_theme_font_size("font_size")
			if font_size < 20:
				failures.append("action below 20: " + path)
		elif control is Label or control is LineEdit:
			font_size = control.get_theme_font_size("font_size")
			var floor_size: int = (
				18 if str(control.theme_type_variation).begins_with("Token") else 20
			)
			if font_size < floor_size:
				failures.append("copy below %d: %s" % [floor_size, path])
			if control is LineEdit:
				Invariants.validate_element(
					GuiSnapshotMeasurement.element(control, layer, &"number-value"), failures
				)
		elif control is RichTextLabel:
			font_size = control.get_theme_font_size("normal_font_size")
			var floor_size: int = 18 if control.get_parent() is GuiEventLog else 20
			if font_size < floor_size:
				failures.append("rich copy below %d: %s" % [floor_size, path])
		if control is GuiPlayingCard:
			var card: GuiCardSnapshot = control.get_card_snapshot(layer, &"capture", true)
			if card.element.rect.size.x / card.element.rect.size.y < 5.0 / 7.0:
				failures.append("card aspect: " + path)
			if card.kind == GuiCardSnapshot.Kind.FACE:
				CardAssertions.validate_card(card, path, failures)
			cards.append(
				{
					"path": path,
					"kind": card.kind,
					"rect": _rect(card.element.rect),
					"rank": card.rank.text,
					"suit": card.suit.text,
					"rank_ink": _rect(card.rank.rect),
					"suit_ink": _rect(card.suit.rect),
					"rank_font": card.rank.font_size,
					"suit_font": card.suit.font_size
				}
			)
		controls.append({"path": path, "rect": _rect(control.get_global_rect()), "font": font_size})
	var output: String = OUTPUT + title
	var save_error: Error = viewport.get_texture().get_image().save_png(output + ".png")
	if save_error != OK:
		failures.append("PNG save error: %s" % save_error)
	var metadata := FileAccess.open(output + ".json", FileAccess.WRITE)
	if metadata == null:
		_failures.append("Cannot save metadata: " + title)
	else:
		metadata.store_string(
			JSON.stringify(
				{
					"image": output + ".png",
					"size": [viewport.size.x, viewport.size.y],
					"save_error": save_error,
					"failures": failures,
					"controls": controls,
					"cards": cards,
					"source_sha256": _hashes(),
					"component_review_only": true,
					"device_acceptance": false,
					"finished_table_layout": false,
					"maximum_seats_per_row": 2
				},
				"\t"
			)
		)
	_failures.append_array(failures)
	print("Capture ", title, ": ", failures.size(), " failures; save ", save_error)
	viewport.queue_free()
	await process_frame


func _hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [
		"tests/visual/gui_phase4_capture.gd",
		"resources/gui_theme.tres",
		"resources/gui_typography_compact.tres",
		"resources/gui_typography_regular.tres",
		"scenes/gui/components/SeatToken.tscn",
		"scripts/gui/components/gui_seat_token.gd",
		"scenes/gui/components/ActionBar.tscn",
		"scripts/gui/components/gui_action_bar.gd",
		"scripts/gui/layout/gui_action_rows.gd",
		"scenes/gui/components/HeroActionSummary.tscn",
		"scripts/gui/components/gui_hero_action_summary.gd",
		"scenes/gui/components/EventLog.tscn",
		"scripts/gui/components/gui_event_log.gd",
		"scenes/gui/components/OverlayHost.tscn",
		"scripts/gui/components/gui_overlay_host.gd",
		"scripts/gui/gui_modal_guard.gd",
		"scripts/gui/gui_snapshot_measurement.gd",
		"scenes/gui/components/NumericKeypad.tscn",
		"scripts/gui/components/gui_numeric_keypad.gd",
		"scripts/gui/view_models/seat_view_model.gd",
		"scripts/gui/view_models/action_bar_view_model.gd",
		"scripts/gui/view_models/event_log_view_model.gd",
		"scripts/gui/view_models/hand_summary_view_model.gd",
		"scripts/gui/view_models/number_entry_view_model.gd",
		"scripts/gui/components/gui_hole_cards.gd",
		"scripts/gui/components/gui_playing_card.gd"
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _seat(index: int) -> SeatViewModel:
	var model := SeatViewModel.new()
	model.valid = true
	model.seat = index
	model.display_name = ["Emiliano", "Leilani", "Matteo", "Freya", "Sofia", "Khalil", "You"][index]
	model.stack_value_text = "9000000"
	model.stack_text = "9000000"
	model.wager_text = "Bet 1000000"
	model.cards = CardRowViewModel.new()
	model.cards.cards = [CardViewModel.back(), CardViewModel.back()]
	match index:
		0:
			model.acting = true
			model.is_dealer = true
			model.is_small_blind = true
			model.status_text = "Raise to 1000000"
		1:
			model.is_big_blind = true
			model.status_text = "Call to 1000000"
		2:
			model.folded = true
			model.status_text = "Fold"
			model.cards.cards = [CardViewModel.empty(), CardViewModel.empty()]
		3:
			model.all_in = true
			model.stack_text = "0"
			model.stack_value_text = "0"
			model.status_text = "All In to 1000000"
		4, 5:
			model.winner_emphasis = true
			model.status_compact = (
				"Full house\nQueens / Sevens" if index == 4 else "Two pair\nAces / Kings"
			)
			model.cards.cards = _faces()
		6:
			model.is_hero = true
			model.cards.cards = _faces()
	return model


func _faces() -> Array[CardViewModel]:
	return [
		CardViewModel.face(CardData.new(10, CardData.Suit.SPADES)),
		CardViewModel.face(CardData.new(14, CardData.Suit.HEARTS))
	]


func _actions(compact: bool) -> ActionBarViewModel:
	var model := ActionBarViewModel.new()
	model.valid = true
	model.is_human_turn = true
	model.can_wager = true
	for role: String in ["fold", "check_call", "minimum", "pot", "wager", "all_in"]:
		model.set(role + "_enabled", true)
		model.set(role + "_visible", true)
		model.set("phone_" + role + "_visible", role not in ["minimum", "pot"])
	model.check_call_text = "Call 1000000"
	model.minimum_text = "Min Raise 1000000"
	model.pot_text = "Pot 3000000"
	model.wager_text = "Raise"
	model.all_in_text = "All In"
	model.input_placeholder = "Total" if compact else "Wager total"
	model.status_text = "Your turn — Pre-flop."
	model.phone_status_text = "Your turn: Pre-flop"
	return model


func _history() -> EventLogViewModel:
	return EventLogViewModel.from_lines(
		[
			"Hand 12 · Pre-flop",
			"Emiliano posts small blind 500000",
			"Leilani posts big blind 1000000",
			"You raise to 1000000",
			"Matteo calls to 1000000",
			"Freya folds",
			"Sofia is All In to 1000000",
			"Main pot (6000000): Sofia +3000000, Khalil +3000000",
			"Side pot (2000000): Khalil +2000000"
		]
	)


func _summary_model() -> HandSummaryViewModel:
	var model := HandSummaryViewModel.new()
	model.visible = true
	model.lines = [
		HandSummaryLineViewModel.create(
			"Main pot (6000000): Sofia +3000000, Khalil +3000000", true
		),
		HandSummaryLineViewModel.create("Side pot (2000000): Khalil +2000000", true),
		HandSummaryLineViewModel.create("Sofia — Full house: Queens full of Sevens", true),
		HandSummaryLineViewModel.create("Khalil — Two pair: Aces and Kings", true)
	]
	var lines := PackedStringArray()
	for line: HandSummaryLineViewModel in model.lines:
		lines.append(line.text)
	model.text = "\n".join(lines)
	return model


func _label(parent: Node, copy: String, variation: StringName = &"BodyText") -> void:
	var label := Label.new()
	label.text = copy
	label.theme_type_variation = variation
	parent.add_child(label)


func _rect(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
