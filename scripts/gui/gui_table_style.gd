class_name GuiTableStyle
extends RefCounted

## Creates presentation-only styles shared by the poker table controls.

const MINIMUM_FONT_SIZE: int = 20


static func box(
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


static func compact_box(
	background_color: Color,
	border_color: Color,
	border_width: int,
	corner_radius: int,
) -> StyleBoxFlat:
	var style := box(background_color, border_color, border_width, corner_radius)
	style.content_margin_left = 2.0
	style.content_margin_top = 1.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 1.0
	return style


static func action_control_box(
	background_color: Color,
	border_color: Color,
	border_width: int,
) -> StyleBoxFlat:
	var style := box(background_color, border_color, border_width, 4)
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0
	return style
