class_name GuiViewportGeometry
extends RefCounted

## Immutable value API. Rectangles are app-root-local logical coordinates;
## factories retain no Window, Control, DOM object or mutable caller dictionary.
var logical_size: Vector2i:
	get:
		return _logical_size
var full_rect: Rect2:
	get:
		return Rect2(Vector2.ZERO, Vector2(_logical_size))
var usable_rect: Rect2:
	get:
		return _usable_rect
var backing_size: Vector2i:
	get:
		return _backing_size
var ui_scale: float:
	get:
		return _ui_scale
var source: StringName:
	get:
		return _source
var valid: bool:
	get:
		return _valid
var generation: int:
	get:
		return _generation

var _logical_size := Vector2i.ZERO
var _usable_rect := Rect2()
var _backing_size := Vector2i.ZERO
var _ui_scale: float = 1.0
var _source: StringName = &"unavailable"
var _valid: bool = false
var _generation: int = 0


static func from_web(
	backing: Vector2i,
	canvas: Rect2,
	layout: Rect2,
	visual: Rect2,
	insets: Vector4,
	dpr: float = 1.0
) -> GuiViewportGeometry:
	var result := GuiViewportGeometry.new()
	result._source = &"web_actual_css"
	if not _positive(Vector2(backing)) or not _rect_valid(canvas) or not _rect_valid(layout):
		return result
	if not _rect_valid(visual) or not insets.is_finite():
		return result
	result._logical_size = _floor_size(canvas.size)
	if result._logical_size == Vector2i.ZERO:
		return result
	result._backing_size = backing
	result._ui_scale = dpr if is_finite(dpr) and dpr > 0.0 else 1.0
	var safe := Rect2(
		layout.position + Vector2(maxf(0.0, insets.x), maxf(0.0, insets.y)),
		(
			(
				layout.size
				- Vector2(
					maxf(0.0, insets.x) + maxf(0.0, insets.z),
					maxf(0.0, insets.y) + maxf(0.0, insets.w)
				)
			)
			. max(Vector2.ZERO)
		)
	)
	var visible: Rect2 = canvas.intersection(visual).intersection(safe)
	var ratio: Vector2 = Vector2(result._logical_size) / canvas.size
	result._usable_rect = Rect2((visible.position - canvas.position) * ratio, visible.size * ratio)
	result._valid = _rect_valid(result._usable_rect)
	return result


static func from_native(
	client: Vector2i,
	scale: float,
	client_origin_global: Vector2i = Vector2i.ZERO,
	safe_area_global: Rect2i = Rect2i(),
	apply_safe_area: bool = false
) -> GuiViewportGeometry:
	var result := GuiViewportGeometry.new()
	result._source = &"native_current_window_scale"
	if not _positive(Vector2(client)):
		return result
	if not is_finite(scale) or scale <= 0.0:
		scale = 1.0
		result._source = &"native_scale_unavailable_fallback_1"
	result._ui_scale = scale
	result._backing_size = client
	result._logical_size = _floor_size(Vector2(client) / scale)
	if result._logical_size == Vector2i.ZERO:
		return result
	result._usable_rect = result.full_rect
	if apply_safe_area and safe_area_global.size.x > 0 and safe_area_global.size.y > 0:
		var client_rect := Rect2(Vector2(client_origin_global), Vector2(client))
		var visible: Rect2 = client_rect.intersection(Rect2(safe_area_global))
		var ratio: Vector2 = Vector2(result._logical_size) / Vector2(client)
		result._usable_rect = Rect2(
			(visible.position - client_rect.position) * ratio, visible.size * ratio
		)
	result._valid = _rect_valid(result._usable_rect)
	return result


static func injected(size: Vector2, usable: Rect2 = Rect2()) -> GuiViewportGeometry:
	var result := GuiViewportGeometry.new()
	result._source = &"injected_logical_control"
	if not _positive(size):
		return result
	result._logical_size = _floor_size(size)
	if result._logical_size == Vector2i.ZERO:
		return result
	result._backing_size = result._logical_size
	result._usable_rect = (
		result.full_rect if usable == Rect2() else usable.intersection(result.full_rect)
	)
	result._valid = _rect_valid(result._usable_rect)
	return result


func with_generation(value: int) -> GuiViewportGeometry:
	var result := GuiViewportGeometry.new()
	result._logical_size = _logical_size
	result._usable_rect = _usable_rect
	result._backing_size = _backing_size
	result._ui_scale = _ui_scale
	result._source = _source
	result._valid = _valid
	result._generation = value
	return result


func get_data() -> Dictionary:
	return {
		"logical_size": logical_size,
		"full_rect": full_rect,
		"usable_rect": usable_rect,
		"backing_size": backing_size,
		"ui_scale": ui_scale,
		"source": source,
		"valid": valid,
		"generation": generation,
	}


static func _positive(size: Vector2) -> bool:
	return size.is_finite() and size.x > 0.0 and size.y > 0.0


static func _rect_valid(rect: Rect2) -> bool:
	return rect.position.is_finite() and _positive(rect.size)


static func _floor_size(size: Vector2) -> Vector2i:
	var value := Vector2i(floori(size.x), floori(size.y))
	return value if value.x > 0 and value.y > 0 else Vector2i.ZERO
