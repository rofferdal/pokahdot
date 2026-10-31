class_name GuiCenterBoard
extends VBoxContainer

@export var horizontal_cards: bool = false

@export var compact_copy: bool = false

var _blind_text: String = ""
var _blind_queued: bool = false


func _enter_tree() -> void:
	_queue_blind_copy()


func _queue_blind_copy() -> void:
	if not _blind_queued and is_inside_tree():
		_blind_queued = true
		call_deferred("_apply_blind_copy")


func _apply_blind_copy() -> void:
	if not is_inside_tree():
		_blind_queued = false
		return
	# Bound frame callbacks disconnect automatically if this node is freed.
	if not get_tree().process_frame.is_connected(_finish_blind_copy):
		get_tree().process_frame.connect(_finish_blind_copy, CONNECT_ONE_SHOT)


func _finish_blind_copy() -> void:
	_blind_queued = false
	if not is_inside_tree():
		return
	(get_node("BlindLevel") as Label).text = _blind_text


func render(model: CenterViewModel) -> void:
	if model == null or not model.valid:
		push_error("CenterBoard requires a valid presentation model.")
		_blind_text = ""
		get_cards().render(CardRowViewModel.new())
		for path: String in ["BoardTitle", "Totals/Pot", "Totals/Wager", "BlindLevel"]:
			(get_node(path) as Label).text = ""
		return
	(get_node("BoardTitle") as Label).visible = not compact_copy
	(get_node("BoardTitle") as Label).text = model.board_title
	get_cards().render(model.board)
	(get_node("Totals/Pot") as Label).text = model.phone_pot_text
	(get_node("Totals/Wager") as Label).text = (
		model.compact_wager_text if compact_copy else model.phone_wager_text
	)
	_blind_text = model.compact_blind_text if compact_copy else model.blind_level_text
	# Let native containers assign width before wrapped text contributes height.
	# A zero-width initial Label otherwise latches a word-per-line ancestor minimum.
	_queue_blind_copy()


func get_cards() -> GuiCardRow:
	return get_node("%Cards") as GuiCardRow


func _ready() -> void:
	if horizontal_cards:
		for card: GuiPlayingCard in get_cards().get_children():
			card.configure_glyphs(true)


## Tablet cards share the human panel width; native VBox flow keeps copy adjacent.
func set_card_group_width(width: float) -> void:
	if not is_finite(width) or width <= 0.0:
		push_error("CenterBoard card-group width must be positive and finite.")
		return
	var frame := get_node_or_null("CardsFrame") as AspectRatioContainer
	if frame == null:
		return
	var row: GuiCardRow = get_cards()
	var ratios: float = 0.0
	var count: int = 0
	for card: Node in row.get_children():
		if card is GuiPlayingCard:
			ratios += (card as GuiPlayingCard).ratio
			count += 1
	if count == 0 or ratios <= 0.0:
		return
	var fitted_width: float = maxf(width, row.get_combined_minimum_size().x)
	var spacing: float = row.get_theme_constant("separation") * (count - 1)
	var height: float = (fitted_width - spacing) / ratios
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.ratio = fitted_width / height
	frame.custom_minimum_size = Vector2(fitted_width, ceilf(height))


func get_card_group_height() -> float:
	var frame := get_node_or_null("CardsFrame") as AspectRatioContainer
	return frame.custom_minimum_size.y if frame != null else get_cards().size.y
