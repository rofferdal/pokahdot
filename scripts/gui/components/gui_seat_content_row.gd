class_name GuiSeatContentRow
extends Container


## Owns avatar and sibling columns; allocation never changes intrinsic minima.
func _ready() -> void:
	if not get_node_or_null("Avatar") is TextureRect or not get_parent() is PanelContainer:
		push_error("Seat content requires an Avatar TextureRect and a PanelContainer parent.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and is_node_ready():
		_arrange()


func _columns() -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in get_children():
		if child is Control and child.name != &"Avatar" and child.visible:
			result.append(child)
	return result


func _gap() -> float:
	return get_theme_constant(
		"separation", &"HBoxContainer" if theme_type_variation == &"" else theme_type_variation
	)


func _padding_height() -> float:
	var panel := get_parent() as PanelContainer
	return panel.get_theme_stylebox("panel").get_minimum_size().y if panel != null else 0.0


func _get_minimum_size() -> Vector2:
	var columns: Array[Control] = _columns()
	var result := Vector2(0, maxf(custom_minimum_size.y, _padding_height()))
	for column: Control in columns:
		var minimum: Vector2 = column.get_combined_minimum_size()
		result.x += minimum.x
		result.y = maxf(result.y, minimum.y)
	var avatar := get_node_or_null("Avatar") as TextureRect
	if avatar != null and avatar.visible:
		result.x += ceilf((result.y + _padding_height()) * 0.5) + _gap()
	result.x += max(0, columns.size() - 1) * _gap()
	return result


func _arrange() -> void:
	var avatar := get_node_or_null("Avatar") as TextureRect
	if avatar == null:
		return
	var columns: Array[Control] = _columns()
	var required: float = max(0, columns.size() - 1) * _gap()
	var expanding: int = 0
	for column: Control in columns:
		required += column.get_combined_minimum_size().x
		if column.size_flags_horizontal & Control.SIZE_EXPAND:
			expanding += 1
	var x: float = 0.0
	if avatar.visible:
		var ratio: float = 1.0
		if avatar.texture != null and avatar.texture.get_height() > 0:
			ratio = float(avatar.texture.get_width()) / avatar.texture.get_height()
		var height: float = floorf(
			minf((size.y + _padding_height()) * 0.5, maxf(0.0, size.x - required - _gap()) / ratio)
		)
		fit_child_in_rect(avatar, Rect2(Vector2.ZERO, Vector2(height * ratio, height)))
		x = height * ratio + _gap()
	var surplus: float = maxf(0.0, size.x - x - required)
	for column: Control in columns:
		var width: float = column.get_combined_minimum_size().x
		if expanding > 0 and column.size_flags_horizontal & Control.SIZE_EXPAND:
			width += surplus / expanding
		fit_child_in_rect(column, Rect2(x, 0, width, size.y))
		x += width + _gap()
