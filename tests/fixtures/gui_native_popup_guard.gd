extends SceneTree

const Placement := preload("res://scripts/gui/platform/gui_popup_placement.gd")


func _initialize() -> void:
	# Capture this intentional diagnostic in the parent test process. The LAN
	# build must continue to reject any unhandled error in the main check log.
	var popup := Window.new()
	popup.size = Vector2i(1236, 604)
	popup.content_scale_size = Vector2i(618, 302)
	popup.visible = true
	var embedded: bool = popup.is_embedded()
	Placement.apply(popup, root, Rect2(11, 24, 618, 302), Vector2i(618, 302), true)
	var result: Dictionary = {
		"embedded": embedded,
		"visible": popup.visible,
		"width": popup.size.x,
		"height": popup.size.y,
		"scale_width": popup.content_scale_size.x,
		"scale_height": popup.content_scale_size.y,
	}
	print("POPUP_GUARD_RESULT:" + JSON.stringify(result))
	popup.free()
	quit()
