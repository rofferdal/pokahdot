extends SceneTree

## Independent review fixture of actual reusable card scenes.
const CardScene := preload("res://scenes/gui/components/PlayingCard.tscn")
const RowScene := preload("res://scenes/gui/components/CardRow.tscn")
const CenterScene := preload("res://scenes/gui/components/CenterBoard.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const OUTPUT: String = "res://localtmp/gui-elements/rg40-card-components"

var _cards: Array[GuiPlayingCard] = []
var _roles: Array[String] = []


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("0b271b")
	background.size = Vector2(viewport.size)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var stack := VBoxContainer.new()
	stack.position = Vector2(32, 24)
	stack.size = Vector2(1136, 952)
	stack.theme = Palette
	stack.add_theme_constant_override("separation", 16)
	viewport.add_child(stack)
	_label(stack, "Reusable cards & center board", &"HeadingText")
	var boards := HBoxContainer.new()
	boards.add_theme_constant_override("separation", 24)
	stack.add_child(boards)
	_add_center(boards, "Wide center board", Vector2(720, 330), false)
	_add_center(boards, "Compact center board", Vector2(340, 330), true)
	_label(stack, "Faces, hidden cards & reserved slots", &"HeadingText")
	var samples := HBoxContainer.new()
	samples.alignment = BoxContainer.ALIGNMENT_CENTER
	samples.add_theme_constant_override("separation", 20)
	stack.add_child(samples)
	var models: Array[CardViewModel] = [
		_face("10", "♠", 3),
		_face("A", "♥", 2),
		_face("10", "♣", 0),
		_face("K", "♦", 1),
		CardViewModel.back(),
		CardViewModel.empty()
	]
	var captions: Array[String] = ["Spades", "Hearts", "Clubs", "Diamonds", "Hidden", "Empty"]
	for index: int in models.size():
		var cell := VBoxContainer.new()
		samples.add_child(cell)
		var card: GuiPlayingCard = CardScene.instantiate()
		card.custom_minimum_size = Vector2(120, 160)
		cell.add_child(card)
		card.render(models[index])
		# The fixture supplies an allocation; the card still owns its measured floor.
		card.custom_minimum_size = card.custom_minimum_size.max(Vector2(120, 160))
		_track(card, "sample/%s" % captions[index])
		_label(cell, captions[index], &"BodyText", HORIZONTAL_ALIGNMENT_CENTER)
	_label(stack, "The same card row reused for hands", &"HeadingText")
	var hands := HBoxContainer.new()
	hands.alignment = BoxContainer.ALIGNMENT_CENTER
	hands.add_theme_constant_override("separation", 56)
	stack.add_child(hands)
	_add_hand(hands, "Your cards", [_face("A", "♠", 3), _face("10", "♥", 2)])
	_add_hand(hands, "Opponent cards", [CardViewModel.back(), CardViewModel.back()])
	_add_hand(hands, "Reserved minimum", [CardViewModel.empty(), CardViewModel.empty()], true)
	_label(stack, "Cards retain readable glyphs and proportions as their containers change.")
	for frame: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var observations: Array[Dictionary] = []
	var failures := PackedStringArray()
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	for node: Node in stack.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and not bounds.encloses(control.get_global_rect()):
			failures.append("escaped: %s" % stack.get_path_to(control))
	for index: int in _cards.size():
		var card: GuiPlayingCard = _cards[index]
		var snapshot: GuiCardSnapshot = card.get_card_snapshot(
			stack, StringName(_roles[index]), true
		)
		var rect: Rect2 = snapshot.element.rect
		if rect.size.x / rect.size.y < 5.0 / 7.0:
			failures.append("narrow card: %s" % _roles[index])
		var observation: Dictionary = {
			"role": _roles[index],
			"kind": snapshot.kind,
			"surface": _rect(rect),
			"minimum": [card.get_combined_minimum_size().x, card.get_combined_minimum_size().y],
			"rank": snapshot.rank.text,
			"suit": snapshot.suit.text,
			"font_size": snapshot.rank.font_size,
			"rank_ink": _rect(snapshot.rank.rect),
			"suit_ink": _rect(snapshot.suit.rect)
		}
		if snapshot.kind == GuiCardSnapshot.Kind.FACE:
			if snapshot.rank.font_size < 20 or snapshot.suit.font_size < 20:
				failures.append("font floor: %s" % _roles[index])
			if not rect.encloses(snapshot.rank.rect) or not rect.encloses(snapshot.suit.rect):
				failures.append("escaped ink: %s" % _roles[index])
		observations.append(observation)
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	var error: Error = viewport.get_texture().get_image().save_png(OUTPUT + ".png")
	var metadata := FileAccess.open(OUTPUT + ".json", FileAccess.WRITE)
	if metadata == null:
		push_error("Cannot save card-component capture metadata.")
		quit(1)
		return
	var hashes: Dictionary = {}
	for path: String in [
		"scenes/gui/components/PlayingCard.tscn",
		"scenes/gui/components/CardFace.tscn",
		"scenes/gui/components/CardBack.tscn",
		"scenes/gui/components/CardRow.tscn",
		"scenes/gui/components/CenterBoard.tscn",
		"scripts/gui/components/gui_playing_card.gd",
		"scripts/gui/components/gui_card_face.gd",
		"scripts/gui/components/gui_card_back.gd",
		"scripts/gui/components/gui_card_row.gd",
		"scripts/gui/components/gui_card_glyphs.gd",
		"scripts/gui/components/gui_card_ink.gd",
		"scripts/gui/components/gui_center_board.gd",
		"scripts/gui/view_models/card_view_model.gd",
		"scripts/gui/view_models/card_row_view_model.gd",
		"scripts/gui/view_models/center_view_model.gd",
		"scripts/gui/gui_snapshot_measurement.gd",
		"resources/gui_theme.tres",
		"resources/gui_typography_compact.tres",
		"resources/gui_typography_regular.tres",
		"tests/visual/gui_card_components_capture.gd"
	]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	metadata.store_string(
		JSON.stringify(
			{
				"image": OUTPUT + ".png",
				"save_error": error,
				"failures": failures,
				"cards": observations,
				"source_sha256": hashes,
				"device_acceptance": false,
				"size": [1200, 1000]
			},
			"\t"
		)
	)
	viewport.queue_free()
	quit(0 if error == OK and failures.is_empty() else 1)


func _add_center(parent: Node, title: String, allocation: Vector2, compact: bool) -> void:
	var cell := VBoxContainer.new()
	parent.add_child(cell)
	_label(cell, title, &"BodyText", HORIZONTAL_ALIGNMENT_CENTER)
	var center: GuiCenterBoard = CenterScene.instantiate()
	center.custom_minimum_size = allocation
	cell.add_child(center)
	var model := CenterViewModel.new()
	model.valid = true
	model.board = CardRowViewModel.new()
	model.board.cards = [
		_face("10", "♠", 3),
		_face("A", "♥", 2),
		_face("7", "♣", 0),
		CardViewModel.empty(),
		CardViewModel.empty()
	]
	model.phone_pot_text = "Pot: 9,000,000" if compact else "Pot: 240"
	model.phone_wager_text = "Current wager: 1,000,000" if compact else "Current wager: 40"
	model.blind_level_text = (
		"Blinds 500,000 / 1,000,000 · Level 64 · 10 hands to next level"
		if compact
		else "Blinds 5 / 10 · Level 1 · 8 hands to next level"
	)
	center.render(model)
	for index: int in (center.get_node("Cards") as GuiCardRow).cards.size():
		_track((center.get_node("Cards") as GuiCardRow).cards[index], "%s/%d" % [title, index])


func _add_hand(
	parent: Node, title: String, models: Array[CardViewModel], minimum: bool = false
) -> void:
	var cell := VBoxContainer.new()
	parent.add_child(cell)
	_label(cell, title, &"BodyText", HORIZONTAL_ALIGNMENT_CENTER)
	var row: GuiCardRow = RowScene.instantiate()
	if not minimum:
		row.custom_minimum_size = Vector2(180, 120)
	cell.add_child(row)
	var model := CardRowViewModel.new()
	model.cards = models
	row.render(model)
	for index: int in row.cards.size():
		_track(row.cards[index], "%s/%d" % [title, index])


func _track(card: GuiPlayingCard, role: String) -> void:
	_cards.append(card)
	_roles.append(role)


func _face(rank: String, suit: String, suit_id: int) -> CardViewModel:
	var model := CardViewModel.new()
	model.state = CardViewModel.State.FACE
	model.rank_text = rank
	model.suit_text = suit
	model.suit = suit_id
	return model


func _label(
	parent: Node,
	copy: String,
	variation: StringName = &"BodyText",
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	var label := Label.new()
	label.text = copy
	label.theme_type_variation = variation
	label.horizontal_alignment = align
	parent.add_child(label)


func _rect(value: Rect2) -> Array[float]:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
