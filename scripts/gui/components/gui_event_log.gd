class_name GuiEventLog
extends VBoxContainer

## The adapter supplies public history; this view keeps only detached plain text.
const EMPTY_COPY: String = "No events yet."
var _copy: String = ""
var _scroll_pending: bool = false
var _follow_end: bool = true
var _reader_offset: float = 0.0


func _enter_tree() -> void:
	_queue_scroll()


func _ready() -> void:
	_reserve_empty_line()
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	get_body().gui_input.connect(_on_body_input)
	_queue_scroll()


func _exit_tree() -> void:
	if not _scroll_pending:
		_capture_reader()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_reserve_empty_line()


func _on_resized() -> void:
	# The outer allocation changes before the container resizes the text body.
	# Capture the reader against the previous wrapping and restore after layout.
	if not _scroll_pending:
		_capture_reader()
	_queue_scroll()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_queue_scroll()
	elif not _scroll_pending:
		_capture_reader()


func _on_body_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.relative.y != 0.0:
		var body: RichTextLabel = get_body()
		body.get_v_scroll_bar().value -= event.relative.y
		body.deselect()
		body.accept_event()


func render(model: EventLogViewModel) -> void:
	var next_copy: String = ""
	if model == null:
		push_error("EventLog requires a public-history presentation model.")
	else:
		next_copy = model.text
	var body: RichTextLabel = get_body()
	(get_node("Empty") as Label).text = EMPTY_COPY if next_copy.is_empty() else ""
	if next_copy == _copy and body.text == next_copy:
		return
	# Several events may arrive before native layout settles. Keep the reader
	# intent from before the first replacement rather than sampling a reset bar.
	if not _scroll_pending:
		_capture_reader()
	_copy = next_copy
	body.text = _copy
	_queue_scroll()


func get_log_text() -> String:
	return get_body().text


func get_body() -> RichTextLabel:
	return get_node("Body") as RichTextLabel


func get_observation(root: Control) -> GuiLayoutElement:
	var value: GuiLayoutElement = GuiSnapshotMeasurement.element(get_body(), root, &"event")
	value.interactive = true
	return value


func _reserve_empty_line() -> void:
	var empty: Label = get_node("Empty")
	empty.custom_minimum_size = (
		empty
		. get_theme_font("font")
		. get_string_size(
			EMPTY_COPY, HORIZONTAL_ALIGNMENT_LEFT, -1.0, empty.get_theme_font_size("font_size")
		)
		. ceil()
	)


func _capture_reader() -> void:
	var bar: VScrollBar = get_body().get_v_scroll_bar()
	_reader_offset = bar.value
	_follow_end = bar.value >= maxf(bar.min_value, bar.max_value - bar.page) - 1.0


func _queue_scroll() -> void:
	if not _scroll_pending and is_inside_tree():
		_scroll_pending = true
		call_deferred("_restore_scroll")


func _restore_scroll() -> void:
	if not is_inside_tree():
		_scroll_pending = false
		return
	# Bound frame callbacks disconnect automatically if this node is freed.
	if not get_tree().process_frame.is_connected(_finish_scroll_restore):
		get_tree().process_frame.connect(_finish_scroll_restore, CONNECT_ONE_SHOT)


func _finish_scroll_restore() -> void:
	_scroll_pending = false
	if not is_inside_tree():
		return
	var bar: VScrollBar = get_body().get_v_scroll_bar()
	var end: float = maxf(bar.min_value, bar.max_value - bar.page)
	bar.value = end if _follow_end else clampf(_reader_offset, bar.min_value, end)
