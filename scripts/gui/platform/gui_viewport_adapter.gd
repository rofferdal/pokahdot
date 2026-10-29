class_name GuiViewportAdapter
extends Node

## GUI-scene-owned platform boundary. CLI/simulation never instantiate it.
## Local headless/SubViewport fixtures use explicit Control geometry and cannot
## acquire ownership of the host process's Window normalization.
signal geometry_changed(geometry: GuiViewportGeometry)

const WebProbe := preload("res://scripts/gui/platform/gui_web_geometry_probe.gd")
var _host: Control
var _startup: Control
var _table: Control
var _geometry := GuiViewportGeometry.new()
var _injected: GuiViewportGeometry
var _pending: bool = false
var _owns_window: bool = false
var _generation: int = 0
var _last_platform_signature: String = ""


func bind(host: Control, startup_root: Control, table_root: Control) -> void:
	_host = host
	_startup = startup_root
	_table = table_root
	_host.resized.connect(_queue_refresh)
	_host.get_viewport().size_changed.connect(_queue_refresh)
	if _host.get_viewport() == get_tree().root:
		_host.get_window().dpi_changed.connect(_queue_refresh)
	_startup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_queue_refresh()
	set_process(true)


func inject_geometry(geometry: GuiViewportGeometry) -> void:
	_injected = geometry
	_queue_refresh()


func clear_injected_geometry() -> void:
	_injected = null
	_queue_refresh()


func get_geometry() -> GuiViewportGeometry:
	return _geometry


func is_pending() -> bool:
	return _pending


func _process(_delta: float) -> void:
	if not is_instance_valid(_host):
		return
	var signature: String = "%s/%s" % [_host.size, _host.get_global_transform_with_canvas()]
	if _can_own_window():
		var window: Window = _host.get_window()
		signature += (
			"%s/%s/%s/%s"
			% [
				window.size,
				window.position,
				window.current_screen,
				DisplayServer.screen_get_scale()
			]
		)
		if OS.has_feature("web"):
			signature += "/%d" % WebProbe.revision()
	if signature != _last_platform_signature or (_injected == null and not _geometry.valid):
		_last_platform_signature = signature
		_queue_refresh()


func _can_own_window() -> bool:
	if _owns_window:
		return true
	if DisplayServer.get_name() == "headless" or not is_instance_valid(_host):
		return false
	var viewport: Viewport = _host.get_viewport()
	if viewport != get_tree().root or not viewport is Window:
		return false
	var full_anchors: bool = _host.anchor_right == 1.0 and _host.anchor_bottom == 1.0
	_owns_window = full_anchors and _host.size.is_equal_approx(viewport.get_visible_rect().size)
	return _owns_window


func _queue_refresh() -> void:
	if _pending or not is_instance_valid(_host):
		return
	_pending = true
	_table.call("set_viewport_geometry_pending", true)
	call_deferred("_refresh")


func _refresh() -> void:
	if not is_instance_valid(_host):
		_pending = false
		return
	var geometry: GuiViewportGeometry = _injected
	var owned: bool = _can_own_window()
	if geometry == null:
		if owned:
			geometry = _platform_geometry()
		else:
			geometry = GuiViewportGeometry.injected(_host.size)
	_generation += 1
	_geometry = geometry.with_generation(_generation)
	if owned and _geometry.logical_size.x > 0 and _geometry.logical_size.y > 0:
		var window: Window = _host.get_window()
		if window.content_scale_size != _geometry.logical_size:
			window.content_scale_size = _geometry.logical_size
	if _geometry.valid:
		var usable: Rect2 = _geometry.usable_rect
		_startup.position = usable.position + Vector2(12, 12)
		_startup.size = (usable.size - Vector2(24, 24)).max(Vector2.ZERO)
		_table.position = usable.position
		_table.size = usable.size
	_table.call("set_viewport_geometry", _geometry, _host.get_global_transform_with_canvas())
	_pending = false
	_table.call("set_viewport_geometry_pending", false)
	geometry_changed.emit(_geometry)


func _platform_geometry() -> GuiViewportGeometry:
	var window: Window = _host.get_window()
	if OS.has_feature("web"):
		return WebProbe.capture(window.size)
	var mobile: bool = OS.has_feature("android") or OS.has_feature("ios")
	var safe_area := Rect2i()
	if mobile:
		safe_area = DisplayServer.get_display_safe_area()
	return GuiViewportGeometry.from_native(
		window.size, DisplayServer.screen_get_scale(), window.position, safe_area, mobile
	)
