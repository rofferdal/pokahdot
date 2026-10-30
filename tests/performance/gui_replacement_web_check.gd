extends Node

## Export-only read-only observer; all interactions travel through the canvas.
const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")
const Observer := preload("res://tests/performance/profiled_replacement_table.gd")
const CardScene := preload("res://scenes/gui/components/PlayingCard.tscn")
const Palette := preload("res://resources/gui_theme.tres")
var _table: GuiReplacementTableController
var _match: TournamentMatch
var _cards: Array[GuiPlayingCard] = []
var _back: GuiPlayingCard
var _stars: Array[GuiSeatStar] = []
var _root: Control
var _frames: int = 0
var _landscape: bool = false


class CallingAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		return (
			PlayerAction.check_action()
			if PlayerAction.Kind.CHECK in view.legal_actions
			else PlayerAction.call_action()
		)


func _ready() -> void:
	_landscape = (
		OS.has_feature("web")
		and bool(
			JavaScriptBridge.eval(
				"new URLSearchParams(location.search).get('layout') === 'landscape'"
			)
		)
	)
	get_window().content_scale_size = Vector2i(1000, 1000)
	_root = Control.new()
	_root.theme = Palette
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var background := ColorRect.new()
	background.color = Color("102d24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)
	var title := Label.new()
	title.text = "Exported replacement: real canvas input and minimum card suits"
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 22)
	_root.add_child(title)
	_table = TableScene.instantiate()
	_table.set_script(Observer)
	_table.touch_entry = true
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 0.0
	timing.showdown_pause_seconds = 0.0
	_table.action_timing_config = timing
	_table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.add_child(_table)
	_table.position = Vector2(20, 90)
	var logical_size := Vector2(844, 390) if _landscape else Vector2(390, 844)
	_table.size = logical_size
	_table.set_viewport_geometry(
		GuiViewportGeometry.injected(
			logical_size, Rect2(44, 0, 756, 369) if _landscape else Rect2()
		)
	)
	_table.set_layout_mode_override(
		GuiSizeClass.LayoutMode.PHONE_LANDSCAPE if _landscape else GuiSizeClass.LayoutMode.PHONE
	)
	_table.use_keypad(true)
	_table.set_wager_draft("0075")
	var agents: Dictionary[int, Agent] = {0: HumanAgent.new(), 1: CallingAgent.new()}
	var roles: Dictionary[int, StringName] = {0: &"human", 1: &"scripted"}
	if _landscape:
		agents[2] = CallingAgent.new()
		roles[2] = &"scripted"
	_match = TournamentMatch.new(
		ResolvedTournamentConfig.new(
			3 if _landscape else 2, 1000, 5, 10, 9123, &"single_table", roles
		),
		agents
	)
	_match.start()
	_table.bind_match(_match, 0, {}, {0: "Human", 1: "Emiliano", 2: "Leilani"})
	_table.set_wager_draft("0075")
	_gallery()


func _gallery() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(450, 530) if _landscape else Vector2(450, 120)
	column.size = Vector2(500, 240)
	_root.add_child(column)
	var label := Label.new()
	label.text = "Four suits at each card's native minimum"
	label.add_theme_font_size_override("font_size", 20)
	column.add_child(label)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	for suit: CardData.Suit in [
		CardData.Suit.CLUBS, CardData.Suit.DIAMONDS, CardData.Suit.HEARTS, CardData.Suit.SPADES
	]:
		var card: GuiPlayingCard = CardScene.instantiate()
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(card)
		card.render(CardViewModel.face(CardData.new([14, 10, 12, 13][suit], suit)))
		_cards.append(card)
	_back = CardScene.instantiate()
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_back)
	_back.render(CardViewModel.back())
	var note := Label.new()
	note.text = "Clubs     Diamonds     Hearts     Spades\nRank/suit nominal size must be at least 20."
	note.add_theme_font_size_override("font_size", 18)
	column.add_child(note)
	var star_label := Label.new()
	star_label.text = "Winner stars: 28 and 64"
	star_label.add_theme_font_size_override("font_size", 20)
	column.add_child(star_label)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 24)
	column.add_child(stars)
	for variation: StringName in [&"TokenWinnerStar", &"SeatWinnerStar"]:
		var star := GuiSeatStar.new()
		star.theme_type_variation = variation
		star.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stars.add_child(star)
		_stars.append(star)


func _process(_delta: float) -> void:
	if not OS.has_feature("web") or _table == null:
		return
	_frames += 1
	var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
	var controls: Dictionary = {}
	var composition: GuiTableComposition = _table.get_composition()
	if composition != null:
		for role: StringName in [&"more", &"wager", &"check_call"]:
			controls[str(role)] = _control(composition.get_control(role))
	var overlay: GuiOverlayHost = _table.get_overlay_host()
	controls["menu_close"] = _control(overlay.get_control(&"menu_close"))
	controls["cancel"] = _control(overlay.get_keypad().get_control(&"cancel"))
	controls["done"] = _control(overlay.get_keypad().get_control(&"done"))
	controls["clear"] = _control(overlay.get_keypad().get_control(&"clear"))
	controls["key2"] = _control(overlay.get_keypad().get_control(&"2"))
	controls["delete"] = _control(overlay.get_keypad().get_control(&"back"))
	var delete := overlay.get_keypad().get_control(&"back") as Button
	controls["delete"]["text"] = delete.text
	controls["delete"]["required_width"] = (
		delete
		. get_theme_font("font")
		. get_string_size(
			delete.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, delete.get_theme_font_size("font_size")
		)
		. x
	)
	controls["delete"]["font_size"] = delete.get_theme_font_size("font_size")
	var cards: Array[Dictionary] = []
	for card: GuiPlayingCard in _cards:
		var value: GuiCardSnapshot = card.get_card_snapshot(_root, &"gallery", true)
		cards.append(
			{
				"rank": value.rank.text,
				"suit": value.suit.text,
				"font_size": value.suit.font_size,
				"rank_ink": _rect(value.rank.rect),
				"suit_ink": _rect(value.suit.rect),
				"card": _rect(value.element.rect),
				"minimum": [card.get_combined_minimum_size().x, card.get_combined_minimum_size().y]
			}
		)
	var state: Dictionary = {
		"frame": _frames,
		"ready": snapshot.ready,
		"pending": snapshot.pending,
		"guidance": snapshot.fit_guidance,
		"overlay": str(overlay.get_active_kind()),
		"controls": controls,
		"cards": cards,
		"back": _card_state(_back, false),
		"stars": _star_state(),
		"raw_draft": _table.get_wager_draft(),
		"keypad_draft": overlay.get_keypad().get_draft(),
		"history_count": _match.get_view_for(0).action_history.size(),
		"geometry": _geometry_state(snapshot),
	}
	JavaScriptBridge.eval("window.pokahdotReplacementCheck = %s; void 0" % JSON.stringify(state))


func _geometry_state(snapshot: GuiLayoutSnapshot) -> Dictionary:
	# This gallery embeds a full-viewport controller at an offset. Normalize the
	# observed app-root rectangles back to its explicitly injected local geometry.
	var to_table: Transform2D = _table.get_global_transform_with_canvas().affine_inverse()
	var result: Dictionary = {
		"usable": _rect(snapshot.usable_rect),
		"surface": _rect(to_table * snapshot.surface_rect),
		"seats": [],
	}
	for id: int in snapshot.seats:
		var seat: GuiSeatSnapshot = snapshot.seats[id]
		result.seats.append({"id": id, "hero": seat.hero, "rect": _rect(to_table * seat.footprint)})
	for role: StringName in [&"center", &"action"]:
		if snapshot.elements.has(role):
			result[str(role)] = _rect(to_table * snapshot.elements[role].rect)
	return result


func _card_state(card: GuiPlayingCard, authorized: bool) -> Dictionary:
	var snapshot: GuiCardSnapshot = card.get_card_snapshot(_root, &"gallery", authorized)
	return {
		"kind": snapshot.kind,
		"authorized": snapshot.authorized,
		"rect": _rect(snapshot.element.rect),
		"rank": snapshot.rank.text,
		"suit": snapshot.suit.text,
	}


func _star_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for star: GuiSeatStar in _stars:
		var font: Font = star.get_theme_font("font")
		var font_size: int = star.get_theme_font_size("font_size")
		var color: Color = star.get_theme_color("font_color")
		(
			result
			. append(
				{
					"font_size": font_size,
					"source":
					(
						"svg"
						if GuiCardInk.symbol_fallback_texture(font, "★", font_size) != null
						else "font"
					),
					"rect": _rect(star.get_global_rect()),
					"ink": _rect(GuiCardInk.bounds(font, "★", font_size)),
					"color": [color.r, color.g, color.b, color.a],
				}
			)
		)
	return result


func _control(control: Control) -> Dictionary:
	if control == null:
		return {"visible": false}
	return {
		"rect": _rect(control.get_global_rect()),
		"visible": control.is_visible_in_tree(),
		"enabled": not control.disabled if control is BaseButton else true,
	}


func _rect(value: Rect2) -> Array[float]:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
