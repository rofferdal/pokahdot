class_name GuiMobileTableLayout
extends RefCounted

## Applies presentation-only sizing for tall Web and mobile table surfaces.

const OPPONENT_AVATAR_SIZE := Vector2(56, 56)
const HERO_AVATAR_SIZE := Vector2(64, 64)
const OPPONENT_CARD_SIZE := Vector2(30, 38)
const GUI_MINIMUM_FONT_SIZE: int = 20
const OPPONENT_CHIP_FONT_SIZE: int = 22
const MOBILE_PORTRAIT_ASPECT_RATIO: float = 1.2
const MOBILE_MAX_CONTENT_SCALE: float = 2.0
const MOBILE_OPPONENT_MAX_VERTICAL_POSITION: float = 0.6


static func is_mobile_portrait(surface_size: Vector2) -> bool:
	return surface_size.y / surface_size.x >= MOBILE_PORTRAIT_ASPECT_RATIO


static func content_scale(surface_size: Vector2) -> float:
	return clampf(
		minf(surface_size.x / 480.0, surface_size.y / 1200.0), 1.0, MOBILE_MAX_CONTENT_SCALE
	)


static func opponent_position(position: Vector2, mobile_portrait: bool) -> Vector2:
	if not mobile_portrait:
		return position
	return Vector2(position.x, minf(position.y, MOBILE_OPPONENT_MAX_VERTICAL_POSITION))


static func apply_seat_typography(
	panel: PanelContainer,
	mobile_portrait: bool,
	scale: float,
	is_hero: bool,
) -> void:
	var content_scale: float = scale if mobile_portrait else 1.0
	var avatar := panel.find_child("Avatar", true, false) as TextureRect
	if avatar != null:
		avatar.custom_minimum_size = (
			(HERO_AVATAR_SIZE if is_hero else OPPONENT_AVATAR_SIZE) * content_scale
		)
	var name_label := panel.find_child("Name", true, false) as Label
	if name_label != null:
		name_label.add_theme_font_size_override(
			"font_size", (23 if is_hero else GUI_MINIMUM_FONT_SIZE) * content_scale
		)
	var stack_label := panel.find_child("Stack", true, false) as Label
	if stack_label != null:
		stack_label.add_theme_font_size_override(
			"font_size", OPPONENT_CHIP_FONT_SIZE * content_scale
		)
	var marker_label := panel.find_child("Marker", true, false) as Label
	if marker_label != null:
		marker_label.custom_minimum_size = Vector2(48.0 * content_scale, 28.0 * content_scale)
		marker_label.add_theme_font_size_override(
			"font_size", GUI_MINIMUM_FONT_SIZE * content_scale
		)


static func apply_scale(
	mobile_portrait: bool,
	content_scale: float,
	board_label: Label,
	pot_label: Label,
	wager_label: Label,
	action_status: Label,
	event_log: RichTextLabel,
	quit_button: Button,
	action_controls: Array[Control],
	card_slots: HBoxContainer,
	seat_widgets: Dictionary[int, PanelContainer],
	seat_action_widgets: Dictionary[int, Label],
	seat_showdown_widgets: Dictionary[int, Label],
) -> void:
	var scale: float = content_scale if mobile_portrait else 1.0
	board_label.add_theme_font_size_override("font_size", 29 * scale)
	pot_label.add_theme_font_size_override("font_size", 29 * scale)
	wager_label.add_theme_font_size_override("font_size", 29 * scale)
	action_status.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
	event_log.add_theme_font_size_override("normal_font_size", GUI_MINIMUM_FONT_SIZE * scale)
	quit_button.add_theme_font_size_override("font_size", 21 * scale)
	for control: Control in action_controls:
		control.add_theme_font_size_override("font_size", 21 * scale)
	for card: Control in card_slots.get_children():
		_scale_card_face(card, Vector2(30.0, 38.0) * scale, 29 * scale)
	for seat: int in seat_widgets:
		var panel: PanelContainer = seat_widgets[seat]
		for card: Control in panel.find_children("*", "Control", true, false):
			if card.name.begins_with("CardBack"):
				card.custom_minimum_size = OPPONENT_CARD_SIZE * scale
			elif card.name.begins_with("ShowdownCard"):
				_scale_card_face(card, OPPONENT_CARD_SIZE * scale, 20 * scale)
			elif card.name.begins_with("HeroCard"):
				_scale_card_face(card, Vector2(54.0, 42.0) * scale, 29 * scale)
		var action_label: Label = seat_action_widgets.get(seat)
		if action_label != null:
			action_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)
		var showdown_label: Label = seat_showdown_widgets.get(seat)
		if showdown_label != null:
			showdown_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE * scale)


static func layout_seat_action_label(
	label: Label,
	panel: PanelContainer,
	compact_layout: bool,
	scale: float,
) -> void:
	if label == null:
		return
	label.size = Vector2(panel.size.x, (20.0 if not compact_layout else 17.0) * scale)
	label.position = Vector2(panel.position.x, panel.position.y + panel.size.y + 2.0)


static func layout_seat_showdown_label(
	label: Label,
	panel: PanelContainer,
	compact_layout: bool,
	scale: float,
) -> void:
	if label == null or not label.visible:
		return
	label.size = Vector2(panel.size.x, (22.0 if compact_layout else 24.0) * scale)
	label.position = Vector2(panel.position.x, maxf(0.0, panel.position.y - label.size.y - 2.0))


static func layout_human_adjacent_panels(
	surface_size: Vector2,
	compact_layout: bool,
	content_scale: float,
	hero_panel: PanelContainer,
	action_panel: PanelContainer,
	event_log: RichTextLabel,
) -> void:
	if hero_panel == null:
		return
	if compact_layout:
		_layout_compact_human_panels(
			surface_size, hero_panel, content_scale, action_panel, event_log
		)
		return
	var action_size := Vector2(clampf(surface_size.x * 0.32, 560.0, 640.0), 104.0)
	action_size = Vector2(
		maxf(action_size.x, action_panel.get_combined_minimum_size().x),
		maxf(action_size.y, action_panel.get_combined_minimum_size().y),
	)
	var event_size := Vector2(clampf(surface_size.x * 0.22, 380.0, 440.0), 132.0)
	event_size = Vector2(
		maxf(event_size.x, event_log.get_combined_minimum_size().x),
		maxf(event_size.y, event_log.get_combined_minimum_size().y),
	)
	var panel_y: float = minf(
		hero_panel.position.y + hero_panel.size.y - action_size.y,
		surface_size.y - action_size.y - 12.0,
	)
	action_panel.size = action_size
	action_panel.position = Vector2(
		minf(
			surface_size.x - action_size.x - 12.0,
			hero_panel.position.x + hero_panel.size.x + 14.0,
		),
		panel_y,
	)
	event_log.size = event_size
	event_log.position = Vector2(
		maxf(12.0, hero_panel.position.x - event_size.x - 14.0),
		clampf(
			hero_panel.position.y + hero_panel.size.y - event_size.y,
			12.0,
			surface_size.y - event_size.y - 12.0,
		),
	)


static func _layout_compact_human_panels(
	surface_size: Vector2,
	hero_panel: PanelContainer,
	content_scale: float,
	action_panel: PanelContainer,
	event_log: RichTextLabel,
) -> void:
	var panel_width: float = surface_size.x - 24.0
	var action_height: float = maxf(
		150.0 * content_scale, action_panel.get_combined_minimum_size().y
	)
	action_panel.size = Vector2(panel_width, action_height)
	action_panel.position = Vector2(12.0, maxf(12.0, hero_panel.position.y - action_height - 8.0))
	var event_height: float = 82.0 * content_scale
	event_log.size = Vector2(panel_width, event_height)
	event_log.position = Vector2(12.0, maxf(12.0, action_panel.position.y - event_height - 8.0))


static func _scale_card_face(card: Control, size: Vector2, rank_font_size: int) -> void:
	card.custom_minimum_size = size
	var rank_label := card.find_child("Rank", true, false) as Label
	if rank_label != null:
		rank_label.add_theme_font_size_override("font_size", rank_font_size)
	var suit := card.find_child("Suit", true, false) as TextureRect
	if suit != null:
		suit.custom_minimum_size = Vector2(rank_font_size * 0.9, rank_font_size * 0.9)
