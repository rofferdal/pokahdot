class_name GuiKeypadBody
extends Container

## Arranges stable keypad groups without moving their controls between parents.
var landscape: bool = false
var gap: float = 4.0
var header_minimum := Vector2.ZERO


func configure(is_landscape: bool, spacing: float, header_size: Vector2) -> void:
	landscape = is_landscape
	gap = spacing
	header_minimum = header_size
	queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_arrange()


func _arrange() -> void:
	var header: Control = get_node("Header")
	var digits: Control = get_node("Digits")
	var utilities: Control = get_node("Utilities")
	var digit_size: Vector2 = digits.get_combined_minimum_size()
	var utility_size: Vector2 = utilities.get_combined_minimum_size()
	fit_child_in_rect(header, Rect2(0, 0, size.x, header_minimum.y))
	if landscape:
		var content_width: float = digit_size.x + gap + utility_size.x
		var left: float = maxf(0.0, (size.x - content_width) / 2.0)
		var height: float = maxf(digit_size.y, utility_size.y)
		fit_child_in_rect(digits, Rect2(left, header_minimum.y, digit_size.x, height))
		fit_child_in_rect(
			utilities, Rect2(left + digit_size.x + gap, header_minimum.y, utility_size.x, height)
		)
	else:
		fit_child_in_rect(
			digits,
			Rect2((size.x - digit_size.x) / 2.0, header_minimum.y + gap, digit_size.x, digit_size.y)
		)
		fit_child_in_rect(
			utilities,
			Rect2(
				(size.x - utility_size.x) / 2.0,
				header_minimum.y + gap + digit_size.y + gap,
				utility_size.x,
				utility_size.y
			)
		)
