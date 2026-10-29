class_name GuiCardGlyphs
extends Control

var rank_text: String = ""
var suit_text: String = ""
var font_size: int = 20
var _fit_queued: bool = false


func render(model: CardViewModel) -> void:
	rank_text = model.rank_text if model != null and model.state == CardViewModel.State.FACE else ""
	suit_text = model.suit_text if model != null and model.state == CardViewModel.State.FACE else ""
	theme_type_variation = (
		&"CardRankRed" if model != null and model.suit in [1, 2] else &"CardRank"
	)
	_queue_fit()


func _get_minimum_size() -> Vector2:
	return GuiCardInk.minimum_content(get_theme_font("font"), gap())


func gap() -> float:
	return get_theme_constant("glyph_separation", &"CardGlyphs")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		if what == NOTIFICATION_THEME_CHANGED:
			update_minimum_size()
		_queue_fit()


func _queue_fit() -> void:
	if not _fit_queued:
		_fit_queued = true
		call_deferred("_fit")


func _fits(candidate: int) -> bool:
	var font: Font = get_theme_font("font")
	var rank_size: Vector2 = GuiCardInk.bounds(font, rank_text, candidate).size.ceil()
	var suit_size: Vector2 = GuiCardInk.bounds(font, suit_text, candidate).size.ceil()
	return maxf(rank_size.x, suit_size.x) <= size.x and rank_size.y + suit_size.y + gap() <= size.y


func _fit() -> void:
	_fit_queued = false
	font_size = 20
	if not rank_text.is_empty() and not suit_text.is_empty():
		var font: Font = get_theme_font("font")
		if (
			not GuiCardInk.bounds(font, rank_text, 20).has_area()
			or not GuiCardInk.bounds(font, suit_text, 20).has_area()
		):
			push_error("Card glyphs require visible rank and suit ink.")
			rank_text = ""
			suit_text = ""
			queue_redraw()
			return
		# The measured allocation supplies the search bound, not a sample font cap.
		var upper: int = 40
		while _fits(upper):
			upper *= 2
		for candidate: int in range(21, upper + 1):
			if _fits(candidate):
				font_size = candidate
	queue_redraw()


func get_ink_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if rank_text.is_empty() or suit_text.is_empty():
		return result
	var font: Font = get_theme_font("font")
	var rank: Rect2 = GuiCardInk.bounds(font, rank_text, font_size)
	var suit: Rect2 = GuiCardInk.bounds(font, suit_text, font_size)
	var height: float = rank.size.y + suit.size.y + gap()
	var top: float = floorf((size.y - height) * 0.5)
	result.append(Rect2(Vector2(floorf((size.x - rank.size.x) * 0.5), top), rank.size))
	result.append(
		Rect2(Vector2(floorf((size.x - suit.size.x) * 0.5), top + rank.size.y + gap()), suit.size)
	)
	return result


func _draw() -> void:
	var rects: Array[Rect2] = get_ink_rects()
	if rects.is_empty():
		return
	var font: Font = get_theme_font("font")
	var copies: Array[String] = [rank_text, suit_text]
	for index: int in 2:
		var ink: Rect2 = GuiCardInk.bounds(font, copies[index], font_size)
		var fallback: Texture2D = GuiCardInk.suit_fallback_texture(font, copies[index], font_size)
		if fallback != null:
			draw_texture_rect_region(
				fallback,
				rects[index],
				GuiCardInk.suit_texture_region(copies[index]),
				get_theme_color("font_color")
			)
			continue
		font.draw_string(
			get_canvas_item(),
			rects[index].position - ink.position,
			copies[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			get_theme_color("font_color")
		)


func get_layout_elements(root: Control, role: StringName, redact: bool) -> Array[GuiLayoutElement]:
	var result: Array[GuiLayoutElement] = []
	var rects: Array[Rect2] = get_ink_rects()
	for index: int in rects.size():
		var value: GuiLayoutElement = GuiSnapshotMeasurement.element(self, root, role, redact)
		value.role = StringName("%s/%s" % [role, "rank" if index == 0 else "suit"])
		value.text_kind = &"label"
		value.texture_present = (
			index == 1
			and (
				GuiCardInk.suit_fallback_texture(get_theme_font("font"), suit_text, font_size)
				!= null
			)
		)
		value.font_size = font_size
		value.effective_font_size = font_size * minf(value.logical_scale.x, value.logical_scale.y)
		var output_scale: Vector2 = root.get_viewport().get_final_transform().get_scale().abs()
		value.output_font_size = value.effective_font_size * minf(output_scale.x, output_scale.y)
		value.rect = GuiSnapshotMeasurement.local_rect(self, root, rects[index])
		value.content_rect = value.rect
		# Both runs share this Control allocation; rect records each visible ink bound.
		value.allocated_size = size
		value.local_content_size = rects[index].size
		value.required_size = rects[index].size
		value.line_count = 1
		value.text = "" if redact else (rank_text if index == 0 else suit_text)
		value.value_text = value.text
		result.append(value)
	return result
