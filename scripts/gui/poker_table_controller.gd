class_name PokerTableController
extends Control
# gdlint: disable=max-file-lines
signal tournament_quit_confirmed
signal return_to_startup_requested
const GuiPhoneTokenContentPlanScript := preload("res://scripts/gui/gui_phone_token_content_plan.gd")
const CardFaceFactoryScript := preload("res://scripts/gui/card_face_factory.gd")
const GuiActionPacerScript := preload("res://scripts/gui/gui_action_pacer.gd")
const GuiEventFormatterScript := preload("res://scripts/gui/gui_event_formatter.gd")
const GuiMatchProgressInspectorScript := preload(
	"res://scripts/gui/gui_match_progress_inspector.gd"
)
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const GuiMobileTableLayoutScript := preload("res://scripts/gui/gui_mobile_table_layout.gd")
const GuiSixSeatDesktopPlanScript := preload("res://scripts/gui/gui_six_seat_desktop_plan.gd")
const GuiPhoneLayoutPlanScript := preload("res://scripts/gui/gui_phone_layout_plan.gd")
const GuiPhoneSeatLayoutScript := preload("res://scripts/gui/gui_phone_seat_layout.gd")
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")
const PotWagerTargetScript := preload("res://scripts/core/pot_wager_target.gd")
const ShowdownHandFormatterScript := preload("res://scripts/gui/showdown_hand_formatter.gd")
const TournamentStatusFormatterScript := preload("res://scripts/gui/tournament_status_formatter.gd")
const GuiModalGuardScript := preload("res://scripts/gui/gui_modal_guard.gd")
const WagerKeypadScript := preload("res://scripts/gui/wager_keypad.gd")
const PHONE_CARD_SIZE = GuiTableSeatFactory.PHONE_CARD_SIZE
const PHONE_SHOWDOWN_CARD_SIZE = GuiTableSeatFactory.PHONE_SHOWDOWN_CARD_SIZE
const PHONE_SHOWDOWN_CARD_GAP = GuiTableSeatFactory.PHONE_SHOWDOWN_CARD_GAP
const GUI_MINIMUM_FONT_SIZE: int = GuiTableStyle.MINIMUM_FONT_SIZE
const SEAT_TEXT_FONT_SIZE = GuiTableSeatFactory.SEAT_TEXT_FONT_SIZE
const DESKTOP_CENTER_ZONE_MAX_WIDTH: float = 520.0
const CENTER_ZONE_SEPARATION: float = 8.0
const CENTER_BOARD_MINIMUM_HEIGHT: float = 74.0
const PHONE_ACTION_HORIZONTAL_PADDING: float = 12.0
const PHONE_HERO_ACTION_HORIZONTAL_PADDING: float = 4.0
const PHONE_OPPONENT_ACTION_MINIMUM_WIDTH: float = 48.0
@export var action_timing_config: Resource

var board_card_count: int = 0
var wager_amounts: Dictionary[int, int] = {}
var displayed_pot_amount: int = 0
var displayed_hero_cards: Array[CardData] = []
var _overlay_views := GuiTableOverlayViews.new()
var _action_controls := GuiTableActionControls.new()
var _seat_factory := GuiTableSeatFactory.new()
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
var _compact_six_seat_desktop: bool = false
var _layout_queued: bool = false
var _layout_generation: int = 0
var _applied_usable_size: Vector2 = Vector2.ZERO
var _applied_phone_layout_plan: GuiPhoneLayoutPlan
var _resolved_center_size: Vector2 = Vector2.ZERO
var _resolved_center_position: Vector2 = Vector2.ZERO
var _event_texts: Array[String] = []
var _active_round_latest_actions: Dictionary[int, PublicActionRecord] = {}
var _retained_fold_actions: Dictionary[int, PublicActionRecord] = {}
var _action_pacer = GuiActionPacerScript.new()
var _modal_guard: GuiModalGuard
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
	_action_controls.configure(self)
	_overlay_views.configure(self)
	_apply_table_styles()
	_wager_input.virtual_keyboard_enabled = false
	_wager_input.virtual_keyboard_show_on_focus = false
	_wager_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_modal_guard = GuiModalGuardScript.new()
	add_child(_modal_guard)
	_modal_guard.configure(self, _surface)
	_add_phone_modal_quit(_phone_showdown_overlay.get_node("Content"))
	_wager_keypad = WagerKeypadScript.new()
	add_child(_wager_keypad)
	_wager_keypad.confirmed.connect(_on_wager_keypad_confirmed)
	_wager_keypad.popup_hide.connect(_on_wager_keypad_hidden)
	_wager_keypad.quit_requested.connect(_on_modal_quit_pressed)
	_wager_keypad.set_quit_available(true)
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
	_quit_confirmation.visibility_changed.connect(_finish_phone_modal_if_closed)
	_phone_more_button.pressed.connect(_on_phone_more_pressed)
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
	_seat_factory.configure(_bound_view, _avatar_assignments, _name_assignments)
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
	_seat_factory.configure(_bound_view, _avatar_assignments, _name_assignments)
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
		var panel := _seat_widgets[seat] as GuiTableSeatView
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
	_switch_phone_modal(true)
	var pot_target: PotWagerTargetResult = _resolved_pot_wager_target()
	(
		_wager_keypad
		. open(
			_wager_input,
			_bound_view.minimum_wager_total,
			_bound_view.maximum_wager_total,
			GuiMobileTableLayoutScript.content_scale(_current_usable_size()),
			GuiLayoutProfileScript.is_phone(get_layout_profile()) or _uses_numeric_keypad(),
			pot_target.contribution,
			pot_target.wager_total,
			Vector2i(size),
		)
	)

	(
		_modal_guard
		. begin(
			_wager_keypad,
			_wager_keypad.cancel,
			_wager_keypad.get_node("Content/Cancel"),
			_wager_button,
		)
	)


func _on_wager_keypad_hidden() -> void:
	if not _overlay_views.switching:
		_modal_guard.finish()


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
	_action_controls.apply_action_control_styles()


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
	if not phone_layout and _uses_large_chip_values():
		_pot_label.text = (
			"Pot: %d | L%d\nSB %d BB %d"
			% [
				displayed_pot_amount,
				_bound_view.blind_level,
				_bound_view.small_blind,
				_bound_view.big_blind
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


func _uses_large_chip_values() -> bool:
	if _bound_view == null:
		return false
	if _bound_view.pot_amount >= 1000000 or _bound_view.big_blind >= 100000:
		return true
	for player: PlayerView in _bound_view.seats:
		if player.stack >= 100000 or player.bet_this_round >= 100000:
			return true
	return false


func _uses_numeric_keypad() -> bool:
	return GuiTableLayoutPass.numeric_keypad(
		get_layout_profile(), _surface.size, _compact_six_seat_desktop, _uses_large_chip_values()
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
	_seat_factory.configure(_bound_view, _avatar_assignments, _name_assignments)
	for seat_widget: PanelContainer in _seat_widgets.values():
		seat_widget.free()
	for status_widget: Label in _seat_status_widgets.values():
		status_widget.free()
	_seat_widgets.clear()
	_seat_status_widgets.clear()
	_phone_seat_widgets = GuiLayoutProfileScript.is_phone(get_layout_profile())
	for player_view: PlayerView in _bound_view.seats:
		var seat_widget := (
			_seat_factory.create_hero_seat_widget(player_view)
			if player_view.seat == _bound_view.hero_seat
			else (
				_seat_factory.create_phone_opponent_token(
					player_view,
					_phone_opponent_action_for_seat(player_view.seat),
					_open_phone_seat_detail
				)
				if _phone_seat_widgets
				else _seat_factory.create_seat_widget(player_view)
			)
		)
		_seats.add_child(seat_widget)
		_seat_widgets[player_view.seat] = seat_widget
		var status_widget := _create_seat_status_label(player_view)
		_seats.add_child(status_widget)
		_seat_status_widgets[player_view.seat] = status_widget
	_refresh_phone_seat_detail()


func _layout_phone_opponent_action_badges(landscape: bool, expanded_rows: bool = false) -> void:
	for seat: int in _seat_widgets:
		var seat_widget := _seat_widgets[seat] as GuiTableSeatView
		var action_badge := seat_widget.action_badge
		if action_badge == null:
			continue
		var action_width: float = _phone_action_badge_width(action_badge)
		var cards := seat_widget.hole_cards
		var revealed_cards: bool = _phone_token_shows_cards(cards)
		action_badge.visible = action_badge.visible and not revealed_cards
		var cards_width: float = (
			PHONE_SHOWDOWN_CARD_SIZE.x * 2.0 + PHONE_SHOWDOWN_CARD_GAP if revealed_cards else 40.0
		)
		var reserved_action_width: float = (
			action_width if action_badge.visible or not revealed_cards else 0.0
		)
		if landscape:
			# Landscape retains the two-row emergency composition and abbreviates
			# exact-thousand all-ins; full landscape support remains deferred.
			action_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			action_badge.offset_left = -45.0 - action_width
			action_badge.offset_right = -45.0
			action_badge.offset_top = 30.0
			action_badge.offset_bottom = 59.0
		else:
			# Anchor from the fixed card fields so Web-font glyph width, rather
			# than an exact middle-cell split, owns the action badge width.
			action_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			action_badge.offset_left = -cards_width - reserved_action_width
			action_badge.offset_right = -cards_width
			action_badge.offset_top = 30.0
			action_badge.offset_bottom = 60.0
		action_badge.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
		var state_badge := seat_widget.state_badge
		state_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		state_badge.visible = not (
			String(state_badge.get_meta("full_text", state_badge.text)).is_empty()
		)
		state_badge.text = state_badge.get_meta("full_text", state_badge.text)
		for extra_name: String in ["BadgeRow2", "BadgeRow3"]:
			var extra: Label = seat_widget.badge_rows.get(extra_name)
			if extra != null:
				extra.hide()
		var state_width: float = (
			ceilf(
				(
					state_badge
					. get_theme_font("font")
					. get_string_size(
						state_badge.text,
						HORIZONTAL_ALIGNMENT_LEFT,
						-1.0,
						state_badge.get_theme_font_size("font_size")
					)
					. x
				)
			)
			+ 4.0
		)
		var badge_style := state_badge.get_theme_stylebox("normal") as StyleBoxFlat
		badge_style.content_margin_left = 2.0
		badge_style.content_margin_right = 2.0
		badge_style.content_margin_top = 0.0 if expanded_rows else 1.0
		badge_style.content_margin_bottom = 0.0 if expanded_rows else 1.0
		state_badge.offset_top = 0.0
		state_badge.offset_right = -4.0
		state_badge.offset_left = -state_width - 4.0
		state_badge.offset_bottom = 30.0
		var name_label := seat_widget.name_label
		name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		name_label.offset_left = 4.0
		name_label.offset_top = 0.0
		name_label.offset_bottom = 28.0
		name_label.offset_right = -state_width - 4.0
		var stack := seat_widget.stack_label
		stack.set_anchors_preset(Control.PRESET_TOP_LEFT if landscape else Control.PRESET_TOP_WIDE)
		stack.offset_left = 4.0
		stack.offset_top = 23.0 if landscape else 30.0
		stack.offset_right = 62.0 if landscape else -cards_width - reserved_action_width
		stack.offset_bottom = 47.0 if landscape else 60.0
		cards.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		cards.offset_left = -cards_width - 2.0 if landscape else -cards_width
		cards.offset_top = 30.0
		cards.offset_right = -2.0 if landscape else 0.0
		cards.offset_bottom = (
			cards.offset_top + (PHONE_SHOWDOWN_CARD_SIZE.y if revealed_cards else PHONE_CARD_SIZE.y)
		)
		if expanded_rows:
			# Exact actions own a full row; revealed cards replace that row at showdown.
			stack.offset_top = 28.0
			stack.offset_right = -4.0 if revealed_cards else -cards_width
			stack.offset_bottom = 56.0
			state_badge.offset_bottom = 28.0
			action_badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
			action_badge.offset_left = 4.0
			action_badge.offset_right = -4.0
			action_badge.offset_top = 56.0
			action_badge.offset_bottom = 86.0
			cards.offset_top = 56.0 if revealed_cards else 28.0
			cards.offset_bottom = cards.offset_top + (30.0 if revealed_cards else 26.0)
			_layout_expanded_phone_identity(seat_widget, revealed_cards, cards_width)


func _layout_expanded_phone_identity(
	panel: GuiTableSeatView, revealed: bool, cards_width: float
) -> void:
	var badge := panel.state_badge
	var parts: Array = panel.get_meta("phone_badge_parts", [])
	# Heads-up dealer/small-blind is one established compact position alias.
	# Keeping it together avoids paying a separate frame margin for each role.
	if not revealed and parts.size() == 3 and parts[0] == "D" and parts[1] == "SB":
		parts = ["DSB", parts[2]]
	var fields: Dictionary[String, Control] = {}
	var widths: Dictionary[String, float] = {}
	for field_name: String in ["Name", "Stack", "HoleCards", "ActionBadge"]:
		var field := panel.field(field_name)
		if field_name == "ActionBadge" and not field.visible:
			continue
		fields[field_name] = field
		if field is Label:
			widths[field_name] = _phone_action_badge_width(
				field, 0.0, PHONE_ACTION_HORIZONTAL_PADDING if field_name == "ActionBadge" else 0.0
			)
		else:
			widths[field_name] = cards_width
	badge.hide()
	for index: int in range(parts.size()):
		var node_name: String = "Badge" if index == 0 else "BadgeRow%d" % (index + 1)
		var row_badge: Label = panel.badge_rows.get(node_name)
		if row_badge == null:
			row_badge = _seat_factory.phone_token_label(node_name, "")
			row_badge.add_theme_stylebox_override("normal", badge.get_theme_stylebox("normal"))
			badge.get_parent().add_child(row_badge)
			panel.badge_rows[node_name] = row_badge
		var badge_style := row_badge.get_theme_stylebox("normal") as StyleBoxFlat
		badge_style.content_margin_left = 1.0
		badge_style.content_margin_right = 1.0
		row_badge.text = parts[index]
		row_badge.show()
		fields[node_name] = row_badge
		widths[node_name] = _phone_action_badge_width(row_badge, 0.0, 2.0)
	var token_width: float = (
		GuiPhoneSeatLayoutScript.seat_rects(_surface.size, _seat_widgets.size())[1].size.x
	)
	var plan := GuiPhoneTokenContentPlanScript.new()
	if not plan.configure(token_width, widths, revealed):
		push_error(
			(
				"Phone token content does not fit the measured three-row plan: %s at %s px"
				% [widths, token_width]
			)
		)
		return
	for field_name: String in fields:
		var field: Control = fields[field_name]
		if field is Label and field_name == "ActionBadge":
			var style := (field as Label).get_theme_stylebox("normal") as StyleBoxFlat
			style.content_margin_top = 0.0
			style.content_margin_bottom = 0.0
		field.set_anchors_preset(Control.PRESET_TOP_LEFT)
		field.position = plan.rects[field_name].position
		field.size = plan.rects[field_name].size
		if field_name == "HoleCards":
			field.size.y = PHONE_SHOWDOWN_CARD_SIZE.y if revealed else PHONE_CARD_SIZE.y


func _phone_numeric_rows_needed(surface_size: Vector2) -> bool:
	if surface_size.x > surface_size.y or _seat_widgets.size() > 7:
		return false
	var rects: Dictionary[int, Rect2] = GuiPhoneSeatLayoutScript.seat_rects(
		surface_size, _seat_widgets.size()
	)
	for seat: int in _seat_widgets:
		if seat == _bound_view.hero_seat:
			continue
		var panel := _seat_widgets[seat] as GuiTableSeatView
		var name_label := panel.name_label
		var badge := panel.state_badge
		badge.text = badge.get_meta("full_text", badge.text)
		if (
			(
				_phone_action_badge_width(name_label, 0.0, 0.0)
				+ _phone_action_badge_width(badge, 0.0, 4.0)
				+ 8.0
			)
			> rects[1].size.x
		):
			return true
		var stack := panel.stack_label
		var action := panel.action_badge
		var cards := panel.hole_cards
		var revealed: bool = _phone_token_shows_cards(cards)
		var card_width: float = 94.0 if revealed else 40.0
		var action_width: float = _phone_action_badge_width(action) if not revealed else 0.0
		if (
			_phone_action_badge_width(stack, 0.0, 0.0) + card_width + action_width + 4.0
			> rects[1].size.x
		):
			return true
	return false


func _phone_action_badge_width(
	badge: Label,
	minimum_width: float = PHONE_OPPONENT_ACTION_MINIMUM_WIDTH,
	horizontal_padding: float = PHONE_ACTION_HORIZONTAL_PADDING,
) -> float:
	var rendered_width: float = (
		badge
		. get_theme_font("font")
		. get_string_size(
			badge.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			badge.get_theme_font_size("font_size"),
		)
		. x
	)
	return maxf(minimum_width, ceilf(rendered_width + horizontal_padding))


func _compact_phone_action_for_seat(seat: int, abbreviate_exact_thousands: bool = true) -> String:
	var latest_action: PublicActionRecord = _active_round_latest_actions.get(seat)
	if latest_action == null or latest_action.record_kind != PublicActionRecord.Kind.ACTION:
		return ""
	return _compact_phone_action_text(latest_action, abbreviate_exact_thousands)


func _phone_opponent_action_for_seat(seat: int) -> String:
	return _compact_phone_action_for_seat(
		seat, get_layout_profile() == GuiLayoutProfileScript.Kind.PHONE_LANDSCAPE
	)


func _phone_hero_action_for_seat(seat: int) -> String:
	return _compact_phone_action_for_seat(
		seat, get_layout_profile() == GuiLayoutProfileScript.Kind.PHONE_LANDSCAPE
	)


func _compact_phone_action_text(
	latest_record: PublicActionRecord, abbreviate_exact_thousands: bool = true
) -> String:
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
			compact_text = (
				"A%dk" % (latest_record.amount / 1000)
				if (
					abbreviate_exact_thousands
					and latest_record.amount >= 1000
					and latest_record.amount % 1000 == 0
				)
				else "A%d" % latest_record.amount
			)
	return compact_text


func _refresh_rendered_phone_action_badges() -> void:
	if not _phone_seat_widgets or _bound_view == null:
		return
	_phone_hero_action_badge.text = _phone_hero_action_for_seat(_bound_view.hero_seat)
	_phone_hero_action_badge.visible = (
		not _phone_hero_action_badge.text.is_empty() and not _bound_view.hand_complete
	)
	_phone_hero_action_badge.tooltip_text = _phone_action_tooltip(_bound_view.hero_seat)
	for seat: int in _seat_widgets:
		var badge := (_seat_widgets[seat] as GuiTableSeatView).action_badge
		if badge == null:
			continue
		badge.text = _phone_opponent_action_for_seat(seat)
		var cards := (_seat_widgets[seat] as GuiTableSeatView).hole_cards
		badge.visible = not badge.text.is_empty() and not _phone_token_shows_cards(cards)
		badge.tooltip_text = _phone_action_tooltip(seat)


func _phone_action_tooltip(seat: int) -> String:
	var latest_action: PublicActionRecord = _active_round_latest_actions.get(seat)
	if latest_action == null or latest_action.record_kind != PublicActionRecord.Kind.ACTION:
		return ""
	return _action_record_text(latest_action)


func _phone_token_shows_cards(cards: Control) -> bool:
	return cards != null and cards.find_child("ShowdownCard1", false, false) != null


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


func _tablet_status_scale() -> float:
	return GuiTableLayoutPass.resolve_tablet_status_scale(_surface.size, _compact_six_seat_desktop)


func _showdown_hand_text(seat: int) -> String:
	if _bound_view == null:
		return ""
	var showdown_result: ShowdownResult = _bound_view.showdown_results.get(seat)
	if (
		get_layout_profile() == GuiLayoutProfileScript.Kind.TABLET
		and _surface.size.x < 1600.0
		and _surface.size.x >= _surface.size.y
	):
		return ShowdownHandFormatterScript.format_inline(showdown_result)
	if (
		_compact_six_seat_desktop
		or GuiMobileTableLayoutScript.is_small_desktop(_surface.size)
		or (get_layout_profile() == GuiLayoutProfileScript.Kind.TABLET and _surface.size.x < 1600.0)
	):
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


func _open_phone_seat_detail(seat: int) -> void:
	if not _phone_seat_widgets or _player_view_for_seat(seat) == null:
		return
	_switch_phone_modal()
	_overlay_views.detail_seat = seat
	_refresh_phone_seat_detail()
	(
		_modal_guard
		. begin(
			_overlay_views.detail_overlay,
			_close_phone_seat_detail,
			_overlay_views.detail_close_button,
			_phone_more_button,
		)
	)
	_queue_layout()


func _close_phone_seat_detail() -> void:
	_overlay_views.close_detail()
	_finish_phone_modal_if_closed()


func _refresh_phone_seat_detail() -> void:
	if not is_node_ready():
		return
	if not _phone_seat_widgets or _overlay_views.detail_seat == Table.NO_SEAT:
		_close_phone_seat_detail()
		return
	var player_view: PlayerView = _player_view_for_seat(_overlay_views.detail_seat)
	if player_view == null:
		_close_phone_seat_detail()
		return
	_overlay_views.rebuild_detail(
		player_view, _seat_factory, _surface, _close_phone_seat_detail, _on_modal_quit_pressed
	)
	_layout_phone_overlays()
	if _modal_guard.is_active():
		_modal_guard.begin(
			_overlay_views.detail_overlay,
			_close_phone_seat_detail,
			_overlay_views.detail_close_button,
			_phone_more_button
		)


func _player_view_for_seat(seat: int) -> PlayerView:
	if _bound_view == null:
		return null
	for player_view: PlayerView in _bound_view.seats:
		if player_view.seat == seat:
			return player_view
	return null


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
				action_text = "Call to %d" % latest_record.amount
			PlayerAction.Kind.BET:
				action_text = "Bet to %d" % latest_record.amount
			PlayerAction.Kind.RAISE:
				action_text = "Raise to %d" % latest_record.amount
			PlayerAction.Kind.ALL_IN:
				action_text = "All-in to %d" % latest_record.amount
	if latest_record.amount >= 100000 and _uses_compact_table_copy():
		action_text = action_text.replace(" to ", " ")
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
	_action_controls.configure_action_control_copy(
		_bound_view, legal, _uses_compact_table_copy(), _resolved_pot_wager_target()
	)
	_action_controls.configure_action_control_visibility(
		_bound_view, legal, is_human_turn, GuiLayoutProfileScript.is_phone(get_layout_profile())
	)
	_all_in_button.text = "All-in"
	if not can_wager and _wager_keypad != null:
		_wager_keypad.hide()
	if _bound_view.tournament_status == &"finished":
		_action_status.text = TournamentStatusFormatterScript.format(_bound_view)
		if _bound_view.end_reason == &"winner":
			_action_status.text = (
				"%s wins the tournament!"
				% _display_name_for_seat(_bound_view.tournament_winner_seat)
			)
	elif is_human_turn:
		_action_status.text = "Your turn — %s." % GuiEventFormatterScript.street_name(_bound_view)
	elif _bound_view.hand_complete:
		_action_status.text = "Hand complete."
	else:
		_action_status.text = (
			"%s to act — %s"
			% [
				GuiEventFormatterScript.player_name_for(_bound_view, _bound_view.acting_seat),
				GuiEventFormatterScript.street_name(_bound_view),
			]
		)
	if _uses_compact_table_copy():
		if _bound_view.tournament_status == &"finished" and _bound_view.end_reason == &"winner":
			_action_status.text = (
				"%s wins" % _display_name_for_seat(_bound_view.tournament_winner_seat)
			)
		elif _bound_view.tournament_status != &"finished":
			if is_human_turn:
				_action_status.text = (
					"Your turn: %s" % GuiEventFormatterScript.street_name(_bound_view)
				)
			elif _bound_view.hand_complete:
				_action_status.text = "Hand complete"
			else:
				_action_status.text = (
					"Act: %s"
					% GuiEventFormatterScript.player_name_for(_bound_view, _bound_view.acting_seat)
				)

	if GuiLayoutProfileScript.is_phone(get_layout_profile()) and _bound_view.hand_complete:
		var result_text: String = _phone_hand_result_text()
		if not result_text.is_empty() and _bound_view.tournament_status != &"finished":
			_action_status.text = result_text


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
				Vector2(33.0, 44.0),
				22,
				Color("f5f0dc"),
				Color("d9b56d"),
			)
		)
		_phone_hero_cards.add_child(card)


func _phone_hand_result_text(maximum_width: float = INF) -> String:
	if _bound_view == null or not _bound_view.hand_complete:
		return ""
	var recipients: Array[int] = []
	for award: PotAward in _bound_view.pot_awards:
		for seat: int in award.winner_seats:
			if seat not in recipients:
				recipients.append(seat)
	if recipients.is_empty() and _bound_view.hand_winner_seat != Table.NO_SEAT:
		recipients.append(_bound_view.hand_winner_seat)
	if recipients.is_empty():
		return ""
	recipients.sort()
	var lines: Array[String] = []
	var line: String = "Winner: " if recipients.size() == 1 else "Winners: "
	var font: Font = _action_status.get_theme_font("font")
	for seat: int in recipients:
		var player_name: String = _display_name_for_seat(seat)
		var candidate: String = line + player_name
		if (
			font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, GUI_MINIMUM_FONT_SIZE).x
			> maximum_width
		):
			lines.append(line.trim_suffix(", "))
			line = player_name + ", "
		else:
			line = candidate + ", "
	lines.append(line.trim_suffix(", "))
	return "\n".join(lines)


func _on_phone_more_pressed() -> void:
	if _bound_view != null and _bound_view.hand_complete and _has_phone_hand_summary():
		_open_phone_showdown()
	else:
		_open_phone_overflow_menu()


func _refresh_phone_secondary_controls() -> void:
	if _bound_view == null:
		return
	var has_result: bool = _bound_view.hand_complete and _has_phone_hand_summary()
	_phone_more_button.text = "Pots" if has_result else "More"
	_phone_more_button.tooltip_text = "Show pot awards and hands" if has_result else "Table menu"
	_phone_menu_showdown_button.visible = _has_phone_hand_summary()
	_phone_showdown_summary.text = _phone_showdown_summary_text()
	if not _has_phone_hand_summary():
		_close_phone_showdown()


func _has_phone_hand_summary() -> bool:
	return (
		_bound_view != null
		and (
			not _bound_view.showdown_results.is_empty()
			or not _bound_view.pot_awards.is_empty()
			or _bound_view.hand_winner_seat != Table.NO_SEAT
		)
	)


func _display_name_for_seat(seat: int) -> String:
	var player_view: PlayerView = _player_view_for_seat(seat)
	return (
		_seat_factory.seat_title(player_view) if player_view != null else "Player %d" % (seat + 1)
	)


func _phone_showdown_summary_text() -> String:
	if _bound_view == null:
		return ""
	var seats: Array[int] = []
	for seat: int in _bound_view.showdown_results:
		seats.append(seat)
	seats.sort()
	var lines: Array[String] = []
	for award: PotAward in _bound_view.pot_awards:
		var pot_name: String = (
			"Main pot" if award.pot_index == 0 else "Side pot %d" % award.pot_index
		)
		var recipients: Array[String] = []
		for seat: int in award.winner_seats:
			recipients.append(
				"%s +%d" % [_display_name_for_seat(seat), award.amounts_by_seat[seat]]
			)
		lines.append("%s (%d): %s" % [pot_name, award.amount, ", ".join(recipients)])
	if _bound_view.pot_awards.is_empty() and _bound_view.hand_winner_seat != Table.NO_SEAT:
		lines.append("%s wins the hand" % _display_name_for_seat(_bound_view.hand_winner_seat))
	for seat: int in seats:
		var player_view: PlayerView = _player_view_for_seat(seat)
		if player_view == null:
			continue
		var result: ShowdownResult = _bound_view.showdown_results.get(seat)
		var description: String = ShowdownHandFormatterScript.format(result)
		if not description.is_empty():
			lines.append("%s — %s" % [_seat_factory.seat_title(player_view), description])
	return "\n".join(lines)


func _open_phone_overflow_menu() -> void:
	if not GuiLayoutProfileScript.is_phone(get_layout_profile()):
		return
	_switch_phone_modal()
	_phone_overflow_menu.show()
	_modal_guard.begin(
		_phone_overflow_menu,
		_close_phone_overflow_menu,
		_phone_menu_close_button,
		_phone_more_button
	)
	_layout_phone_overlays()


func _close_phone_overflow_menu() -> void:
	_phone_overflow_menu.hide()
	_finish_phone_modal_if_closed()


func _open_phone_showdown() -> void:
	if not GuiLayoutProfileScript.is_phone(get_layout_profile()) or not _has_phone_hand_summary():
		return
	_switch_phone_modal()
	_phone_showdown_summary.text = _phone_showdown_summary_text()
	_phone_showdown_overlay.show()
	_modal_guard.begin(
		_phone_showdown_overlay,
		_close_phone_showdown,
		_phone_showdown_close_button,
		_phone_more_button
	)
	_layout_phone_overlays()


func _close_phone_showdown() -> void:
	_phone_showdown_overlay.hide()
	_finish_phone_modal_if_closed()


func _switch_phone_modal(keep_keypad: bool = false) -> void:
	_overlay_views.switch_modal(_wager_keypad, _quit_confirmation, keep_keypad)


func _close_phone_overlays() -> void:
	_switch_phone_modal()
	_modal_guard.finish()


func _finish_phone_modal_if_closed() -> void:
	_overlay_views.finish_if_closed(_modal_guard, _wager_keypad, _quit_confirmation)


func _on_phone_menu_quit_pressed() -> void:
	_on_modal_quit_pressed()


func _on_modal_quit_pressed() -> void:
	_on_quit_pressed()


func _add_phone_modal_quit(content: Node) -> void:
	_overlay_views.add_quit_button(content, _on_modal_quit_pressed)


func _close_phone_quit_confirmation() -> void:
	_phone_quit_confirmation.hide()
	_finish_phone_modal_if_closed()


func _on_phone_quit_confirmed() -> void:
	_modal_guard.cancel_advance()
	_on_quit_confirmed()
	_close_phone_quit_confirmation()


func _uses_compact_table_copy() -> bool:
	return GuiTableLayoutPass.compact_copy(
		get_layout_profile(), _surface.size, _compact_six_seat_desktop
	)


func _can_submit_pot_wager(legal: Array, is_human_turn: bool) -> bool:
	if not is_human_turn:
		return false
	if PlayerAction.Kind.BET not in legal and PlayerAction.Kind.RAISE not in legal:
		return false
	return _resolved_pot_wager_target().available


func _resolved_pot_wager_target() -> PotWagerTargetResult:
	if _bound_view == null:
		return PotWagerTargetScript.resolve(0, 0, 0, 1, 0)
	var existing_wager: int = -1
	for seat: PlayerView in _bound_view.seats:
		if seat.seat == _bound_view.hero_seat:
			existing_wager = seat.bet_this_round
			break
	return (
		PotWagerTargetScript
		. resolve(
			displayed_pot_amount,
			existing_wager,
			_bound_view.call_amount,
			_bound_view.minimum_wager_total,
			_bound_view.maximum_wager_total,
		)
	)


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
	var pot_target: PotWagerTargetResult = _resolved_pot_wager_target()
	submit_wager_total(pot_target.wager_total)


func _on_wager_pressed() -> void:
	if GuiLayoutProfileScript.is_phone(get_layout_profile()) or _uses_numeric_keypad():
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
		_modal_guard.cancel_advance()
		_close_phone_overlays()
		return_to_startup_requested.emit()
	elif _match.state == TournamentMatch.State.RUNNING:
		if GuiLayoutProfileScript.is_phone(get_layout_profile()):
			_switch_phone_modal()
			_phone_quit_confirmation.show()
			_modal_guard.begin(
				_phone_quit_confirmation,
				_close_phone_quit_confirmation,
				_phone_quit_continue_button,
				_phone_more_button
			)
			_layout_phone_overlays()
		else:
			_switch_phone_modal()
			_quit_confirmation.popup_centered()
			_modal_guard.begin(
				_quit_confirmation,
				_quit_confirmation.hide,
				_quit_confirmation.get_cancel_button(),
				_quit_button
			)


func _on_quit_confirmed() -> void:
	if _match == null:
		return
	_action_pacer.cancel()
	_modal_guard.cancel_advance()
	var result: StepResult = _match.request_quit()
	refresh_from_match()
	if result.status == StepResult.Status.ERROR:
		_action_status.text = result.message
		return
	tournament_quit_confirmed.emit()


func _submit_action(action: PlayerAction) -> void:
	if _modal_guard.is_active():
		return
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
	if _modal_guard.hold_advance(_advance_after_action_pause):
		return
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
	if _modal_guard.hold_advance(_advance_after_hand_boundary):
		return
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
	if usable_size.x <= 0.0 or usable_size.y <= 0.0 or _bound_view == null:
		return
	_applied_usable_size = usable_size
	var layout := GuiTableLayoutPass.new()
	layout.configure(
		size,
		usable_size,
		_layout_profile_override,
		_bound_view.seats.size(),
		_uses_large_chip_values()
	)
	# The root Control is the usable viewport. TableSurface is inset by authored
	# felt margins and must not make a small desktop look like a phone.
	var composition_changed: bool = layout.compact_desktop != _compact_six_seat_desktop
	_compact_six_seat_desktop = layout.compact_desktop
	var profile_changed: bool = layout.layout_profile != _applied_layout_profile
	var had_applied_profile: bool = _applied_layout_profile != GuiLayoutProfileScript.AUTOMATIC
	_applied_layout_profile = layout.layout_profile
	if profile_changed or composition_changed:
		_refresh_action_controls()
	_configure_center_copy(layout.phone_layout)
	if layout.phone_layout != _phone_seat_widgets and _bound_view != null:
		if not layout.phone_layout:
			_close_phone_overlays()
			if _wager_keypad != null and _wager_keypad.is_bottom_sheet():
				_wager_keypad.cancel()
		_rebuild_seats()
	elif (
		(profile_changed or composition_changed) and had_applied_profile and not layout.phone_layout
	):
		# Compact/tablet styling changes child minimum sizes. Rebuilding the full
		# panels on profile exit prevents those old Container minima from becoming
		# a second geometry owner when desktop bounds are restored.
		_rebuild_seats()
	# Content can be bound while the table is hidden at its authored scene size.
	# Re-resolve viewport-dependent compact/full copy in the same pass that owns
	# its geometry so showing or resizing cannot leave stale status text behind.
	_refresh_seat_status_labels()
	var is_human_turn: bool = _bound_view.acting_seat == _bound_view.hero_seat
	var active_legal: Array = _bound_view.legal_actions if is_human_turn else []
	_action_controls.configure_action_control_copy(
		_bound_view, active_legal, _uses_compact_table_copy(), _resolved_pot_wager_target()
	)
	_action_controls.configure_action_control_visibility(
		_bound_view, active_legal, is_human_turn, layout.phone_layout
	)
	if layout.phone_layout:
		_quit_confirmation.dialog_text = "Quit tournament?"
		_layout_phone_table(layout.surface_size, generation)
		return
	_style_desktop_table(layout)
	_measure_desktop_center(layout)
	if _seat_widgets.is_empty():
		return
	GuiTableSeatLayout.apply(
		layout,
		_bound_view.seats,
		_bound_view.hero_seat,
		_seat_widgets,
		_seat_status_widgets,
		_action_panel.get_combined_minimum_size()
	)
	_finish_desktop_layout(layout)


func _style_desktop_table(layout: GuiTableLayoutPass) -> void:
	_applied_phone_layout_plan = null
	_board_label.show()
	_quit_confirmation.dialog_text = "Do you want to quit the tournament?"
	var desktop_action_margin := _action_controls.margin
	desktop_action_margin.add_theme_constant_override("margin_top", 6)
	desktop_action_margin.add_theme_constant_override("margin_bottom", 6)
	desktop_action_margin.add_theme_constant_override("margin_right", 2)
	_action_controls.restore_phone_action_rows()
	_event_log.show()
	_quit_button.show()
	_phone_more_button.hide()
	for seat: int in _seat_widgets:
		_seat_widgets[seat].show()
		_seat_status_widgets[seat].show()
	_card_slots.add_theme_constant_override(
		"separation", 2 if layout.small_desktop_layout or layout.compact_tablet_layout else 6
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
	(
		GuiMobileTableLayoutScript
		. apply_scale(
			layout.mobile_portrait_layout,
			layout.mobile_content_scale,
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
			layout.seat_content_scale,
			layout.seat_visual_scale,
		)
	)
	var action_margin := _action_controls.margin
	action_margin.add_theme_constant_override("margin_left", 2)
	action_margin.add_theme_constant_override("margin_right", 2)
	action_margin.add_theme_constant_override("margin_top", 2 if layout.small_desktop_layout else 6)
	action_margin.add_theme_constant_override(
		"margin_bottom", 2 if layout.small_desktop_layout else 6
	)
	var action_panel_style := GuiTableStyleScript.box(Color("062516ed"), Color("d9b56d"), 1, 12)
	if layout.small_desktop_layout:
		action_panel_style.content_margin_top = 0.0
		action_panel_style.content_margin_bottom = 0.0
	_action_panel.add_theme_stylebox_override("panel", action_panel_style)
	var action_content := _action_controls.content
	var action_rows := _action_controls.rows
	action_content.add_theme_constant_override(
		"separation", 0 if layout.small_desktop_layout else 2
	)
	action_rows.add_theme_constant_override("separation", 0 if layout.small_desktop_layout else 2)
	if layout.small_desktop_layout or layout.compact_tablet_layout:
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
				if layout.compact_tablet_layout:
					control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 48.0)
		for button: Button in [
			_fold_button, _check_call_button, _min_wager_button, _pot_raise_button
		]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for status_label: Label in _seat_status_widgets.values():
			status_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
			if (
				layout.compact_tablet_layout
				and not layout.portrait_tablet_layout
				and not layout.compact_desktop
			):
				status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
				status_label.max_lines_visible = 1
		for card: Control in _card_slots.get_children():
			GuiMobileTableLayoutScript._scale_card_face(card, Vector2(52.0, 57.0), 22)
	if layout.short_desktop_center_layout:
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
	if layout.compact_tablet_layout or layout.short_desktop_center_layout:
		_pot_zone.custom_minimum_size.y = 42.0
		_wager_zone.custom_minimum_size.y = 42.0
	if _uses_large_chip_values():
		_pot_zone.custom_minimum_size.y = maxf(
			_pot_zone.custom_minimum_size.y,
			(
				(
					ceilf(
						_pot_label.get_theme_font("font").get_height(
							_pot_label.get_theme_font_size("font_size")
						)
					)
					* 2.0
				)
				+ 8.0
			)
		)
		if _uses_numeric_keypad():
			_action_controls.configure_numeric_action_rows()
		else:
			for control: Control in [
				_fold_button,
				_check_call_button,
				_min_wager_button,
				_pot_raise_button,
				_all_in_button,
				_wager_button,
				_wager_input
			]:
				control.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
				control.custom_minimum_size = Vector2(
					maxf(control.custom_minimum_size.x, 48.0), 48.0
				)
		if layout.small_desktop_layout:
			_wager_zone.custom_minimum_size.y = 30.0


func _measure_desktop_center(layout: GuiTableLayoutPass) -> void:
	layout.center_width = clampf(
		layout.surface_size.x * (0.56 if layout.mobile_portrait_layout else 0.48),
		230.0,
		(
			280.0
			if layout.small_desktop_layout
			else (680.0 if layout.mobile_portrait_layout else DESKTOP_CENTER_ZONE_MAX_WIDTH)
		),
	)
	if layout.portrait_tablet_layout:
		layout.center_width = 306.0
	elif layout.compact_tablet_layout:
		var required_side_width: float = maxf(
			_action_panel.get_combined_minimum_size().x,
			_event_log.get_combined_minimum_size().x,
		)
		layout.center_width = minf(
			layout.center_width,
			maxf(230.0, layout.surface_size.x - 2.0 * (required_side_width + 8.0)),
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
	layout.center_size = Vector2(
		layout.center_width,
		maxf(
			(
				184.0
				if layout.small_desktop_layout
				else (
					184.0 * layout.mobile_content_scale if layout.mobile_portrait_layout else 184.0
				)
			),
			center_content_height,
		),
	)
	layout.center_position = (layout.surface_size - layout.center_size) * 0.5
	if layout.portrait_tablet_layout and _uses_large_chip_values():
		var lower_height: float = maxf(125.0, _action_panel.get_combined_minimum_size().y)
		var status_height: float = (
			(
				GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT
				+ GuiMobileTableLayoutScript.STATUS_BAND_GAP
			)
			* _tablet_status_scale()
		)
		layout.center_position.y = minf(
			layout.center_position.y,
			maxf(
				0.0,
				(
					layout.surface_size.y
					- lower_height * 2.0
					- status_height
					- 12.0
					- layout.center_size.y
				)
			)
		)
	if layout.small_desktop_layout:
		# Use the top safety edge so the compact side panels can begin directly
		# after the central stack without entering its bounds.
		layout.center_position.y = 0.0
	_resolved_center_size = layout.center_size
	_resolved_center_position = layout.center_position
	# CenterZone is a manually positioned presentation region. Apply one
	# resolved width after rebuilding all children and never defer an older
	# bounds value past a newer layout pass. Child minimum sizes are deliberately
	# cleared in the same operation so status text cannot widen the stack.
	_apply_center_zone_bounds(layout.center_size, layout.center_position)
	if not layout.compact_desktop:
		call_deferred(
			"_apply_center_zone_bounds_if_current",
			layout.center_size,
			layout.center_position,
			_layout_generation,
		)


func _finish_desktop_layout(layout: GuiTableLayoutPass) -> void:
	(
		GuiMobileTableLayoutScript
		. layout_human_adjacent_panels(
			layout.surface_size,
			layout.compact_layout,
			layout.mobile_content_scale,
			_seat_widgets.get(_bound_view.hero_seat),
			_action_panel,
			_event_log,
			_seat_widgets.size(),
		)
	)
	if layout.full_ring_desktop_layout:
		var reserved_opponent_height: float = layout.full_ring_footprint_height * 3.0 + 4.0
		var side_bottom: float = (
			_seat_widgets[_bound_view.hero_seat].position.y
			+ _seat_widgets[_bound_view.hero_seat].size.y
		)
		var side_height: float = side_bottom - reserved_opponent_height
		_action_panel.position.y = reserved_opponent_height
		_event_log.position.y = reserved_opponent_height
		_action_panel.size.y = side_height
		_event_log.size.y = side_height
	if layout.small_desktop_layout:
		var hero_panel: PanelContainer = _seat_widgets.get(_bound_view.hero_seat)
		hero_panel.position.y = (
			layout.surface_size.y
			- hero_panel.size.y
			- GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT
			- GuiMobileTableLayoutScript.STATUS_BAND_GAP
		)
	elif layout.compact_tablet_layout:
		_layout_compact_tablet_lower_regions(layout.surface_size, layout.center_width)
	if layout.compact_layout:
		for seat: int in _seat_widgets:
			(
				GuiMobileTableLayoutScript
				. layout_seat_status_band(
					_seat_status_widgets[seat],
					_seat_widgets[seat],
					true,
					(
						_tablet_status_scale()
						if layout.compact_tablet_layout
						else (1.0 if layout.small_desktop_layout else layout.seat_visual_scale)
					),
				)
			)
	if not layout.mobile_portrait_layout and not layout.compact_desktop:
		_resolve_status_band_clearance(
			layout.surface_size,
			layout.compact_layout,
			(
				_tablet_status_scale()
				if layout.compact_tablet_layout
				else (1.0 if layout.small_desktop_layout else layout.seat_visual_scale)
			),
		)
	if (
		not layout.mobile_portrait_layout
		and not layout.small_desktop_layout
		and not layout.compact_desktop
	):
		_resolve_seat_panel_intersections(
			layout.compact_layout,
			(
				_tablet_status_scale()
				if layout.compact_tablet_layout
				else (1.0 if layout.small_desktop_layout else layout.seat_visual_scale)
			),
		)
	if not layout.compact_layout:
		# Containers can report a larger minimum after their children resolve.
		# Re-apply the approved compact desktop height after layout so the
		# reserved side regions remain deterministic.
		var desktop_side_height: float = (
			_action_panel.size.y if layout.full_ring_desktop_layout else 180.0
		)
		var desktop_side_bottom: float = (
			_seat_widgets[_bound_view.hero_seat].position.y
			+ _seat_widgets[_bound_view.hero_seat].size.y
		)
		var desktop_side_y: float = (
			layout.full_ring_footprint_height * 3.0 + 4.0
			if layout.full_ring_desktop_layout
			else desktop_side_bottom - desktop_side_height
		)
		_action_panel.size.y = desktop_side_height
		_event_log.size.y = desktop_side_height
		_action_panel.position.y = desktop_side_y
		_event_log.position.y = desktop_side_y
	if layout.compact_desktop:
		var desktop_plan: GuiSixSeatDesktopPlan = _compact_desktop_plan(
			layout.surface_size, layout.center_size
		)
		if desktop_plan == null:
			push_error("Compact six-seat desktop content exceeds its reserved composition.")
			return
		_apply_compact_desktop_plan(desktop_plan)
		layout.center_position = desktop_plan.center_rect.position
		_resolved_center_position = layout.center_position
	layout.center_position = _reserve_desktop_quit_clearance(
		layout.center_position,
		layout.center_size,
		layout.portrait_tablet_layout,
		layout.compact_tablet_layout,
	)
	if not layout.compact_desktop:
		_layout_quit_button(
			layout.center_position,
			layout.center_size,
			layout.portrait_tablet_layout,
			layout.compact_tablet_layout,
		)
	if _wager_keypad != null and _wager_keypad.visible:
		_wager_keypad.refresh_layout(layout.mobile_content_scale)
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
			card, Vector2(38.0, 42.0) if landscape else Vector2(48.0, 54.0), 22
		)
	_card_slots.add_theme_constant_override("separation", 2 if landscape else 5)
	var action_margin := _action_controls.margin
	action_margin.add_theme_constant_override("margin_top", 2 if landscape else 6)
	action_margin.add_theme_constant_override("margin_bottom", 2 if landscape else 6)
	action_margin.add_theme_constant_override("margin_right", 78)
	var action_content := _action_controls.content
	action_content.add_theme_constant_override("separation", 2)
	_phone_hero_summary.add_theme_constant_override("separation", 4)
	_phone_hero_cards.add_theme_constant_override("separation", 2)
	_action_controls.configure_phone_action_rows(landscape)
	var numeric_rows: bool = _phone_numeric_rows_needed(surface_size)
	_layout_phone_opponent_action_badges(landscape, numeric_rows)
	if _phone_more_button.get_parent() != _surface:
		_phone_more_button.reparent(_surface)
	_phone_more_button.show()
	_phone_hero_stack.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_phone_hero_stack.clip_text = true
	_phone_hero_stack.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_phone_hero_stack.custom_minimum_size.x = _phone_action_badge_width(_phone_hero_stack, 0.0, 0.0)
	_phone_hero_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phone_hero_action_badge.clip_text = false
	_phone_hero_action_badge.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_phone_hero_action_badge.custom_minimum_size.x = _phone_action_badge_width(
		_phone_hero_action_badge, 0.0, PHONE_HERO_ACTION_HORIZONTAL_PADDING
	)
	_phone_hero_action_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Preserve exact stack and action text when a large wager exceeds the shared row.
	var summary_width: float = surface_size.x - 106.0
	var hero_required_width: float = (
		_phone_hero_cards.get_combined_minimum_size().x
		+ _phone_action_badge_width(_phone_hero_stack, 0.0, 0.0)
		+ (
			_phone_hero_action_badge.custom_minimum_size.x
			if _phone_hero_action_badge.visible
			else 0.0
		)
		+ 8.0
	)
	if not landscape and _phone_hero_action_badge.visible and hero_required_width > summary_width:
		if not is_instance_valid(_action_controls.numeric_feedback):
			_action_controls.numeric_feedback = HBoxContainer.new()
			_action_controls.numeric_feedback.name = "PhoneNumericFeedback"
			_action_controls.numeric_feedback.add_theme_constant_override("separation", 4)
			action_content.add_child(_action_controls.numeric_feedback)
		_action_controls.numeric_feedback.show()
		_action_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_content.move_child(_action_controls.numeric_feedback, 1)
		_action_status.reparent(_action_controls.numeric_feedback)
		_phone_hero_action_badge.reparent(_action_controls.numeric_feedback)
		if not _bound_view.hand_complete:
			_action_status.text = (
				"Your turn" if _bound_view.acting_seat == _bound_view.hero_seat else "Waiting"
			)

	if (
		numeric_rows
		or (
			_phone_hero_action_badge.visible
			and hero_required_width > summary_width
			and not landscape
		)
	):
		action_margin.add_theme_constant_override("margin_right", 2)
		if not is_instance_valid(_action_controls.more_spacer):
			_action_controls.more_spacer = Control.new()
			_action_controls.more_spacer.name = "PhoneMoreSpacer"
			_action_controls.more_spacer.custom_minimum_size.x = 64.0
			_phone_hero_summary.add_child(_action_controls.more_spacer)
		_action_controls.more_spacer.show()
	_action_status.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	_action_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_action_status.clip_text = true
	_action_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_action_status.max_lines_visible = 1
	if _bound_view.hand_complete and not landscape and _has_phone_hand_summary():
		# Completed rounds use the full status width for all named recipients.
		# Existing card/seat geometry and the More/Pots touch target stay owned
		# by the same phone plan; no overlay obscures the revealed cards.
		action_margin.add_theme_constant_override("margin_right", 2)
		if not is_instance_valid(_action_controls.more_spacer):
			_action_controls.more_spacer = Control.new()
			_action_controls.more_spacer.name = "PhoneMoreSpacer"
			_action_controls.more_spacer.custom_minimum_size.x = 64.0
			_phone_hero_summary.add_child(_action_controls.more_spacer)
		_action_controls.more_spacer.show()
		var panel_style: StyleBox = _action_panel.get_theme_stylebox("panel")
		var result_width: float = (
			surface_size.x
			- panel_style.get_minimum_size().x
			- action_margin.get_theme_constant("margin_left")
			- action_margin.get_theme_constant("margin_right")
			- 4.0
		)
		if _bound_view.tournament_status != &"finished":
			_action_status.text = _phone_hand_result_text(result_width)
		_action_status.max_lines_visible = -1
		_action_status.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		var line_count: int = _action_status.text.count("\n") + 1
		_action_status.custom_minimum_size.y = (
			(
				ceilf(_action_status.get_theme_font("font").get_height(GUI_MINIMUM_FONT_SIZE))
				* line_count
			)
			+ _action_status.get_theme_constant("line_spacing") * maxi(0, line_count - 1)
		)
	for button: Button in [_fold_button, _check_call_button, _wager_button, _all_in_button]:
		button.custom_minimum_size = Vector2(48.0, 48.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	var plan: GuiPhoneLayoutPlan = GuiPhoneLayoutPlanScript.new()
	var detail_minimum_size := Vector2.ZERO
	if is_instance_valid(_overlay_views.detail_overlay):
		detail_minimum_size = _overlay_views.detail_overlay.get_combined_minimum_size()
	if not (
		plan
		. configure(
			surface_size,
			_seat_widgets.size(),
			_action_panel.get_combined_minimum_size(),
			_phone_overflow_menu.get_combined_minimum_size(),
			detail_minimum_size,
			86.0 if numeric_rows else GuiPhoneSeatLayoutScript.PORTRAIT_TOKEN_HEIGHT,
		)
	):
		return
	var phone_status_font_size: int = GUI_MINIMUM_FONT_SIZE
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


func _apply_phone_layout_plan(plan: GuiPhoneLayoutPlan) -> void:
	_apply_center_zone_bounds(plan.center_rect.size, plan.center_rect.position)
	if plan.compact_numeric_center:
		_pot_label.text = "Pot %d" % displayed_pot_amount
		_wager_label.text = "Bet %d" % _current_wager_total()
		_board_zone.size.y = 58.0
		_pot_zone.position = Vector2(0.0, 62.0)
		_pot_zone.custom_minimum_size.y = 34.0
		_pot_zone.size = Vector2(plan.center_rect.size.x * 0.5, 34.0)
		_wager_zone.position = Vector2(plan.center_rect.size.x * 0.5, 62.0)
		_wager_zone.custom_minimum_size.y = 34.0
		_wager_zone.size = _pot_zone.size

	var player_count: int = _seat_widgets.size()
	for seat: int in _seat_widgets:
		var panel := _seat_widgets[seat] as GuiTableSeatView
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


func _apply_phone_layout_if_current(plan: GuiPhoneLayoutPlan, generation: int) -> void:
	if generation != _layout_generation or plan != _applied_phone_layout_plan:
		return
	_apply_phone_layout_plan(plan)


func _compact_desktop_plan(surface_size: Vector2, center_size: Vector2) -> GuiSixSeatDesktopPlan:
	var hero: PanelContainer = _seat_widgets[_bound_view.hero_seat]
	var opponent_minimum := Vector2(160.0, 102.0)
	for seat: int in _seat_widgets:
		if seat != _bound_view.hero_seat:
			opponent_minimum = opponent_minimum.max(_seat_widgets[seat].get_combined_minimum_size())
	var plan := GuiSixSeatDesktopPlanScript.new()
	var side_minimum: Vector2 = _action_panel.get_combined_minimum_size().max(
		_event_log.get_combined_minimum_size()
	)
	if not (
		plan
		. configure(
			surface_size,
			center_size,
			hero.get_combined_minimum_size(),
			side_minimum,
			_quit_button.get_combined_minimum_size().max(Vector2(48.0, 48.0)),
			opponent_minimum,
		)
	):
		return null
	return plan


func _apply_compact_desktop_plan(plan: GuiSixSeatDesktopPlan) -> void:
	for seat: int in _seat_widgets:
		var relative_seat: int = posmod(seat - _bound_view.hero_seat, 6)
		var panel := _seat_widgets[seat] as GuiTableSeatView
		var panel_rect: Rect2 = plan.seat_rects[relative_seat]
		panel.position = panel_rect.position
		panel.size = panel_rect.size
		var status: Label = _seat_status_widgets[seat]
		var status_rect: Rect2 = plan.status_rects[relative_seat]
		status.position = status_rect.position
		status.size = status_rect.size
	_action_panel.position = plan.action_rect.position
	_action_panel.size = plan.action_rect.size
	_event_log.position = plan.event_rect.position
	_event_log.size = plan.event_rect.size
	_quit_button.position = plan.quit_rect.position
	_quit_button.size = plan.quit_rect.size
	_apply_center_zone_bounds(plan.center_rect.size, plan.center_rect.position)


func _layout_compact_tablet_lower_regions(surface_size: Vector2, center_width: float) -> void:
	var hero_panel: PanelContainer = _seat_widgets.get(_bound_view.hero_seat)
	if hero_panel == null:
		push_error("Compact tablet layout requires a human seat panel.")
		return
	var status_reservation: float = (
		(GuiMobileTableLayoutScript.COMPACT_STATUS_BAND_HEIGHT * _tablet_status_scale())
		+ (GuiMobileTableLayoutScript.STATUS_BAND_GAP * _tablet_status_scale())
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
			var panel := _seat_widgets[seat] as GuiTableSeatView
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


func _layout_phone_overlays(plan: GuiPhoneLayoutPlan = _applied_phone_layout_plan) -> void:
	if plan == null:
		_queue_layout()
		return
	_overlay_views.layout(plan)
