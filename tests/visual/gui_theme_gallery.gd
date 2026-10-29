extends Control

## Review-fixture typography only. RG-40 will own reusable measured card views.
var _fit_queued: bool = false


func _ready() -> void:
	for path: String in ["Margin/Gallery/Lower/Cards/Face", "Margin/Gallery/Lower/Cards/RedFace"]:
		get_node(path).resized.connect(_queue_fit)
	_queue_fit()


func _queue_fit() -> void:
	if not _fit_queued:
		_fit_queued = true
		call_deferred("_fit_cards")


func _fit_cards() -> void:
	_fit_queued = false
	for path: String in ["Margin/Gallery/Lower/Cards/Face", "Margin/Gallery/Lower/Cards/RedFace"]:
		fit_card(get_node(path) as PanelContainer)


static func fit_card(card: PanelContainer) -> void:
	var value: GuiCardGlyphSample = card.get_node("Glyphs/Value")
	var suit: GuiCardGlyphSample = card.get_node("Glyphs/Suit")
	var font: Font = value.get_theme_font("font")
	var box: StyleBox = card.get_theme_stylebox("panel")
	var available: Vector2 = card.size - box.get_minimum_size()
	var gap: int = card.get_node("Glyphs").get_theme_constant("separation")
	var best: int = 20
	for font_size: int in range(20, 161):
		var value_ink: Vector2 = (
			GuiCardGlyphSample.ink_bounds(font, value.text, font_size).size.ceil()
		)
		var suit_ink: Vector2 = (
			GuiCardGlyphSample.ink_bounds(font, suit.text, font_size).size.ceil()
		)
		var width: float = maxf(value_ink.x, suit_ink.x)
		var height: float = value_ink.y + suit_ink.y + gap
		if width > available.x or height > available.y:
			break
		best = font_size
	value.font_size = best
	suit.font_size = best
