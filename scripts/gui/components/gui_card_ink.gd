class_name GuiCardInk
extends RefCounted


## Visible shaped glyph bounds, excluding unused font line leading.
static func bounds(font: Font, copy: String, font_size: int) -> Rect2:
	var line := TextLine.new()
	if not line.add_string(copy, font, font_size):
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


static func minimum_content(font: Font, gap: float) -> Vector2:
	var rank_size := Vector2.ZERO
	var suit_size := Vector2.ZERO
	for copy: String in ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]:
		rank_size = rank_size.max(bounds(font, copy, 20).size.ceil())
	for copy: String in ["♣", "♦", "♥", "♠"]:
		suit_size = suit_size.max(bounds(font, copy, 20).size.ceil())
	return Vector2(maxf(rank_size.x, suit_size.x), rank_size.y + suit_size.y + gap)
