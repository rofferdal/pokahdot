class_name GuiKeypadHeader
extends Container

## Places the same title, value and limits controls for either header arrangement.
var compact: bool = false
var gap: float = 4.0


func configure(is_compact: bool, spacing: float) -> void:
	compact = is_compact
	gap = spacing
	queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_arrange()


func _arrange() -> void:
	var title: Control = get_node("Title")
	var value: Control = get_node("Value")
	var limits: Control = get_node("Limits")
	var title_size: Vector2 = title.get_combined_minimum_size()
	var value_size: Vector2 = value.get_combined_minimum_size()
	var limits_size: Vector2 = limits.get_combined_minimum_size()
	if compact:
		var width: float = title_size.x + gap + value_size.x
		var top_height: float = maxf(title_size.y, value_size.y)
		var left: float = maxf(0.0, (size.x - width) / 2.0)
		fit_child_in_rect(title, Rect2(left, 0, title_size.x, top_height))
		fit_child_in_rect(value, Rect2(left + title_size.x + gap, 0, value_size.x, top_height))
		fit_child_in_rect(limits, Rect2(0, top_height, size.x, limits_size.y))
	else:
		fit_child_in_rect(title, Rect2(0, 0, size.x, title_size.y))
		fit_child_in_rect(value, Rect2(0, title_size.y + gap, size.x, value_size.y))
		fit_child_in_rect(
			limits, Rect2(0, title_size.y + gap + value_size.y + gap, size.x, limits_size.y)
		)
