class_name GuiMobileTableLayout
extends RefCounted

## Applies presentation-only sizing for tall Web and mobile table surfaces.

const OPPONENT_AVATAR_SIZE := Vector2(112, 112)
const HERO_AVATAR_SIZE := Vector2(128, 128)
const OPPONENT_CARD_SIZE := Vector2(60, 76)
const GUI_MINIMUM_FONT_SIZE: int = 20
const OPPONENT_CHIP_FONT_SIZE: int = 44
const SEAT_TEXT_FONT_SIZE: int = 40
const HERO_SEAT_TEXT_FONT_SIZE: int = 46
const TABLE_TEXT_FONT_SIZE: int = 32
const ACTION_TEXT_FONT_SIZE: int = 21
const MOBILE_PORTRAIT_ASPECT_RATIO: float = 1.2
const MOBILE_MAX_CONTENT_SCALE: float = 2.0
const MOBILE_TOUCH_TARGET_HEIGHT: float = 48.0
# Desktop source sizes.  These are authored at their final display point size;
# keeping them as integer values avoids fractional post-render scaling on HiDPI.
const DESKTOP_SEAT_TEXT_FONT_SIZE: int = 30
const DESKTOP_HERO_SEAT_TEXT_FONT_SIZE: int = 34
const DESKTOP_CHIP_FONT_SIZE: int = 33
const DESKTOP_OPPONENT_CARD_RANK_FONT_SIZE: int = 30
const DESKTOP_HERO_CARD_RANK_FONT_SIZE: int = 44


static func is_mobile_portrait(surface_size: Vector2) -> bool:
	return surface_size.y / surface_size.x >= MOBILE_PORTRAIT_ASPECT_RATIO


static func content_scale(surface_size: Vector2) -> float:
	return clampf(
		minf(surface_size.x / 480.0, surface_size.y / 1200.0), 1.0, MOBILE_MAX_CONTENT_SCALE
	)


static func seat_scale(surface_size: Vector2) -> float:
	var mobile_portrait: bool = is_mobile_portrait(surface_size)
	if mobile_portrait:
		# High-resolution portrait surfaces retain the full 2x baseline. Smaller phones
		# use the largest scale that can keep all 2-9 seat panels distinct and in bounds.
		if surface_size.x >= 900.0:
			return content_scale(surface_size)
		return clampf(
			minf(content_scale(surface_size), maxf(0.5, surface_size.x / 900.0)), 0.5, 2.0
		)
	if surface_size.x >= 1600.0:
		return 1.0
	return clampf(surface_size.y / 1100.0, 0.5, 1.0)


static func opponent_position(
	position: Vector2, mobile_portrait: bool, content_scale_value: float = 1.0
) -> Vector2:
	if not mobile_portrait:
		return position
	var lower_position: float = 0.55 if content_scale_value > 1.0 else 0.7
	return Vector2(position.x, lower_position if position.y > 0.6 else position.y)


static func apply_seat_typography(
	panel: PanelContainer,
	scale: float,
	is_hero: bool,
	typography_scale: float = 1.0,
	desktop_source_sizes: bool = false,
) -> void:
	var content_scale: float = scale
	var seat_font_size: int = (
		DESKTOP_HERO_SEAT_TEXT_FONT_SIZE
		if is_hero
		else (
			DESKTOP_SEAT_TEXT_FONT_SIZE
			if desktop_source_sizes
			else roundi(
				(
					(HERO_SEAT_TEXT_FONT_SIZE if is_hero else SEAT_TEXT_FONT_SIZE)
					* content_scale
					* typography_scale
				)
			)
		)
	)
	var chip_font_size: int = (
		DESKTOP_CHIP_FONT_SIZE
		if desktop_source_sizes
		else roundi(OPPONENT_CHIP_FONT_SIZE * content_scale * typography_scale)
	)
	var avatar := panel.find_child("Avatar", true, false) as TextureRect
	if avatar != null:
		avatar.custom_minimum_size = (
			(HERO_AVATAR_SIZE if is_hero else OPPONENT_AVATAR_SIZE) * content_scale
		)
	var name_label := panel.find_child("Name", true, false) as Label
	if name_label != null:
		(
			name_label
			. add_theme_font_size_override(
				"font_size",
				seat_font_size,
			)
		)
	var stack_label := panel.find_child("Stack", true, false) as Label
	if stack_label != null:
		stack_label.add_theme_font_size_override("font_size", chip_font_size)
	var marker_label := panel.find_child("Marker", true, false) as Label
	if marker_label != null:
		marker_label.custom_minimum_size = Vector2(96.0 * content_scale, 56.0 * content_scale)
		marker_label.add_theme_font_size_override("font_size", seat_font_size)


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
	seat_content_scale: float = -1.0,
	seat_visual_scale: float = -1.0,
) -> void:
	var scale: float = content_scale if mobile_portrait else 1.0
	var desktop_source_sizes: bool = not mobile_portrait
	var seat_scale_value: float = scale if seat_content_scale < 0.0 else seat_content_scale
	if seat_visual_scale >= 0.0:
		seat_scale_value = seat_visual_scale
	var action_font_size: float = (
		TABLE_TEXT_FONT_SIZE * scale if not mobile_portrait else ACTION_TEXT_FONT_SIZE * scale
	)
	board_label.add_theme_font_size_override("font_size", TABLE_TEXT_FONT_SIZE * scale)
	pot_label.add_theme_font_size_override("font_size", TABLE_TEXT_FONT_SIZE * scale)
	wager_label.add_theme_font_size_override("font_size", TABLE_TEXT_FONT_SIZE * scale)
	action_status.add_theme_font_size_override("font_size", ACTION_TEXT_FONT_SIZE * scale)
	event_log.add_theme_font_size_override("normal_font_size", ACTION_TEXT_FONT_SIZE * scale)
	quit_button.add_theme_font_size_override("font_size", action_font_size)
	for control: Control in action_controls:
		control.add_theme_font_size_override("font_size", action_font_size)
		control.custom_minimum_size = Vector2(
			control.custom_minimum_size.x,
			MOBILE_TOUCH_TARGET_HEIGHT * scale if mobile_portrait else 0.0,
		)
	for card: Control in card_slots.get_children():
		_scale_card_face(card, Vector2(60.0, 76.0) * scale, 58 * scale)
	for seat: int in seat_widgets:
		var panel: PanelContainer = seat_widgets[seat]
		for card: Control in panel.find_children("*", "Control", true, false):
			if card.name.begins_with("CardBack"):
				card.custom_minimum_size = OPPONENT_CARD_SIZE * seat_scale_value
			elif card.name.begins_with("ShowdownCard"):
				_scale_card_face(
					card,
					OPPONENT_CARD_SIZE * seat_scale_value,
					(
						DESKTOP_OPPONENT_CARD_RANK_FONT_SIZE
						if desktop_source_sizes
						else roundi(40 * seat_scale_value)
					),
				)
			elif card.name.begins_with("HeroCard"):
				_scale_card_face(
					card,
					Vector2(108.0, 84.0) * seat_scale_value,
					(
						DESKTOP_HERO_CARD_RANK_FONT_SIZE
						if desktop_source_sizes
						else roundi(58 * seat_scale_value)
					),
				)
		var action_label: Label = seat_action_widgets.get(seat)
		if action_label != null:
			(
				action_label
				. add_theme_font_size_override(
					"font_size",
					(
						DESKTOP_SEAT_TEXT_FONT_SIZE
						if desktop_source_sizes
						else roundi(SEAT_TEXT_FONT_SIZE * seat_scale_value)
					),
				)
			)
		var showdown_label: Label = seat_showdown_widgets.get(seat)
		if showdown_label != null:
			(
				showdown_label
				. add_theme_font_size_override(
					"font_size",
					(
						DESKTOP_SEAT_TEXT_FONT_SIZE
						if desktop_source_sizes
						else roundi(SEAT_TEXT_FONT_SIZE * seat_scale_value)
					),
				)
			)


static func layout_seat_action_label(
	label: Label,
	panel: PanelContainer,
	compact_layout: bool,
	scale: float,
) -> void:
	if label == null:
		return
	label.size = Vector2(panel.size.x, (40.0 if not compact_layout else 32.0) * scale)
	label.position = Vector2(panel.position.x, panel.position.y + panel.size.y + 2.0)


static func layout_seat_showdown_label(
	label: Label,
	panel: PanelContainer,
	compact_layout: bool,
	scale: float,
) -> void:
	if label == null or not label.visible:
		return
	label.size = Vector2(panel.size.x, (40.0 if compact_layout else 48.0) * scale)
	label.position = Vector2(panel.position.x, maxf(0.0, panel.position.y - label.size.y - 2.0))


static func layout_human_adjacent_panels(
	surface_size: Vector2,
	compact_layout: bool,
	content_scale: float,
	hero_panel: PanelContainer,
	action_panel: PanelContainer,
	event_log: RichTextLabel,
	seat_count: int = 0,
) -> void:
	if hero_panel == null:
		return
	if compact_layout:
		_layout_compact_human_panels(
			surface_size, hero_panel, content_scale, action_panel, event_log
		)
		return
	hero_panel.size.y = maxf(hero_panel.size.y, action_panel.get_combined_minimum_size().y)
	hero_panel.position.y = clampf(
		hero_panel.position.y, 0.0, maxf(0.0, surface_size.y - hero_panel.size.y)
	)
	var action_width: float = clampf(surface_size.x * 0.32, 560.0, 640.0)
	var event_width: float = clampf(surface_size.x * 0.22, 380.0, 440.0)
	var panel_width: float = maxf(
		maxf(action_width, event_width),
		maxf(action_panel.get_combined_minimum_size().x, event_log.get_combined_minimum_size().x),
	)
	# Keep a real gap on both sides of the human seat. The desktop surface is
	# slightly asymmetric after its margins, so the shorter side determines the
	# shared width for the mirrored panels.
	var available_side_width: float = (
		minf(hero_panel.position.x, surface_size.x - hero_panel.position.x - hero_panel.size.x)
		- 46.0
	)
	panel_width = minf(panel_width, maxf(0.0, available_side_width))
	var panel_height: float = maxf(
		132.0,
		maxf(action_panel.get_combined_minimum_size().y, event_log.get_combined_minimum_size().y),
	)
	var panel_size := Vector2(panel_width, panel_height)
	var desktop_panel_gap: float = 594.0 if seat_count >= 9 else 164.0
	var panel_y: float = clampf(
		hero_panel.position.y - panel_size.y - desktop_panel_gap,
		12.0,
		surface_size.y - panel_size.y - 12.0,
	)
	action_panel.size = panel_size
	action_panel.position = Vector2(
		minf(
			surface_size.x - panel_size.x - 12.0,
			hero_panel.position.x + hero_panel.size.x + 46.0,
		),
		panel_y,
	)
	event_log.size = panel_size
	event_log.position = Vector2(
		maxf(12.0, hero_panel.position.x - panel_size.x - 46.0),
		panel_y,
	)


static func _layout_compact_human_panels(
	surface_size: Vector2,
	hero_panel: PanelContainer,
	content_scale: float,
	action_panel: PanelContainer,
	event_log: RichTextLabel,
) -> void:
	if content_scale <= 1.0:
		hero_panel.position.y = minf(
			surface_size.y - hero_panel.size.y, hero_panel.position.y + 24.0
		)
	var panel_width: float = surface_size.x - 24.0
	var action_height: float = maxf(
		140.0 * content_scale, action_panel.get_combined_minimum_size().y
	)
	action_panel.size = Vector2(panel_width, action_height)
	action_panel.position = Vector2(12.0, maxf(12.0, hero_panel.position.y - action_height - 8.0))
	var event_height: float = 60.0 * content_scale
	event_log.size = Vector2(panel_width, event_height)
	event_log.position = Vector2(12.0, surface_size.y * 0.165)


static func _scale_card_face(card: Control, size: Vector2, rank_font_size: int) -> void:
	card.custom_minimum_size = size
	var rank_label := card.find_child("Rank", true, false) as Label
	if rank_label != null:
		rank_label.add_theme_font_size_override("font_size", rank_font_size)
	var suit := card.find_child("Suit", true, false) as TextureRect
	if suit != null:
		suit.custom_minimum_size = Vector2(rank_font_size * 0.9, rank_font_size * 0.9)
