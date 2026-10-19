class_name PokerTableController
extends Control
signal tournament_quit_confirmed
signal return_to_startup_requested

const FoldedSeatStyleScript := preload("res://scripts/gui/folded_seat_style.gd")
const CardFaceFactoryScript := preload("res://scripts/gui/card_face_factory.gd")
const GuiActionPacerScript := preload("res://scripts/gui/gui_action_pacer.gd")
const GuiEventFormatterScript := preload("res://scripts/gui/gui_event_formatter.gd")
const GuiMatchProgressInspectorScript := preload(
	"res://scripts/gui/gui_match_progress_inspector.gd"
)
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")
const ShowdownHandFormatterScript := preload("res://scripts/gui/showdown_hand_formatter.gd")
const TableSeatLayoutScript := preload("res://scripts/gui/table_seat_layout.gd")
const TournamentStatusFormatterScript := preload("res://scripts/gui/tournament_status_formatter.gd")
const OPPONENT_AVATAR_SIZE := Vector2(56, 56)
const HERO_AVATAR_SIZE := Vector2(64, 64)
const OPPONENT_CARD_SIZE := Vector2(30, 38)
const GUI_MINIMUM_FONT_SIZE: int = 20
const OPPONENT_CHIP_FONT_SIZE: int = 22
const NORMAL_SEAT_FRAME_WIDTH: int = 1
const HERO_SEAT_FRAME_WIDTH: int = 2
const ACTING_SEAT_FRAME_COLOR := Color.WHITE

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
var _event_texts: Array[String] = []
var _action_pacer = GuiActionPacerScript.new()

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
@onready var _action_panel: PanelContainer = $TableMargin/Felt/TableSurface/ActionPanel
@onready var _action_status: Label = %ActionStatus
@onready var _fold_button: Button = %FoldButton
@onready var _check_call_button: Button = %CheckCallButton
@onready var _min_wager_button: Button = %MinWagerButton
@onready var _half_wager_button: Button = %HalfWagerButton
@onready var _wager_input: LineEdit = %WagerInput
@onready var _wager_button: Button = %WagerButton
@onready var _all_in_button: Button = %AllInButton
@onready var _event_log: RichTextLabel = %EventLog
@onready var _quit_button: Button = %QuitButton
@onready var _quit_confirmation: ConfirmationDialog = %QuitConfirmation


func _ready() -> void:
	_action_pacer.configure(get_tree(), action_timing_config)
	resized.connect(_queue_layout)
	_surface.resized.connect(_queue_layout)
	visibility_changed.connect(_queue_layout)
	_apply_table_styles()
	_fold_button.pressed.connect(_on_fold_pressed)
	_check_call_button.pressed.connect(_on_check_call_pressed)
	_min_wager_button.pressed.connect(_on_min_wager_pressed)
	_half_wager_button.pressed.connect(_on_half_wager_pressed)
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


func is_action_advance_pending() -> bool:
	return _action_pacer.is_waiting()


func submit_wager_total(total: int) -> void:
	if _bound_view == null:
		return
	if PlayerAction.Kind.BET in _bound_view.legal_actions:
		_submit_action(PlayerAction.bet_to(total))
	elif PlayerAction.Kind.RAISE in _bound_view.legal_actions:
		_submit_action(PlayerAction.raise_to(total))


func _refresh_visuals() -> void:
	if not is_node_ready() or _bound_view == null:
		return
	_board_label.text = "Community cards"
	_wager_label.text = "Wagers  •  %d active" % _count_wagers()
	_pot_label.text = "POT  •  %d%s" % [displayed_pot_amount, _pot_layer_text()]
	_rebuild_card_slots()
	_rebuild_seats()
	_refresh_action_controls()
	_enforce_minimum_gui_text_size()
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
		_half_wager_button,
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
				Vector2(30, 38),
				29,
				Color("f5f0dc") if is_face_up else Color("173e58"),
				Color("e7d39b"),
			)
		)
		slot.modulate.a = 1.0 if index < board_card_count else 0.48
		_card_slots.add_child(slot)


func _rebuild_seats() -> void:
	for seat_widget: PanelContainer in _seat_widgets.values():
		seat_widget.queue_free()
	for action_widget: Label in _seat_action_widgets.values():
		action_widget.queue_free()
	for showdown_widget: Label in _seat_showdown_widgets.values():
		showdown_widget.queue_free()
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
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var avatar_path: String = _avatar_assignments.get(player_view.seat, "")
	if not avatar_path.is_empty():
		avatar.texture = load(avatar_path) as Texture2D
	row.add_child(avatar)
	_add_main_pot_winner_star(row, player_view.seat, OPPONENT_AVATAR_SIZE)
	row.add_child(_create_seat_identity(player_view, 20))
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
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var avatar_path: String = _avatar_assignments.get(player_view.seat, "")
	if not avatar_path.is_empty():
		avatar.texture = load(avatar_path) as Texture2D
	header.add_child(avatar)
	_add_main_pot_winner_star(header, player_view.seat, HERO_AVATAR_SIZE)
	header.add_child(_create_seat_identity(player_view, 23))
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
					Vector2(54, 42),
					29,
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
	marker.custom_minimum_size = Vector2(48, 28)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	marker.autowrap_mode = TextServer.AUTOWRAP_OFF
	marker.clip_text = true
	marker.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
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
	action_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
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
	showdown_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
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
			20,
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
	var latest_record: PublicActionRecord = null
	for record: PublicActionRecord in _bound_view.action_history:
		if record.seat == seat:
			latest_record = record
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


func _pot_layer_text() -> String:
	return "" if _bound_view.pots.size() <= 1 else "  •  %d layers" % _bound_view.pots.size()


func _enforce_minimum_gui_text_size() -> void:
	_enforce_minimum_gui_text_size_for_node(self)


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
	var can_wager: bool = PlayerAction.Kind.BET in legal or PlayerAction.Kind.RAISE in legal
	_fold_button.disabled = not (PlayerAction.Kind.FOLD in legal)
	_check_call_button.disabled = not (
		PlayerAction.Kind.CHECK in legal or PlayerAction.Kind.CALL in legal
	)
	_min_wager_button.disabled = not can_wager
	_half_wager_button.disabled = not can_wager
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
	_half_wager_button.text = "Preset %s %d" % [wager_name, _preset_wager_total()]
	_wager_button.text = wager_name
	_all_in_button.text = "All-in"
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


func _preset_wager_total() -> int:
	var minimum: int = _bound_view.minimum_wager_total
	var maximum: int = _bound_view.maximum_wager_total
	return clampi(minimum + (maximum - minimum) / 2, minimum, maximum)


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


func _on_half_wager_pressed() -> void:
	submit_wager_total(_preset_wager_total())


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
	var events: Array[DomainEvent] = _match.get_events()
	if events.is_empty() or events[-1].kind != DomainEvent.Kind.ACTION_APPLIED:
		return
	_schedule_next_action(events[-1].seat)


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
	var action_records: Array[PublicActionRecord] = []
	for record: PublicActionRecord in _bound_view.action_history:
		if record.record_kind == PublicActionRecord.Kind.ACTION:
			action_records.append(record)
	var action_index: int = 0
	var street_transition_index: int = 0
	for event: DomainEvent in events:
		var action_record: PublicActionRecord = null
		if event.kind == DomainEvent.Kind.ACTION_APPLIED and action_index < action_records.size():
			action_record = action_records[action_index]
			action_index += 1
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


func _layout_table() -> void:
	if not is_node_ready():
		return
	var surface_size: Vector2 = _surface.size
	if surface_size.x <= 0.0 or surface_size.y <= 0.0:
		return
	var center_minimum_size: Vector2 = _center_zone.get_combined_minimum_size()
	var center_size := Vector2(
		maxf(clampf(surface_size.x * 0.48, 230.0, 340.0), center_minimum_size.x),
		maxf(184.0, center_minimum_size.y),
	)
	_center_zone.size = center_size
	_center_zone.position = (surface_size - center_size) * 0.5
	if _seat_widgets.is_empty():
		return
	var compact_layout: bool = surface_size.x < 600.0
	var seat_width: float = (
		clampf(surface_size.x * 0.27, 104.0, 140.0)
		if compact_layout
		else clampf(surface_size.x * 0.23, 250.0, 280.0)
	)
	var seat_count: int = _seat_widgets.size()
	for seat: int in _seat_widgets:
		var is_hero: bool = seat == _bound_view.hero_seat
		var seat_size := Vector2(seat_width, 96.0) if is_hero else Vector2(seat_width, 70.0)
		if compact_layout and is_hero:
			seat_size = Vector2(clampf(surface_size.x * 0.56, 190.0, 220.0), 80.0)
		var normalized_position: Vector2 = _normalized_seat_position(
			_visual_slot_for_seat(seat, seat_count), seat_count, is_hero
		)
		var panel: PanelContainer = _seat_widgets[seat]
		_apply_compact_seat_typography(panel, compact_layout, is_hero)
		var minimum_size: Vector2 = panel.get_combined_minimum_size()
		var resolved_seat_size := Vector2(
			maxf(seat_size.x, minimum_size.x), maxf(seat_size.y, minimum_size.y)
		)
		panel.size = resolved_seat_size
		var intended_position: Vector2 = (
			normalized_position * surface_size - resolved_seat_size * 0.5
		)
		panel.position = Vector2(
			clampf(intended_position.x, 0.0, surface_size.x - resolved_seat_size.x),
			clampf(intended_position.y, 0.0, surface_size.y - resolved_seat_size.y),
		)
		_layout_seat_action_label(seat, panel, compact_layout)
		_layout_seat_showdown_label(seat, panel, compact_layout)
	_layout_human_adjacent_panels(surface_size, compact_layout)


func _layout_seat_action_label(seat: int, panel: PanelContainer, compact_layout: bool) -> void:
	var action_label: Label = _seat_action_widgets.get(seat)
	if action_label == null:
		return
	var action_height: float = 20.0 if not compact_layout else 17.0
	action_label.size = Vector2(panel.size.x, action_height)
	action_label.position = Vector2(panel.position.x, panel.position.y + panel.size.y + 2.0)


func _layout_seat_showdown_label(seat: int, panel: PanelContainer, compact_layout: bool) -> void:
	var showdown_label: Label = _seat_showdown_widgets.get(seat)
	if showdown_label == null or not showdown_label.visible:
		return
	var label_height: float = 22.0 if compact_layout else 24.0
	showdown_label.size = Vector2(panel.size.x, label_height)
	showdown_label.position = Vector2(
		panel.position.x, maxf(0.0, panel.position.y - showdown_label.size.y - 2.0)
	)


func _layout_human_adjacent_panels(surface_size: Vector2, compact_layout: bool) -> void:
	var hero_panel: PanelContainer = _seat_widgets.get(_bound_view.hero_seat)
	if hero_panel == null:
		return
	if compact_layout:
		_layout_compact_human_panels(surface_size, hero_panel)
		return
	var action_size := Vector2(clampf(surface_size.x * 0.32, 560.0, 640.0), 104.0)
	action_size = Vector2(
		maxf(action_size.x, _action_panel.get_combined_minimum_size().x),
		maxf(action_size.y, _action_panel.get_combined_minimum_size().y),
	)
	var event_size := Vector2(clampf(surface_size.x * 0.22, 380.0, 440.0), 132.0)
	event_size = Vector2(
		maxf(event_size.x, _event_log.get_combined_minimum_size().x),
		maxf(event_size.y, _event_log.get_combined_minimum_size().y),
	)
	var panel_y: float = minf(
		hero_panel.position.y + hero_panel.size.y - action_size.y,
		surface_size.y - action_size.y - 12.0,
	)
	_action_panel.size = action_size
	_action_panel.position = Vector2(
		minf(
			surface_size.x - action_size.x - 12.0,
			hero_panel.position.x + hero_panel.size.x + 14.0,
		),
		panel_y,
	)
	_event_log.size = event_size
	_event_log.position = Vector2(
		maxf(12.0, hero_panel.position.x - event_size.x - 14.0),
		clampf(
			hero_panel.position.y + hero_panel.size.y - event_size.y,
			12.0,
			surface_size.y - event_size.y - 12.0,
		),
	)


func _layout_compact_human_panels(surface_size: Vector2, hero_panel: PanelContainer) -> void:
	var panel_width: float = surface_size.x - 24.0
	var action_height: float = maxf(150.0, _action_panel.get_combined_minimum_size().y)
	_action_panel.size = Vector2(panel_width, action_height)
	_action_panel.position = Vector2(12.0, maxf(12.0, hero_panel.position.y - action_height - 8.0))
	_event_log.size = Vector2(panel_width, 82.0)
	_event_log.position = Vector2(12.0, maxf(12.0, _action_panel.position.y - 90.0))


func _apply_compact_seat_typography(
	panel: PanelContainer,
	compact_layout: bool,
	is_hero: bool,
) -> void:
	if not compact_layout or is_hero:
		return
	var avatar := panel.find_child("Avatar", true, false) as TextureRect
	if avatar != null:
		avatar.custom_minimum_size = OPPONENT_AVATAR_SIZE
	var name_label := panel.find_child("Name", true, false) as Label
	if name_label != null:
		name_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)
	var marker_label := panel.find_child("Marker", true, false) as Label
	if marker_label != null:
		marker_label.add_theme_font_size_override("font_size", GUI_MINIMUM_FONT_SIZE)


func _visual_slot_for_seat(seat: int, seat_count: int) -> int:
	var bottom_slot: int = seat_count / 2
	var relative_seat: int = posmod(seat - _bound_view.hero_seat, seat_count)
	return posmod(bottom_slot + relative_seat, seat_count)


func _normalized_seat_position(
	visual_slot: int,
	seat_count: int,
	is_hero: bool,
) -> Vector2:
	if is_hero:
		return Vector2(0.5, 0.91)
	return TableSeatLayoutScript.symmetric_positions(seat_count)[visual_slot]


func _queue_layout() -> void:
	if not is_node_ready() or _layout_queued:
		return
	_layout_queued = true
	call_deferred("_apply_queued_layout")


func _apply_queued_layout() -> void:
	_layout_queued = false
	_layout_table()
