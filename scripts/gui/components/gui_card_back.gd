class_name GuiCardBack
extends PanelContainer


func _ready() -> void:
	_refresh_mark()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_refresh_mark()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func render(_model: CardViewModel) -> void:
	# A back has no identity-bearing content to bind.
	_refresh_mark()


func _refresh_mark() -> void:
	var mark := get_node("Mark") as Label
	mark.visible = (
		GuiCardInk.symbol_fallback_texture(
			mark.get_theme_font("font"), "◆", mark.get_theme_font_size("font_size")
		)
		== null
	)
	queue_redraw()


func _draw() -> void:
	var mark := get_node("Mark") as Label
	var font: Font = mark.get_theme_font("font")
	var font_size: int = mark.get_theme_font_size("font_size")
	var fallback: Texture2D = GuiCardInk.symbol_fallback_texture(font, "◆", font_size)
	if fallback == null:
		return
	var ink: Rect2 = GuiCardInk.bounds(font, "◆", font_size)
	draw_texture_rect_region(
		fallback,
		Rect2(((size - ink.size) * 0.5).floor(), ink.size),
		GuiCardInk.symbol_texture_region("◆"),
		mark.get_theme_color("font_color")
	)
