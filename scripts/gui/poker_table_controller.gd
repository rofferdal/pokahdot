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
const CENTER_ZONE_SEPARATION: float = 8.0
const CENTER_BOARD_MINIMUM_HEIGHT: float = 74.0
@export var action_timing_config: Resource

var board_card_count: int = 0
var wager_amounts: Dictionary[int, int] = {}
var displayed_pot_amount: int = 0
var displayed_hero_cards: Array[CardData] = []
var _bound_view: GameView
var _match: TournamentMatch
var _recipient_seat: int = Table.NO_SEAT
var _avatar_assignments: Dictionary[int, String] = {}
var _name_assignments: Dictionary[int, String] = {}
var _seat_widgets: Dictionary[int, PanelContainer] = {}
var _seat_status_widgets: Dictionary[int, Label] = {}
var _layout_queued: bool = false
var _layout_generation: int = 0
var _resolved_center_size: Vector2 = Vector2.ZERO
var _resolved_center_position: Vector2 = Vector2.ZERO
var _event_texts: Array[String] = []
var _active_round_latest_actions: Dictionary[int, PublicActionRecord] = {}
var _retained_fold_actions: Dictionary[int, PublicActionRecord] = {}
var _action_pacer = GuiActionPacerScript.new()
var _wager_keypad: WagerKeypad

@onready var _felt: Panel = $TableMargin/Felt
@onready var _surface: Control = $TableMargin/Felt/TableSurface
@onready var _center_zone: Control = $TableMargin/Felt/TableSurface/CenterZone
@onready var _board_zone: Panel = $TableMargin/Felt/TableSurface/CenterZone/BoardZone
@onready
var _board_content: VBoxContainer = $TableMargin/Felt/TableSurface/CenterZone/BoardZone/BoardContent
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


func bind_view(
	view: GameView,
	avatar_assignments: Dictionary[int, String],
	name_assignments: Dictionary[int, String] = {},
) -> void:
	if view == null:
		push_error("PokerTableController requires a GameView.")
		return
	_bound_view = view
	_avatar_assignments = avatar_assignments.duplicate()
	_name_assignments = name_assignments.duplicate()
	_event_texts.clear()
	board_card_count = view.community_cards.size()
	displayed_pot_amount = view.pot_amount
	displayed_hero_cards = view.hero_hole_cards
	wager_amounts.clear()
	_active_round_latest_actions.clear()
	_retained_fold_actions.clear()
	for record: PublicActionRecord in view.action_history:
		_active_round_latest_actions[record.seat] = record
		if (
			record.record_kind == PublicActionRecord.Kind.ACTION
			and record.kind == PlayerAction.Kind.FOLD
		):
			_retained_fold_actions[record.seat] = record
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
	name_assignments: Dictionary[int, String] = {},
) -> void:
	if match == null:
		push_error("PokerTableController requires a TournamentMatch.")
		return
	_match = match
	_recipient_seat = recipient_seat
	_avatar_assignments = avatar_assignments.duplicate()
	_name_assignments = name_assignments.duplicate()
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
	bind_view(view, _avatar_assignments, _name_assignments)
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
		regions[StringName("status_%d" % seat)] = _surface_local_rect(_seat_status_widgets[seat])
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


## Read-only layout diagnostics used by deterministic resize regressions.
func get_layout_generation() -> int:
	return _layout_generation


func is_layout_pending() -> bool:
	return _layout_queued


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
		"Pot: %d | SB %d BB %d | L%d"
		% [
			displayed_pot_amount,
			_bound_view.small_blind,
			_bound_view.big_blind,
			_bound_view.blind_level,
		]
	)
	_configure_status_label(_pot_label)
	_configure_status_label(_wager_label)
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
				Vector2(68, 76),
				CardFaceFactoryScript.COMMUNITY_CARD_RANK_FONT_SIZE,
				Color("f5f0dc") if is_face_up else Color("173e58"),
				Color("e7d39b"),
				true,
			)
		)
		slot.modulate.a = 1.0 if index < board_card_count else 0.48
		_card_slots.add_child(slot)


func _rebuild_seats() -> void:
	for seat_widget: PanelContainer in _seat_widgets.values():
		seat_widget.free()
	for status_widget: Label in _seat_status_widgets.values():
		status_widget.free()
	_seat_widgets.clear()
	_seat_status_widgets.clear()
	for player_view: PlayerView in _bound_view.seats:
		var seat_widget := (
			_create_hero_seat_widget(player_view)
			if player_view.seat == _bound_view.hero_seat
			else _create_seat_widget(player_view)
		)
		_seats.add_child(seat_widget)
		_seat_widgets[player_view.seat] = seat_widget
		var status_widget := _create_seat_status_label(player_view)
		_seats.add_child(status_widget)
		_seat_status_widgets[player_view.seat] = status_widget


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
	var avatar_region := _create_avatar_region(player_view.seat, OPPONENT_AVATAR_SIZE)
	row.add_child(avatar_region)
	_add_main_pot_winner_star(avatar_region, player_view.seat, OPPONENT_AVATAR_SIZE)
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
	var avatar_region := _create_avatar_region(player_view.seat, HERO_AVATAR_SIZE)
	header.add_child(avatar_region)
	_add_main_pot_winner_star(avatar_region, player_view.seat, HERO_AVATAR_SIZE)
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


func _create_avatar_region(seat: int, avatar_size: Vector2) -> Control:
	var region := Control.new()
	region.name = "AvatarRegion"
	region.custom_minimum_size = avatar_size
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Avatars are authored at their display dimensions. Linear filtering keeps
	# their edges smooth on desktop HiDPI surfaces.
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var avatar_path: String = _avatar_assignments.get(seat, "")
	if not avatar_path.is_empty():
		avatar.texture = load(avatar_path) as Texture2D
	region.add_child(avatar)
	return region


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
	var marker_style := GuiTableStyleScript.compact_box(Color("e7d39b"), Color("f5f0dc"), 1, 5)
	if marker.text.is_empty():
		marker_style.bg_color = Color.TRANSPARENT
		marker_style.border_color = Color.TRANSPARENT
	marker.add_theme_stylebox_override("normal", marker_style)
	return marker


func _add_main_pot_winner_star(
	avatar_region: Control,
	seat: int,
	avatar_size: Vector2,
) -> void:
	if not _is_main_pot_winner_at_showdown(seat):
		return
	var star := CardFaceFactoryScript.create_main_pot_winner_star(avatar_size)
	star.set_anchors_preset(Control.PRESET_TOP_LEFT)
	star.position = Vector2.ZERO
	avatar_region.add_child(star)


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


func _create_seat_status_label(player_view: PlayerView) -> Label:
	var status_label := Label.new()
	status_label.name = "Seat%dStatus" % player_view.seat
	status_label.z_index = 100
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.clip_text = true
	status_label.add_theme_font_size_override("font_size", SEAT_TEXT_FONT_SIZE)
	status_label.add_theme_color_override(
		"font_color", Color("a6a6a6") if player_view.folded else Color("f5f0dc")
	)
	_configure_seat_status_label(status_label, player_view.seat)
	return status_label


func _showdown_hand_text(seat: int) -> String:
	if _bound_view == null:
		return ""
	var showdown_result: ShowdownResult = _bound_view.showdown_results.get(seat)
	if GuiMobileTableLayoutScript.is_small_desktop(_surface.size):
		return ShowdownHandFormatterScript.format_compact(showdown_result)
	return ShowdownHandFormatterScript.format(showdown_result)


func _configure_seat_status_label(label: Label, seat: int) -> void:
	var showdown_text: String = _showdown_hand_text(seat)
	if not showdown_text.is_empty():
		label.text = showdown_text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 2
		return
	if _is_pre_showdown_winner(seat):
		label.text = "Winner"
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.max_lines_visible = 1
		return
	label.text = _latest_action_text(seat)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = 1


func _is_pre_showdown_winner(seat: int) -> bool:
	return (
		_bound_view != null
		and _bound_view.hand_complete
		and _bound_view.hand_winner_seat != Table.NO_SEAT
		and _bound_view.hand_winner_seat == seat
		and _bound_view.showdown_results.is_empty()
	)


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
	if player_view.is_human:
		return NameAssignmentService.HUMAN_LABEL
	return _name_assignments.get(player_view.seat, player_view.display_name)


func _seat_marker_text(player_view: PlayerView) -> String:
	var markers: Array[String] = []
	if player_view.seat == _bound_view.button_seat:
		markers.append("D")
	if player_view.seat == _bound_view.small_blind_seat:
		markers.append("SB")
	if player_view.seat == _bound_view.big_blind_seat:
		markers.append("BB")
	return " ".join(markers)


func _latest_action_text(seat: int) -> String:
	if _bound_view == null:
		return ""
	var latest_record: PublicActionRecord = _active_round_latest_actions.get(seat)
	if latest_record == null:
		latest_record = _retained_fold_actions.get(seat)
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


func _refresh_seat_status_labels() -> void:
	for seat: int in _seat_status_widgets:
		_configure_seat_status_label(_seat_status_widgets[seat], seat)


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
	_configure_action_control_copy(legal)
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
	if _uses_compact_table_copy():
		if _bound_view.tournament_status == &"finished" and _bound_view.end_reason == &"winner":
			_action_status.text = "Player %d wins" % (_bound_view.tournament_winner_seat + 1)
		elif _bound_view.tournament_status != &"finished":
			if is_human_turn:
				_action_status.text = (
					"Your turn: %s" % GuiEventFormatterScript.street_name(_bound_view)
				)
			elif _bound_view.hand_complete:
				_action_status.text = "Hand complete"
			else:
				_action_status.text = (
					"Waiting: %s"
					% GuiEventFormatterScript.player_name_for(_bound_view, _bound_view.acting_seat)
				)


func _configure_action_control_copy(legal: Array) -> void:
	var compact_copy: bool = _uses_compact_table_copy()
	if PlayerAction.Kind.CHECK in legal:
		_check_call_button.text = "Check"
	elif PlayerAction.Kind.CALL in legal:
		_check_call_button.text = "Call %d" % _bound_view.call_amount
	else:
		_check_call_button.text = "Call" if compact_copy else "Check / Call"
	var wager_name: String = "Bet" if PlayerAction.Kind.BET in legal else "Raise"
	_min_wager_button.text = (
		"Min %d" % _bound_view.minimum_wager_total
		if compact_copy
		else "Min %s %d" % [wager_name, _bound_view.minimum_wager_total]
	)
	_pot_raise_button.text = "Pot" if compact_copy else "Pot raise"
	_wager_button.text = wager_name
	_wager_input.placeholder_text = "Total" if compact_copy else "Wager total"
	_wager_input.custom_minimum_size.x = 72.0 if compact_copy else 200.0


func _uses_compact_table_copy() -> bool:
	return (
		GuiMobileTableLayoutScript.is_small_desktop(_surface.size)
		or GuiMobileTableLayoutScript.is_portrait_tablet(_surface.size)
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
	_action_pacer.schedule_after_completed_hand(_advance_after_hand_boundary)


func _render_events(events: Array[DomainEvent]) -> void:
	_event_texts.clear()
	_active_round_latest_actions.clear()
	_retained_fold_actions.clear()
	var action_records: Array[PublicActionRecord] = []
	for record: PublicActionRecord in _bound_view.action_history:
		action_records.append(record)
	var action_index: int = 0
	var street_transition_index: int = 0
	for event: DomainEvent in events:
		var action_record: PublicActionRecord = _action_record_for_event(
			event, action_records, action_index
		)
		if action_record != null:
			for record_index: int in range(action_index, action_records.size()):
				if action_records[record_index] == action_record:
					action_index = record_index + 1
					break
		if (
			event.kind == DomainEvent.Kind.HAND_STARTED
			or event.kind == DomainEvent.Kind.STREET_CHANGED
		):
			_active_round_latest_actions.clear()
		if action_record != null:
			_active_round_latest_actions[action_record.seat] = action_record
			if (
				action_record.record_kind == PublicActionRecord.Kind.ACTION
				and action_record.kind == PlayerAction.Kind.FOLD
			):
				_retained_fold_actions[action_record.seat] = action_record
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
	_refresh_seat_status_labels()


func _action_record_for_event(
	event: DomainEvent,
	records: Array[PublicActionRecord],
	start_index: int,
) -> PublicActionRecord:
	if (
		event.kind != DomainEvent.Kind.ACTION_APPLIED
		and event.kind != DomainEvent.Kind.BLIND_POSTED
	):
		return null
	for record_index: int in range(start_index, records.size()):
		var record: PublicActionRecord = records[record_index]
		if record.seat != event.seat or record.amount != event.amount:
			continue
		if event.kind == DomainEvent.Kind.ACTION_APPLIED:
			if record.record_kind == PublicActionRecord.Kind.ACTION:
				return record
		elif record.record_kind != PublicActionRecord.Kind.ACTION:
			return record
	return null


func _layout_table() -> void:
	if not is_node_ready():
		return
	var surface_size: Vector2 = _surface.size
	if surface_size.x <= 0.0 or surface_size.y <= 0.0:
		return
	# Content can be bound while the table is hidden at its authored scene size.
	# Re-resolve viewport-dependent compact/full copy in the same pass that owns
	# its geometry so showing or resizing cannot leave stale status text behind.
	_refresh_seat_status_labels()
	var mobile_portrait_layout: bool = GuiMobileTableLayoutScript.is_mobile_portrait(surface_size)
	var portrait_tablet_layout: bool = GuiMobileTableLayoutScript.is_portrait_tablet(surface_size)
	var landscape_tablet_layout: bool = GuiMobileTableLayoutScript.is_landscape_tablet(surface_size)
	var small_desktop_layout: bool = GuiMobileTableLayoutScript.is_small_desktop(surface_size)
	var is_human_turn: bool = _bound_view.acting_seat == _bound_view.hero_seat
	var active_legal: Array = _bound_view.legal_actions if is_human_turn else []
	_configure_action_control_copy(active_legal)
	var mobile_content_scale: float = GuiMobileTableLayoutScript.content_scale(surface_size)
	var seat_content_scale: float = GuiMobileTableLayoutScript.seat_scale(surface_size)
	_card_slots.add_theme_constant_override(
		"separation", 2 if small_desktop_layout or portrait_tablet_layout else 6
	)
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
			_seat_status_widgets,
			seat_content_scale,
			seat_visual_scale,
		)
	)
	var action_margin := _action_panel.get_node("Margin") as MarginContainer
	action_margin.add_theme_constant_override("margin_left", 2)
	action_margin.add_theme_constant_override("margin_right", 2)
	action_margin.add_theme_constant_override("margin_top", 2 if small_desktop_layout else 6)
	action_margin.add_theme_constant_override("margin_bottom", 2 if small_desktop_layout else 6)
	var action_panel_style := GuiTableStyleScript.box(Color("062516ed"), Color("d9b56d"), 1, 12)
	if small_desktop_layout:
		action_panel_style.content_margin_top = 0.0
		action_panel_style.content_margin_bottom = 0.0
	_action_panel.add_theme_stylebox_override("panel", action_panel_style)
	var action_content := _action_panel.get_node("Margin/Content") as VBoxContainer
	var action_rows := _action_panel.get_node("Margin/Content/ActionRows") as VBoxContainer
	var primary_buttons := action_rows.get_node("PrimaryButtons") as HBoxContainer
	action_content.add_theme_constant_override("separation", 0 if small_desktop_layout else 2)
	action_rows.add_theme_constant_override("separation", 0 if small_desktop_layout else 2)
	if small_desktop_layout or portrait_tablet_layout:
		_board_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_pot_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_wager_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_action_status.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_action_status.autowrap_mode = TextServer.AUTOWRAP_OFF
		_action_status.clip_text = true
		_action_status.max_lines_visible = 1
		_quit_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
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
			if control is Button or control is LineEdit:
				control.custom_minimum_size.y = 48.0
		for button: Button in [
			_fold_button, _check_call_button, _min_wager_button, _pot_raise_button
		]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for status_label: Label in _seat_status_widgets.values():
			status_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		for card: Control in _card_slots.get_children():
			GuiMobileTableLayoutScript._scale_card_face(card, Vector2(52.0, 57.0), 22)
	_quit_button.custom_minimum_size.y = 48.0
	_reserve_status_zone_height()
	var center_width: float = clampf(
		surface_size.x * (0.56 if mobile_portrait_layout else 0.48),
		230.0,
		(
			280.0
			if small_desktop_layout
			else (680.0 if mobile_portrait_layout else DESKTOP_CENTER_ZONE_MAX_WIDTH)
		),
	)
	if portrait_tablet_layout:
		center_width = 306.0
	var board_style: StyleBox = _board_zone.get_theme_stylebox("panel")
	var board_style_height: float = board_style.get_minimum_size().y if board_style != null else 0.0
	var board_height: float = maxf(
		CENTER_BOARD_MINIMUM_HEIGHT,
		_board_content.get_combined_minimum_size().y + board_style_height,
	)
	var center_content_height: float = (
		board_height
		+ _pot_zone.custom_minimum_size.y
		+ _wager_zone.custom_minimum_size.y
		+ CENTER_ZONE_SEPARATION * 2.0
	)
	var center_size := Vector2(
		center_width,
		maxf(
			(
				184.0
				if small_desktop_layout
				else (184.0 * mobile_content_scale if mobile_portrait_layout else 184.0)
			),
			center_content_height,
		),
	)
	var center_position: Vector2 = (surface_size - center_size) * 0.5
	if small_desktop_layout or portrait_tablet_layout:
		# Use the top safety edge so the compact side panels can begin directly
		# after the central stack without entering its bounds.
		center_position.y = 0.0
	_resolved_center_size = center_size
	_resolved_center_position = center_position
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
	var full_ring_desktop_layout: bool = (
		seat_count == 9 and not compact_layout and not landscape_tablet_layout
	)
	var full_ring_opponent_height: float = 198.0 * seat_visual_scale
	var full_ring_footprint_height: float = (
		full_ring_opponent_height
		+ GuiMobileTableLayoutScript.STATUS_BAND_GAP * seat_visual_scale
		+ GuiMobileTableLayoutScript.STATUS_BAND_HEIGHT * seat_visual_scale
	)
	var small_desktop_opponent_index: int = 0
	var small_desktop_side_width: float = (surface_size.x - center_width) * 0.5
	var small_desktop_column_gap: float = 6.0
	var small_desktop_column_width: float = (
		(small_desktop_side_width - small_desktop_column_gap) * 0.5
	)
	var small_desktop_cell_order: Array[int] = [1, 2, 0, 3, 5, 6, 4, 7]
	var portrait_tablet_opponent_index: int = 0
	var portrait_tablet_seat_width: float = (surface_size.x - center_width) * 0.5 - 8.0
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
		if portrait_tablet_layout:
			seat_size.x = center_width if is_hero else portrait_tablet_seat_width
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
		if not small_desktop_layout and not portrait_tablet_layout:
			GuiMobileTableLayoutScript.restore_standard_seat_overlays(panel, is_hero)
		GuiMobileTableLayoutScript.apply_seat_typography(
			panel,
			seat_visual_scale,
			is_hero,
			1.0,
			not mobile_portrait_layout and not small_desktop_layout
		)
		if small_desktop_layout or portrait_tablet_layout:
			GuiMobileTableLayoutScript.apply_small_desktop_seat_footprint(panel)
		_reserve_full_name_width(panel, small_desktop_layout or portrait_tablet_layout)
		var minimum_size: Vector2 = panel.get_combined_minimum_size()
		var standard_desktop_layout: bool = not compact_layout and not landscape_tablet_layout
		var resolved_seat_size := (
			Vector2(
				seat_size.x,
				(220.0 if is_hero else 198.0) * seat_visual_scale,
			)
			if standard_desktop_layout
			else Vector2(maxf(seat_size.x, minimum_size.x), maxf(seat_size.y, minimum_size.y))
		)
		if landscape_tablet_layout and seat_count in [6, 7]:
			# Reserve one stable footprint for every seat. This prevents a
			# showdown card/summary refresh or optional action text from changing
			# the seat's rectangle and moving neighboring presentation regions.
			resolved_seat_size.y = maxf(resolved_seat_size.y, 220.0 * seat_visual_scale)
		if not mobile_portrait_layout and surface_size.x < 1200.0 and not is_hero:
			# Short desktop surfaces cannot fit nine full-height source panels in
			# the regular ring. Keep the panel footprint compact; its content is
			# still laid out by the same presentation controls and remains clipped
			# to the seat boundary instead of colliding with neighboring seats.
			resolved_seat_size.y = minf(resolved_seat_size.y, 170.0)
		if small_desktop_layout and not is_hero:
			resolved_seat_size = Vector2(small_desktop_column_width, 88.0)
		elif portrait_tablet_layout and not is_hero:
			resolved_seat_size = Vector2(portrait_tablet_seat_width, 102.0)
		elif full_ring_desktop_layout and not is_hero:
			resolved_seat_size.y = full_ring_opponent_height
		panel.size = resolved_seat_size
		var intended_position: Vector2 = (
			normalized_position * surface_size - resolved_seat_size * 0.5
		)
		panel.position = Vector2(
			clampf(intended_position.x, 0.0, surface_size.x - resolved_seat_size.x),
			clampf(intended_position.y, 0.0, surface_size.y - resolved_seat_size.y),
		)
		if full_ring_desktop_layout and not is_hero:
			var status_footprint_height: float = (
				resolved_seat_size.y
				+ GuiMobileTableLayoutScript.STATUS_BAND_GAP * seat_visual_scale
				+ GuiMobileTableLayoutScript.STATUS_BAND_HEIGHT * seat_visual_scale
			)
			var outer_right_x: float = surface_size.x - resolved_seat_size.x
			var inner_right_x: float = outer_right_x - resolved_seat_size.x
			var full_ring_positions: Dictionary[int, Vector2] = {
				0: Vector2(inner_right_x, 0.0),
				1: Vector2(outer_right_x, 0.0),
				2: Vector2(outer_right_x, status_footprint_height),
				3: Vector2(outer_right_x, status_footprint_height * 2.0),
				5: Vector2(0.0, status_footprint_height * 2.0),
				6: Vector2(0.0, status_footprint_height),
				7: Vector2(0.0, 0.0),
				8: Vector2(resolved_seat_size.x, 0.0),
			}
			panel.position = full_ring_positions[visual_slot]
		if small_desktop_layout:
			if is_hero:
				panel.position = Vector2(
					(surface_size.x - panel.size.x) * 0.5,
					(
						surface_size.y
						- panel.size.y
						- GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT
						- GuiMobileTableLayoutScript.STATUS_BAND_GAP
					),
				)
			else:
				var cell: int = small_desktop_cell_order[small_desktop_opponent_index]
				var column: int = cell % 4
				var row: int = cell / 4
				var cell_x_positions: Array[float] = [
					0.0,
					center_position.x - panel.size.x,
					center_position.x + center_size.x,
					surface_size.x - panel.size.x,
				]
				panel.position = Vector2(cell_x_positions[column], row * 172.0)
				small_desktop_opponent_index += 1
		elif portrait_tablet_layout:
			if is_hero:
				panel.position = Vector2(
					(surface_size.x - panel.size.x) * 0.5,
					(
						surface_size.y
						- panel.size.y
						- GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT
						- GuiMobileTableLayoutScript.STATUS_BAND_GAP
					),
				)
			else:
				var column: int = portrait_tablet_opponent_index % 2
				var row: int = portrait_tablet_opponent_index / 2
				panel.position = Vector2(
					0.0 if column == 0 else surface_size.x - panel.size.x,
					row * 168.0,
				)
				portrait_tablet_opponent_index += 1
		var status_label: Label = _seat_status_widgets.get(seat)
		var status_scale: float = 1.0 if small_desktop_layout else seat_visual_scale
		GuiMobileTableLayoutScript.layout_seat_status_band(
			status_label, panel, compact_layout, status_scale
		)
		var status_overflow: float = status_label.get_rect().end.y - surface_size.y
		if status_overflow > 0.0:
			panel.position.y = maxf(0.0, panel.position.y - status_overflow)
			GuiMobileTableLayoutScript.layout_seat_status_band(
				status_label, panel, compact_layout, status_scale
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
	if full_ring_desktop_layout:
		var reserved_opponent_height: float = full_ring_footprint_height * 3.0 + 4.0
		var side_bottom: float = (
			_seat_widgets[_bound_view.hero_seat].position.y
			+ _seat_widgets[_bound_view.hero_seat].size.y
		)
		var side_height: float = side_bottom - reserved_opponent_height
		_action_panel.position.y = reserved_opponent_height
		_event_log.position.y = reserved_opponent_height
		_action_panel.size.y = side_height
		_event_log.size.y = side_height
	if small_desktop_layout:
		var hero_panel: PanelContainer = _seat_widgets.get(_bound_view.hero_seat)
		hero_panel.position.y = (
			surface_size.y
			- hero_panel.size.y
			- GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT
			- GuiMobileTableLayoutScript.STATUS_BAND_GAP
		)
	elif portrait_tablet_layout:
		var portrait_hero: PanelContainer = _seat_widgets.get(_bound_view.hero_seat)
		var portrait_side_size := Vector2(center_width, 125.0)
		_event_log.size = portrait_side_size
		_event_log.position = Vector2(center_position.x, center_size.y + 4.0)
		_action_panel.size = portrait_side_size
		_action_panel.position = Vector2(
			center_position.x, _event_log.position.y + _event_log.size.y + 4.0
		)
		portrait_hero.position = Vector2(
			center_position.x,
			(
				surface_size.y
				- portrait_hero.size.y
				- GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT
				- GuiMobileTableLayoutScript.STATUS_BAND_GAP
			),
		)
	if compact_layout:
		for seat: int in _seat_widgets:
			(
				GuiMobileTableLayoutScript
				. layout_seat_status_band(
					_seat_status_widgets[seat],
					_seat_widgets[seat],
					true,
					1.0 if small_desktop_layout or portrait_tablet_layout else seat_visual_scale,
				)
			)
	if not mobile_portrait_layout:
		_resolve_status_band_clearance(
			surface_size,
			compact_layout,
			1.0 if small_desktop_layout else seat_visual_scale,
		)
	if not mobile_portrait_layout and not small_desktop_layout:
		_resolve_seat_panel_intersections(
			compact_layout,
			1.0 if small_desktop_layout else seat_visual_scale,
		)
	if not compact_layout:
		# Containers can report a larger minimum after their children resolve.
		# Re-apply the approved compact desktop height after layout so the
		# reserved side regions remain deterministic.
		var desktop_side_height: float = _action_panel.size.y if full_ring_desktop_layout else 180.0
		var desktop_side_bottom: float = (
			_seat_widgets[_bound_view.hero_seat].position.y
			+ _seat_widgets[_bound_view.hero_seat].size.y
		)
		var desktop_side_y: float = (
			full_ring_footprint_height * 3.0 + 4.0
			if full_ring_desktop_layout
			else desktop_side_bottom - desktop_side_height
		)
		_action_panel.size.y = desktop_side_height
		_event_log.size.y = desktop_side_height
		_action_panel.position.y = desktop_side_y
		_event_log.position.y = desktop_side_y
	_layout_quit_button(
		center_position,
		center_size,
		portrait_tablet_layout,
	)
	if _wager_keypad != null and _wager_keypad.visible:
		_wager_keypad.refresh_layout(mobile_content_scale)
	if _quit_confirmation.visible:
		_quit_confirmation.popup_centered()


func _layout_quit_button(
	center_position: Vector2,
	center_size: Vector2,
	portrait_tablet_layout: bool,
) -> void:
	_quit_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_quit_button.size = Vector2(72.0, 48.0)
	var top: float = center_position.y + center_size.y + 4.0
	if portrait_tablet_layout:
		top = _action_panel.position.y + _action_panel.size.y + 4.0
	_quit_button.position = Vector2(
		center_position.x + (center_size.x - _quit_button.size.x) * 0.5,
		top,
	)


func _reserve_full_name_width(panel: PanelContainer, should_reserve: bool) -> void:
	var name_label := panel.find_child("Name", true, false) as Label
	if name_label == null:
		return
	name_label.custom_minimum_size.x = 0.0
	if not should_reserve:
		return
	var font_size: int = name_label.get_theme_font_size("font_size")
	var rendered_width: float = (
		name_label
		. get_theme_font("font")
		. get_string_size(
			name_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
		)
		. x
	)
	name_label.custom_minimum_size.x = ceilf(rendered_width)


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
	_resolved_center_size = resolved_size
	_resolved_center_position = resolved_position
	_center_zone.custom_minimum_size = Vector2.ZERO
	_center_zone.size = resolved_size
	_center_zone.position = resolved_position
	var pot_height: float = _pot_zone.custom_minimum_size.y
	var wager_height: float = _wager_zone.custom_minimum_size.y
	var board_height: float = maxf(
		CENTER_BOARD_MINIMUM_HEIGHT,
		resolved_size.y - pot_height - wager_height - CENTER_ZONE_SEPARATION * 2.0,
	)
	_board_zone.position = Vector2.ZERO
	_board_zone.size = Vector2(resolved_size.x, board_height)
	_pot_zone.position = Vector2(0.0, board_height + CENTER_ZONE_SEPARATION)
	_pot_zone.size = Vector2(resolved_size.x, pot_height)
	_wager_zone.position = Vector2(
		0.0,
		board_height + CENTER_ZONE_SEPARATION + pot_height + CENTER_ZONE_SEPARATION,
	)
	_wager_zone.size = Vector2(resolved_size.x, wager_height)
	_configure_status_label(_pot_label)
	_configure_status_label(_wager_label)


func _configure_status_label(label: Label) -> void:
	if label == null:
		return
	label.visible = true
	label.modulate = Color.WHITE
	label.add_theme_color_override("font_color", Color("f5f0dc"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Keep long status strings inside the resolved central footprint. Ellipsis is
	# preferable to painting over seats, side panels, or community cards.
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(0.0, float(label.get_theme_font_size("font_size")))
	# clip_text removes the text-driven minimum width.  The status labels must
	# explicitly fill their PanelContainer, otherwise the panels render while
	# their labels are allocated a zero-width content rectangle.
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _reserve_status_zone_height() -> void:
	_configure_status_label(_pot_label)
	_configure_status_label(_wager_label)
	var status_height: float = maxf(
		52.0,
		(
			float(
				maxi(
					_pot_label.get_theme_font_size("font_size"),
					_wager_label.get_theme_font_size("font_size"),
				)
			)
			+ 16.0
		),
	)
	_pot_zone.custom_minimum_size = Vector2(0.0, status_height)
	_wager_zone.custom_minimum_size = Vector2(0.0, status_height)


func _apply_center_zone_bounds_if_current(
	resolved_size: Vector2,
	resolved_position: Vector2,
	generation: int,
) -> void:
	if generation != _layout_generation:
		return
	_apply_center_zone_bounds(resolved_size, resolved_position)


func _resolve_status_band_clearance(
	surface_size: Vector2,
	compact_layout: bool,
	status_scale: float,
) -> void:
	# Resolve every seat from the same snapshot. Applying shifts one seat at a
	# time made otherwise mirrored desktop positions depend on dictionary order.
	for _attempt: int in range(3):
		var major_obstacles: Array[Rect2] = [
			_surface_local_rect(_center_zone),
			_surface_local_rect(_event_log),
			_surface_local_rect(_action_panel),
		]
		var seat_rects: Dictionary[int, Rect2] = {}
		for seat: int in _seat_widgets:
			seat_rects[seat] = _seat_widgets[seat].get_rect()
		var shifts: Dictionary[int, Vector2] = {}
		for seat: int in _seat_widgets:
			var status_rect: Rect2 = _surface_local_rect(_seat_status_widgets[seat])
			var shift_up: float = maxf(0.0, status_rect.end.y - surface_size.y + 4.0)
			var shift_down: float = maxf(0.0, -status_rect.position.y + 4.0)
			for obstacle: Rect2 in major_obstacles:
				if status_rect.intersects(obstacle):
					shift_up = maxf(shift_up, status_rect.end.y - obstacle.position.y + 4.0)
			for other_seat: int in seat_rects:
				if other_seat == seat:
					continue
				var other_rect: Rect2 = seat_rects[other_seat]
				if status_rect.intersects(other_rect):
					shift_up = maxf(shift_up, status_rect.end.y - other_rect.position.y + 4.0)
			if shift_up > 0.0 or shift_down > 0.0:
				shifts[seat] = Vector2(shift_up, shift_down)
		if shifts.is_empty():
			break
		for seat: int in shifts:
			var panel: PanelContainer = _seat_widgets[seat]
			var shift: Vector2 = shifts[seat]
			panel.position.y = clampf(
				panel.position.y - shift.x + shift.y,
				0.0,
				surface_size.y - panel.size.y,
			)
			GuiMobileTableLayoutScript.layout_seat_status_band(
				_seat_status_widgets[seat], panel, compact_layout, status_scale
			)


func _resolve_seat_panel_intersections(compact_layout: bool, status_scale: float) -> void:
	var seats: Array[int] = []
	for seat: int in _seat_widgets:
		seats.append(seat)
	seats.sort()
	for _pass: int in range(seats.size()):
		var changed: bool = false
		for first_index: int in range(seats.size()):
			for second_index: int in range(first_index + 1, seats.size()):
				var first_panel: PanelContainer = _seat_widgets[seats[first_index]]
				var second_panel: PanelContainer = _seat_widgets[seats[second_index]]
				if not first_panel.get_rect().intersects(second_panel.get_rect()):
					continue
				var upper_panel: PanelContainer = (
					first_panel
					if first_panel.position.y <= second_panel.position.y
					else second_panel
				)
				var lower_panel: PanelContainer = (
					second_panel if upper_panel == first_panel else first_panel
				)
				var overlap: float = upper_panel.get_rect().end.y - lower_panel.position.y
				var shift: float = minf(overlap + 4.0, upper_panel.position.y)
				var moved_panel: PanelContainer = upper_panel
				if shift > 0.0:
					upper_panel.position.y -= shift
				else:
					var lower_limit: float = (
						_surface.size.y
						- lower_panel.size.y
						- GuiMobileTableLayoutScript.STATUS_BAND_GAP * status_scale
						- (
							(
								GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT
								if compact_layout
								else GuiMobileTableLayoutScript.STATUS_BAND_HEIGHT
							)
							* status_scale
						)
					)
					lower_panel.position.y = minf(upper_panel.get_rect().end.y + 4.0, lower_limit)
					moved_panel = lower_panel
				var moved_seat: int = (
					seats[first_index] if moved_panel == first_panel else seats[second_index]
				)
				(
					GuiMobileTableLayoutScript
					. layout_seat_status_band(
						_seat_status_widgets[moved_seat],
						moved_panel,
						compact_layout,
						status_scale,
					)
				)
				changed = true
		if not changed:
			return
