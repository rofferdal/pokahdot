extends SceneTree

## Independent review fixture of authored complete-seat components.
const SeatScene := preload("res://scenes/gui/components/SeatPanel.tscn")
const HeroScene := preload("res://scenes/gui/components/HeroPanel.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const OUTPUT: String = "res://localtmp/gui-elements/rg50s-seat-panels"

var _seats: Array[GuiSeatPanel] = []
var _states: Array[String] = []


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 1320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("0b271b")
	background.size = Vector2(viewport.size)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var palette_layer := Control.new()
	palette_layer.theme = Palette
	palette_layer.size = Vector2(viewport.size)
	viewport.add_child(palette_layer)
	var stack := VBoxContainer.new()
	stack.position = Vector2(32, 24)
	stack.size = Vector2(1376, 1272)
	stack.theme = GuiTypography.Regular
	stack.add_theme_constant_override("separation", 16)
	palette_layer.add_child(stack)
	_label(stack, "Seat panels & your player panel", &"HeadingText")
	_label(
		stack, "Three text lines, paired hole cards, upper-left avatars and a reserved status band."
	)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 20)
	stack.add_child(grid)
	var titles: Dictionary = {
		"normal": "Normal · dealer-only position marker",
		"acting": "Acting · separate dealer and small blind",
		"folded": "Folded · complete surface and avatar in grayscale",
		"all-in": "All In · exact wager copy",
		"split-winner": "Split-pot winner · bold result and large star",
		"side-winner": "Side-pot winner · the same winner emphasis",
		"fold-winner": "Fold winner · exact Winner copy",
		"hero": "Your panel · larger avatar and preferred text"
	}
	for state: String in titles:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 8)
		grid.add_child(cell)
		_label(cell, titles[state])
		var seat: GuiSeatPanel = (
			HeroScene.instantiate() if state == "hero" else SeatScene.instantiate()
		)
		seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(seat)
		seat.render(_model(state, _seats.size()))
		_seats.append(seat)
		_states.append(state)
	_label(
		stack, "Component review — final table compositions and device fit follow in later tasks."
	)
	for frame: int in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var failures := PackedStringArray()
	for node: Node in stack.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and not bounds.encloses(control.get_global_rect()):
			failures.append("escaped: %s" % stack.get_path_to(control))
	var observations: Array[Dictionary] = []
	for index: int in _seats.size():
		var seat: GuiSeatPanel = _seats[index]
		var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(stack)
		var state: String = _states[index]
		if (
			not snapshot.footprint.encloses(snapshot.panel.rect)
			or not snapshot.footprint.encloses(snapshot.status.rect)
		):
			failures.append("incomplete footprint: %s" % state)
		for element: GuiLayoutElement in snapshot.fields.values():
			Invariants.validate_element(element, failures)
		Invariants.validate_element(snapshot.status, failures)
		var inherited: bool = true
		for node: Node in seat.find_children("*", "CanvasItem", true, false):
			inherited = inherited and (node as CanvasItem).use_parent_material
		if state == "folded" and not inherited:
			failures.append("folded material inheritance: %s" % state)
		var avatar: TextureRect = seat.get_node("%Avatar")
		var star: Control = seat.get_node("%Winner")
		var dealer: Control = seat.get_node("%Dealer")
		var sb: Label = seat.get_node("%SB")
		var name_label: Label = seat.get_node("%Name")
		var card_observations: Array[Dictionary] = []
		for card: GuiCardSnapshot in snapshot.cards:
			if card.element.rect.size.x / card.element.rect.size.y < 5.0 / 7.0:
				failures.append("narrow card: %s" % state)
			if card.kind == GuiCardSnapshot.Kind.FACE and card.rank.font_size < 20:
				failures.append("card font floor: %s" % state)
			card_observations.append(
				{
					"kind": card.kind,
					"rect": _rect(card.element.rect),
					"rank": card.rank.text,
					"suit": card.suit.text,
					"font_size": card.rank.font_size
				}
			)
		observations.append(
			{
				"state": state,
				"seat": snapshot.seat_id,
				"hero": snapshot.hero,
				"footprint": _rect(snapshot.footprint),
				"panel": _rect(snapshot.panel.rect),
				"status": _rect(snapshot.status.rect),
				"status_text": snapshot.status.text,
				"status_font": snapshot.status.font_size,
				"avatar": _rect(avatar.get_global_rect()),
				"avatar_path": avatar.texture.resource_path if avatar.texture != null else "",
				"name_font": name_label.get_theme_font_size("font_size"),
				"winner": _rect(star.get_global_rect()),
				"winner_opacity": star.modulate.a,
				"dealer": _rect(dealer.get_global_rect()),
				"dealer_opacity": dealer.modulate.a,
				"small_blind": _rect(sb.get_global_rect()),
				"small_blind_visible": sb.visible,
				"big_blind": _rect((seat.get_node("%BB") as Control).get_global_rect()),
				"marker_font": sb.get_theme_font_size("font_size"),
				"star_font": star.get_theme_font_size("font_size"),
				"copy_lines": 3,
				"folded_material": seat.material != null,
				"all_materials_inherit": inherited,
				"cards": card_observations
			}
		)
	DirAccess.make_dir_recursive_absolute("res://localtmp/gui-elements")
	var error: Error = viewport.get_texture().get_image().save_png(OUTPUT + ".png")
	var metadata := FileAccess.open(OUTPUT + ".json", FileAccess.WRITE)
	if metadata == null:
		push_error("Cannot save seat-panel capture metadata.")
		quit(1)
		return
	var hashes: Dictionary = {}
	for path: String in [
		"scenes/gui/components/SeatPanel.tscn",
		"scenes/gui/components/HeroPanel.tscn",
		"scripts/gui/components/gui_seat_panel.gd",
		"scripts/gui/components/gui_seat_star.gd",
		"scenes/gui/components/HoleCards.tscn",
		"scripts/gui/components/gui_hole_cards.gd",
		"scenes/gui/components/CardRow.tscn",
		"scenes/gui/components/PlayingCard.tscn",
		"scripts/gui/components/gui_card_row.gd",
		"scripts/gui/components/gui_playing_card.gd",
		"scripts/gui/components/gui_card_glyphs.gd",
		"scripts/gui/components/gui_card_ink.gd",
		"scripts/gui/view_models/seat_view_model.gd",
		"scripts/gui/gui_snapshot_measurement.gd",
		"resources/gui_theme.tres",
		"resources/gui_typography_compact.tres",
		"resources/gui_typography_regular.tres",
		"resources/gui_grayscale.gdshader",
		"resources/gui_grayscale_material.tres",
		"tests/visual/gui_seat_components_capture.gd"
	]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	metadata.store_string(
		JSON.stringify(
			{
				"image": OUTPUT + ".png",
				"size": [1440, 1320],
				"save_error": error,
				"failures": failures,
				"seats": observations,
				"source_sha256": hashes,
				"maximum_seats_per_row": 2,
				"device_acceptance": false
			},
			"\t"
		)
	)
	viewport.queue_free()
	quit(0 if error == OK and failures.is_empty() else 1)


func _model(state: String, index: int) -> SeatViewModel:
	var model := SeatViewModel.new()
	model.valid = true
	model.seat = index
	model.display_name = [
		"Leilani", "Matteo", "Astrid", "Khalil", "Freya", "Emiliano", "Sofia", "You"
	][index]
	model.avatar_path = "res://assets/avatars/avatar_%02d.png" % (index % 4 + 1)
	model.stack_text = "1000000" if state == "normal" else "940 chips"
	model.stack_value_text = "1000000" if state == "normal" else "940"
	model.is_dealer = state == "normal"
	model.wager_text = "Bet 60"
	model.cards = CardRowViewModel.new()
	model.cards.cards = [CardViewModel.back(), CardViewModel.back()]
	match state:
		"acting":
			model.acting = true
			model.is_dealer = true
			model.is_small_blind = true
			model.state_text = "Turn"
			model.status_text = "Raise to 60"
		"folded":
			model.folded = true
			model.state_text = "Fold"
			model.status_text = "Fold"
			model.cards.cards = [CardViewModel.empty(), CardViewModel.empty()]
		"all-in":
			model.all_in = true
			model.state_text = "All In"
			model.stack_text = "0 chips"
			model.stack_value_text = "0"
			model.wager_text = "Bet 1000000"
			model.status_text = "All In to 1000000"
		"split-winner", "side-winner":
			model.winner_emphasis = true
			model.status_text = (
				"Two pair\nAces / Kings"
				if state == "split-winner"
				else "Full house: Queens full of Sevens"
			)
			model.cards.cards = [_face("A", "♠", 3), _face("10", "♥", 2)]
		"fold-winner":
			model.winner_emphasis = true
			model.pre_showdown_winner = true
			model.status_text = "Winner"
		"hero":
			model.is_hero = true
			model.is_big_blind = true
			model.cards.cards = [_face("A", "♠", 3), _face("10", "♥", 2)]
	return model


func _face(rank: String, suit: String, suit_id: int) -> CardViewModel:
	var model := CardViewModel.new()
	model.state = CardViewModel.State.FACE
	model.rank_text = rank
	model.suit_text = suit
	model.suit = suit_id
	return model


func _label(parent: Node, copy: String, variation: StringName = &"BodyText") -> void:
	var label := Label.new()
	label.text = copy
	label.theme_type_variation = variation
	parent.add_child(label)


func _rect(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
