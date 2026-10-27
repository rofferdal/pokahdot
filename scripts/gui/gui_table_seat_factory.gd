class_name GuiTableSeatFactory
extends RefCounted

## Builds disposable seat widgets from recipient-safe presentation data.
## Match progression and public-action lifetime remain in the controller.

const FoldedSeatStyleScript := preload("res://scripts/gui/folded_seat_style.gd")
const CardFaceFactoryScript := preload("res://scripts/gui/card_face_factory.gd")
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")
const OPPONENT_AVATAR_SIZE := Vector2(112, 112)
const HERO_AVATAR_SIZE := Vector2(128, 128)
const OPPONENT_CARD_SIZE := Vector2(60, 76)
const PHONE_CARD_SIZE := Vector2(18, 26)
const PHONE_SHOWDOWN_CARD_SIZE := Vector2(46, 30)
const PHONE_SHOWDOWN_CARD_GAP: float = 2.0
const GUI_MINIMUM_FONT_SIZE: int = GuiTableStyle.MINIMUM_FONT_SIZE
const OPPONENT_CHIP_FONT_SIZE: int = 44
const SEAT_TEXT_FONT_SIZE: int = 40
const HERO_SEAT_TEXT_FONT_SIZE: int = 46
const NORMAL_SEAT_FRAME_WIDTH: int = 1
const HERO_SEAT_FRAME_WIDTH: int = 2
const ACTING_SEAT_FRAME_COLOR := Color.WHITE

var _bound_view: GameView
var _avatar_assignments: Dictionary[int, String]
var _name_assignments: Dictionary[int, String]


## The controller owns these assignment snapshots for the current tournament.
func configure(
	view: GameView, avatars: Dictionary[int, String], names: Dictionary[int, String]
) -> void:
	_bound_view = view
	_avatar_assignments = avatars
	_name_assignments = names


func create_phone_opponent_token(
	player_view: PlayerView, action_text: String, open_detail: Callable
) -> GuiTableSeatView:
	var panel := GuiTableSeatView.new()
	panel.name = "Seat%d" % player_view.seat
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := seat_frame_style(
		player_view,
		Color("0d271bf2"),
		Color("5dbf86"),
		NORMAL_SEAT_FRAME_WIDTH,
	)
	panel_style.content_margin_left = 0.0
	panel_style.content_margin_top = 0.0
	panel_style.content_margin_right = 0.0
	panel_style.content_margin_bottom = 0.0
	panel.add_theme_stylebox_override("panel", panel_style)
	var content := Control.new()
	content.name = "PhoneTokenContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var name_label := phone_token_label("Name", seat_title(player_view))
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = 4.0
	name_label.offset_top = 0.0
	name_label.offset_right = -44.0
	name_label.offset_bottom = 24.0
	content.add_child(name_label)
	var stack_label := phone_token_label("Stack", str(player_view.stack))
	stack_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stack_label.offset_left = 4.0
	stack_label.offset_top = 23.0
	stack_label.offset_right = 62.0
	stack_label.offset_bottom = 47.0
	content.add_child(stack_label)
	var badge := phone_token_label("Badge", phone_token_badge_text(player_view))
	badge.visible = not badge.text.is_empty()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -44.0
	badge.offset_top = 0.0
	badge.offset_right = -4.0
	badge.offset_bottom = 30.0
	badge.add_theme_color_override("font_color", Color("f5f0dc"))
	badge.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.compact_box(Color("172331f2"), Color("d9b56d"), 1, 4)
	)
	content.add_child(badge)
	var parts: Array[String] = []
	if not player_view.busted:
		for part: String in seat_marker_text(player_view).split(" ", false):
			parts.append(part)
	if player_view.folded:
		parts.append("F")
	elif player_view.all_in:
		parts.append("AI")
	elif player_view.busted:
		parts.append("Out")
	elif player_view.seat == _bound_view.acting_seat:
		parts.append("T")
	panel.set_meta("phone_badge_parts", parts)
	badge.set_meta("full_text", badge.text)
	var cards := create_phone_opponent_hole_cards(player_view)
	cards.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cards.offset_left = -cards.size.x - 2.0
	cards.offset_top = 30.0
	cards.offset_right = -2.0
	cards.offset_bottom = 30.0 + cards.size.y
	content.add_child(cards)
	var action_badge := create_phone_action_badge(action_text)
	action_badge.visible = (
		action_badge.visible and cards.find_child("ShowdownCard1", false, false) == null
	)
	content.add_child(action_badge)
	var details_button := Button.new()
	details_button.name = "DetailsButton"
	details_button.flat = true
	details_button.tooltip_text = "Show details for %s" % seat_title(player_view)
	details_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details_button.pressed.connect(open_detail.bind(player_view.seat))
	panel.add_child(details_button)
	if player_view.folded or player_view.busted:
		FoldedSeatStyleScript.apply(panel)
	panel.capture_fields()
	return panel


func phone_token_label(label_name: String, label_text: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = label_text
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	return label


func phone_seat_badge_text(player_view: PlayerView) -> String:
	var badges: Array[String] = []
	var position_text: String = seat_marker_text(player_view)
	if not position_text.is_empty():
		badges.append(position_text)
	if player_view.seat == _bound_view.acting_seat:
		badges.append("Turn")
	if player_view.folded:
		badges.append("Fold")
	elif player_view.all_in:
		badges.append("AI")
	elif player_view.busted:
		badges.append("Out")
	return " ".join(badges)


func phone_token_badge_text(player_view: PlayerView) -> String:
	var badges: Array[String] = []
	var position_text: String = seat_marker_text(player_view)
	if not position_text.is_empty() and not player_view.busted:
		badges.append(position_text.replace(" ", ""))
	if player_view.folded:
		badges.append("F")
	elif player_view.all_in:
		badges.append("AI")
	elif player_view.busted:
		badges.append("Out")
	elif player_view.seat == _bound_view.acting_seat:
		badges.append("T")
	return "".join(badges) if player_view.all_in else " ".join(badges)


func create_phone_action_badge(action_text: String) -> Label:
	var badge := phone_token_label("ActionBadge", action_text)
	badge.z_index = 2
	badge.visible = not badge.text.is_empty()
	badge.clip_text = false
	badge.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	badge.offset_left = 62.0
	badge.offset_top = 29.0
	badge.offset_right = -45.0
	badge.offset_bottom = 59.0
	badge.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.compact_box(Color("172331f2"), Color("e7d39b"), 1, 5)
	)
	return badge


func create_phone_opponent_hole_cards(player_view: PlayerView) -> Control:
	var cards := Control.new()
	cards.name = "HoleCards"
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var revealed_cards: Array = _bound_view.revealed_hole_cards.get(player_view.seat, [])
	var shows_cards: bool = (
		revealed_cards.size() == 2 and not player_view.folded and not player_view.busted
	)
	var card_size: Vector2 = PHONE_SHOWDOWN_CARD_SIZE if shows_cards else PHONE_CARD_SIZE
	var card_gap: float = PHONE_SHOWDOWN_CARD_GAP if shows_cards else 2.0
	cards.size = Vector2(maxf(40.0, card_size.x * 2.0 + card_gap), card_size.y)
	for index: int in range(2):
		var card: Control
		if player_view.folded or player_view.busted:
			var empty_field := Label.new()
			empty_field.name = "HoleCardField%d" % (index + 1)
			(
				empty_field
				. add_theme_stylebox_override(
					"normal",
					GuiTableStyleScript.compact_box(Color("0d271b"), Color("82968b"), 1, 2),
				)
			)
			card = empty_field
		elif revealed_cards.size() == 2:
			card = (
				CardFaceFactoryScript
				. create_card_face(
					revealed_cards[index],
					"ShowdownCard%d" % (index + 1),
					card_size,
					GUI_MINIMUM_FONT_SIZE,
					Color("f5f0dc"),
					Color("d9b56d"),
					true,
				)
			)
		else:
			var card_back := Label.new()
			card_back.name = "CardBack%d" % (index + 1)
			(
				card_back
				. add_theme_stylebox_override(
					"normal",
					GuiTableStyleScript.compact_box(Color("173e58"), Color("e7d39b"), 1, 2),
				)
			)
			card = card_back
		card.position = Vector2(index * (card_size.x + card_gap), 0)
		card.size = card_size
		cards.add_child(card)
	return cards


func create_seat_widget(player_view: PlayerView) -> GuiTableSeatView:
	var panel := GuiTableSeatView.new()
	panel.name = "Seat%d" % player_view.seat
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	(
		panel
		. add_theme_stylebox_override(
			"panel",
			seat_frame_style(
				player_view,
				Color("0d271bd9"),
				Color("5dbf86"),
				NORMAL_SEAT_FRAME_WIDTH,
			),
		)
	)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 0)
	panel.add_child(content)
	var row := HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", 5)
	content.add_child(row)
	var avatar_region := create_avatar_region(player_view.seat, OPPONENT_AVATAR_SIZE)
	row.add_child(avatar_region)
	add_main_pot_winner_star(avatar_region, player_view.seat, OPPONENT_AVATAR_SIZE)
	row.add_child(create_seat_identity(player_view, SEAT_TEXT_FONT_SIZE))
	row.add_child(create_marker_label(player_view))
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 4)
	content.add_child(footer)
	footer.add_child(create_opponent_hole_cards(player_view))
	if player_view.folded or player_view.busted:
		FoldedSeatStyleScript.apply(panel)
	panel.capture_fields()
	return panel


func create_hero_seat_widget(player_view: PlayerView) -> GuiTableSeatView:
	var panel := GuiTableSeatView.new()
	panel.name = "Seat%d" % player_view.seat
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	(
		panel
		. add_theme_stylebox_override(
			"panel",
			seat_frame_style(
				player_view,
				Color("102d21f2"),
				Color("e7d39b"),
				HERO_SEAT_FRAME_WIDTH,
			),
		)
	)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 2)
	panel.add_child(content)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 7)
	content.add_child(header)
	var avatar_region := create_avatar_region(player_view.seat, HERO_AVATAR_SIZE)
	header.add_child(avatar_region)
	add_main_pot_winner_star(avatar_region, player_view.seat, HERO_AVATAR_SIZE)
	header.add_child(create_seat_identity(player_view, HERO_SEAT_TEXT_FONT_SIZE))
	header.add_child(create_marker_label(player_view))
	var cards := HBoxContainer.new()
	cards.name = "HeroCards"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 6)
	content.add_child(cards)
	if not player_view.folded:
		for index: int in range(_bound_view.hero_hole_cards.size()):
			var card := (
				CardFaceFactoryScript
				. create_card_face(
					_bound_view.hero_hole_cards[index],
					"HeroCard%d" % (index + 1),
					Vector2(108, 84),
					58,
					Color("f5f0dc"),
					Color("d9b56d"),
				)
			)
			cards.add_child(card)
	if player_view.folded or player_view.busted:
		FoldedSeatStyleScript.apply(panel)
	panel.capture_fields()
	return panel


func create_avatar_region(seat: int, avatar_size: Vector2) -> Control:
	var region := Control.new()
	region.name = "AvatarRegion"
	region.custom_minimum_size = avatar_size
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Avatar sources are 64 by 64 pixels; layout adapts their display regions.
	# Linear filtering keeps scaled edges smooth on HiDPI surfaces.
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var avatar_path: String = _avatar_assignments.get(seat, "")
	if not avatar_path.is_empty():
		avatar.texture = load(avatar_path) as Texture2D
	region.add_child(avatar)
	return region


func seat_frame_style(
	player_view: PlayerView,
	background_color: Color,
	normal_border_color: Color,
	normal_border_width: int,
) -> StyleBoxFlat:
	var is_acting: bool = player_view.seat == _bound_view.acting_seat
	var border_color: Color = ACTING_SEAT_FRAME_COLOR if is_acting else normal_border_color
	var border_width: int = normal_border_width * 3 if is_acting else normal_border_width
	return GuiTableStyleScript.box(background_color, border_color, border_width, 10)


func create_marker_label(player_view: PlayerView) -> Label:
	var marker := Label.new()
	marker.name = "Marker"
	marker.text = seat_marker_text(player_view)
	marker.custom_minimum_size = Vector2(96, 56)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	marker.autowrap_mode = TextServer.AUTOWRAP_OFF
	marker.clip_text = true
	marker.add_theme_font_size_override("font_size", SEAT_TEXT_FONT_SIZE)
	marker.add_theme_color_override("font_color", Color("172331"))
	var marker_style := GuiTableStyleScript.compact_box(Color("e7d39b"), Color("f5f0dc"), 1, 5)
	if marker.text.is_empty():
		marker_style.bg_color = Color.TRANSPARENT
		marker_style.border_color = Color.TRANSPARENT
	marker.add_theme_stylebox_override("normal", marker_style)
	return marker


func add_main_pot_winner_star(
	avatar_region: Control,
	seat: int,
	avatar_size: Vector2,
) -> void:
	if not is_main_pot_winner_at_showdown(seat):
		return
	var star := CardFaceFactoryScript.create_main_pot_winner_star(avatar_size)
	star.set_anchors_preset(Control.PRESET_TOP_LEFT)
	star.position = Vector2.ZERO
	avatar_region.add_child(star)


func is_main_pot_winner_at_showdown(seat: int) -> bool:
	if _bound_view == null or not _bound_view.showdown_results.has(seat):
		return false
	for award: PotAward in _bound_view.pot_awards:
		if award.pot_index == 0:
			return seat in award.winner_seats
	return false


func create_seat_identity(player_view: PlayerView, name_font_size: int) -> VBoxContainer:
	var identity := VBoxContainer.new()
	identity.name = "Identity"
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = seat_title(player_view)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", name_font_size)
	identity.add_child(name_label)
	var stack_label := Label.new()
	stack_label.name = "Stack"
	stack_label.text = (
		str(player_view.stack) if player_view.stack >= 100000 else "%d chips" % player_view.stack
	)
	stack_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack_label.clip_text = true
	stack_label.add_theme_font_size_override("font_size", OPPONENT_CHIP_FONT_SIZE)
	identity.add_child(stack_label)
	return identity


func create_opponent_hole_cards(player_view: PlayerView) -> HBoxContainer:
	var cards := HBoxContainer.new()
	cards.name = "HoleCards"
	cards.add_theme_constant_override("separation", 3)
	if player_view.folded or player_view.busted:
		return cards
	var revealed_cards: Array = _bound_view.revealed_hole_cards.get(player_view.seat, [])
	if revealed_cards.size() == 2:
		for index: int in range(2):
			var card: CardData = revealed_cards[index]
			cards.add_child(create_opponent_card_face(card, index + 1))
		return cards
	for index: int in range(2):
		cards.add_child(create_opponent_card_back(index + 1))
	return cards


func create_opponent_card_back(index: int) -> Label:
	var card_back := Label.new()
	card_back.name = "CardBack%d" % index
	card_back.custom_minimum_size = OPPONENT_CARD_SIZE
	card_back.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.compact_box(Color("173e58"), Color("e7d39b"), 2, 3)
	)
	return card_back


func create_opponent_card_face(card_data: CardData, index: int) -> PanelContainer:
	return (
		CardFaceFactoryScript
		. create_card_face(
			card_data,
			"ShowdownCard%d" % index,
			OPPONENT_CARD_SIZE,
			40,
			Color("f5f0dc"),
			Color("d9b56d"),
		)
	)


func seat_title(player_view: PlayerView) -> String:
	if player_view.is_human:
		return NameAssignmentService.HUMAN_LABEL
	return _name_assignments.get(player_view.seat, player_view.display_name)


func seat_marker_text(player_view: PlayerView) -> String:
	var markers: Array[String] = []
	if player_view.seat == _bound_view.button_seat:
		markers.append("D")
	if player_view.seat == _bound_view.small_blind_seat:
		markers.append("SB")
	if player_view.seat == _bound_view.big_blind_seat:
		markers.append("BB")
	return " ".join(markers)
