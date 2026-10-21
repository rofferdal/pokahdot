class_name PokerTableController
extends Control
# gdlint: disable=max-file-lines
signal tournament_quit_confirmed
signal return_to_startup_requested
const FoldedSeatStyleScript := preload("res://scripts/gui/folded_seat_style.gd")
const CardFaceFactoryScript := preload("res://scripts/gui/card_face_factory.gd")
const GuiActionPacerScript := preload("res://scripts/gui/gui_action_pacer.gd")
const GuiEventFormatterScript := preload("res://scripts/gui/gui_event_formatter.gd")
const GuiMatchProgressInspectorScript := preload(
	"res://scripts/gui/gui_match_progress_inspector.gd"
)
const GuiMobileTableLayoutScript := preload("res://scripts/gui/gui_mobile_table_layout.gd")
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")
const ShowdownHandFormatterScript := preload("res://scripts/gui/showdown_hand_formatter.gd")
const TableSeatLayoutScript := preload("res://scripts/gui/table_seat_layout.gd")
const TournamentStatusFormatterScript := preload("res://scripts/gui/tournament_status_formatter.gd")
const WagerKeypadScript := preload("res://scripts/gui/wager_keypad.gd")
const OPPONENT_AVATAR_SIZE := Vector2(112, 112)
const HERO_AVATAR_SIZE := Vector2(128, 128)
const OPPONENT_CARD_SIZE := Vector2(60, 76)
const GUI_MINIMUM_FONT_SIZE: int = 20
const OPPONENT_CHIP_FONT_SIZE: int = 44
const SEAT_TEXT_FONT_SIZE: int = 40
const HERO_SEAT_TEXT_FONT_SIZE: int = 46
const NORMAL_SEAT_FRAME_WIDTH: int = 1
const HERO_SEAT_FRAME_WIDTH: int = 2
const ACTING_SEAT_FRAME_COLOR := Color.WHITE
const DESKTOP_CENTER_ZONE_MAX_WIDTH: float = 520.0
@export var action_timing_config: Resource

var board_card_count: int = 0
var wager_amounts: Dictionary[int, int] = {}
var displayed_pot_amount: int = 0
var displayed_hero_cards: Array[CardData] = []
var _bound_view: GameView
var _match: TournamentMatch
var _recipient_seat: int = Table.NO_SEAT
var _avatar_assignments: Dictionary[int, String] = {}
var _seat_widgets: Dictionary[int, PanelContainer] = {}
var _seat_action_widgets: Dictionary[int, Label] = {}
var _seat_showdown_widgets: Dictionary[int, Label] = {}
var _layout_queued: bool = false
var _layout_generation: int = 0
var _event_texts: Array[String] = []
var _active_round_latest_actions: Dictionary[int, PublicActionRecord] = {}
var _action_pacer = GuiActionPacerScript.new()
var _wager_keypad: WagerKeypad

@onready var _felt: Panel = $TableMargin/Felt
@onready var _surface: Control = $TableMargin/Felt/TableSurface
@onready var _center_zone: VBoxContainer = $TableMargin/Felt/TableSurface/CenterZone
@onready var _board_zone: PanelContainer = $TableMargin/Felt/TableSurface/CenterZone/BoardZone
@onready var _pot_zone: Panel = $TableMargin/Felt/TableSurface/CenterZone/PotZone
@onready var _wager_zone: Panel = $TableMargin/Felt/TableSurface/CenterZone/WagerZone
@onready var _board_label: Label = %BoardLabel
@onready var _wager_label: Label = %WagerLabel
@onready var _pot_label: Label = %PotLabel
@onready var _card_slots: HBoxContainer = %CardSlots
@onready var _seats: Control = %Seats
@onready var _action_panel: PanelContainer = $TableMargin/Felt/TableSurface/ActionPanel
@onready var _action_status: Label = %ActionStatus
@onready var _fold_button: Button = %FoldButton
@onready var _check_call_button: Button = %CheckCallButton
@onready var _min_wager_button: Button = %MinWagerButton
@onready var _pot_raise_button: Button = %PotRaiseButton
@onready var _wager_input: LineEdit = %WagerInput
@onready var _wager_button: Button = %WagerButton
@onready var _all_in_button: Button = %AllInButton
@onready var _event_log: RichTextLabel = %EventLog
@onready var _quit_button: Button = %QuitButton
@onready var _quit_confirmation: ConfirmationDialog = %QuitConfirmation


func _ready() -> void:
	if theme != null and theme.default_font == null:
		theme.default_font = ThemeDB.fallback_font
	_action_pacer.configure(get_tree(), action_timing_config)
	resized.connect(_queue_layout)
	_surface.resized.connect(_queue_layout)
	visibility_changed.connect(_queue_layout)
	_apply_table_styles()
	_wager_input.virtual_keyboard_enabled = false
	_wager_input.virtual_keyboard_show_on_focus = false
	_wager_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_wager_keypad = WagerKeypadScript.new()
	add_child(_wager_keypad)
	_wager_input.gui_input.connect(_on_wager_input_gui_input)
	_fold_button.pressed.connect(_on_fold_pressed)
	_check_call_button.pressed.connect(_on_check_call_pressed)
	_min_wager_button.pressed.connect(_on_min_wager_pressed)
	_pot_raise_button.pressed.connect(_on_pot_raise_pressed)
	_wager_button.pressed.connect(_on_wager_pressed)
	_all_in_button.pressed.connect(_on_all_in_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_confirmation.confirmed.connect(_on_quit_confirmed)
	_refresh_visuals()
	_queue_layout()


func bind_view(view: GameView, avatar_assignments: Dictionary[int, String]) -> void:
	if view == null:
		push_error("PokerTableController requires a GameView.")
		return
	_bound_view = view
	_avatar_assignments = avatar_assignments.duplicate()
	_event_texts.clear()
	board_card_count = view.community_cards.size()
	displayed_pot_amount = view.pot_amount
	displayed_hero_cards = view.hero_hole_cards
	wager_amounts.clear()
	_active_round_latest_actions.clear()
	for record: PublicActionRecord in view.action_history:
		_active_round_latest_actions[record.seat] = record
	for player_view: PlayerView in view.seats:
		wager_amounts[player_view.seat] = player_view.bet_this_round
	_refresh_visuals()


func set_action_timing_config(timing_config: Resource) -> void:
	action_timing_config = timing_config
	if is_node_ready():
		_action_pacer.configure(get_tree(), action_timing_config)


func bind_match(
	match: TournamentMatch,
	recipient_seat: int,
	avatar_assignments: Dictionary[int, String],
) -> void:
	if match == null:
		push_error("PokerTableController requires a TournamentMatch.")
		return
	_match = match
	_recipient_seat = recipient_seat
	_avatar_assignments = avatar_assignments.duplicate()
	refresh_from_match()
	_schedule_after_latest_action()


func refresh_from_match() -> void:
	if _match == null:
		push_error("PokerTableController cannot refresh without a TournamentMatch.")
		return
	var view: GameView = _match.get_view_for(_recipient_seat)
	if view == null:
		push_error("TournamentMatch has no view for the requested table recipient.")
		return
	bind_view(view, _avatar_assignments)
	_render_events(_match.get_events())


func get_seat_rects() -> Dictionary[int, Rect2]:
	var seat_rects: Dictionary[int, Rect2] = {}
	for seat: int in _seat_widgets:
		var panel: PanelContainer = _seat_widgets[seat]
		seat_rects[seat] = Rect2(panel.position, panel.size)
	return seat_rects


## Returns resolved table regions in TableSurface-local coordinates for GUI tests.
func get_resolved_region_rects() -> Dictionary[StringName, Rect2]:
	var regions: Dictionary[StringName, Rect2] = {
		&"center": _surface_local_rect(_center_zone),
		&"board": _surface_local_rect(_board_zone),
		&"pot": _surface_local_rect(_pot_zone),
		&"wager": _surface_local_rect(_wager_zone),
		&"action": _surface_local_rect(_action_panel),
		&"event": _surface_local_rect(_event_log),
	}
	if _bound_view != null and _seat_widgets.has(_bound_view.hero_seat):
		regions[&"hero"] = _surface_local_rect(_seat_widgets[_bound_view.hero_seat])
	for seat: int in _seat_widgets:
		regions[StringName("seat_%d" % seat)] = _surface_local_rect(_seat_widgets[seat])
		var action_label: Label = _seat_action_widgets[seat]
		regions[StringName("action_%d" % seat)] = (
			_surface_local_rect(action_label) if action_label.visible else Rect2()
		)
		var showdown_label: Label = _seat_showdown_widgets[seat]
		regions[StringName("showdown_%d" % seat)] = (
			_surface_local_rect(showdown_label) if showdown_label.visible else Rect2()
		)
	return regions


func get_action_control_rects() -> Dictionary[StringName, Rect2]:
	var controls: Array[Control] = [
		_fold_button,
		_check_call_button,
		_pot_raise_button,
		_all_in_button,
		_wager_input,
		_wager_button,
	]
	var rects: Dictionary[StringName, Rect2] = {}
	for control: Control in controls:
		if control.visible:
			rects[StringName(control.name)] = control.get_global_rect()
	return rects


func _surface_local_rect(control: Control) -> Rect2:
	var global_rect: Rect2 = control.get_global_rect()
	return Rect2(global_rect.position - _surface.global_position, global_rect.size)


func is_action_advance_pending() -> bool:
	return _action_pacer.is_waiting()


func submit_wager_total(total: int) -> void:
	if _bound_view == null:
		return
	if PlayerAction.Kind.BET in _bound_view.legal_actions:
		_submit_action(PlayerAction.bet_to(total))
	elif PlayerAction.Kind.RAISE in _bound_view.legal_actions:
		_submit_action(PlayerAction.raise_to(total))


func show_wager_keypad() -> void:
	if _bound_view == null or not WagerKeypadScript.can_wager(_bound_view):
		return
	(
		_wager_keypad
		. open(
			_wager_input,
			_bound_view.minimum_wager_total,
			_bound_view.maximum_wager_total,
			GuiMobileTableLayoutScript.content_scale(_surface.size),
		)
	)


func _on_wager_input_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventScreenTouch and event.pressed
		or (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		)
	):
		show_wager_keypad()
		accept_event()


func _refresh_visuals() -> void:
	if not is_node_ready() or _bound_view == null:
		return
	_board_label.text = "Community cards"
	_wager_label.text = "Wagers  •  %d active" % _count_wagers()
	_pot_label.text = (
		"POT %d%s | SB %d BB %d | L%d %d/%d"
		% [
			displayed_pot_amount,
			_pot_layer_text(),
			_bound_view.small_blind,
			_bound_view.big_blind,
			_bound_view.blind_level,
			_bound_view.completed_hands_in_level,
			_bound_view.hands_until_next_level,
		]
	)
	# Keep changing status text from widening the central table footprint. The
	# board, pot, and wager panels share the fixed resolved width below.
	_pot_label.clip_text = true
	_pot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wager_label.clip_text = true
	_wager_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_wager_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rebuild_card_slots()
	_rebuild_seats()
	_refresh_action_controls()
	_enforce_minimum_gui_text_size_for_node(self)
	_queue_layout()


func _apply_table_styles() -> void:
	_felt.add_theme_stylebox_override(
		"panel", GuiTableStyleScript.box(Color("075c35"), Color("d9b56d"), 3, 72)
	)
	_board_zone.add_theme_stylebox_override(
		"panel", GuiTableStyleScript.box(Color("062516e8"), Color("75c99a"), 1, 12)
	)
	_pot_zone.add_theme_stylebox_override(
		"panel", GuiTableStyleScript.box(Color("102d21ed"), Color("d9b56d"), 1, 12)
	)
	_wager_zone.add_theme_stylebox_override(
		"panel", GuiTableStyleScript.box(Color("062516d9"), Color("4fae7c"), 1, 12)
	)
	_action_panel.add_theme_stylebox_override(
		"panel", GuiTableStyleScript.box(Color("062516ed"), Color("d9b56d"), 1, 12)
	)
	_event_log.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.box(Color("dedede"), Color("8e8e8e"), 1, 8)
	)
	_event_log.add_theme_color_override("default_color", Color("111111"))
	_apply_action_control_styles()


func _apply_action_control_styles() -> void:
	var action_buttons: Array[Button] = [
		_fold_button,
		_check_call_button,
		_min_wager_button,
		_pot_raise_button,
		_wager_button,
		_all_in_button,
	]
	for action_button: Button in action_buttons:
		action_button.add_theme_stylebox_override(
			"normal", GuiTableStyleScript.action_control_box(Color("102d21"), Color("75c99a"), 1)
		)
		action_button.add_theme_stylebox_override(
			"hover", GuiTableStyleScript.action_control_box(Color("1b4933"), Color("e7d39b"), 2)
		)
		action_button.add_theme_stylebox_override(
			"pressed", GuiTableStyleScript.action_control_box(Color("0b1d15"), Color("d9b56d"), 2)
		)
		action_button.add_theme_stylebox_override(
			"disabled", GuiTableStyleScript.action_control_box(Color("0a1711"), Color("385443"), 1)
		)
		action_button.add_theme_color_override("font_disabled_color", Color("7e8a83"))
	_wager_input.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.action_control_box(Color("102d21"), Color("75c99a"), 1)
	)
	_wager_input.add_theme_stylebox_override(
		"focus", GuiTableStyleScript.action_control_box(Color("1b4933"), Color("e7d39b"), 2)
	)
	_wager_input.add_theme_stylebox_override(
		"read_only", GuiTableStyleScript.action_control_box(Color("0a1711"), Color("385443"), 1)
	)
	_wager_input.add_theme_color_override("font_placeholder_color", Color("7e8a83"))


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
		var cards: Array[CardData] = _bound_view.community_cards
		var is_face_up: bool = index < cards.size()
		var slot := (
			CardFaceFactoryScript
			. create_card_face(
				cards[index] if is_face_up else null,
				"CardSlot%d" % (index + 1),
				Vector2(60, 76),
				58,
				Color("f5f0dc") if is_face_up else Color("173e58"),
				Color("e7d39b"),
			)
		)
		slot.modulate.a = 1.0 if index < board_card_count else 0.48
		_card_slots.add_child(slot)


func _rebuild_seats() -> void:
	for seat_widget: PanelContainer in _seat_widgets.values():
		seat_widget.free()
	for action_widget: Label in _seat_action_widgets.values():
		action_widget.free()
	for showdown_widget: Label in _seat_showdown_widgets.values():
		showdown_widget.free()
	_seat_widgets.clear()
	_seat_action_widgets.clear()
	_seat_showdown_widgets.clear()
	for player_view: PlayerView in _bound_view.seats:
		var seat_widget := (
			_create_hero_seat_widget(player_view)
			if player_view.seat == _bound_view.hero_seat
			else _create_seat_widget(player_view)
		)
		_seats.add_child(seat_widget)
		_seat_widgets[player_view.seat] = seat_widget
		var action_widget := _create_seat_action_label(player_view)
		_seats.add_child(action_widget)
		_seat_action_widgets[player_view.seat] = action_widget
		var showdown_widget := _create_showdown_label(player_view.seat)
		_seats.add_child(showdown_widget)
		_seat_showdown_widgets[player_view.seat] = showdown_widget


func _create_seat_widget(player_view: PlayerView) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Seat%d" % player_view.seat
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	(
		panel
		. add_theme_stylebox_override(
			"panel",
			_seat_frame_style(
				player_view,
				Color("0d271bd9"),
				Color("5dbf86"),
				NORMAL_SEAT_FRAME_WIDTH,
			),
		)
	)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 0)
	panel.add_child(content)
	var row := HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", 5)
	content.add_child(row)
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = OPPONENT_AVATAR_SIZE
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Avatars are authored at their display dimensions.  Linear filtering keeps
	# their edges smooth on desktop HiDPI surfaces; scaling a low-resolution
	# texture with nearest-neighbour filtering made the six-player layout look
	# visibly pixelated.
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var avatar_path: String = _avatar_assignments.get(player_view.seat, "")
	if not avatar_path.is_empty():
		avatar.texture = load(avatar_path) as Texture2D
	row.add_child(avatar)
	_add_main_pot_winner_star(row, player_view.seat, OPPONENT_AVATAR_SIZE)
	row.add_child(_create_seat_identity(player_view, SEAT_TEXT_FONT_SIZE))
	row.add_child(_create_marker_label(player_view))
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 4)
	content.add_child(footer)
	footer.add_child(_create_opponent_hole_cards(player_view))
	if player_view.folded or player_view.busted:
		FoldedSeatStyleScript.apply(panel)
	return panel


func _create_hero_seat_widget(player_view: PlayerView) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Seat%d" % player_view.seat
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	(
		panel
		. add_theme_stylebox_override(
			"panel",
			_seat_frame_style(
				player_view,
				Color("102d21f2"),
				Color("e7d39b"),
				HERO_SEAT_FRAME_WIDTH,
			),
		)
	)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 2)
	panel.add_child(content)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 7)
	content.add_child(header)
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = HERO_AVATAR_SIZE
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var avatar_path: String = _avatar_assignments.get(player_view.seat, "")
	if not avatar_path.is_empty():
		avatar.texture = load(avatar_path) as Texture2D
	header.add_child(avatar)
	_add_main_pot_winner_star(header, player_view.seat, HERO_AVATAR_SIZE)
	header.add_child(_create_seat_identity(player_view, HERO_SEAT_TEXT_FONT_SIZE))
	header.add_child(_create_marker_label(player_view))
	var cards := HBoxContainer.new()
	cards.name = "HeroCards"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 6)
	content.add_child(cards)
	if not player_view.folded:
		for index: int in range(displayed_hero_cards.size()):
			var card := (
				CardFaceFactoryScript
				. create_card_face(
					displayed_hero_cards[index],
					"HeroCard%d" % (index + 1),
					Vector2(108, 84),
					58,
					Color("f5f0dc"),
					Color("d9b56d"),
				)
			)
			cards.add_child(card)
	if player_view.folded or player_view.busted:
		FoldedSeatStyleScript.apply(panel)
	return panel


func _seat_frame_style(
	player_view: PlayerView,
	background_color: Color,
	normal_border_color: Color,
	normal_border_width: int,
) -> StyleBoxFlat:
	var is_acting: bool = player_view.seat == _bound_view.acting_seat
	var border_color: Color = ACTING_SEAT_FRAME_COLOR if is_acting else normal_border_color
	var border_width: int = normal_border_width * 3 if is_acting else normal_border_width
	return GuiTableStyleScript.box(background_color, border_color, border_width, 10)


func _create_marker_label(player_view: PlayerView) -> Label:
	var marker := Label.new()
	marker.name = "Marker"
	marker.text = _seat_marker_text(player_view)
	marker.custom_minimum_size = Vector2(96, 56)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	marker.autowrap_mode = TextServer.AUTOWRAP_OFF
	marker.clip_text = true
	marker.add_theme_font_size_override("font_size", SEAT_TEXT_FONT_SIZE)
	marker.add_theme_color_override("font_color", Color("172331"))
	marker.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.compact_box(Color("e7d39b"), Color("f5f0dc"), 1, 5)
	)
	return marker


func _add_main_pot_winner_star(
	header: HBoxContainer,
	seat: int,
	avatar_size: Vector2,
) -> void:
	if not _is_main_pot_winner_at_showdown(seat):
		return
	header.add_child(CardFaceFactoryScript.create_main_pot_winner_star(avatar_size))


func _is_main_pot_winner_at_showdown(seat: int) -> bool:
	if _bound_view == null or not _bound_view.showdown_results.has(seat):
		return false
	for award: PotAward in _bound_view.pot_awards:
		if award.pot_index == 0:
			return seat in award.winner_seats
	return false


func _create_seat_identity(player_view: PlayerView, name_font_size: int) -> VBoxContainer:
	var identity := VBoxContainer.new()
	identity.name = "Identity"
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = _seat_title(player_view)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", name_font_size)
	identity.add_child(name_label)
	var stack_label := Label.new()
	stack_label.name = "Stack"
	stack_label.text = "%d chips" % player_view.stack
	stack_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack_label.clip_text = true
	stack_label.add_theme_font_size_override("font_size", OPPONENT_CHIP_FONT_SIZE)
	identity.add_child(stack_label)
	return identity


func _create_opponent_hole_cards(player_view: PlayerView) -> HBoxContainer:
	var cards := HBoxContainer.new()
	cards.name = "HoleCards"
	cards.add_theme_constant_override("separation", 3)
	if player_view.folded or player_view.busted:
		return cards
	var revealed_cards: Array = _bound_view.revealed_hole_cards.get(player_view.seat, [])
	if revealed_cards.size() == 2:
		for index: int in range(2):
			var card: CardData = revealed_cards[index]
			cards.add_child(_create_opponent_card_face(card, index + 1))
		return cards
	for index: int in range(2):
		cards.add_child(_create_opponent_card_back(index + 1))
	return cards


func _create_seat_action_label(player_view: PlayerView) -> Label:
	var action_label := Label.new()
	action_label.name = "Seat%dAction" % player_view.seat
	action_label.text = _latest_action_text(player_view.seat)
	action_label.visible = not action_label.text.is_empty()
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	action_label.clip_text = true
	action_label.add_theme_font_size_override("font_size", SEAT_TEXT_FONT_SIZE)
	action_label.add_theme_color_override(
		"font_color", Color("a6a6a6") if player_view.folded else Color("f5f0dc")
	)
	return action_label


func _create_showdown_label(seat: int) -> Label:
	var showdown_label := Label.new()
	showdown_label.name = "Seat%dShowdown" % seat
	showdown_label.text = _showdown_hand_text(seat)
	showdown_label.visible = not showdown_label.text.is_empty()
	showdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	showdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	showdown_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	showdown_label.clip_text = true
	showdown_label.add_theme_font_size_override("font_size", SEAT_TEXT_FONT_SIZE)
	showdown_label.add_theme_color_override("font_color", Color("f5f0dc"))
	showdown_label.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.compact_box(Color("102d21ed"), Color("d9b56d"), 1, 5)
	)
	return showdown_label


func _showdown_hand_text(seat: int) -> String:
	if _bound_view == null:
		return ""
	var showdown_result: ShowdownResult = _bound_view.showdown_results.get(seat)
	return ShowdownHandFormatterScript.format(showdown_result)


func _create_opponent_card_back(index: int) -> Label:
	var card_back := Label.new()
	card_back.name = "CardBack%d" % index
	card_back.custom_minimum_size = OPPONENT_CARD_SIZE
	card_back.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.compact_box(Color("173e58"), Color("e7d39b"), 2, 3)
	)
	return card_back


func _create_opponent_card_face(card_data: CardData, index: int) -> PanelContainer:
	return (
		CardFaceFactoryScript
		. create_card_face(
			card_data,
			"ShowdownCard%d" % index,
			OPPONENT_CARD_SIZE,
			40,
			Color("f5f0dc"),
			Color("d9b56d"),
		)
	)


func _seat_title(player_view: PlayerView) -> String:
	var human_suffix: String = " (you)" if player_view.is_human else ""
	var elimination_suffix: String = " (eliminated)" if player_view.busted else ""
	return "%s%s%s" % [player_view.display_name, human_suffix, elimination_suffix]


func _seat_marker_text(player_view: PlayerView) -> String:
	var markers: Array[String] = []
	if player_view.seat == _bound_view.button_seat:
		markers.append("D")
	if player_view.seat == _bound_view.small_blind_seat:
		markers.append("SB")
	if player_view.seat == _bound_view.big_blind_seat:
		markers.append("BB")
	if player_view.seat == _bound_view.acting_seat:
		markers.append("ACT")
	return " ".join(markers)


func _latest_action_text(seat: int) -> String:
	if _bound_view == null:
		return ""
	var latest_record: PublicActionRecord = _active_round_latest_actions.get(seat)
	if latest_record == null:
		return ""
	var action_text: String = ""
	if latest_record.record_kind == PublicActionRecord.Kind.SMALL_BLIND:
		action_text = "Small blind %d" % latest_record.amount
	elif latest_record.record_kind == PublicActionRecord.Kind.BIG_BLIND:
		action_text = "Big blind %d" % latest_record.amount
	else:
		match latest_record.kind:
			PlayerAction.Kind.FOLD:
				action_text = "Fold"
			PlayerAction.Kind.CHECK:
				action_text = "Check"
			PlayerAction.Kind.CALL:
				action_text = "Call %d" % latest_record.amount
			PlayerAction.Kind.BET:
				action_text = "Bet %d" % latest_record.amount
			PlayerAction.Kind.RAISE:
				action_text = "Raise %d" % latest_record.amount
			PlayerAction.Kind.ALL_IN:
				action_text = "All-in %d" % latest_record.amount
	return action_text


func _refresh_seat_action_labels() -> void:
	for seat: int in _seat_action_widgets:
		var action_label: Label = _seat_action_widgets[seat]
		action_label.text = _latest_action_text(seat)
		action_label.visible = not action_label.text.is_empty()


func _pot_layer_text() -> String:
	return "" if _bound_view.pots.size() <= 1 else "  •  %d layers" % _bound_view.pots.size()


func _enforce_minimum_gui_text_size_for_node(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit:
		if node.get_theme_font_size("font_size") < GUI_MINIMUM_FONT_SIZE:
			node.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	elif node is RichTextLabel:
		if node.get_theme_font_size("normal_font_size") < GUI_MINIMUM_FONT_SIZE:
			node.add_theme_font_size_override("normal_font_size", GUI_MINIMUM_FONT_SIZE)
	for child: Node in node.get_children():
		_enforce_minimum_gui_text_size_for_node(child)


func _refresh_action_controls() -> void:
	if _bound_view == null:
		return
	var is_human_turn: bool = _bound_view.acting_seat == _bound_view.hero_seat
	var legal: Array = _bound_view.legal_actions if is_human_turn else []
	var can_wager: bool = WagerKeypadScript.can_wager(_bound_view)
	_fold_button.disabled = not (PlayerAction.Kind.FOLD in legal)
	_check_call_button.disabled = not (
		PlayerAction.Kind.CHECK in legal or PlayerAction.Kind.CALL in legal
	)
	_min_wager_button.disabled = not can_wager
	_pot_raise_button.disabled = not _can_submit_pot_raise(legal, is_human_turn)
	_wager_input.editable = can_wager
	_wager_button.disabled = not can_wager
	_all_in_button.disabled = not (PlayerAction.Kind.ALL_IN in legal)
	if PlayerAction.Kind.CHECK in legal:
		_check_call_button.text = "Check"
	elif PlayerAction.Kind.CALL in legal:
		_check_call_button.text = "Call %d" % _bound_view.call_amount
	else:
		_check_call_button.text = "Check / Call"
	var wager_name: String = "Bet" if PlayerAction.Kind.BET in legal else "Raise"
	_min_wager_button.text = "Min %s %d" % [wager_name, _bound_view.minimum_wager_total]
	_wager_button.text = wager_name
	_all_in_button.text = "All-in"
	if not can_wager and _wager_keypad != null:
		_wager_keypad.hide()
	if _bound_view.tournament_status == &"finished":
		_action_status.text = TournamentStatusFormatterScript.format(_bound_view)
	elif is_human_turn:
		_action_status.text = "Your turn — %s." % GuiEventFormatterScript.street_name(_bound_view)
	elif _bound_view.hand_complete:
		_action_status.text = "Hand complete."
	else:
		_action_status.text = (
			"Waiting for %s — %s."
			% [
				GuiEventFormatterScript.player_name_for(_bound_view, _bound_view.acting_seat),
				GuiEventFormatterScript.street_name(_bound_view),
			]
		)


func _can_submit_pot_raise(legal: Array, is_human_turn: bool) -> bool:
	if not is_human_turn or PlayerAction.Kind.RAISE not in legal:
		return false
	var target: int = displayed_pot_amount
	return target >= _bound_view.minimum_wager_total and target <= _bound_view.maximum_wager_total


func _on_fold_pressed() -> void:
	_submit_action(PlayerAction.fold_action())


func _on_check_call_pressed() -> void:
	if _bound_view == null:
		return
	if PlayerAction.Kind.CHECK in _bound_view.legal_actions:
		_submit_action(PlayerAction.check_action())
	elif PlayerAction.Kind.CALL in _bound_view.legal_actions:
		_submit_action(PlayerAction.call_action())


func _on_min_wager_pressed() -> void:
	submit_wager_total(_bound_view.minimum_wager_total)


func _on_pot_raise_pressed() -> void:
	if _bound_view == null:
		return
	if not _can_submit_pot_raise(
		_bound_view.legal_actions, _bound_view.acting_seat == _bound_view.hero_seat
	):
		return
	submit_wager_total(displayed_pot_amount)


func _on_wager_pressed() -> void:
	if not _wager_input.text.is_valid_int():
		_action_status.text = "Enter a whole-number wager total."
		return
	submit_wager_total(_wager_input.text.to_int())


func _on_all_in_pressed() -> void:
	_submit_action(PlayerAction.all_in_action())


func _on_quit_pressed() -> void:
	if _match == null:
		return
	if _match.state == TournamentMatch.State.FINISHED:
		return_to_startup_requested.emit()
	elif _match.state == TournamentMatch.State.RUNNING:
		_quit_confirmation.popup_centered()


func _on_quit_confirmed() -> void:
	if _match == null:
		return
	_action_pacer.cancel()
	var result: StepResult = _match.request_quit()
	refresh_from_match()
	if result.status == StepResult.Status.ERROR:
		_action_status.text = result.message
		return
	tournament_quit_confirmed.emit()


func _submit_action(action: PlayerAction) -> void:
	if _match == null:
		push_error("PokerTableController cannot submit without a TournamentMatch.")
		return
	var result: StepResult = _match.submit_human_action_without_advance(action)
	refresh_from_match()
	if not result.message.is_empty():
		_action_status.text = result.message
	if result.status == StepResult.Status.YIELDED:
		_schedule_after_latest_action()


func _schedule_after_latest_action() -> void:
	if _match == null:
		return
	var view: GameView = _match.get_view_for(_recipient_seat)
	if view == null:
		return
	if view.hand_complete:
		_schedule_after_completed_hand()
		return
	var events: Array[DomainEvent] = _match.get_events()
	if not events.is_empty() and events[-1].kind == DomainEvent.Kind.ACTION_APPLIED:
		_schedule_next_action(events[-1].seat)
		return
	if view.acting_seat == Table.NO_SEAT and view.legal_actions.is_empty():
		# A short blind or an all-in runout can complete a betting round without
		# an action event. Continue from the resolved view state rather than
		# leaving the table displaying a fictitious waiting player.
		if not events.is_empty() and events[-1].kind == DomainEvent.Kind.COMMUNITY_CARDS_DEALT:
			_schedule_next_action(Table.NO_SEAT)
		else:
			call_deferred("_advance_after_action_pause")
		return
	return


func _schedule_next_action(actor_seat: int) -> void:
	_action_pacer.schedule_after_action(actor_seat, _advance_after_action_pause)


func _advance_after_action_pause() -> void:
	if _match == null:
		return
	var latest_action_seat: int = GuiMatchProgressInspectorScript.latest_action_seat(
		_match.get_events()
	)
	var result: StepResult = _match.advance_one_action()
	refresh_from_match()
	if result.status == StepResult.Status.YIELDED:
		if GuiMatchProgressInspectorScript.latest_event_is_community_cards_dealt(
			_match.get_events()
		):
			_schedule_next_action(latest_action_seat)
		else:
			_schedule_after_latest_action()
	elif result.status == StepResult.Status.HAND_COMPLETED:
		_schedule_after_completed_hand()
	elif result.status == StepResult.Status.ERROR:
		_action_status.text = result.message


func _advance_after_hand_boundary() -> void:
	if _match == null or _match.state != TournamentMatch.State.RUNNING:
		return
	var result: StepResult = _match.advance_one_action()
	refresh_from_match()
	if result.status == StepResult.Status.YIELDED:
		_schedule_after_latest_action()
	elif result.status == StepResult.Status.HAND_COMPLETED:
		_schedule_after_completed_hand()
	elif result.status == StepResult.Status.ERROR:
		_action_status.text = result.message


func _schedule_after_completed_hand() -> void:
	if GuiMatchProgressInspectorScript.contains_showdown(_match.get_events()):
		_action_pacer.schedule_after_showdown(_advance_after_hand_boundary)
	else:
		call_deferred("_advance_after_hand_boundary")


func _render_events(events: Array[DomainEvent]) -> void:
	_event_texts.clear()
	_active_round_latest_actions.clear()
	var action_records: Array[PublicActionRecord] = []
	for record: PublicActionRecord in _bound_view.action_history:
		action_records.append(record)
	var action_index: int = 0
	var street_transition_index: int = 0
	for event: DomainEvent in events:
		var action_record: PublicActionRecord = null
		if (
			event.kind == DomainEvent.Kind.HAND_STARTED
			or event.kind == DomainEvent.Kind.STREET_CHANGED
		):
			_active_round_latest_actions.clear()
		if (
			(
				event.kind == DomainEvent.Kind.ACTION_APPLIED
				or event.kind == DomainEvent.Kind.BLIND_POSTED
			)
			and action_index < action_records.size()
		):
			action_record = action_records[action_index]
			action_index += 1
			_active_round_latest_actions[action_record.seat] = action_record
		if event.kind == DomainEvent.Kind.STREET_CHANGED:
			_event_texts.append(
				GuiEventFormatterScript.street_transition_text(street_transition_index)
			)
			street_transition_index += 1
		else:
			_event_texts.append(
				GuiEventFormatterScript.format_event(event, _bound_view, action_record)
			)
	_event_log.text = "\n".join(_event_texts)
	_refresh_seat_action_labels()


func _layout_table() -> void:
	if not is_node_ready():
		return
	var surface_size: Vector2 = _surface.size
	if surface_size.x <= 0.0 or surface_size.y <= 0.0:
		return
	var mobile_portrait_layout: bool = GuiMobileTableLayoutScript.is_mobile_portrait(surface_size)
	var landscape_tablet_layout: bool = GuiMobileTableLayoutScript.is_landscape_tablet(surface_size)
	var small_desktop_layout: bool = GuiMobileTableLayoutScript.is_small_desktop(surface_size)
	var mobile_content_scale: float = GuiMobileTableLayoutScript.content_scale(surface_size)
	var seat_content_scale: float = GuiMobileTableLayoutScript.seat_scale(surface_size)
	# Desktop controls use source dimensions directly.  The previous 0.75
	# post-render correction scaled fonts, card faces, avatars, and border
	# geometry together, producing blurry text and uneven line weights at normal
	# MacBook display scaling.  The desktop source sizes are now the approved
	# display sizes; mobile retains its responsive content scale below.
	# Keep normal full-HD desktops at their authored sizes, while smaller desktop
	# surfaces reflow their geometry from the available space. Typography remains
	# at its integer source size through `desktop_source_sizes`; this is layout,
	# not a post-render transform.
	var seat_visual_scale: float = seat_content_scale
	(
		GuiMobileTableLayoutScript
		. apply_scale(
			mobile_portrait_layout,
			mobile_content_scale,
			_board_label,
			_pot_label,
			_wager_label,
			_action_status,
			_event_log,
			_quit_button,
			[
				_fold_button,
				_check_call_button,
				_min_wager_button,
				_pot_raise_button,
				_wager_input,
				_wager_button,
				_all_in_button,
			],
			_card_slots,
			_seat_widgets,
			_seat_action_widgets,
			_seat_showdown_widgets,
			seat_content_scale,
			seat_visual_scale,
		)
	)
	if small_desktop_layout:
		_board_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_pot_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_wager_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_action_status.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_action_status.clip_text = true
		for control: Control in [
			_fold_button,
			_check_call_button,
			_min_wager_button,
			_pot_raise_button,
			_wager_input,
			_wager_button,
			_all_in_button,
		]:
			control.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		for card: Control in _card_slots.get_children():
			GuiMobileTableLayoutScript._scale_card_face(card, Vector2(45.0, 57.0), 22)
	var center_width: float = clampf(
		surface_size.x * (0.56 if mobile_portrait_layout else 0.48),
		230.0,
		(
			360.0
			if small_desktop_layout
			else (680.0 if mobile_portrait_layout else DESKTOP_CENTER_ZONE_MAX_WIDTH)
		),
	)
	var center_minimum_height: float = _center_zone.get_combined_minimum_size().y
	var center_size := Vector2(
		center_width,
		maxf(
			(
				184.0
				if small_desktop_layout
				else (184.0 * mobile_content_scale if mobile_portrait_layout else 184.0)
			),
			center_minimum_height if not small_desktop_layout else 184.0,
		),
	)
	var center_position: Vector2 = (surface_size - center_size) * 0.5
	if small_desktop_layout:
		center_position.y = 8.0
	# CenterZone is a manually positioned presentation region. Apply one
	# resolved width after rebuilding all children and never defer an older
	# bounds value past a newer layout pass. Child minimum sizes are deliberately
	# cleared in the same operation so status text cannot widen the stack.
	_apply_center_zone_bounds(center_size, center_position)
	call_deferred(
		"_apply_center_zone_bounds_if_current",
		center_size,
		center_position,
		_layout_generation,
	)
	if _seat_widgets.is_empty():
		return
	var compact_layout: bool = (
		surface_size.x < 600.0 or mobile_portrait_layout or small_desktop_layout
	)
	var seat_width: float = (
		clampf(
			surface_size.x * 0.32,
			104.0 * seat_content_scale,
			280.0 * seat_content_scale,
		)
		if mobile_portrait_layout
		else (
			clampf(surface_size.x * 0.27, 104.0 * seat_content_scale, 140.0 * seat_content_scale)
			if compact_layout
			else maxf(
				360.0 * seat_content_scale,
				clampf(
					surface_size.x * 0.23, 250.0 * seat_content_scale, 360.0 * seat_content_scale
				),
			)
		)
	)
	# The avatar is the dominant visual element in a seat. Reserve roughly half
	# of its displayed width as additional horizontal breathing room so names,
	# stacks, markers, and card backs do not crowd the avatar at desktop sizes.
	if not mobile_portrait_layout:
		seat_width += maxf(OPPONENT_AVATAR_SIZE.x, HERO_AVATAR_SIZE.x) * 0.5 * seat_visual_scale
	var seat_count: int = _seat_widgets.size()
	for seat: int in _seat_widgets:
		var is_hero: bool = seat == _bound_view.hero_seat
		var hero_minimum_height: float = maxf(
			96.0 * seat_visual_scale, _action_panel.get_combined_minimum_size().y
		)
		var seat_size := (
			Vector2(seat_width, hero_minimum_height)
			if is_hero
			else Vector2(seat_width, 70.0 * seat_visual_scale)
		)
		if compact_layout and is_hero:
			seat_size = Vector2(
				clampf(
					surface_size.x * (0.76 if mobile_portrait_layout else 0.56),
					190.0 * seat_visual_scale,
					440.0 * seat_visual_scale,
				),
				80.0 * seat_visual_scale,
			)
		var visual_slot: int = _visual_slot_for_seat(seat, seat_count)
		var normalized_position: Vector2 = (
			Vector2(0.5, 0.91)
			if is_hero
			else (
				TableSeatLayoutScript.landscape_tablet_positions(seat_count)[visual_slot]
				if landscape_tablet_layout
				else (
					(
						TableSeatLayoutScript.small_desktop_positions(seat_count)[visual_slot]
						if small_desktop_layout
						else (
							TableSeatLayoutScript.compact_desktop_positions(seat_count)[visual_slot]
						)
					)
					if not mobile_portrait_layout and surface_size.x < 1200.0
					else TableSeatLayoutScript.symmetric_positions(seat_count)[visual_slot]
				)
			)
		)
		normalized_position = (
			GuiMobileTableLayoutScript
			. opponent_position(
				normalized_position,
				mobile_portrait_layout and not is_hero,
				seat_content_scale,
			)
		)
		var panel: PanelContainer = _seat_widgets[seat]
		GuiMobileTableLayoutScript.apply_seat_typography(
			panel,
			seat_visual_scale,
			is_hero,
			1.0,
			not mobile_portrait_layout and not small_desktop_layout
		)
		var minimum_size: Vector2 = panel.get_combined_minimum_size()
		var resolved_seat_size := Vector2(
			maxf(seat_size.x, minimum_size.x), maxf(seat_size.y, minimum_size.y)
		)
		if not mobile_portrait_layout and surface_size.x < 1200.0 and not is_hero:
			# Short desktop surfaces cannot fit nine full-height source panels in
			# the regular ring. Keep the panel footprint compact; its content is
			# still laid out by the same presentation controls and remains clipped
			# to the seat boundary instead of colliding with neighboring seats.
			resolved_seat_size.y = minf(resolved_seat_size.y, 170.0)
		panel.size = resolved_seat_size
		var intended_position: Vector2 = (
			normalized_position * surface_size - resolved_seat_size * 0.5
		)
		panel.position = Vector2(
			clampf(intended_position.x, 0.0, surface_size.x - resolved_seat_size.x),
			clampf(intended_position.y, 0.0, surface_size.y - resolved_seat_size.y),
		)
		(
			GuiMobileTableLayoutScript
			. layout_seat_action_label(
				_seat_action_widgets.get(seat),
				panel,
				compact_layout,
				1.0 if small_desktop_layout else seat_visual_scale,
			)
		)
		var action_label: Label = _seat_action_widgets.get(seat)
		if action_label != null and action_label.visible:
			var action_overflow: float = action_label.get_rect().end.y - surface_size.y
			if action_overflow > 0.0:
				panel.position.y = maxf(0.0, panel.position.y - action_overflow - 2.0)
				(
					GuiMobileTableLayoutScript
					. layout_seat_action_label(
						action_label,
						panel,
						compact_layout,
						1.0 if small_desktop_layout else seat_visual_scale,
					)
				)
		(
			GuiMobileTableLayoutScript
			. layout_seat_showdown_label(
				_seat_showdown_widgets.get(seat),
				panel,
				compact_layout,
				1.0 if small_desktop_layout else seat_visual_scale,
			)
		)
	(
		GuiMobileTableLayoutScript
		. layout_human_adjacent_panels(
			surface_size,
			compact_layout,
			mobile_content_scale,
			_seat_widgets.get(_bound_view.hero_seat),
			_action_panel,
			_event_log,
			_seat_widgets.size(),
		)
	)
	if small_desktop_layout:
		_resolve_small_desktop_auxiliary_clearance(surface_size)
	if not compact_layout:
		# Containers can report a larger minimum after their children resolve.
		# Re-apply the approved compact desktop height after layout so the
		# reserved side regions remain deterministic.
		var desktop_side_height: float = 180.0
		var desktop_side_bottom: float = (
			_seat_widgets[_bound_view.hero_seat].position.y
			+ _seat_widgets[_bound_view.hero_seat].size.y
		)
		var desktop_side_y: float = desktop_side_bottom - desktop_side_height
		_action_panel.size.y = desktop_side_height
		_event_log.size.y = desktop_side_height
		_action_panel.position.y = desktop_side_y
		_event_log.position.y = desktop_side_y


func _visual_slot_for_seat(seat: int, seat_count: int) -> int:
	var bottom_slot: int = seat_count / 2
	var relative_seat: int = posmod(seat - _bound_view.hero_seat, seat_count)
	return posmod(bottom_slot + relative_seat, seat_count)


func _queue_layout() -> void:
	if not is_node_ready() or _layout_queued:
		return
	_layout_queued = true
	_layout_generation += 1
	call_deferred("_apply_queued_layout")


func _apply_queued_layout() -> void:
	_layout_queued = false
	_layout_table()


func _apply_center_zone_bounds(resolved_size: Vector2, resolved_position: Vector2) -> void:
	if not is_instance_valid(_center_zone):
		return
	_center_zone.custom_minimum_size = Vector2(resolved_size.x, 0.0)
	_center_zone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_center_zone.size = resolved_size
	_center_zone.position = resolved_position
	for child: Control in [_board_zone, _pot_zone, _wager_zone]:
		child.custom_minimum_size.x = 0.0
		child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		child.size.x = resolved_size.x


func _apply_center_zone_bounds_if_current(
	resolved_size: Vector2,
	resolved_position: Vector2,
	generation: int,
) -> void:
	if generation != _layout_generation:
		return
	_apply_center_zone_bounds(resolved_size, resolved_position)


func _resolve_small_desktop_auxiliary_clearance(surface_size: Vector2) -> void:
	var obstacles: Array[Rect2] = [
		_surface_local_rect(_center_zone),
		_surface_local_rect(_event_log),
		_surface_local_rect(_action_panel),
	]
	for seat: int in _seat_widgets:
		var panel: PanelContainer = _seat_widgets[seat]
		var action_label: Label = _seat_action_widgets[seat]
		var showdown_label: Label = _seat_showdown_widgets[seat]
		for attempt: int in range(3):
			var auxiliary_rects: Array[Rect2] = []
			if action_label.visible:
				auxiliary_rects.append(_surface_local_rect(action_label))
			if showdown_label.visible:
				auxiliary_rects.append(_surface_local_rect(showdown_label))
			var has_collision: bool = false
			for auxiliary_rect: Rect2 in auxiliary_rects:
				if auxiliary_rect.position.y < 0.0 or auxiliary_rect.end.y > surface_size.y:
					has_collision = true
					break
				for obstacle: Rect2 in obstacles:
					if auxiliary_rect.intersects(obstacle):
						has_collision = true
						break
				if has_collision:
					break
			if not has_collision:
				break
			var shift_up: float = 0.0
			var shift_down: float = 0.0
			for auxiliary_rect: Rect2 in auxiliary_rects:
				if auxiliary_rect.end.y > surface_size.y:
					shift_up = maxf(shift_up, auxiliary_rect.end.y - surface_size.y + 4.0)
				if auxiliary_rect.position.y < 0.0:
					shift_down = maxf(shift_down, -auxiliary_rect.position.y + 4.0)
				for obstacle: Rect2 in obstacles:
					if auxiliary_rect.intersects(obstacle):
						if auxiliary_rect == _surface_local_rect(showdown_label):
							if obstacle.end.y <= panel.position.y:
								shift_down = maxf(
									shift_down, obstacle.end.y - auxiliary_rect.position.y + 4.0
								)
							else:
								shift_up = maxf(
									shift_up, auxiliary_rect.end.y - obstacle.position.y + 4.0
								)
						else:
							shift_up = maxf(
								shift_up, auxiliary_rect.end.y - obstacle.position.y + 4.0
							)
			if shift_up <= 0.0 and shift_down <= 0.0:
				break
			panel.position.y = clampf(
				panel.position.y - shift_up + shift_down,
				0.0,
				surface_size.y - panel.size.y,
			)
			GuiMobileTableLayoutScript.layout_seat_action_label(action_label, panel, true, 1.0)
			GuiMobileTableLayoutScript.layout_seat_showdown_label(showdown_label, panel, true, 1.0)
		# Keep the resolved panel in the surface after any auxiliary-label shift.
		panel.position.y = clampf(panel.position.y, 0.0, surface_size.y - panel.size.y)
