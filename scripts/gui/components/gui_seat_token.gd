class_name GuiSeatToken
extends VBoxContainer

## One stable opponent arrangement; native containers own all field geometry.
signal detail_requested(seat: int)

const Grayscale := preload("res://resources/gui_grayscale_material.tres")
var _bound: bool = false
var _seat: int = -1
var _folded: bool = false
var _busted: bool = false
var _acting: bool = false
var _emphasized: bool = false
var _hero: bool = false
var _authorization: Array[bool] = []
var _required_badges: String = ""
var _status_copy: String = ""
var _status_queued: bool = false
var _fields: Dictionary[String, Control] = {}


func _enter_tree() -> void:
	_queue_status()


func _ready() -> void:
	_init_fields()
	focus_entered.connect(_apply_frame)
	focus_exited.connect(_apply_frame)
	GuiSeatPanel._inherit_material(self)
	if _bound:
		_measure()
	_queue_status()


func _init_fields() -> void:
	if _fields.is_empty():
		for key: String in ["Name", "Stack", "Wager", "Markers"]:
			_fields[key] = get_node("%" + key) as Control
		_fields["Cards"] = get_node("%PairCards") as Control


func render(model: SeatViewModel) -> void:
	_init_fields()
	if model == null or not model.valid or model.cards == null:
		push_error("SeatToken requires a valid presentation model with card slots.")
		_clear()
		return
	_bound = true
	_seat = model.seat
	_folded = model.folded
	_busted = model.busted
	_acting = model.acting
	_emphasized = model.winner_emphasis
	_hero = model.is_hero
	focus_mode = Control.FOCUS_ALL
	material = Grayscale if _folded else null
	(_fields["Name"] as Label).text = model.display_name
	(_fields["Stack"] as Label).text = model.stack_value_text
	(_fields["Wager"] as Label).text = model.wager_text
	_status_copy = (
		model.status_compact if not model.status_compact.is_empty() else model.status_text
	)
	if _status_copy.is_empty():
		_status_copy = model.state_text
	_authorization.clear()
	for card: CardViewModel in model.cards.cards:
		_authorization.append(card != null and card.state == CardViewModel.State.FACE)
	(get_node("%PairCards") as GuiHoleCards).render(model.cards)
	(get_node("%Dealer") as Control).visible = model.is_dealer
	(get_node("%SB") as Control).visible = model.is_small_blind
	(get_node("%BB") as Control).visible = model.is_big_blind
	(get_node("%Winner") as Control).visible = _emphasized
	var badges: Array[String] = []
	if model.is_small_blind:
		badges.append("SB")
	if model.is_big_blind:
		badges.append("BB")
	_required_badges = " ".join(badges)
	(get_node("Status") as Label).theme_type_variation = (
		&"TokenWinningText" if _emphasized else &"TokenText"
	)
	_apply_frame()
	_measure()
	GuiSeatPanel._inherit_material(self)
	_queue_status()


func _clear() -> void:
	_bound = false
	_seat = -1
	_status_copy = ""
	_authorization.clear()
	_required_badges = ""
	material = null
	focus_mode = Control.FOCUS_NONE
	if has_focus():
		release_focus()
	for key: String in ["Name", "Stack", "Wager"]:
		(_fields[key] as Label).text = ""
	(get_node("Status") as Label).text = ""
	for key: String in ["Dealer", "SB", "BB", "Winner"]:
		(get_node("%" + key) as Control).visible = false
	(get_node("%PairCards") as GuiHoleCards).render(CardRowViewModel.new())
	_folded = false
	_busted = false
	_acting = false
	_emphasized = false
	_hero = false
	_apply_frame()


func _apply_frame() -> void:
	(get_node("Panel") as PanelContainer).theme_type_variation = (
		&"SeatTokenFocused"
		if has_focus()
		else (
			&"SeatTokenFolded"
			if _folded
			else (&"SeatTokenActing" if _acting else &"SeatTokenFrame")
		)
	)


func _measure() -> void:
	for key: String in ["Name", "Stack", "Wager"]:
		var label := _fields[key] as Label
		var extent: Vector2 = (
			label
			. get_theme_font("font")
			. get_string_size(
				label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size("font_size")
			)
			. ceil()
		)
		label.custom_minimum_size.x = extent.x
	var content_minimum: Vector2 = (
		(get_node("Panel/Content") as Control).get_combined_minimum_size()
	)
	var status: Label = get_node("Status")
	var panel_padding: Vector2 = (
		(get_node("Panel") as Control).get_theme_stylebox("panel").get_minimum_size()
	)
	var paragraph := TextParagraph.new()
	paragraph.width = content_minimum.x + panel_padding.x
	paragraph.break_flags = (
		TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	)
	paragraph.add_string(
		_status_copy, status.get_theme_font("font"), status.get_theme_font_size("font_size")
	)
	var minimum_height: float = maxf(
		(
			paragraph.get_size().y
			+ maxi(0, paragraph.get_line_count() - 1) * status.get_theme_constant("line_spacing")
		),
		(
			2.0 * ceilf(status.get_theme_font("font").get_height(18))
			+ status.get_theme_constant("line_spacing")
		)
	)
	status.custom_minimum_size.y = minimum_height
	custom_minimum_size.x = maxf(48.0, content_minimum.x + panel_padding.x)


func _queue_status() -> void:
	if not _status_queued and is_inside_tree():
		_status_queued = true
		call_deferred("_apply_status")


func _apply_status() -> void:
	if not is_inside_tree():
		_status_queued = false
		return
	if not get_tree().process_frame.is_connected(_commit_status):
		get_tree().process_frame.connect(_commit_status, CONNECT_ONE_SHOT)


func _commit_status() -> void:
	_status_queued = false
	if is_inside_tree():
		(get_node("Status") as Label).text = _status_copy


func get_field(role: StringName) -> Control:
	var names: Dictionary[StringName, String] = {
		&"name": "Name",
		&"stack": "Stack",
		&"action": "Wager",
		&"marker": "D",
		&"badge": "SB",
		&"badge_row_2": "BB",
		&"winner": "Winner"
	}
	if role == &"cards":
		return get_node("%PairCards") as Control
	return get_node("%" + names[role]) as Control if names.has(role) else null


func get_card_views() -> Array[GuiPlayingCard]:
	return (get_field(&"cards") as GuiHoleCards).cards


func get_seat_snapshot(root: Control) -> GuiSeatSnapshot:
	var result := GuiSeatSnapshot.new()
	result.seat_id = _seat
	result.hero = _hero
	result.folded = _folded
	result.busted = _busted
	result.face_authorized = _authorization.has(true)
	result.required_badge_text = _required_badges
	result.panel = GuiSnapshotMeasurement.element(
		get_node("Panel"), root, StringName("seat/%d" % _seat)
	)
	result.panel.interactive = _bound
	result.status = GuiSnapshotMeasurement.element(
		get_node("Status"), root, StringName("status/%d" % _seat)
	)
	result.footprint = GuiSnapshotMeasurement.rect(self, root)
	for role: StringName in [
		&"name", &"stack", &"action", &"marker", &"badge", &"badge_row_2", &"cards"
	]:
		result.fields[role] = GuiSnapshotMeasurement.element(
			get_field(role), root, StringName("seat/%d/%s" % [_seat, role])
		)
	for card: GuiPlayingCard in get_card_views():
		var index: int = result.cards.size()
		result.cards.append(
			card.get_card_snapshot(
				root,
				StringName("seat/%d/cards/%d" % [_seat, index]),
				_authorization[index] if index < _authorization.size() else false
			)
		)
	return result


func _gui_input(event: InputEvent) -> void:
	if not _bound:
		return
	var pressed: bool = event is InputEventScreenTouch and event.pressed
	pressed = (
		pressed
		or (
			event is InputEventMouseButton
			and event.device != -1
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
	)
	pressed = pressed or (event.is_action_pressed(&"ui_accept") and not event.is_echo())
	if pressed:
		accept_event()
		detail_requested.emit(_seat)
