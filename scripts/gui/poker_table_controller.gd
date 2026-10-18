class_name PokerTableController
extends Control

## Presentation-only table shell. Poker state stays in TournamentMatch views.

var board_card_count: int = 0
var wager_amounts: Dictionary[int, int] = {}
var displayed_pot_amount: int = 0
var _bound_view: GameView
var _avatar_assignments: Dictionary[int, String] = {}
var _seat_widgets: Dictionary[int, PanelContainer] = {}
var _layout_queued: bool = false

@onready var _felt: Panel = $TableMargin/Felt
@onready var _surface: Control = $TableMargin/Felt/TableSurface
@onready var _center_zone: VBoxContainer = $TableMargin/Felt/TableSurface/CenterZone
@onready var _board_zone: PanelContainer = $TableMargin/Felt/TableSurface/CenterZone/BoardZone
@onready var _pot_zone: PanelContainer = $TableMargin/Felt/TableSurface/CenterZone/PotZone
@onready var _wager_zone: PanelContainer = $TableMargin/Felt/TableSurface/CenterZone/WagerZone
@onready var _board_label: Label = %BoardLabel
@onready var _wager_label: Label = %WagerLabel
@onready var _pot_label: Label = %PotLabel
@onready var _card_slots: HBoxContainer = %CardSlots
@onready var _seats: Control = %Seats


func _ready() -> void:
	resized.connect(_queue_layout)
	_surface.resized.connect(_queue_layout)
	visibility_changed.connect(_queue_layout)
	_apply_table_styles()
	_refresh_visuals()
	_queue_layout()


func bind_view(view: GameView, avatar_assignments: Dictionary[int, String]) -> void:
	if view == null:
		push_error("PokerTableController requires a GameView.")
		return
	_bound_view = view
	_avatar_assignments = avatar_assignments.duplicate()
	board_card_count = view.community_cards.size()
	displayed_pot_amount = view.pot_amount
	wager_amounts.clear()
	for player_view: PlayerView in view.seats:
		wager_amounts[player_view.seat] = player_view.bet_this_round
	_refresh_visuals()


func get_card_slot_count() -> int:
	return _card_slots.get_child_count() if is_node_ready() else 0


func get_seat_rects() -> Dictionary[int, Rect2]:
	var seat_rects: Dictionary[int, Rect2] = {}
	for seat: int in _seat_widgets:
		var panel: PanelContainer = _seat_widgets[seat]
		seat_rects[seat] = Rect2(panel.position, panel.size)
	return seat_rects


func get_surface_size() -> Vector2:
	return _surface.size if is_node_ready() else Vector2.ZERO


func _refresh_visuals() -> void:
	if not is_node_ready() or _bound_view == null:
		return
	_board_label.text = "Community cards"
	_wager_label.text = "Wagers  •  %d active" % _count_wagers()
	_pot_label.text = "POT  •  %d" % displayed_pot_amount
	_rebuild_card_slots()
	_rebuild_seats()
	_queue_layout()


func _apply_table_styles() -> void:
	_felt.add_theme_stylebox_override("panel", _style_box(Color("075c35"), Color("d9b56d"), 3, 72))
	_board_zone.add_theme_stylebox_override(
		"panel", _style_box(Color("062516e8"), Color("75c99a"), 1, 12)
	)
	_pot_zone.add_theme_stylebox_override(
		"panel", _style_box(Color("102d21ed"), Color("d9b56d"), 1, 12)
	)
	_wager_zone.add_theme_stylebox_override(
		"panel", _style_box(Color("062516d9"), Color("4fae7c"), 1, 12)
	)


func _style_box(
	background_color: Color,
	border_color: Color,
	border_width: int,
	corner_radius: int,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 8.0
	style.content_margin_top = 5.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 5.0
	return style


func _count_wagers() -> int:
	var count: int = 0
	for amount: int in wager_amounts.values():
		if amount > 0:
			count += 1
	return count


func _rebuild_card_slots() -> void:
	for slot: Node in _card_slots.get_children():
		slot.queue_free()
	for index: int in range(5):
		var slot := Label.new()
		slot.name = "CardSlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(30, 38)
		slot.text = "♠"
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 29)
		slot.add_theme_color_override("font_color", Color("e7d39b"))
		slot.modulate.a = 1.0 if index < board_card_count else 0.48
		slot.add_theme_stylebox_override(
			"normal", _style_box(Color("173e58"), Color("e7d39b"), 2, 4)
		)
		_card_slots.add_child(slot)


func _rebuild_seats() -> void:
	for seat_widget: PanelContainer in _seat_widgets.values():
		seat_widget.queue_free()
	_seat_widgets.clear()
	for player_view: PlayerView in _bound_view.seats:
		var seat_widget := _create_seat_widget(player_view)
		_seats.add_child(seat_widget)
		_seat_widgets[player_view.seat] = seat_widget


func _create_seat_widget(player_view: PlayerView) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Seat%d" % player_view.seat
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel", _style_box(Color("0d271bd9"), Color("5dbf86"), 1, 10)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = Vector2(32, 32)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var avatar_path: String = _avatar_assignments.get(player_view.seat, "")
	if not avatar_path.is_empty():
		avatar.texture = load(avatar_path) as Texture2D
	row.add_child(avatar)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = player_view.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 23)
	row.add_child(name_label)
	return panel


func _layout_table() -> void:
	if not is_node_ready():
		return
	var surface_size: Vector2 = _surface.size
	if surface_size.x <= 0.0 or surface_size.y <= 0.0:
		return
	var center_size := Vector2(clampf(surface_size.x * 0.48, 230.0, 340.0), 184.0)
	_center_zone.size = center_size
	_center_zone.position = (surface_size - center_size) * 0.5
	if _seat_widgets.is_empty():
		return
	var compact_layout: bool = surface_size.x < 600.0
	var seat_width: float = (
		clampf(surface_size.x * 0.27, 104.0, 164.0)
		if compact_layout
		else clampf(surface_size.x * 0.15, 118.0, 164.0)
	)
	var seat_size := Vector2(seat_width, 48.0)
	var seat_count: int = _seat_widgets.size()
	for seat: int in _seat_widgets:
		var normalized_position: Vector2 = _normalized_seat_position(
			seat, seat_count, compact_layout
		)
		var panel: PanelContainer = _seat_widgets[seat]
		panel.size = seat_size
		var intended_position: Vector2 = normalized_position * surface_size - seat_size * 0.5
		panel.position = Vector2(
			clampf(intended_position.x, 0.0, surface_size.x - seat_size.x),
			clampf(intended_position.y, 0.0, surface_size.y - seat_size.y),
		)


func _normalized_seat_position(seat: int, seat_count: int, compact_layout: bool) -> Vector2:
	var angle: float = -PI * 0.5 + TAU * float(seat) / float(seat_count)
	var horizontal_radius: float = 0.47 if compact_layout else 0.39
	return Vector2(0.5 + cos(angle) * horizontal_radius, 0.5 + sin(angle) * 0.40)


func _queue_layout() -> void:
	if not is_node_ready() or _layout_queued:
		return
	_layout_queued = true
	call_deferred("_apply_queued_layout")


func _apply_queued_layout() -> void:
	_layout_queued = false
	_layout_table()
