class_name GuiCenterBoard
extends VBoxContainer

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
		(get_node("Cards") as GuiCardRow).render(CardRowViewModel.new())
		for path: String in ["BoardTitle", "Totals/Pot", "Totals/Wager", "BlindLevel"]:
			(get_node(path) as Label).text = ""
		return
	(get_node("BoardTitle") as Label).text = model.board_title
	(get_node("Cards") as GuiCardRow).render(model.board)
	(get_node("Totals/Pot") as Label).text = model.phone_pot_text
	(get_node("Totals/Wager") as Label).text = model.phone_wager_text
	_blind_text = model.blind_level_text
	# Let native containers assign width before wrapped text contributes height.
	# A zero-width initial Label otherwise latches a word-per-line ancestor minimum.
	_queue_blind_copy()
