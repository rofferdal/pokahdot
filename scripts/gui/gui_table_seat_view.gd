class_name GuiTableSeatView
extends PanelContainer

## Typed handles belong to this rebuilt widget, never to a different seat.
## Discover authored child names once after construction, before layout uses them.
var name_label: Label
var stack_label: Label
var state_badge: Label
var action_badge: Label
var hole_cards: Control
var badge_rows: Dictionary[String, Label] = {}


func capture_fields() -> void:
	name_label = find_child("Name", true, false) as Label
	stack_label = find_child("Stack", true, false) as Label
	state_badge = find_child("Badge", true, false) as Label
	action_badge = find_child("ActionBadge", true, false) as Label
	hole_cards = find_child("HoleCards", true, false) as Control
	if state_badge != null:
		badge_rows["Badge"] = state_badge


func field(field_name: String) -> Control:
	match field_name:
		"Name":
			return name_label
		"Stack":
			return stack_label
		"HoleCards":
			return hole_cards
		"ActionBadge":
			return action_badge
	return badge_rows.get(field_name)


func reserve_full_name_width(should_reserve: bool) -> void:
	if name_label == null:
		return
	name_label.custom_minimum_size.x = 0.0
	if not should_reserve:
		return
	var font_size: int = name_label.get_theme_font_size("font_size")
	var rendered_width: float = (
		name_label
		. get_theme_font("font")
		. get_string_size(
			name_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
		)
		. x
	)
	name_label.custom_minimum_size.x = ceilf(rendered_width)
