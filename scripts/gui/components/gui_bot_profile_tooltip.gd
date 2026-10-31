class_name GuiBotProfileTooltip
extends PanelContainer

## Passive name-only hover. The table supplies targets and usable geometry.
const HOVER_DELAY_SECONDS: float = 0.5

var _target_at: Callable
var _blocked: Callable
var _usable_area: Callable
var _seat: int = Table.NO_SEAT
var _text: String = ""
var _pointer := Vector2.ZERO
var _name_rect := Rect2()
var _elapsed: float = 0.0

@onready var _label: Label = $Text


func configure(target_at: Callable, blocked: Callable, usable_area: Callable) -> void:
	_target_at = target_at
	_blocked = blocked
	_usable_area = usable_area
	cancel()


func get_text() -> String:
	return _text


func cancel() -> void:
	_seat = Table.NO_SEAT
	_text = ""
	_elapsed = 0.0
	hide()
	if is_node_ready():
		_label.text = ""


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if not _target_at.is_valid() or not _blocked.is_valid() or _blocked.call():
			cancel()
			return
		var parent := get_parent() as Control
		_pointer = parent.get_global_transform_with_canvas().affine_inverse() * event.position
		var target: Dictionary = _target_at.call(_pointer)
		var seat: int = target.get("seat", Table.NO_SEAT)
		var text: String = target.get("text", "")
		var rect: Rect2 = target.get("rect", Rect2())
		if seat == Table.NO_SEAT or text.is_empty():
			cancel()
		elif seat != _seat or text != _text or rect != _name_rect:
			cancel()
			_seat = seat
			_text = text
			_name_rect = rect
	elif (
		event is InputEventMouse
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or (event is InputEventKey and event.pressed)
	):
		cancel()


func _process(delta: float) -> void:
	if _seat == Table.NO_SEAT:
		return
	if not _blocked.is_valid() or _blocked.call():
		cancel()
		return
	var target: Dictionary = _target_at.call(_pointer)
	if (
		target.get("seat", Table.NO_SEAT) != _seat
		or target.get("text", "") != _text
		or target.get("rect", Rect2()) != _name_rect
	):
		cancel()
		return
	_elapsed += delta
	if not visible and _elapsed >= HOVER_DELAY_SECONDS:
		_present()


func _present() -> void:
	var usable: Rect2 = _usable_area.call()
	var padding: Vector2 = get_theme_stylebox("panel").get_minimum_size()
	var font: Font = _label.get_theme_font("font")
	var font_size: int = maxi(20, _label.get_theme_font_size("font_size"))
	var text_width: float = floorf(usable.size.x - padding.x)
	if text_width <= 0.0 or usable.size.y <= padding.y:
		cancel()
		return
	var natural_width: float = (
		font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	text_width = minf(text_width, natural_width)
	var paragraph := TextParagraph.new()
	paragraph.width = text_width
	paragraph.break_flags = (
		TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	)
	paragraph.add_string(_text, font, font_size)
	var text_height: float = (
		paragraph.get_size().y
		+ maxi(0, paragraph.get_line_count() - 1) * _label.get_theme_constant("line_spacing")
	)
	var extent: Vector2 = Vector2(text_width, text_height).ceil() + padding
	# Optional hover cannot fit if the complete name exceeds the available area.
	if extent.x > usable.size.x or extent.y > usable.size.y:
		cancel()
		return
	# Seed the final wrap width before assigning text; an initially zero-width
	# Label otherwise reports a character-per-line minimum to PanelContainer.
	_label.size = Vector2(text_width, text_height)
	_label.text = _text
	_label.add_theme_font_size_override("font_size", font_size)
	custom_minimum_size = extent
	size = extent
	var origin := Vector2(_name_rect.position.x, _name_rect.end.y + 8.0)
	if origin.y + extent.y > usable.end.y:
		origin.y = _name_rect.position.y - extent.y - 8.0
	position = Vector2(
		clampf(origin.x, usable.position.x, usable.end.x - extent.x),
		clampf(origin.y, usable.position.y, usable.end.y - extent.y)
	)
	show()
