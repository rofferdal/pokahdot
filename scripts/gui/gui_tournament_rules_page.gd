class_name GuiTournamentRulesPage
extends MarginContainer

## Persistent startup reference. This page never receives or constructs a match.
signal back_requested

const Document := preload("res://resources/presentation/tournament_rules.tres")
const READING_WIDTH: float = 960.0

@onready var _title: Label = %RulesTitle
@onready var _body: RichTextLabel = %RulesBody
@onready var _back: Button = %RulesBack


func _ready() -> void:
	_back.pressed.connect(func() -> void: back_requested.emit())
	resized.connect(_fit_reading_width)
	_body.gui_input.connect(_on_body_input)
	var result: TournamentRulesDocument.RenderResult = Document.render_plain_text()
	if not result.is_valid():
		_title.text = "Rules unavailable"
		_body.text = "The tournament rules reference could not be loaded."
		push_error("Invalid tournament rules: " + "; ".join(result.errors))
	else:
		_title.text = Document.title
		_body.text = result.text.trim_prefix(Document.title + "\n\n")
	_fit_reading_width()


func set_usable_rect(area: Rect2) -> void:
	position = area.position
	size = area.size
	_fit_reading_width()


func begin_reading() -> void:
	_body.get_v_scroll_bar().value = 0.0
	_body.scroll_to_line(0)
	_back.grab_focus()


func get_body() -> RichTextLabel:
	return _body


func get_back_button() -> Button:
	return _back


func _fit_reading_width() -> void:
	var inset: int = maxi(12, int((size.x - READING_WIDTH) / 2.0))
	add_theme_constant_override("margin_left", inset)
	add_theme_constant_override("margin_right", inset)


func _on_body_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.relative.y != 0.0:
		_body.get_v_scroll_bar().value -= event.relative.y
		_body.deselect()
		_body.accept_event()
