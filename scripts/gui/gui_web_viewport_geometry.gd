class_name GuiWebViewportGeometry
extends RefCounted

## Converts the Web canvas backing size into CSS-pixel GUI geometry.
##
## Godot's full-window Web loader sizes the canvas backing store as
## `window.innerWidth * devicePixelRatio`. The GUI layout contracts use logical
## pixels, so the root Window must use the corresponding CSS size as its
## virtual content base. The backing store remains high resolution.


static func logical_size(backing_size: Vector2i, pixel_ratio: float) -> Vector2i:
	if backing_size.x <= 0 or backing_size.y <= 0:
		return Vector2i.ZERO
	var safe_ratio: float = pixel_ratio if pixel_ratio > 0.0 else 1.0
	return Vector2i(
		maxi(1, roundi(float(backing_size.x) / safe_ratio)),
		maxi(1, roundi(float(backing_size.y) / safe_ratio)),
	)
