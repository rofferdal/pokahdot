class_name GuiSeatCardsColumn
extends Container


## Intrinsic minima stay stable while compact cards use the allocated panel space.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and is_node_ready():
		_arrange()


func _get_minimum_size() -> Vector2:
	var markers := get_node_or_null("Markers") as Control
	var cards := get_node_or_null("PairCards") as GuiHoleCards
	if markers == null or cards == null:
		return Vector2.ZERO
	var marker_minimum: Vector2 = markers.get_combined_minimum_size()
	var card_minimum: Vector2 = cards.get_combined_minimum_size()
	return Vector2(maxf(marker_minimum.x, card_minimum.x), marker_minimum.y + card_minimum.y)


func _arrange() -> void:
	var markers := get_node("Markers") as Control
	var cards := get_node("PairCards") as GuiHoleCards
	var marker_minimum: Vector2 = markers.get_combined_minimum_size()
	var card_minimum: Vector2 = cards.get_combined_minimum_size()
	fit_child_in_rect(markers, Rect2(Vector2(size.x - marker_minimum.x, 0), marker_minimum))
	var panel_padding: float = get_theme_stylebox("panel", &"SeatTokenFrame").get_minimum_size().y
	var height: float = maxf(
		card_minimum.y,
		minf(
			(size.y + panel_padding) * 2.0 / 3.0,
			minf(size.y - marker_minimum.y, size.x / cards.ratio)
		)
	)
	var extent := Vector2(height * cards.ratio, height)
	fit_child_in_rect(cards, Rect2(size - extent, extent))
