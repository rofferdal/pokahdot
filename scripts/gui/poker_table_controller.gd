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
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const GuiMobileTableLayoutScript := preload("res://scripts/gui/gui_mobile_table_layout.gd")
const GuiPhoneLayoutPlanScript := preload("res://scripts/gui/gui_phone_layout_plan.gd")
const GuiPhoneSeatLayoutScript := preload("res://scripts/gui/gui_phone_seat_layout.gd")
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")
const ShowdownHandFormatterScript := preload("res://scripts/gui/showdown_hand_formatter.gd")
const TableSeatLayoutScript := preload("res://scripts/gui/table_seat_layout.gd")
const TournamentStatusFormatterScript := preload("res://scripts/gui/tournament_status_formatter.gd")
const WagerKeypadScript := preload("res://scripts/gui/wager_keypad.gd")
const OPPONENT_AVATAR_SIZE := Vector2(112, 112)
const HERO_AVATAR_SIZE := Vector2(128, 128)
const OPPONENT_CARD_SIZE := Vector2(60, 76)
const PHONE_CARD_SIZE := Vector2(18, 26)
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
var _layout_profile_override: int = GuiLayoutProfileScript.AUTOMATIC
var _applied_layout_profile: int = GuiLayoutProfileScript.AUTOMATIC
var _phone_seat_widgets: bool = false
var _seat_detail_seat: int = Table.NO_SEAT
var _seat_detail_overlay: PanelContainer
var _layout_queued: bool = false
var _layout_generation: int = 0
var _applied_usable_size: Vector2 = Vector2.ZERO
var _applied_phone_layout_plan: RefCounted
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
@onready var _phone_hero_summary: HBoxContainer = %PhoneHeroSummary
@onready var _phone_hero_cards: HBoxContainer = %PhoneHeroCards
@onready var _phone_hero_stack: Label = %PhoneHeroStack
@onready var _phone_hero_action_badge: Label = %PhoneHeroActionBadge
@onready var _phone_player_count_notice: Label = %PhonePlayerCountNotice
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
@onready var _phone_more_button: Button = %PhoneMoreButton
@onready var _phone_quit_confirmation: PanelContainer = %PhoneQuitConfirmation
@onready var _phone_quit_continue_button: Button = %PhoneQuitContinueButton
@onready var _phone_quit_confirm_button: Button = %PhoneQuitConfirmButton
@onready var _phone_showdown_overlay: PanelContainer = %PhoneShowdownOverlay
@onready var _phone_showdown_summary: Label = %PhoneShowdownSummary
@onready var _phone_showdown_close_button: Button = %PhoneShowdownCloseButton
@onready var _phone_overflow_menu: PanelContainer = %PhoneOverflowMenu
@onready var _phone_menu_showdown_button: Button = %PhoneMenuShowdownButton
@onready var _phone_blind_level_detail: Label = %PhoneBlindLevelDetail
@onready var _phone_menu_quit_button: Button = %PhoneMenuQuitButton
@onready var _phone_menu_close_button: Button = %PhoneMenuCloseButton


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
	_wager_keypad.confirmed.connect(_on_wager_keypad_confirmed)
	_wager_input.gui_input.connect(_on_wager_input_gui_input)
	_wager_input.text_submitted.connect(_on_wager_input_submitted)
	_fold_button.pressed.connect(_on_fold_pressed)
	_check_call_button.pressed.connect(_on_check_call_pressed)
	_min_wager_button.pressed.connect(_on_min_wager_pressed)
	_pot_raise_button.pressed.connect(_on_pot_raise_pressed)
	_wager_button.pressed.connect(_on_wager_pressed)
	_all_in_button.pressed.connect(_on_all_in_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_confirmation.confirmed.connect(_on_quit_confirmed)
	_phone_more_button.pressed.connect(_open_phone_overflow_menu)
	_phone_quit_continue_button.pressed.connect(_close_phone_quit_confirmation)
	_phone_quit_confirm_button.pressed.connect(_on_phone_quit_confirmed)
	_phone_showdown_close_button.pressed.connect(_close_phone_showdown)
	_phone_menu_showdown_button.pressed.connect(_open_phone_showdown)
	_phone_menu_quit_button.pressed.connect(_on_phone_menu_quit_pressed)
	_phone_menu_close_button.pressed.connect(_close_phone_overflow_menu)
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


## Supplies explicit device evidence to presentation tests and platform adapters.
## Automatic geometry classification remains the default and invalid overrides
## are deliberately ignored by GuiLayoutProfile.
func set_layout_profile_override(profile_override: int) -> void:
	if _layout_profile_override == profile_override:
		return
	_layout_profile_override = profile_override
	if not is_node_ready():
		return
	_configure_center_copy(GuiLayoutProfileScript.is_phone(get_layout_profile()))
	if _bound_view != null:
		_refresh_rendered_phone_action_badges()
		_rebuild_seats()
	_queue_layout()


func get_layout_profile() -> int:
	return GuiLayoutProfileScript.classify(size, _layout_profile_override)


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
		&"quit": _surface_local_rect(_quit_button),
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
			GuiMobileTableLayoutScript.content_scale(_current_usable_size()),
			GuiLayoutProfileScript.is_phone(get_layout_profile()),
			displayed_pot_amount,
			Vector2i(size),
		)
	)


func _on_wager_input_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		show_wager_keypad()
		accept_event()
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and _wager_keypad.visible
	):
		# Preserve the committed value when switching from touch to pointer/keyboard.
		_wager_keypad.cancel()


func _refresh_visuals() -> void:
	if not is_node_ready() or _bound_view == null:
		return
	_board_label.text = "Community cards"
	_configure_center_copy(GuiLayoutProfileScript.is_phone(get_layout_profile()))
	_configure_status_label(_pot_label)
	_configure_status_label(_wager_label)
	_rebuild_card_slots()
	_refresh_rendered_phone_action_badges()
	_rebuild_seats()
	_refresh_phone_hero_summary()
	_refresh_action_controls()
	_refresh_phone_secondary_controls()
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
	for overlay: PanelContainer in [
		_phone_showdown_overlay,
		_phone_overflow_menu,
		_phone_quit_confirmation,
	]:
		overlay.add_theme_stylebox_override(
			"panel", GuiTableStyleScript.box(Color("062516fa"), Color("e7d39b"), 2, 10)
		)
	_phone_hero_action_badge.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.compact_box(Color("172331f2"), Color("e7d39b"), 1, 5)
	)
	for button: Button in [_phone_quit_continue_button, _phone_quit_confirm_button]:
		button.add_theme_stylebox_override(
			"normal", GuiTableStyleScript.action_control_box(Color("102d21"), Color("75c99a"), 2)
		)
		button.add_theme_stylebox_override(
			"pressed", GuiTableStyleScript.action_control_box(Color("0b1d15"), Color("d9b56d"), 2)
		)
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
			"focus", GuiTableStyleScript.action_control_box(Color("1b4933"), Color("f5f0dc"), 3)
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


func _current_wager_total() -> int:
	var current_wager: int = 0
	for amount: int in wager_amounts.values():
		current_wager = maxi(current_wager, amount)
	return current_wager


func _configure_center_copy(phone_layout: bool) -> void:
	if _bound_view == null:
		return
	if phone_layout:
		_pot_label.text = "Pot: %d" % displayed_pot_amount
		_wager_label.text = "Current wager: %d" % _current_wager_total()
	else:
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
	_phone_blind_level_detail.text = (
		"Blinds %d / %d  ·  Level %d  ·  %d hands to next level"
		% [
			_bound_view.small_blind,
			_bound_view.big_blind,
			_bound_view.blind_level,
			_bound_view.hands_until_next_level,
		]
	)


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
				Color("f5f0dc") if is_face_up else Color("294c5c"),
				Color("e7d39b") if is_face_up else Color("82968b"),
				true,
			)
		)
		slot.modulate.a = 1.0 if not is_face_up or index < board_card_count else 0.48
		_card_slots.add_child(slot)


func _rebuild_seats() -> void:
	for seat_widget: PanelContainer in _seat_widgets.values():
		seat_widget.free()
	for status_widget: Label in _seat_status_widgets.values():
		status_widget.free()
	_seat_widgets.clear()
	_seat_status_widgets.clear()
	_phone_seat_widgets = GuiLayoutProfileScript.is_phone(get_layout_profile())
	for player_view: PlayerView in _bound_view.seats:
		var seat_widget := (
			_create_hero_seat_widget(player_view)
			if player_view.seat == _bound_view.hero_seat
			else (
				_create_phone_opponent_token(player_view)
				if _phone_seat_widgets
				else _create_seat_widget(player_view)
			)
		)
		_seats.add_child(seat_widget)
		_seat_widgets[player_view.seat] = seat_widget
		var status_widget := _create_seat_status_label(player_view)
		_seats.add_child(status_widget)
		_seat_status_widgets[player_view.seat] = status_widget
	_refresh_phone_seat_detail()


func _create_phone_opponent_token(player_view: PlayerView) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Seat%d" % player_view.seat
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := _seat_frame_style(
		player_view,
		Color("0d271bf2"),
		Color("5dbf86"),
		NORMAL_SEAT_FRAME_WIDTH,
	)
	panel_style.content_margin_left = 0.0
	panel_style.content_margin_top = 0.0
	panel_style.content_margin_right = 0.0
	panel_style.content_margin_bottom = 0.0
	panel.add_theme_stylebox_override("panel", panel_style)
	var content := Control.new()
	content.name = "PhoneTokenContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var name_label := _phone_token_label("Name", _seat_title(player_view))
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = 4.0
	name_label.offset_top = 0.0
	name_label.offset_right = -44.0
	name_label.offset_bottom = 24.0
	content.add_child(name_label)
	var stack_label := _phone_token_label("Stack", str(player_view.stack))
	stack_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stack_label.offset_left = 4.0
	stack_label.offset_top = 23.0
	stack_label.offset_right = 62.0
	stack_label.offset_bottom = 47.0
	content.add_child(stack_label)
	var badge := _phone_token_label("Badge", _phone_token_badge_text(player_view))
	badge.visible = not badge.text.is_empty()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -44.0
	badge.offset_top = 0.0
	badge.offset_right = -4.0
	badge.offset_bottom = 30.0
	badge.add_theme_color_override("font_color", Color("f5f0dc"))
	badge.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.compact_box(Color("172331f2"), Color("d9b56d"), 1, 4)
	)
	content.add_child(badge)
	var cards := _create_phone_opponent_hole_cards(player_view)
	cards.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cards.offset_left = -42.0
	cards.offset_top = 30.0
	cards.offset_right = -2.0
	cards.offset_bottom = 30.0 + PHONE_CARD_SIZE.y
	content.add_child(cards)
	var action_badge := _create_phone_action_badge(player_view.seat)
	content.add_child(action_badge)
	var details_button := Button.new()
	details_button.name = "DetailsButton"
	details_button.flat = true
	details_button.tooltip_text = "Show details for %s" % _seat_title(player_view)
	details_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details_button.pressed.connect(_open_phone_seat_detail.bind(player_view.seat))
	panel.add_child(details_button)
	if player_view.folded or player_view.busted:
		FoldedSeatStyleScript.apply(panel)
	return panel


func _phone_token_label(label_name: String, label_text: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = label_text
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	return label


func _phone_seat_badge_text(player_view: PlayerView) -> String:
	var badges: Array[String] = []
	var position_text: String = _seat_marker_text(player_view)
	if not position_text.is_empty():
		badges.append(position_text)
	if player_view.seat == _bound_view.acting_seat:
		badges.append("Turn")
	if player_view.folded:
		badges.append("Fold")
	elif player_view.all_in:
		badges.append("AI")
	elif player_view.busted:
		badges.append("Out")
	return " ".join(badges)


func _phone_token_badge_text(player_view: PlayerView) -> String:
	var badges: Array[String] = []
	var position_text: String = _seat_marker_text(player_view)
	if not position_text.is_empty():
		badges.append(position_text)
	if player_view.folded:
		badges.append("F")
	elif player_view.all_in:
		badges.append("AI")
	elif player_view.busted:
		badges.append("Out")
	elif player_view.seat == _bound_view.acting_seat:
		badges.append("T")
	return " ".join(badges)


func _create_phone_action_badge(seat: int) -> Label:
	var badge := _phone_token_label("ActionBadge", _compact_phone_action_for_seat(seat))
	badge.z_index = 2
	badge.visible = not badge.text.is_empty()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The action owns the remainder of the second text row. The marker cell and
	# both card fields stay independently visible at the token's right edge.
	badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	badge.offset_left = 62.0
	badge.offset_top = 29.0
	badge.offset_right = -45.0
	badge.offset_bottom = 59.0
	badge.add_theme_stylebox_override(
		"normal", GuiTableStyleScript.compact_box(Color("172331f2"), Color("e7d39b"), 1, 5)
	)
	return badge


func _compact_phone_action_for_seat(seat: int) -> String:
	var latest_action: PublicActionRecord = _active_round_latest_actions.get(seat)
	if latest_action == null or latest_action.record_kind != PublicActionRecord.Kind.ACTION:
		return ""
	return _compact_phone_action_text(latest_action)


func _compact_phone_action_text(latest_record: PublicActionRecord) -> String:
	var compact_text: String = ""
	match latest_record.kind:
		PlayerAction.Kind.FOLD:
			compact_text = "F"
		PlayerAction.Kind.CHECK:
			compact_text = "Chk"
		PlayerAction.Kind.CALL:
			compact_text = "C%d" % latest_record.amount
		PlayerAction.Kind.BET:
			compact_text = "B%d" % latest_record.amount
		PlayerAction.Kind.RAISE:
			compact_text = "R%d" % latest_record.amount
		PlayerAction.Kind.ALL_IN:
			compact_text = "AI"
	return compact_text


func _refresh_rendered_phone_action_badges() -> void:
	if not _phone_seat_widgets or _bound_view == null:
		return
	_phone_hero_action_badge.text = _compact_phone_action_for_seat(_bound_view.hero_seat)
	_phone_hero_action_badge.visible = not _phone_hero_action_badge.text.is_empty()
	for seat: int in _seat_widgets:
		var badge := _seat_widgets[seat].find_child("ActionBadge", true, false) as Label
		if badge == null:
			continue
		badge.text = _compact_phone_action_for_seat(seat)
		badge.visible = not badge.text.is_empty()


func _create_phone_opponent_hole_cards(player_view: PlayerView) -> Control:
	var cards := Control.new()
	cards.name = "HoleCards"
	cards.size = Vector2(40, PHONE_CARD_SIZE.y)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var revealed_cards: Array = _bound_view.revealed_hole_cards.get(player_view.seat, [])
	for index: int in range(2):
		var card: Control
		if player_view.folded or player_view.busted:
			var empty_field := Label.new()
			empty_field.name = "HoleCardField%d" % (index + 1)
			(
				empty_field
				. add_theme_stylebox_override(
					"normal",
					GuiTableStyleScript.compact_box(Color("0d271b"), Color("82968b"), 1, 2),
				)
			)
			card = empty_field
		elif revealed_cards.size() == 2:
			card = (
				CardFaceFactoryScript
				. create_card_face(
					revealed_cards[index],
					"ShowdownCard%d" % (index + 1),
					PHONE_CARD_SIZE,
					GUI_MINIMUM_FONT_SIZE,
					Color("f5f0dc"),
					Color("d9b56d"),
				)
			)
		else:
			var card_back := Label.new()
			card_back.name = "CardBack%d" % (index + 1)
			(
				card_back
				. add_theme_stylebox_override(
					"normal",
					GuiTableStyleScript.compact_box(Color("173e58"), Color("e7d39b"), 1, 2),
				)
			)
			card = card_back
		card.position = Vector2(index * 20, 0)
		card.size = PHONE_CARD_SIZE
		cards.add_child(card)
	return cards


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
		"font_color", Color("d6d0be") if player_view.folded else Color("f5f0dc")
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


func _open_phone_seat_detail(seat: int) -> void:
	if not _phone_seat_widgets or _player_view_for_seat(seat) == null:
		return
	_seat_detail_seat = seat
	_refresh_phone_seat_detail()
	_queue_layout()


func _close_phone_seat_detail() -> void:
	_seat_detail_seat = Table.NO_SEAT
	if is_instance_valid(_seat_detail_overlay):
		_seat_detail_overlay.hide()


func _refresh_phone_seat_detail() -> void:
	if not is_node_ready():
		return
	if not _phone_seat_widgets or _seat_detail_seat == Table.NO_SEAT:
		_close_phone_seat_detail()
		return
	var player_view: PlayerView = _player_view_for_seat(_seat_detail_seat)
	if player_view == null:
		_close_phone_seat_detail()
		return
	if is_instance_valid(_seat_detail_overlay):
		_seat_detail_overlay.free()
	_seat_detail_overlay = PanelContainer.new()
	_seat_detail_overlay.name = "SeatDetailOverlay"
	_seat_detail_overlay.z_index = 500
	_seat_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_seat_detail_overlay.add_theme_stylebox_override(
		"panel", GuiTableStyleScript.box(Color("062516f7"), Color("e7d39b"), 2, 10)
	)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 4)
	_seat_detail_overlay.add_child(content)
	var heading := _phone_token_label("Name", _seat_title(player_view))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var stack := _phone_token_label("Stack", "%d chips" % player_view.stack)
	stack.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stack)
	var state_text: String = _phone_seat_badge_text(player_view)
	var state := _phone_token_label("State", state_text.strip_edges())
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(state)
	var cards := _create_opponent_hole_cards(player_view)
	cards.name = "DetailHoleCards"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(cards)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(96, 48)
	close_button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	close_button.pressed.connect(_close_phone_seat_detail)
	content.add_child(close_button)
	_surface.add_child(_seat_detail_overlay)
	_layout_phone_seat_detail()


func _player_view_for_seat(seat: int) -> PlayerView:
	if _bound_view == null:
		return null
	for player_view: PlayerView in _bound_view.seats:
		if player_view.seat == seat:
			return player_view
	return null


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
	return _action_record_text(latest_record)


func _action_record_text(latest_record: PublicActionRecord) -> String:
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
	_pot_raise_button.disabled = not _can_submit_pot_wager(legal, is_human_turn)
	_wager_input.editable = can_wager
	_wager_button.disabled = not can_wager
	_all_in_button.disabled = not (PlayerAction.Kind.ALL_IN in legal)
	_configure_action_control_copy(legal)
	_configure_action_control_visibility(legal, is_human_turn)
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
	_pot_raise_button.text = (
		"Pot" if compact_copy else "Pot bet" if PlayerAction.Kind.BET in legal else "Pot raise"
	)
	_wager_button.text = wager_name
	_wager_input.placeholder_text = "Total" if compact_copy else "Wager total"
	_wager_input.custom_minimum_size.x = 72.0 if compact_copy else 200.0


func _configure_action_control_visibility(legal: Array, is_human_turn: bool) -> void:
	var phone_layout: bool = GuiLayoutProfileScript.is_phone(get_layout_profile())
	_phone_hero_summary.visible = phone_layout
	_phone_player_count_notice.visible = (
		phone_layout
		and _bound_view.seats.size() > GuiPhoneSeatLayoutScript.MAX_SUPPORTED_PLAYER_COUNT
	)
	var action_rows := _action_panel.get_node("Margin/Content/ActionRows") as VBoxContainer
	var primary_buttons := action_rows.get_node("PrimaryButtons") as HBoxContainer
	var wager_controls := action_rows.get_node("WagerControls") as HBoxContainer
	if not phone_layout:
		action_rows.show()
		primary_buttons.show()
		wager_controls.show()
		for control: Control in [
			_fold_button,
			_check_call_button,
			_min_wager_button,
			_pot_raise_button,
			_wager_input,
			_wager_button,
			_all_in_button,
		]:
			control.show()
		return
	_fold_button.visible = is_human_turn and PlayerAction.Kind.FOLD in legal
	_check_call_button.visible = (
		is_human_turn and (PlayerAction.Kind.CHECK in legal or PlayerAction.Kind.CALL in legal)
	)
	_min_wager_button.hide()
	_pot_raise_button.hide()
	_wager_input.hide()
	_wager_button.visible = (
		is_human_turn and (PlayerAction.Kind.BET in legal or PlayerAction.Kind.RAISE in legal)
	)
	_all_in_button.visible = is_human_turn and PlayerAction.Kind.ALL_IN in legal
	primary_buttons.visible = _fold_button.visible or _check_call_button.visible
	wager_controls.visible = _wager_button.visible or _all_in_button.visible
	action_rows.visible = primary_buttons.visible or wager_controls.visible


func _refresh_phone_hero_summary() -> void:
	for child: Node in _phone_hero_cards.get_children():
		child.free()
	var hero_view: PlayerView = _player_view_for_seat(_bound_view.hero_seat)
	if hero_view == null:
		_phone_hero_stack.text = "—"
		_phone_hero_action_badge.hide()
		return
	_phone_hero_stack.text = str(hero_view.stack)
	_refresh_rendered_phone_action_badges()
	if hero_view.folded:
		return
	for index: int in range(displayed_hero_cards.size()):
		var card := (
			CardFaceFactoryScript
			. create_card_face(
				displayed_hero_cards[index],
				"PhoneHeroCard%d" % (index + 1),
				Vector2(42.0, 48.0),
				28,
				Color("f5f0dc"),
				Color("d9b56d"),
			)
		)
		_phone_hero_cards.add_child(card)


func _refresh_phone_secondary_controls() -> void:
	if _bound_view == null:
		return
	_phone_menu_showdown_button.visible = not _bound_view.showdown_results.is_empty()
	_phone_showdown_summary.text = _phone_showdown_summary_text()
	if _bound_view.showdown_results.is_empty():
		_close_phone_showdown()


func _phone_showdown_summary_text() -> String:
	if _bound_view == null:
		return ""
	var seats: Array[int] = []
	for seat: int in _bound_view.showdown_results:
		seats.append(seat)
	seats.sort()
	var lines: Array[String] = []
	for seat: int in seats:
		var player_view: PlayerView = _player_view_for_seat(seat)
		if player_view == null:
			continue
		var result: ShowdownResult = _bound_view.showdown_results.get(seat)
		var description: String = ShowdownHandFormatterScript.format(result)
		if not description.is_empty():
			lines.append("%s — %s" % [_seat_title(player_view), description])
	return "\n".join(lines)


func _open_phone_overflow_menu() -> void:
	if not GuiLayoutProfileScript.is_phone(get_layout_profile()):
		return
	_phone_showdown_overlay.hide()
	_phone_overflow_menu.show()
	_layout_phone_overlays()


func _close_phone_overflow_menu() -> void:
	_phone_overflow_menu.hide()


func _open_phone_showdown() -> void:
	if (
		not GuiLayoutProfileScript.is_phone(get_layout_profile())
		or _bound_view == null
		or _bound_view.showdown_results.is_empty()
	):
		return
	_phone_overflow_menu.hide()
	_phone_showdown_summary.text = _phone_showdown_summary_text()
	_phone_showdown_overlay.show()
	_layout_phone_overlays()


func _close_phone_showdown() -> void:
	_phone_showdown_overlay.hide()


func _close_phone_overlays() -> void:
	_close_phone_showdown()
	_close_phone_overflow_menu()
	_close_phone_quit_confirmation()


func _on_phone_menu_quit_pressed() -> void:
	_close_phone_overflow_menu()
	_on_quit_pressed()


func _close_phone_quit_confirmation() -> void:
	_phone_quit_confirmation.hide()


func _on_phone_quit_confirmed() -> void:
	_close_phone_quit_confirmation()
	_on_quit_confirmed()


func _uses_compact_table_copy() -> bool:
	return (
		GuiLayoutProfileScript.is_phone(get_layout_profile())
		or GuiMobileTableLayoutScript.is_small_desktop(_surface.size)
		or GuiMobileTableLayoutScript.is_portrait_tablet(_surface.size)
	)


func _can_submit_pot_wager(legal: Array, is_human_turn: bool) -> bool:
	if not is_human_turn:
		return false
	if PlayerAction.Kind.BET not in legal and PlayerAction.Kind.RAISE not in legal:
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
	if not _can_submit_pot_wager(
		_bound_view.legal_actions, _bound_view.acting_seat == _bound_view.hero_seat
	):
		return
	submit_wager_total(displayed_pot_amount)


func _on_wager_pressed() -> void:
	if GuiLayoutProfileScript.is_phone(get_layout_profile()):
		show_wager_keypad()
		return
	_submit_wager_input()


func _submit_wager_input() -> void:
	if not _wager_input.text.is_valid_int():
		_action_status.text = "Enter a whole-number wager total."
		return
	submit_wager_total(_wager_input.text.to_int())


func _on_wager_input_submitted(_submitted_text: String) -> void:
	_submit_wager_input()


func _on_wager_keypad_confirmed() -> void:
	_submit_wager_input()


func _on_all_in_pressed() -> void:
	_submit_action(PlayerAction.all_in_action())


func _on_quit_pressed() -> void:
	if _match == null:
		return
	if _match.state == TournamentMatch.State.FINISHED:
		return_to_startup_requested.emit()
	elif _match.state == TournamentMatch.State.RUNNING:
		if GuiLayoutProfileScript.is_phone(get_layout_profile()):
			_phone_quit_confirmation.show()
			_layout_phone_quit_confirmation()
		else:
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
	_event_log.scroll_to_line(maxi(0, _event_log.get_line_count() - 1))
	_refresh_phone_secondary_controls()
	_refresh_seat_status_labels()
	_refresh_rendered_phone_action_badges()


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


func _layout_table(usable_size: Vector2, generation: int) -> void:
	if not is_node_ready():
		return
	var surface_size: Vector2 = usable_size
	if surface_size.x <= 0.0 or surface_size.y <= 0.0 or _bound_view == null:
		return
	_applied_usable_size = surface_size
	# The root Control is the usable viewport. TableSurface is inset by authored
	# felt margins and must not make a small desktop look like a phone.
	var layout_profile: int = GuiLayoutProfileScript.classify(size, _layout_profile_override)
	var phone_layout: bool = GuiLayoutProfileScript.is_phone(layout_profile)
	var profile_changed: bool = layout_profile != _applied_layout_profile
	var had_applied_profile: bool = _applied_layout_profile != GuiLayoutProfileScript.AUTOMATIC
	_applied_layout_profile = layout_profile
	_configure_center_copy(phone_layout)
	if phone_layout != _phone_seat_widgets and _bound_view != null:
		if not phone_layout:
			_close_phone_overlays()
			if _wager_keypad != null and _wager_keypad.is_bottom_sheet():
				_wager_keypad.cancel()
		_rebuild_seats()
	elif profile_changed and had_applied_profile and not phone_layout:
		# Compact/tablet styling changes child minimum sizes. Rebuilding the full
		# panels on profile exit prevents those old Container minima from becoming
		# a second geometry owner when desktop bounds are restored.
		_rebuild_seats()
	# Content can be bound while the table is hidden at its authored scene size.
	# Re-resolve viewport-dependent compact/full copy in the same pass that owns
	# its geometry so showing or resizing cannot leave stale status text behind.
	_refresh_seat_status_labels()
	var tablet_layout: bool = layout_profile == GuiLayoutProfileScript.Kind.TABLET
	var mobile_portrait_layout: bool = GuiMobileTableLayoutScript.is_mobile_portrait(surface_size)
	var portrait_tablet_layout: bool = tablet_layout and surface_size.y > surface_size.x
	var landscape_tablet_layout: bool = tablet_layout and surface_size.x >= surface_size.y
	var compact_tablet_layout: bool = tablet_layout and surface_size.x < 1600.0
	var small_desktop_layout: bool = (
		GuiMobileTableLayoutScript.is_small_desktop(surface_size) and not tablet_layout
	)
	var short_desktop_center_layout: bool = (
		not tablet_layout and not small_desktop_layout and surface_size.y < 900.0
	)
	var is_human_turn: bool = _bound_view.acting_seat == _bound_view.hero_seat
	var active_legal: Array = _bound_view.legal_actions if is_human_turn else []
	_configure_action_control_copy(active_legal)
	_configure_action_control_visibility(active_legal, is_human_turn)
	if phone_layout:
		_quit_confirmation.dialog_text = "Quit tournament?"
		_layout_phone_table(surface_size, generation)
		return
	_applied_phone_layout_plan = null
	_board_label.show()
	_quit_confirmation.dialog_text = "Do you want to quit the tournament?"
	var desktop_action_margin := _action_panel.get_node("Margin") as MarginContainer
	desktop_action_margin.add_theme_constant_override("margin_top", 6)
	desktop_action_margin.add_theme_constant_override("margin_bottom", 6)
	desktop_action_margin.add_theme_constant_override("margin_right", 2)
	_restore_phone_action_rows()
	_event_log.show()
	_quit_button.show()
	_phone_more_button.hide()
	for seat: int in _seat_widgets:
		_seat_widgets[seat].show()
		_seat_status_widgets[seat].show()
	var mobile_content_scale: float = GuiMobileTableLayoutScript.content_scale(surface_size)
	var seat_content_scale: float = GuiMobileTableLayoutScript.seat_scale(surface_size)
	_card_slots.add_theme_constant_override(
		"separation", 2 if small_desktop_layout or compact_tablet_layout else 6
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
	if _seat_widgets.size() == 9 and not tablet_layout and not small_desktop_layout:
		# A full ring consumes three opponent/status rows above the side panels.
		# Scale that footprint from available height so intermediate short-wide
		# browser canvases retain a complete action/event row at the bottom.
		var source_ring_height: float = (
			3.0
			* (
				198.0
				+ GuiMobileTableLayoutScript.STATUS_BAND_GAP
				+ GuiMobileTableLayoutScript.STATUS_BAND_HEIGHT
			)
		)
		var available_ring_height: float = maxf(0.0, surface_size.y - 192.0)
		seat_visual_scale = minf(
			seat_visual_scale,
			clampf(available_ring_height / source_ring_height, 0.65, 1.0),
		)
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
	if small_desktop_layout or compact_tablet_layout:
		_board_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_pot_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_wager_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_action_status.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_action_status.autowrap_mode = TextServer.AUTOWRAP_OFF
		_action_status.clip_text = true
		_action_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
				if compact_tablet_layout:
					control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 48.0)
		for button: Button in [
			_fold_button, _check_call_button, _min_wager_button, _pot_raise_button
		]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for status_label: Label in _seat_status_widgets.values():
			status_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
			if compact_tablet_layout:
				status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
				status_label.clip_text = true
				status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				status_label.max_lines_visible = 1
		for card: Control in _card_slots.get_children():
			GuiMobileTableLayoutScript._scale_card_face(card, Vector2(52.0, 57.0), 22)
	if short_desktop_center_layout:
		# A short, wide browser canvas still has room for source-sized seats and
		# action controls, but its center stack must leave a complete row for the
		# standalone Quit control above the human identity/status footprint.
		_board_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_pot_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		_wager_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		for card: Control in _card_slots.get_children():
			GuiMobileTableLayoutScript._scale_card_face(card, Vector2(52.0, 57.0), 22)
	_quit_button.custom_minimum_size.y = 48.0
	_reserve_status_zone_height()
	if compact_tablet_layout or short_desktop_center_layout:
		_pot_zone.custom_minimum_size.y = 42.0
		_wager_zone.custom_minimum_size.y = 42.0
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
	elif compact_tablet_layout:
		var required_side_width: float = maxf(
			_action_panel.get_combined_minimum_size().x,
			_event_log.get_combined_minimum_size().x,
		)
		center_width = minf(
			center_width,
			maxf(230.0, surface_size.x - 2.0 * (required_side_width + 8.0)),
		)
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
	if small_desktop_layout:
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
		surface_size.x < 600.0
		or mobile_portrait_layout
		or small_desktop_layout
		or compact_tablet_layout
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
	var compact_tablet_seat_width: float = maxf(160.0, (surface_size.x - center_width) * 0.5 - 8.0)
	if compact_tablet_layout:
		seat_width = compact_tablet_seat_width
	var seat_count: int = _seat_widgets.size()
	if compact_tablet_layout and not portrait_tablet_layout and seat_count == 9:
		compact_tablet_seat_width = minf(compact_tablet_seat_width, (surface_size.x - 24.0) * 0.25)
		seat_width = compact_tablet_seat_width
	var full_ring_desktop_layout: bool = (
		seat_count == 9 and not compact_layout and not landscape_tablet_layout
	)
	var full_ring_opponent_height: float = 198.0 * seat_visual_scale
	var full_ring_footprint_height: float = (
		full_ring_opponent_height
		+ GuiMobileTableLayoutScript.STATUS_BAND_GAP * seat_visual_scale
		+ GuiMobileTableLayoutScript.STATUS_BAND_HEIGHT * seat_visual_scale
		+ 5.0
	)
	var small_desktop_opponent_index: int = 0
	var small_desktop_side_width: float = (surface_size.x - center_width) * 0.5
	var small_desktop_column_gap: float = 6.0
	var small_desktop_column_width: float = (
		(small_desktop_side_width - small_desktop_column_gap) * 0.5
	)
	var small_desktop_cell_order: Array[int] = [1, 2, 0, 3, 5, 6, 4, 7]
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
		if compact_tablet_layout:
			seat_size.x = center_width if is_hero else compact_tablet_seat_width
		var visual_slot: int = _visual_slot_for_seat(seat, seat_count)
		var normalized_position: Vector2 = (
			Vector2(0.5, 0.91)
			if is_hero
			else (
				(
					TableSeatLayoutScript.compact_tablet_portrait_positions(seat_count)[visual_slot]
					if portrait_tablet_layout
					else TableSeatLayoutScript.compact_tablet_positions(seat_count)[visual_slot]
				)
				if compact_tablet_layout
				else (
					TableSeatLayoutScript.landscape_tablet_positions(seat_count)[visual_slot]
					if landscape_tablet_layout
					else (
						(
							TableSeatLayoutScript.small_desktop_positions(seat_count)[visual_slot]
							if small_desktop_layout
							else (
								TableSeatLayoutScript
								. compact_desktop_positions(seat_count)[visual_slot]
							)
						)
						if not mobile_portrait_layout and surface_size.x < 1200.0
						else TableSeatLayoutScript.symmetric_positions(seat_count)[visual_slot]
					)
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
		if not small_desktop_layout and not compact_tablet_layout:
			GuiMobileTableLayoutScript.restore_standard_seat_overlays(panel, is_hero)
		GuiMobileTableLayoutScript.apply_seat_typography(
			panel,
			seat_visual_scale,
			is_hero,
			1.0,
			not mobile_portrait_layout and not small_desktop_layout
		)
		if small_desktop_layout:
			GuiMobileTableLayoutScript.apply_small_desktop_seat_footprint(panel)
		elif compact_tablet_layout:
			GuiMobileTableLayoutScript.apply_compact_tablet_seat_footprint(panel)
		_reserve_full_name_width(panel, small_desktop_layout or compact_tablet_layout)
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
		elif compact_tablet_layout and not is_hero:
			resolved_seat_size = Vector2(compact_tablet_seat_width, 102.0)
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
				+ 5.0
			)
			var edge_margin: float = 0.5
			var column_gap: float = 4.0
			var outer_right_x: float = surface_size.x - resolved_seat_size.x - edge_margin
			var inner_right_x: float = outer_right_x - resolved_seat_size.x - column_gap
			var outer_left_x: float = edge_margin
			var inner_left_x: float = outer_left_x + resolved_seat_size.x + column_gap
			var full_ring_positions: Dictionary[int, Vector2] = {
				0: Vector2(inner_right_x, 0.0),
				1: Vector2(outer_right_x, 0.0),
				2: Vector2(outer_right_x, status_footprint_height),
				3: Vector2(outer_right_x, status_footprint_height * 2.0),
				5: Vector2(outer_left_x, status_footprint_height * 2.0),
				6: Vector2(outer_left_x, status_footprint_height),
				7: Vector2(outer_left_x, 0.0),
				8: Vector2(inner_left_x, 0.0),
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
		var status_label: Label = _seat_status_widgets.get(seat)
		var status_scale: float = (
			GuiMobileTableLayoutScript.COMPACT_TABLET_STATUS_SCALE
			if compact_tablet_layout
			else (1.0 if small_desktop_layout else seat_visual_scale)
		)
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
	elif compact_tablet_layout:
		_layout_compact_tablet_lower_regions(surface_size, center_width)
	if compact_layout:
		for seat: int in _seat_widgets:
			(
				GuiMobileTableLayoutScript
				. layout_seat_status_band(
					_seat_status_widgets[seat],
					_seat_widgets[seat],
					true,
					(
						GuiMobileTableLayoutScript.COMPACT_TABLET_STATUS_SCALE
						if compact_tablet_layout
						else (1.0 if small_desktop_layout else seat_visual_scale)
					),
				)
			)
	if not mobile_portrait_layout:
		_resolve_status_band_clearance(
			surface_size,
			compact_layout,
			(
				GuiMobileTableLayoutScript.COMPACT_TABLET_STATUS_SCALE
				if compact_tablet_layout
				else (1.0 if small_desktop_layout else seat_visual_scale)
			),
		)
	if not mobile_portrait_layout and not small_desktop_layout:
		_resolve_seat_panel_intersections(
			compact_layout,
			(
				GuiMobileTableLayoutScript.COMPACT_TABLET_STATUS_SCALE
				if compact_tablet_layout
				else (1.0 if small_desktop_layout else seat_visual_scale)
			),
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
	center_position = _reserve_desktop_quit_clearance(
		center_position,
		center_size,
		portrait_tablet_layout,
		compact_tablet_layout,
	)
	_layout_quit_button(
		center_position,
		center_size,
		portrait_tablet_layout,
		compact_tablet_layout,
	)
	if _wager_keypad != null and _wager_keypad.visible:
		_wager_keypad.refresh_layout(mobile_content_scale)
	if _quit_confirmation.visible:
		_quit_confirmation.popup_centered()


func _layout_phone_table(surface_size: Vector2, generation: int) -> void:
	_event_log.hide()
	_quit_button.hide()
	_phone_more_button.show()
	_board_label.hide()
	var landscape: bool = surface_size.x > surface_size.y
	_pot_zone.custom_minimum_size.y = 28.0 if landscape else 42.0
	_wager_zone.custom_minimum_size.y = 28.0 if landscape else 42.0
	for card: Control in _card_slots.get_children():
		GuiMobileTableLayoutScript._scale_card_face(
			card, Vector2(38.0, 42.0) if landscape else Vector2(46.0, 54.0), 22
		)
	_card_slots.add_theme_constant_override("separation", 2 if landscape else 6)
	var action_margin := _action_panel.get_node("Margin") as MarginContainer
	action_margin.add_theme_constant_override("margin_top", 2 if landscape else 6)
	action_margin.add_theme_constant_override("margin_bottom", 2 if landscape else 6)
	action_margin.add_theme_constant_override("margin_right", 78)
	var action_content := _action_panel.get_node("Margin/Content") as VBoxContainer
	action_content.add_theme_constant_override("separation", 2)
	_configure_phone_action_rows(landscape)
	if _phone_more_button.get_parent() != _surface:
		_phone_more_button.reparent(_surface)
	_phone_more_button.show()
	_phone_hero_stack.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_phone_hero_stack.clip_text = true
	_phone_hero_stack.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_phone_hero_stack.custom_minimum_size.x = 0.0
	_phone_hero_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phone_hero_action_badge.clip_text = true
	_phone_hero_action_badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_phone_hero_action_badge.custom_minimum_size.x = 0.0
	_phone_hero_action_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_status.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_action_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_action_status.clip_text = true
	_action_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_action_status.max_lines_visible = 1
	for button: Button in [_fold_button, _check_call_button, _wager_button, _all_in_button]:
		button.custom_minimum_size = Vector2(48.0, 48.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	var plan: RefCounted = GuiPhoneLayoutPlanScript.new()
	var detail_minimum_size := Vector2.ZERO
	if is_instance_valid(_seat_detail_overlay):
		detail_minimum_size = _seat_detail_overlay.get_combined_minimum_size()
	if not (
		plan
		. configure(
			surface_size,
			_seat_widgets.size(),
			_action_panel.get_combined_minimum_size(),
			_phone_overflow_menu.get_combined_minimum_size(),
			detail_minimum_size,
		)
	):
		return
	var phone_status_font_size: int = GuiMobileTableLayoutScript.TABLE_TEXT_FONT_SIZE
	if landscape and plan.center_rect.size.x < 280.0:
		phone_status_font_size = 24
	_pot_label.add_theme_font_size_override("font_size", phone_status_font_size)
	_wager_label.add_theme_font_size_override("font_size", phone_status_font_size)
	_applied_phone_layout_plan = plan
	_apply_phone_layout_plan(plan)
	# Containers finish child allocation after this method. Re-apply the exact
	# same immutable plan once, guarded so a newer resize can never restore it.
	call_deferred("_apply_phone_layout_if_current", plan, generation)
	_phone_more_button.custom_minimum_size = Vector2(72.0, 48.0)
	if _wager_keypad != null and _wager_keypad.visible:
		_wager_keypad.refresh_layout(
			GuiMobileTableLayoutScript.content_scale(surface_size), Vector2i(size)
		)
	if _quit_confirmation.visible:
		_quit_confirmation.popup_centered()
	_layout_phone_quit_confirmation(plan)


func _configure_phone_action_rows(single_row: bool) -> void:
	var action_content := _action_panel.get_node("Margin/Content") as VBoxContainer
	var hero_summary := action_content.get_node("PhoneHeroSummary") as HBoxContainer
	var action_rows := _action_panel.get_node("Margin/Content/ActionRows") as VBoxContainer
	var primary_buttons := action_rows.get_node("PrimaryButtons") as HBoxContainer
	var wager_controls := action_rows.get_node("WagerControls") as HBoxContainer
	if single_row:
		if _action_status.get_parent() != hero_summary:
			_action_status.reparent(hero_summary)
		if _wager_button.get_parent() != primary_buttons:
			_wager_button.reparent(primary_buttons)
		if _all_in_button.get_parent() != primary_buttons:
			_all_in_button.reparent(primary_buttons)
		wager_controls.hide()
	else:
		_restore_phone_action_rows()


func _restore_phone_action_rows() -> void:
	if not is_instance_valid(_action_panel):
		return
	var action_content := _action_panel.get_node("Margin/Content") as VBoxContainer
	var action_rows := action_content.get_node("ActionRows") as VBoxContainer
	var wager_controls := action_rows.get_node("WagerControls") as HBoxContainer
	if _action_status.get_parent() != action_content:
		_action_status.reparent(action_content)
		action_content.move_child(_action_status, 1)
	if _all_in_button.get_parent() != wager_controls:
		_all_in_button.reparent(wager_controls)
	if _wager_button.get_parent() != wager_controls:
		_wager_button.reparent(wager_controls)
	wager_controls.move_child(_all_in_button, 0)
	wager_controls.move_child(_wager_button, wager_controls.get_child_count() - 1)


func _apply_phone_layout_plan(plan: RefCounted) -> void:
	_apply_center_zone_bounds(plan.center_rect.size, plan.center_rect.position)
	var player_count: int = _seat_widgets.size()
	for seat: int in _seat_widgets:
		var panel: PanelContainer = _seat_widgets[seat]
		var visual_seat: int = posmod(seat - _bound_view.hero_seat, player_count)
		var token_rect: Rect2 = plan.seat_rects[visual_seat]
		panel.visible = seat != _bound_view.hero_seat
		panel.position = token_rect.position
		panel.size = token_rect.size
		_seat_status_widgets[seat].hide()
	_action_panel.position = plan.action_rect.position
	_action_panel.size = plan.action_rect.size
	var side_width: float = maxf(
		120.0, (plan.usable_rect.size.x - plan.center_rect.size.x) * 0.5 - 4.0
	)
	_event_log.size = Vector2(side_width, 96.0)
	_event_log.position = Vector2(0.0, plan.center_rect.end.y + 4.0)
	_phone_more_button.custom_minimum_size = plan.more_rect.size
	_phone_more_button.position = plan.more_rect.position
	_phone_more_button.size = plan.more_rect.size
	_layout_phone_overlays(plan)
	_layout_phone_seat_detail(plan)
	_layout_phone_quit_confirmation(plan)


func _apply_phone_layout_if_current(plan: RefCounted, generation: int) -> void:
	if generation != _layout_generation or plan != _applied_phone_layout_plan:
		return
	_apply_phone_layout_plan(plan)


func _layout_phone_overlays(plan: RefCounted = _applied_phone_layout_plan) -> void:
	if plan == null:
		_queue_layout()
		return
	for overlay: PanelContainer in [_phone_showdown_overlay]:
		overlay.position = plan.overlay_rect.position
		overlay.size = plan.overlay_rect.size
	_phone_overflow_menu.position = plan.menu_rect.position
	_phone_overflow_menu.size = plan.menu_rect.size


func _layout_phone_seat_detail(plan: RefCounted = _applied_phone_layout_plan) -> void:
	if not is_instance_valid(_seat_detail_overlay) or not _seat_detail_overlay.visible:
		return
	if plan == null:
		_queue_layout()
		return
	_seat_detail_overlay.position = plan.seat_detail_rect.position
	_seat_detail_overlay.size = plan.seat_detail_rect.size


func _layout_phone_quit_confirmation(plan: RefCounted = _applied_phone_layout_plan) -> void:
	if not _phone_quit_confirmation.visible:
		return
	if plan == null:
		_queue_layout()
		return
	_phone_quit_confirmation.position = plan.phone_quit_rect.position
	_phone_quit_confirmation.size = plan.phone_quit_rect.size


func _layout_compact_tablet_lower_regions(surface_size: Vector2, center_width: float) -> void:
	var hero_panel: PanelContainer = _seat_widgets.get(_bound_view.hero_seat)
	if hero_panel == null:
		push_error("Compact tablet layout requires a human seat panel.")
		return
	var status_reservation: float = (
		(
			GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT
			* GuiMobileTableLayoutScript.COMPACT_TABLET_STATUS_SCALE
		)
		+ (
			GuiMobileTableLayoutScript.STATUS_BAND_GAP
			* GuiMobileTableLayoutScript.COMPACT_TABLET_STATUS_SCALE
		)
	)
	var required_side_height: float = maxf(
		125.0,
		maxf(
			_action_panel.get_combined_minimum_size().y,
			_event_log.get_combined_minimum_size().y,
		),
	)
	hero_panel.size.y = maxf(hero_panel.size.y, required_side_height)
	hero_panel.size.x = center_width
	if surface_size.y > surface_size.x:
		var portrait_side_height: float = required_side_height
		var portrait_side_y: float = surface_size.y - portrait_side_height
		hero_panel.position = Vector2(
			(surface_size.x - hero_panel.size.x) * 0.5,
			portrait_side_y - status_reservation - hero_panel.size.y - 8.0,
		)
		hero_panel.position.y = maxf(hero_panel.position.y, _center_zone.get_rect().end.y + 4.0)
		_event_log.size = Vector2(center_width, portrait_side_height)
		_event_log.position = Vector2(0.0, portrait_side_y)
		_action_panel.size = Vector2(center_width, portrait_side_height)
		_action_panel.position = Vector2(surface_size.x - center_width, portrait_side_y)
		return
	hero_panel.position = Vector2(
		(surface_size.x - hero_panel.size.x) * 0.5,
		surface_size.y - hero_panel.size.y - status_reservation,
	)
	var side_width: float = maxf(0.0, (surface_size.x - hero_panel.size.x) * 0.5 - 8.0)
	var side_height: float = required_side_height
	var side_y: float = hero_panel.position.y + hero_panel.size.y - side_height
	_event_log.size = Vector2(side_width, side_height)
	_event_log.position = Vector2(0.0, side_y)
	_action_panel.size = Vector2(side_width, side_height)
	_action_panel.position = Vector2(surface_size.x - side_width, side_y)


func _layout_quit_button(
	center_position: Vector2,
	center_size: Vector2,
	portrait_tablet_layout: bool,
	compact_tablet_layout: bool = false,
) -> void:
	_quit_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var quit_minimum: Vector2 = _quit_button.get_combined_minimum_size()
	_quit_button.size = Vector2(maxf(72.0, quit_minimum.x), maxf(48.0, quit_minimum.y))
	var top: float = center_position.y + center_size.y + 4.0
	var left: float = center_position.x + (center_size.x - _quit_button.size.x) * 0.5
	if compact_tablet_layout and portrait_tablet_layout:
		left = (_event_log.size.x - _quit_button.size.x) * 0.5
		top = _event_log.position.y - _quit_button.size.y - 4.0
	elif compact_tablet_layout:
		top = maxf(0.0, center_position.y - _quit_button.size.y - 4.0)
	elif portrait_tablet_layout:
		top = _action_panel.position.y + _action_panel.size.y + 4.0
	_quit_button.position = Vector2(left, top)


func _reserve_desktop_quit_clearance(
	center_position: Vector2,
	center_size: Vector2,
	portrait_tablet_layout: bool,
	compact_tablet_layout: bool,
) -> Vector2:
	if portrait_tablet_layout or compact_tablet_layout or _bound_view == null:
		return center_position
	var hero_panel: PanelContainer = _seat_widgets.get(_bound_view.hero_seat)
	if hero_panel == null:
		return center_position
	var quit_minimum: Vector2 = _quit_button.get_combined_minimum_size()
	var quit_height: float = maxf(48.0, quit_minimum.y)
	var proposed_quit_bottom: float = center_position.y + center_size.y + 4.0 + quit_height
	var available_bottom: float = hero_panel.position.y - 4.0
	var required_shift: float = maxf(0.0, proposed_quit_bottom - available_bottom)
	if required_shift <= 0.0:
		return center_position
	var adjusted_position := Vector2(
		center_position.x,
		maxf(0.0, center_position.y - required_shift),
	)
	_resolved_center_position = adjusted_position
	_apply_center_zone_bounds(center_size, adjusted_position)
	call_deferred(
		"_apply_center_zone_bounds_if_current",
		center_size,
		adjusted_position,
		_layout_generation,
	)
	return adjusted_position


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
	if not is_node_ready():
		return
	_layout_generation += 1
	if _layout_queued:
		return
	_layout_queued = true
	call_deferred("_apply_queued_layout")


func _apply_queued_layout() -> void:
	_layout_queued = false
	_layout_table(_surface.size, _layout_generation)


func _current_usable_size() -> Vector2:
	if _applied_usable_size.x > 0.0 and _applied_usable_size.y > 0.0:
		return _applied_usable_size
	return _surface.size


func _apply_center_zone_bounds(resolved_size: Vector2, resolved_position: Vector2) -> void:
	if not is_instance_valid(_center_zone):
		return
	_resolved_center_size = resolved_size
	_resolved_center_position = resolved_position
	_center_zone.custom_minimum_size = Vector2.ZERO
	_center_zone.size = resolved_size
	_center_zone.position = resolved_position
	var phone_layout: bool = GuiLayoutProfileScript.is_phone(get_layout_profile())
	var landscape_phone: bool = phone_layout and _current_usable_size().x > _current_usable_size().y
	var separation: float = 4.0 if phone_layout else CENTER_ZONE_SEPARATION
	var minimum_board_height: float = 44.0 if landscape_phone else CENTER_BOARD_MINIMUM_HEIGHT
	var pot_height: float = _pot_zone.custom_minimum_size.y
	var wager_height: float = _wager_zone.custom_minimum_size.y
	var board_height: float = maxf(
		minimum_board_height,
		resolved_size.y - pot_height - wager_height - separation * 2.0,
	)
	_board_zone.position = Vector2.ZERO
	_board_zone.size = Vector2(resolved_size.x, board_height)
	_pot_zone.position = Vector2(0.0, board_height + separation)
	_pot_zone.size = Vector2(resolved_size.x, pot_height)
	_wager_zone.position = Vector2(
		0.0,
		board_height + separation + pot_height + separation,
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
