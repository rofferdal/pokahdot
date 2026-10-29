class_name GuiPopupPlacement
extends RefCounted

## Positions embedded GUI popups inside the app's usable logical rectangle.
## The app uses Godot's single-window mode so popup content shares its UI units.


static func apply(
	popup: Window, _host: Node, usable: Rect2, requested: Vector2i, bottom_sheet: bool = false
) -> void:
	if not popup.visible:
		return
	if not popup.is_embedded():
		popup.hide()
		push_error(
			"GUI popups require embedded subwindows; separate native popups are unsupported."
		)
		return
	var origin := Vector2i(usable.position.ceil())
	var end := Vector2i(usable.end.floor())
	var available: Vector2i = (end - origin).max(Vector2i.ONE)
	var minimum := Vector2i(popup.get_contents_minimum_size().ceil())
	var desired: Vector2i = requested.max(minimum).min(available).max(Vector2i.ONE)
	popup.size = desired
	var actual: Vector2i = popup.size
	popup.position = (
		origin
		+ Vector2i(
			(available.x - actual.x) / 2,
			available.y - actual.y if bottom_sheet else (available.y - actual.y) / 2
		)
	)
