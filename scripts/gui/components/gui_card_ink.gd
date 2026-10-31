class_name GuiCardInk
extends RefCounted

const SUIT_TEXTURES: Dictionary[String, Texture2D] = {
	"♣": preload("res://assets/ui/club.svg"),
	"♦": preload("res://assets/ui/diamond.svg"),
	"♥": preload("res://assets/ui/heart.svg"),
	"♠": preload("res://assets/ui/spade.svg")
}
const DECORATION_TEXTURES: Dictionary[String, Texture2D] = {
	"★": preload("res://assets/ui/winner_star.svg"), "◆": SUIT_TEXTURES["♦"]
}
# Match the approved native suit's visible em height without requiring an OS font.
const SUIT_INK_SCALE: float = 1.1
static var _symbol_masks: Dictionary[String, Texture2D] = {}
static var _symbol_regions: Dictionary[String, Rect2] = {}


## Visible shaped glyph bounds, excluding unused font line leading.
static func bounds(font: Font, copy: String, font_size: int) -> Rect2:
	if font == null or copy.is_empty() or font_size <= 0:
		return Rect2()
	var line := TextLine.new()
	if not line.add_string(copy, font, font_size):
		return Rect2()
	var server: TextServer = TextServerManager.get_primary_interface()
	var result := Rect2()
	var started: bool = false
	var pen: float = 0.0
	for glyph: Dictionary in server.shaped_text_get_glyphs(line.get_rid()):
		var font_rid: RID = glyph.font_rid
		if not font_rid.is_valid():
			if SUIT_TEXTURES.has(copy) or DECORATION_TEXTURES.has(copy):
				return _vector_bounds(copy, font_size)
			pen += glyph.advance * glyph.repeat
			continue
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


static func minimum_content(font: Font, gap: float, horizontal: bool = false) -> Vector2:
	var rank_size := Vector2.ZERO
	var suit_size := Vector2.ZERO
	for copy: String in ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]:
		rank_size = rank_size.max(bounds(font, copy, 20).size.ceil())
	for copy: String in ["♣", "♦", "♥", "♠"]:
		suit_size = suit_size.max(bounds(font, copy, 20).size.ceil())
	if horizontal:
		return Vector2(rank_size.x + suit_size.x + gap, maxf(rank_size.y, suit_size.y))
	return Vector2(maxf(rank_size.x, suit_size.x), rank_size.y + suit_size.y + gap)


static func suit_fallback_texture(font: Font, copy: String, font_size: int) -> Texture2D:
	return symbol_fallback_texture(font, copy, font_size) if SUIT_TEXTURES.has(copy) else null


static func symbol_fallback_texture(font: Font, copy: String, font_size: int) -> Texture2D:
	if (not SUIT_TEXTURES.has(copy) and not DECORATION_TEXTURES.has(copy)) or font == null:
		return null
	var line := TextLine.new()
	if not line.add_string(copy, font, font_size):
		return _symbol_mask(copy)
	var server: TextServer = TextServerManager.get_primary_interface()
	for glyph: Dictionary in server.shaped_text_get_glyphs(line.get_rid()):
		if not (glyph.font_rid as RID).is_valid():
			return _symbol_mask(copy)
	return null


static func suit_texture_region(copy: String) -> Rect2:
	return symbol_texture_region(copy)


static func symbol_texture_region(copy: String) -> Rect2:
	_symbol_mask(copy)
	return _symbol_regions.get(copy, Rect2())


static func _vector_bounds(copy: String, font_size: int) -> Rect2:
	var region: Rect2 = symbol_texture_region(copy)
	if not region.has_area():
		return Rect2()
	var height: float = (
		maxf(20.0, font_size * SUIT_INK_SCALE) if SUIT_TEXTURES.has(copy) else float(font_size)
	)
	return Rect2(Vector2.ZERO, Vector2(region.size.x / region.size.y * height, height))


static func _symbol_mask(copy: String) -> Texture2D:
	if _symbol_masks.has(copy):
		return _symbol_masks[copy]
	var texture: Texture2D = SUIT_TEXTURES.get(copy, DECORATION_TEXTURES.get(copy))
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("Symbol assets require a readable alpha image: " + copy)
		return null
	if image.is_compressed() and image.decompress() != OK:
		push_error("Symbol alpha image could not be decompressed: " + copy)
		return null
	image.convert(Image.FORMAT_RGBA8)
	_symbol_regions[copy] = Rect2(image.get_used_rect())
	# Preserve the existing asset's alpha/shape while taking the accepted card
	# color from the theme. Only six immutable asset masks are retained.
	var rgba: PackedByteArray = image.get_data()
	for offset: int in range(0, rgba.size(), 4):
		rgba[offset] = 255
		rgba[offset + 1] = 255
		rgba[offset + 2] = 255
	var mask: Image = Image.create_from_data(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, rgba
	)
	_symbol_masks[copy] = ImageTexture.create_from_image(mask)
	return _symbol_masks[copy]
