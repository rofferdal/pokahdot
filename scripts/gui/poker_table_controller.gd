class_name PokerTableController
extends Control

## Presentation-only table shell. Poker state stays in TournamentMatch views.

const OPPONENT_AVATAR_SIZE := Vector2(56, 56)
const HERO_AVATAR_SIZE := Vector2(64, 64)
const OPPONENT_CARD_SIZE := Vector2(30, 38)
const OPPONENT_CHIP_FONT_SIZE: int = 22

var board_card_count: int = 0
var wager_amounts: Dictionary[int, int] = {}
var displayed_pot_amount: int = 0
var displayed_hero_cards: Array[CardData] = []
var _bound_view: GameView
var _match: TournamentMatch
var _recipient_seat: int = Table.NO_SEAT
var _avatar_assignments: Dictionary[int, String] = {}
var _seat_widgets: Dictionary[int, PanelContainer] = {}
var _layout_queued: bool = false

@onready var _felt: Panel = $TableMargin/Felt
@onready var _surface: Control = $TableMargin/Felt/TableSurface
@onready var _center_zone: VBoxContainer = $TableMargin/Felt/TableSurface/CenterZone
@onready var _board_zone: PanelContainer = $TableMargin/Felt/TableSurface/CenterZone/BoardZone
@onready var _pot_zone: PanelContainer = $TableMargin/Felt/TableSurface/CenterZone/PotZone
@onready var _wager_zone: PanelContainer = $TableMargin/Felt/TableSurface/CenterZone/WagerZone
@onready var _board_label: Label = %BoardLabel
@onready var _wager_label: Label = %WagerLabel
@onready var _pot_label: Label = %PotLabel
@onready var _card_slots: HBoxContainer = %CardSlots
@onready var _seats: Control = %Seats


func _ready() -> void:
	resized.connect(_queue_layout)
	_surface.resized.connect(_queue_layout)
	visibility_changed.connect(_queue_layout)
	_apply_table_styles()
	_refresh_visuals()
	_queue_layout()


func bind_view(view: GameView, avatar_assignments: Dictionary[int, String]) -> void:
	if view == null:
		push_error("PokerTableController requires a GameView.")
		return
	_bound_view = view
	_avatar_assignments = avatar_assignments.duplicate()
	board_card_count = view.community_cards.size()
	displayed_pot_amount = view.pot_amount
	displayed_hero_cards = view.hero_hole_cards
	wager_amounts.clear()
	for player_view: PlayerView in view.seats:
		wager_amounts[player_view.seat] = player_view.bet_this_round
	_refresh_visuals()


func bind_match(
	match: TournamentMatch,
	recipient_seat: int,
	avatar_assignments: Dictionary[int, String],
) -> void:
	if match == null:
		push_error("PokerTableController requires a TournamentMatch.")
		return
	_match = match
	_recipient_seat = recipient_seat
	_avatar_assignments = avatar_assignments.duplicate()
	refresh_from_match()


func refresh_from_match() -> void:
	if _match == null:
		push_error("PokerTableController cannot refresh without a TournamentMatch.")
		return
	var view: GameView = _match.get_view_for(_recipient_seat)
	if view == null:
		push_error("TournamentMatch has no view for the requested table recipient.")
		return
	bind_view(view, _avatar_assignments)


func get_card_slot_count() -> int:
	return _card_slots.get_child_count() if is_node_ready() else 0


func get_seat_rects() -> Dictionary[int, Rect2]:
	var seat_rects: Dictionary[int, Rect2] = {}
	for seat: int in _seat_widgets:
		var panel: PanelContainer = _seat_widgets[seat]
		seat_rects[seat] = Rect2(panel.position, panel.size)
	return seat_rects


func get_surface_size() -> Vector2:
	return _surface.size if is_node_ready() else Vector2.ZERO


func _refresh_visuals() -> void:
	if not is_node_ready() or _bound_view == null:
		return
	_board_label.text = (
		"Community cards  %s" % _card_collection_text(_bound_view.community_cards, "No board yet")
	)
	_wager_label.text = "Wagers  •  %d active" % _count_wagers()
	_pot_label.text = "POT  •  %d%s" % [displayed_pot_amount, _pot_layer_text()]
	_rebuild_card_slots()
	_rebuild_seats()
	_queue_layout()


func _apply_table_styles() -> void:
	_felt.add_theme_stylebox_override("panel", _style_box(Color("075c35"), Color("d9b56d"), 3, 72))
	_board_zone.add_theme_stylebox_override(
		"panel", _style_box(Color("062516e8"), Color("75c99a"), 1, 12)
	)
	_pot_zone.add_theme_stylebox_override(
		"panel", _style_box(Color("102d21ed"), Color("d9b56d"), 1, 12)
	)
	_wager_zone.add_theme_stylebox_override(
		"panel", _style_box(Color("062516d9"), Color("4fae7c"), 1, 12)
	)


func _style_box(
	background_color: Color,
	border_color: Color,
	border_width: int,
	corner_radius: int,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 8.0
	style.content_margin_top = 5.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 5.0
	return style


func _compact_style_box(
	background_color: Color,
	border_color: Color,
	border_width: int,
	corner_radius: int,
) -> StyleBoxFlat:
	var style := _style_box(background_color, border_color, border_width, corner_radius)
	style.content_margin_left = 2.0
	style.content_margin_top = 1.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 1.0
	return style


func _count_wagers() -> int:
	var count: int = 0
	for amount: int in wager_amounts.values():
		if amount > 0:
			count += 1
	return count


func _rebuild_card_slots() -> void:
	for slot: Node in _card_slots.get_children():
		slot.queue_free()
	for index: int in range(5):
		var slot := Label.new()
		slot.name = "CardSlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(30, 38)
		var cards: Array[CardData] = _bound_view.community_cards
		slot.text = _card_text(cards[index]) if index < cards.size() else "♠"
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 29)
		slot.add_theme_color_override("font_color", Color("e7d39b"))
		slot.modulate.a = 1.0 if index < board_card_count else 0.48
		slot.add_theme_stylebox_override(
			"normal", _style_box(Color("173e58"), Color("e7d39b"), 2, 4)
		)
		_card_slots.add_child(slot)


func _rebuild_seats() -> void:
	for seat_widget: PanelContainer in _seat_widgets.values():
		seat_widget.queue_free()
	_seat_widgets.clear()
	for player_view: PlayerView in _bound_view.seats:
		var seat_widget := (
			_create_hero_seat_widget(player_view)
			if player_view.seat == _bound_view.hero_seat
			else _create_seat_widget(player_view)
		)
		_seats.add_child(seat_widget)
		_seat_widgets[player_view.seat] = seat_widget


func _create_seat_widget(player_view: PlayerView) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Seat%d" % player_view.seat
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel", _style_box(Color("0d271bd9"), Color("5dbf86"), 1, 10)
	)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 0)
	panel.add_child(content)
	var row := HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", 5)
	content.add_child(row)
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = OPPONENT_AVATAR_SIZE
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var avatar_path: String = _avatar_assignments.get(player_view.seat, "")
	if not avatar_path.is_empty():
		avatar.texture = load(avatar_path) as Texture2D
	row.add_child(avatar)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = _seat_title(player_view)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 20)
	row.add_child(name_label)
	row.add_child(_create_marker_label(player_view))
	var detail_label := Label.new()
	detail_label.name = "Detail"
	detail_label.text = _opponent_detail_text(player_view)
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail_label.clip_text = true
	detail_label.add_theme_font_size_override("font_size", OPPONENT_CHIP_FONT_SIZE)
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 4)
	content.add_child(footer)
	footer.add_child(detail_label)
	footer.add_child(_create_opponent_hole_cards(player_view))
	return panel


func _create_hero_seat_widget(player_view: PlayerView) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Seat%d" % player_view.seat
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel", _style_box(Color("102d21f2"), Color("e7d39b"), 2, 10)
	)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 2)
	panel.add_child(content)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 7)
	content.add_child(header)
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = HERO_AVATAR_SIZE
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var avatar_path: String = _avatar_assignments.get(player_view.seat, "")
	if not avatar_path.is_empty():
		avatar.texture = load(avatar_path) as Texture2D
	header.add_child(avatar)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = _seat_title(player_view)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 23)
	header.add_child(name_label)
	header.add_child(_create_marker_label(player_view))
	var cards := HBoxContainer.new()
	cards.name = "HeroCards"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 6)
	content.add_child(cards)
	for index: int in range(displayed_hero_cards.size()):
		var card := Label.new()
		card.name = "HeroCard%d" % (index + 1)
		card.custom_minimum_size = Vector2(54, 42)
		card.text = _card_text(displayed_hero_cards[index])
		card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_theme_font_size_override("font_size", 29)
		card.add_theme_color_override("font_color", _card_face_color(displayed_hero_cards[index]))
		card.add_theme_stylebox_override(
			"normal", _style_box(Color("f5f0dc"), Color("d9b56d"), 2, 5)
		)
		cards.add_child(card)
	var state_label := Label.new()
	state_label.name = "State"
	state_label.text = _seat_state_text(player_view)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	state_label.clip_text = true
	state_label.add_theme_font_size_override("font_size", 18)
	content.add_child(state_label)
	return panel


func _create_marker_label(player_view: PlayerView) -> Label:
	var marker := Label.new()
	marker.name = "Marker"
	marker.text = _seat_marker_text(player_view)
	marker.custom_minimum_size = Vector2(64, 28)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	marker.autowrap_mode = TextServer.AUTOWRAP_OFF
	marker.clip_text = true
	marker.add_theme_font_size_override("font_size", 17)
	marker.add_theme_color_override("font_color", Color("172331"))
	marker.add_theme_stylebox_override(
		"normal", _compact_style_box(Color("e7d39b"), Color("f5f0dc"), 1, 5)
	)
	return marker


func _create_opponent_hole_cards(player_view: PlayerView) -> HBoxContainer:
	var cards := HBoxContainer.new()
	cards.name = "HoleCards"
	cards.add_theme_constant_override("separation", 3)
	var revealed_cards: Array = _bound_view.revealed_hole_cards.get(player_view.seat, [])
	if revealed_cards.size() == 2:
		for index: int in range(2):
			var card: CardData = revealed_cards[index]
			cards.add_child(_create_opponent_card_face(card, index + 1))
		return cards
	for index: int in range(2):
		cards.add_child(_create_opponent_card_back(index + 1))
	return cards


func _create_opponent_card_back(index: int) -> Label:
	var card_back := Label.new()
	card_back.name = "CardBack%d" % index
	card_back.custom_minimum_size = OPPONENT_CARD_SIZE
	card_back.add_theme_stylebox_override(
		"normal", _compact_style_box(Color("173e58"), Color("e7d39b"), 2, 3)
	)
	return card_back


func _create_opponent_card_face(card_data: CardData, index: int) -> Label:
	var card_face := Label.new()
	card_face.name = "ShowdownCard%d" % index
	card_face.custom_minimum_size = OPPONENT_CARD_SIZE
	card_face.text = _card_text(card_data)
	card_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_face.add_theme_font_size_override("font_size", 20)
	card_face.add_theme_color_override("font_color", _card_face_color(card_data))
	card_face.add_theme_stylebox_override(
		"normal", _style_box(Color("f5f0dc"), Color("d9b56d"), 2, 3)
	)
	return card_face


func _seat_title(player_view: PlayerView) -> String:
	var title: String = player_view.display_name
	if player_view.is_human:
		title += " (you)"
	return title


func _seat_marker_text(player_view: PlayerView) -> String:
	var markers: Array[String] = []
	if player_view.seat == _bound_view.button_seat:
		markers.append("D")
	if player_view.seat == _bound_view.small_blind_seat:
		markers.append("SB")
	if player_view.seat == _bound_view.big_blind_seat:
		markers.append("BB")
	if player_view.seat == _bound_view.acting_seat:
		markers.append("ACT")
	return " ".join(markers)


func _seat_state_text(player_view: PlayerView) -> String:
	var state: String = "%d chips / %d wager" % [player_view.stack, player_view.bet_this_round]
	if player_view.busted:
		return "%s  •  ELIMINATED" % state
	if player_view.folded:
		return "%s  •  FOLDED" % state
	if player_view.all_in:
		return "%s  •  ALL-IN" % state
	return state


func _opponent_detail_text(player_view: PlayerView) -> String:
	var detail: String = "%d chips" % player_view.stack
	if player_view.busted:
		return "%s  •  ELIMINATED" % detail
	if player_view.folded:
		detail += "  •  FOLDED"
	elif player_view.all_in:
		detail += "  •  ALL-IN"
	return detail


func _pot_layer_text() -> String:
	var pots: Array[PotLayer] = _bound_view.pots
	if pots.size() <= 1:
		return ""
	return "  •  %d layers" % pots.size()


func _card_collection_text(cards: Array[CardData], empty_text: String) -> String:
	if cards.is_empty():
		return empty_text
	var rendered_cards: Array[String] = []
	for card: CardData in cards:
		rendered_cards.append(_card_text(card))
	return "[ %s ]" % "  ".join(rendered_cards)


func _card_text(card: CardData) -> String:
	if card == null:
		return "?"
	var rank_text: String = str(card.rank)
	if card.rank == 14:
		rank_text = "A"
	elif card.rank == 13:
		rank_text = "K"
	elif card.rank == 12:
		rank_text = "Q"
	elif card.rank == 11:
		rank_text = "J"
	var suit_text: String = ["♣", "♦", "♥", "♠"][card.suit]
	return "%s%s" % [rank_text, suit_text]


func _card_face_color(card: CardData) -> Color:
	if card.suit == CardData.Suit.DIAMONDS or card.suit == CardData.Suit.HEARTS:
		return Color("ad2636")
	return Color("172331")


func _layout_table() -> void:
	if not is_node_ready():
		return
	var surface_size: Vector2 = _surface.size
	if surface_size.x <= 0.0 or surface_size.y <= 0.0:
		return
	var center_size := Vector2(clampf(surface_size.x * 0.48, 230.0, 340.0), 184.0)
	_center_zone.size = center_size
	_center_zone.position = (surface_size - center_size) * 0.5
	if _seat_widgets.is_empty():
		return
	var compact_layout: bool = surface_size.x < 600.0
	var seat_width: float = (
		clampf(surface_size.x * 0.27, 104.0, 140.0)
		if compact_layout
		else clampf(surface_size.x * 0.23, 250.0, 280.0)
	)
	var seat_count: int = _seat_widgets.size()
	for seat: int in _seat_widgets:
		var is_hero: bool = seat == _bound_view.hero_seat
		var seat_size := Vector2(seat_width, 96.0) if is_hero else Vector2(seat_width, 70.0)
		if compact_layout and is_hero:
			seat_size = Vector2(clampf(surface_size.x * 0.56, 190.0, 220.0), 80.0)
		var normalized_position: Vector2 = _normalized_seat_position(
			_visual_slot_for_seat(seat, seat_count), seat_count, is_hero
		)
		var panel: PanelContainer = _seat_widgets[seat]
		_apply_compact_seat_typography(panel, compact_layout, is_hero)
		var minimum_size: Vector2 = panel.get_combined_minimum_size()
		var resolved_seat_size := Vector2(
			maxf(seat_size.x, minimum_size.x), maxf(seat_size.y, minimum_size.y)
		)
		panel.size = resolved_seat_size
		var intended_position: Vector2 = (
			normalized_position * surface_size - resolved_seat_size * 0.5
		)
		panel.position = Vector2(
			clampf(intended_position.x, 0.0, surface_size.x - resolved_seat_size.x),
			clampf(intended_position.y, 0.0, surface_size.y - resolved_seat_size.y),
		)


func _apply_compact_seat_typography(
	panel: PanelContainer,
	compact_layout: bool,
	is_hero: bool,
) -> void:
	if not compact_layout or is_hero:
		return
	var avatar := panel.find_child("Avatar", true, false) as TextureRect
	if avatar != null:
		avatar.custom_minimum_size = OPPONENT_AVATAR_SIZE
	var name_label := panel.find_child("Name", true, false) as Label
	if name_label != null:
		name_label.add_theme_font_size_override("font_size", 16)
	var marker_label := panel.find_child("Marker", true, false) as Label
	if marker_label != null:
		marker_label.add_theme_font_size_override("font_size", 14)


func _visual_slot_for_seat(seat: int, seat_count: int) -> int:
	var bottom_slot: int = seat_count / 2
	var relative_seat: int = posmod(seat - _bound_view.hero_seat, seat_count)
	return posmod(bottom_slot + relative_seat, seat_count)


func _normalized_seat_position(
	visual_slot: int,
	seat_count: int,
	is_hero: bool,
) -> Vector2:
	if is_hero:
		return Vector2(0.5, 0.91)
	return _symmetric_seat_positions(seat_count)[visual_slot]


func _symmetric_seat_positions(seat_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	match seat_count:
		2:
			positions = [Vector2(0.5, 0.08), Vector2(0.5, 0.91)]
		3:
			positions = [Vector2(0.15, 0.32), Vector2(0.5, 0.91), Vector2(0.85, 0.32)]
		4:
			positions = [
				Vector2(0.5, 0.06),
				Vector2(0.88, 0.36),
				Vector2(0.5, 0.91),
				Vector2(0.12, 0.36),
			]
		5:
			positions = [
				Vector2(0.28, 0.12),
				Vector2(0.14, 0.55),
				Vector2(0.5, 0.91),
				Vector2(0.86, 0.55),
				Vector2(0.72, 0.12),
			]
		6:
			positions = [
				Vector2(0.5, 0.08),
				Vector2(0.88, 0.30),
				Vector2(0.78, 0.70),
				Vector2(0.5, 0.91),
				Vector2(0.22, 0.70),
				Vector2(0.12, 0.30),
			]
		7:
			positions = [
				Vector2(0.22, 0.72),
				Vector2(0.30, 0.06),
				Vector2(0.88, 0.40),
				Vector2(0.5, 0.91),
				Vector2(0.12, 0.40),
				Vector2(0.70, 0.06),
				Vector2(0.78, 0.72),
			]
		8:
			positions = [
				Vector2(0.5, 0.05),
				Vector2(0.82, 0.19),
				Vector2(0.90, 0.48),
				Vector2(0.74, 0.75),
				Vector2(0.5, 0.91),
				Vector2(0.26, 0.75),
				Vector2(0.10, 0.48),
				Vector2(0.18, 0.19),
			]
		9:
			positions = [
				Vector2(0.20, 0.05),
				Vector2(0.90, 0.30),
				Vector2(0.90, 0.52),
				Vector2(0.75, 0.75),
				Vector2(0.5, 0.91),
				Vector2(0.25, 0.75),
				Vector2(0.10, 0.52),
				Vector2(0.10, 0.30),
				Vector2(0.80, 0.05),
			]
		_:
			push_error("PokerTableController does not support %d seats." % seat_count)
	return positions


func _queue_layout() -> void:
	if not is_node_ready() or _layout_queued:
		return
	_layout_queued = true
	call_deferred("_apply_queued_layout")


func _apply_queued_layout() -> void:
	_layout_queued = false
	_layout_table()
