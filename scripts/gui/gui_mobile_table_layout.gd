class_name GuiMobileTableLayout
extends RefCounted

## Applies presentation-only sizing for tall Web and mobile table surfaces.

const CardFaceFactoryScript := preload("res://scripts/gui/card_face_factory.gd")
const OPPONENT_AVATAR_SIZE := Vector2(112, 112)
const HERO_AVATAR_SIZE := Vector2(128, 128)
const OPPONENT_CARD_SIZE := Vector2(60, 76)
const GUI_MINIMUM_FONT_SIZE: int = 20
const OPPONENT_CHIP_FONT_SIZE: int = 44
const SEAT_TEXT_FONT_SIZE: int = 40
const HERO_SEAT_TEXT_FONT_SIZE: int = 46
const TABLE_TEXT_FONT_SIZE: int = 32
const ACTION_TEXT_FONT_SIZE: int = 21
const STATUS_BAND_HEIGHT: float = 64.0
const COMPACT_STATUS_BAND_HEIGHT: float = 64.0
const STATUS_BAND_GAP: float = 2.0
const MOBILE_PORTRAIT_ASPECT_RATIO: float = 1.2
const LANDSCAPE_TABLET_MIN_WIDTH: float = 1600.0
const LANDSCAPE_TABLET_MIN_HEIGHT: float = 1200.0
const LANDSCAPE_TABLET_MAX_ASPECT_RATIO: float = 1.8
const MOBILE_MAX_CONTENT_SCALE: float = 2.0
const MOBILE_TOUCH_TARGET_HEIGHT: float = 48.0
# Desktop source sizes.  These are authored at their final display point size;
# keeping them as integer values avoids fractional post-render scaling on HiDPI.
const DESKTOP_SEAT_TEXT_FONT_SIZE: int = 30
const DESKTOP_STATUS_TEXT_FONT_SIZE: int = 26
const DESKTOP_HERO_SEAT_TEXT_FONT_SIZE: int = 34
const DESKTOP_CHIP_FONT_SIZE: int = 33
const DESKTOP_OPPONENT_CARD_RANK_FONT_SIZE: int = 30
const DESKTOP_HERO_CARD_RANK_FONT_SIZE: int = 44
const STANDARD_PANEL_MARGIN_HORIZONTAL: float = 8.0
const STANDARD_PANEL_MARGIN_VERTICAL: float = 5.0
const STANDARD_OPPONENT_HEADER_SEPARATION: int = 5
const STANDARD_HERO_HEADER_SEPARATION: int = 7
const COMPACT_AVATAR_REGION_SIZE := Vector2(48.0, 56.0)
const COMPACT_MARKER_WIDTH: float = 48.0
const COMPACT_TABLET_MARKER_WIDTH: float = 36.0
const COMPACT_MARKER_SINGLE_LINE_HEIGHT: float = 32.0
const COMPACT_TABLET_STATUS_SCALE: float = 0.5


static func is_mobile_portrait(surface_size: Vector2) -> bool:
	return surface_size.y / surface_size.x >= MOBILE_PORTRAIT_ASPECT_RATIO


static func is_landscape_tablet(surface_size: Vector2) -> bool:
	if surface_size.x < LANDSCAPE_TABLET_MIN_WIDTH:
		return false
	if surface_size.y < LANDSCAPE_TABLET_MIN_HEIGHT:
		return false
	return surface_size.x / surface_size.y < LANDSCAPE_TABLET_MAX_ASPECT_RATIO


static func is_portrait_tablet(surface_size: Vector2) -> bool:
	return is_mobile_portrait(surface_size) and surface_size.x >= 680.0 and surface_size.x <= 900.0


static func is_small_desktop(surface_size: Vector2) -> bool:
	return (
		not is_mobile_portrait(surface_size) and surface_size.x < 1300.0 and surface_size.y < 760.0
	)


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
	var avatar_region := panel.find_child("AvatarRegion", true, false) as Control
	var resolved_avatar_size: Vector2 = (
		(HERO_AVATAR_SIZE if is_hero else OPPONENT_AVATAR_SIZE) * content_scale
	)
	if avatar_region != null:
		avatar_region.custom_minimum_size = resolved_avatar_size
	if avatar != null:
		avatar.custom_minimum_size = Vector2.ZERO
		avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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


static func apply_small_desktop_seat_footprint(panel: PanelContainer) -> void:
	var panel_style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.content_margin_left = 2.0
	panel_style.content_margin_top = 2.0
	panel_style.content_margin_right = 2.0
	panel_style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", panel_style)
	var header := panel.find_child("Header", true, false) as HBoxContainer
	if header != null:
		header.add_theme_constant_override("separation", 6)
	var avatar_region := panel.find_child("AvatarRegion", true, false) as Control
	var marker := panel.find_child("Marker", true, false) as Label
	var winner_star := panel.find_child("MainPotWinnerStar", true, false) as TextureRect
	if avatar_region != null:
		avatar_region.custom_minimum_size = COMPACT_AVATAR_REGION_SIZE
	if marker != null:
		if avatar_region != null and marker.get_parent() != avatar_region:
			marker.reparent(avatar_region)
		if not marker.has_meta("standard_text"):
			marker.set_meta("standard_text", marker.text)
			marker.set_meta("standard_style", marker.get_theme_stylebox("normal").duplicate())
		marker.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		marker.add_theme_color_override("font_color", Color("f5f0dc"))
		marker.add_theme_color_override("font_outline_color", Color("172331"))
		marker.add_theme_constant_override("outline_size", 4)
		marker.text = _compact_marker_text(marker.get_meta("standard_text", ""))
		var marker_size := Vector2(COMPACT_MARKER_WIDTH, COMPACT_MARKER_SINGLE_LINE_HEIGHT)
		marker.set_anchors_preset(Control.PRESET_TOP_LEFT)
		marker.custom_minimum_size = marker_size
		marker.position = Vector2.ZERO
		marker.size = marker_size
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_make_marker_background_transparent(marker)
	if winner_star != null and avatar_region != null:
		if winner_star.get_parent() != avatar_region:
			winner_star.reparent(avatar_region)
		winner_star.set_anchors_preset(Control.PRESET_TOP_LEFT)
		winner_star.position = Vector2.ZERO
		winner_star.size = Vector2(16.0, 16.0)
		winner_star.custom_minimum_size = Vector2(16.0, 16.0)
	for label_name: String in ["Name", "Stack"]:
		var label := panel.find_child(label_name, true, false) as Label
		if label != null:
			label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	for card: Control in panel.find_children("*", "Control", true, false):
		if card.name.begins_with("CardBack") or card.name.begins_with("ShowdownCard"):
			_scale_card_face(card, Vector2(28.0, 34.0), GUI_MINIMUM_FONT_SIZE)


static func apply_compact_tablet_seat_footprint(panel: PanelContainer) -> void:
	apply_small_desktop_seat_footprint(panel)
	var header := panel.find_child("Header", true, false) as HBoxContainer
	var marker := panel.find_child("Marker", true, false) as Label
	if header == null or marker == null:
		return
	if marker.get_parent() != header:
		marker.reparent(header)
	marker.add_theme_color_override("font_color", Color("172331"))
	marker.remove_theme_color_override("font_outline_color")
	marker.remove_theme_constant_override("outline_size")
	marker.custom_minimum_size = Vector2(
		COMPACT_TABLET_MARKER_WIDTH, COMPACT_MARKER_SINGLE_LINE_HEIGHT
	)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if marker.has_meta("standard_style"):
		var standard_style: Variant = marker.get_meta("standard_style")
		if standard_style is StyleBox:
			marker.add_theme_stylebox_override("normal", standard_style)
	header.move_child(marker, header.get_child_count() - 1)


static func _make_marker_background_transparent(marker: Label) -> void:
	var marker_style := marker.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	marker_style.bg_color = Color.TRANSPARENT
	marker_style.border_color = Color.TRANSPARENT
	marker.add_theme_stylebox_override("normal", marker_style)


static func _compact_marker_text(standard_text: String) -> String:
	var compact_markers := PackedStringArray()
	for marker: String in standard_text.split(" ", false):
		compact_markers.append("S" if marker == "SB" else "B" if marker == "BB" else marker)
	return "/".join(compact_markers)


static func restore_standard_seat_overlays(panel: PanelContainer, is_hero: bool) -> void:
	var header := panel.find_child("Header", true, false) as HBoxContainer
	if header == null:
		return
	var panel_style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.content_margin_left = STANDARD_PANEL_MARGIN_HORIZONTAL
	panel_style.content_margin_top = STANDARD_PANEL_MARGIN_VERTICAL
	panel_style.content_margin_right = STANDARD_PANEL_MARGIN_HORIZONTAL
	panel_style.content_margin_bottom = STANDARD_PANEL_MARGIN_VERTICAL
	panel.add_theme_stylebox_override("panel", panel_style)
	(
		header
		. add_theme_constant_override(
			"separation",
			STANDARD_HERO_HEADER_SEPARATION if is_hero else STANDARD_OPPONENT_HEADER_SEPARATION,
		)
	)
	var marker := panel.find_child("Marker", true, false) as Label
	var winner_star := panel.find_child("MainPotWinnerStar", true, false) as TextureRect
	var avatar_region := panel.find_child("AvatarRegion", true, false) as Control
	if marker != null:
		if marker.get_parent() != header:
			marker.reparent(header)
		marker.text = marker.get_meta("standard_text", marker.text)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		marker.add_theme_color_override("font_color", Color("172331"))
		marker.remove_theme_color_override("font_outline_color")
		marker.remove_theme_constant_override("outline_size")
		if marker.has_meta("standard_style"):
			var standard_style: Variant = marker.get_meta("standard_style")
			if standard_style is StyleBox:
				marker.add_theme_stylebox_override("normal", standard_style)
	if winner_star != null:
		if avatar_region != null and winner_star.get_parent() != avatar_region:
			winner_star.reparent(avatar_region)
		winner_star.custom_minimum_size = (
			HERO_AVATAR_SIZE * 0.5 if is_hero else OPPONENT_AVATAR_SIZE * 0.5
		)
		winner_star.set_anchors_preset(Control.PRESET_TOP_LEFT)
		winner_star.position = Vector2.ZERO
	if avatar_region != null:
		header.move_child(avatar_region, 0)
	if marker != null:
		header.move_child(marker, header.get_child_count() - 1)


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
	seat_status_widgets: Dictionary[int, Label],
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
		var card_width: float = 64.0 * scale if mobile_portrait else 68.0
		_scale_card_face(
			card,
			Vector2(card_width, 76.0 * scale),
			roundi(CardFaceFactoryScript.COMMUNITY_CARD_RANK_FONT_SIZE * scale),
		)
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
		var status_label: Label = seat_status_widgets.get(seat)
		if status_label != null:
			(
				status_label
				. add_theme_font_size_override(
					"font_size",
					(
						DESKTOP_STATUS_TEXT_FONT_SIZE
						if desktop_source_sizes
						else roundi(SEAT_TEXT_FONT_SIZE * seat_scale_value)
					),
				)
			)


static func layout_seat_status_band(
	label: Label,
	panel: PanelContainer,
	compact_layout: bool,
	scale: float,
) -> void:
	if label == null:
		return
	var band_height: float = COMPACT_STATUS_BAND_HEIGHT if compact_layout else STATUS_BAND_HEIGHT
	label.size = Vector2(panel.size.x, band_height * scale)
	label.position = Vector2(
		panel.position.x,
		panel.position.y + panel.size.y + STATUS_BAND_GAP * scale,
	)


static func layout_human_adjacent_panels(
	surface_size: Vector2,
	compact_layout: bool,
	content_scale: float,
	hero_panel: PanelContainer,
	action_panel: PanelContainer,
	event_log: RichTextLabel,
	_seat_count: int = 0,
) -> void:
	if hero_panel == null:
		return
	if compact_layout:
		if surface_size.x >= 700.0 and surface_size.y < 760.0:
			_layout_small_desktop_human_panels(
				surface_size, hero_panel, content_scale, action_panel, event_log
			)
			return
		_layout_compact_human_panels(
			surface_size, hero_panel, content_scale, action_panel, event_log
		)
		return
	hero_panel.size.y = maxf(hero_panel.size.y, action_panel.get_combined_minimum_size().y)
	# Keep the human seat inside the same bottom safety margin used by the side
	# panels. This makes bottom alignment possible without clipping the seat.
	hero_panel.position.y = minf(hero_panel.position.y, surface_size.y - hero_panel.size.y - 12.0)
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
	var panel_height: float = minf(
		180.0,
		maxf(
			132.0,
			maxf(
				action_panel.get_combined_minimum_size().y, event_log.get_combined_minimum_size().y
			),
		),
	)
	if not compact_layout:
		panel_height = 180.0
	# Reserve a shared side-panel pair and align its bottom edge with the human
	# seat. This keeps controls and history out of the lower seat row.
	panel_height = minf(panel_height, maxf(132.0, hero_panel.position.y - 12.0))
	# The human seat may grow after its container resolves its children. Match
	# that resolved height so both side panels share the exact bottom edge.
	panel_height = maxf(panel_height, hero_panel.size.y)
	var panel_size := Vector2(panel_width, panel_height)
	var panel_y: float = hero_panel.position.y + hero_panel.size.y - panel_size.y
	panel_y = clampf(panel_y, 12.0, surface_size.y - panel_size.y - 12.0)
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


static func _layout_small_desktop_human_panels(
	surface_size: Vector2,
	hero_panel: PanelContainer,
	content_scale: float,
	action_panel: PanelContainer,
	event_log: RichTextLabel,
) -> void:
	var bottom_margin: float = 8.0
	hero_panel.position.y = surface_size.y - hero_panel.size.y - bottom_margin
	var side_width: float = clampf((surface_size.x - hero_panel.size.x - 44.0) * 0.5, 210.0, 306.0)
	var side_height: float = 125.0 * minf(content_scale, 1.0)
	# Keep side panels between the central stack and the lower seat row.
	var panel_size := Vector2(side_width, side_height)
	action_panel.size = panel_size
	action_panel.position = Vector2(
		surface_size.x - action_panel.size.x - 12.0,
		surface_size.y - action_panel.size.y,
	)
	event_log.size = panel_size
	event_log.position = Vector2(12.0, surface_size.y - event_log.size.y)


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
		if card.get_meta(CardFaceFactoryScript.FIXED_LAYOUT_META, false):
			suit.custom_minimum_size = Vector2.ZERO
		else:
			suit.custom_minimum_size = Vector2(rank_font_size * 0.9, rank_font_size * 0.9)
