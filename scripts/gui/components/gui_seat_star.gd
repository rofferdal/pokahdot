class_name GuiSeatStar
extends Control


## Decorative ink has its own allocation, independent of a copy line's leading.
func _get_minimum_size() -> Vector2:
	return (
		GuiCardInk.bounds(get_theme_font("font"), "★", get_theme_font_size("font_size")).size.ceil()
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		update_minimum_size()
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")
	var ink: Rect2 = GuiCardInk.bounds(font, "★", font_size)
	font.draw_string(
		get_canvas_item(),
		((size - ink.size) * 0.5).floor() - ink.position,
		"★",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		get_theme_color("font_color")
	)
