class_name GuiCardGlyphSample
extends Control

## Review fixture: reserve the visible glyph bounds instead of line leading.
@export var text: String = ""
@export var font_size: int = 20:
	set(value):
		font_size = value
		update_minimum_size()
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return ink_bounds(get_theme_font("font"), text, font_size).size.ceil()


func _draw() -> void:
	var font: Font = get_theme_font("font")
	var ink: Rect2 = ink_bounds(font, text, font_size)
	var baseline: Vector2 = ((size - ink.size) * 0.5).floor() - ink.position
	font.draw_string(
		get_canvas_item(),
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		get_theme_color("font_color")
	)


static func ink_bounds(font: Font, copy: String, size: int) -> Rect2:
	var line := TextLine.new()
	if not line.add_string(copy, font, size):
		return Rect2()
	var server: TextServer = TextServerManager.get_primary_interface()
	var result := Rect2()
	var started: bool = false
	var pen: float = 0.0
	for glyph: Dictionary in server.shaped_text_get_glyphs(line.get_rid()):
		var font_rid: RID = glyph.font_rid
		var cache_size := Vector2i(glyph.font_size, 0)
		server.font_render_glyph(font_rid, cache_size, glyph.index)
		for repetition: int in glyph.repeat:
			var rect := Rect2(
				(
					server.font_get_glyph_offset(font_rid, cache_size, glyph.index)
					+ Vector2(pen, 0.0)
					+ glyph.offset
				),
				server.font_get_glyph_size(font_rid, cache_size, glyph.index)
			)
			if rect.has_area():
				result = result.merge(rect) if started else rect
				started = true
			pen += glyph.advance
	return result
