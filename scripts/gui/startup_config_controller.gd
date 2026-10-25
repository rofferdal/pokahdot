class_name StartupConfigController
extends Control

const GuiStartupConfigAdapterScript := preload("res://scripts/gui/gui_startup_config_adapter.gd")
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const GuiMobileTableLayoutScript := preload("res://scripts/gui/gui_mobile_table_layout.gd")
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")
const WagerKeypadScript := preload("res://scripts/gui/wager_keypad.gd")
const STARTUP_CHECKBOX_UNCHECKED := preload("res://assets/ui/checkbox_unchecked.svg")
const STARTUP_CHECKBOX_CHECKED := preload("res://assets/ui/checkbox_checked.svg")

const PORTRAIT_ASPECT_RATIO_THRESHOLD := 1.15
const PORTRAIT_FORM_WIDTH_RATIO := 0.84
const DESKTOP_FORM_WIDTH_RATIO := 0.46
const DESKTOP_FORM_MIN_WIDTH := 720.0
const DESKTOP_FORM_MAX_WIDTH := 900.0
const PORTRAIT_FONT_SCALE := 2.0
const COMPACT_FONT_SCALE := 0.625
const COMPACT_LANDSCAPE_MAX_WIDTH := 1300.0
const COMPACT_LANDSCAPE_MAX_HEIGHT := 800.0
const DEFAULT_FORM_FONT_SIZE := 32
const DEFAULT_TITLE_FONT_SIZE := 64
const STARTUP_TOUCH_TARGET_HEIGHT := 64.0
const PHONE_MAX_PLAYER_COUNT := 7
const PHONE_PLAYER_COUNT_ERROR := (
	"Phone layouts support 2–7 players. " + "Enlarge the window to start with 8 or 9."
)
const STARTUP_DESCRIPTION := (
	"Strategic models are used by default. Enable legacy heuristic models below "
	+ "to include them."
)

## Binds the startup controls to the GUI configuration adapter.

var startup_adapter
var _number_keypad: WagerKeypad
var _layout_profile_override: int = GuiLayoutProfileScript.AUTOMATIC
var _guidance_field_parent: VBoxContainer

@onready var _player_count_input: LineEdit = %PlayerCountInput
@onready var _title: Label = %Title
@onready var _description: Label = %Description
@onready var _player_count_label: Label = %PlayerCountLabel
@onready var _starting_stack_label: Label = %StartingStackLabel
@onready var _small_blind_label: Label = %SmallBlindLabel
@onready var _big_blind_label: Label = %BigBlindLabel
@onready var _starting_stack_input: LineEdit = %StartingStackInput
@onready var _small_blind_input: LineEdit = %SmallBlindInput
@onready var _big_blind_input: LineEdit = %BigBlindInput
@onready var _use_legacy_models_checkbox: CheckBox = %UseLegacyModelsCheckBox
@onready var _player_count_error: Label = %PlayerCountError
@onready var _phone_player_count_guidance: Label = %PhonePlayerCountGuidance
@onready var _starting_stack_error: Label = %StartingStackError
@onready var _small_blind_error: Label = %SmallBlindError
@onready var _big_blind_error: Label = %BigBlindError
@onready var _form_status: Label = %FormStatus
@onready var _start_button: Button = %StartButton
@onready var _startup_panel: CenterContainer = $Center
@onready var _startup_form_panel: PanelContainer = %Panel
@onready var _startup_form: VBoxContainer = %Form
@onready var _startup_fields: GridContainer = %Fields
@onready var _poker_table: Control = $PokerTable
@onready var _quit_application_button: Button = %QuitApplicationButton


func _ready() -> void:
	_guidance_field_parent = _phone_player_count_guidance.get_parent() as VBoxContainer
	startup_adapter = GuiStartupConfigAdapterScript.new(
		load("res://resources/default_tournament_config.tres") as TournamentConfig
	)
	_configure_numeric_inputs_for_mobile()
	_configure_startup_control_visuals()
	_number_keypad = WagerKeypadScript.new()
	_number_keypad.name = "StartupNumberKeypad"
	add_child(_number_keypad)
	_apply_defaults()
	%StartButton.pressed.connect(_on_start_pressed)
	_poker_table.tournament_quit_confirmed.connect(_on_tournament_quit_confirmed)
	_poker_table.return_to_startup_requested.connect(_on_return_to_startup_requested)
	_quit_application_button.pressed.connect(_on_quit_application_pressed)
	resized.connect(_refresh_startup_layout)
	call_deferred("_refresh_startup_layout")


func _on_start_pressed() -> void:
	startup_adapter.player_count_text = _player_count_input.text
	startup_adapter.starting_stack_text = _starting_stack_input.text
	startup_adapter.small_blind_text = _small_blind_input.text
	startup_adapter.big_blind_text = _big_blind_input.text
	startup_adapter.use_legacy_models = _use_legacy_models_checkbox.button_pressed
	if not _phone_player_count_is_valid():
		startup_adapter.field_errors.clear()
		startup_adapter.field_errors[&"player_count"] = PHONE_PLAYER_COUNT_ERROR
		_render_errors()
		return
	if startup_adapter.try_start():
		_clear_errors()
		(
			_poker_table
			. call(
				"bind_match",
				startup_adapter.match_instance,
				0,
				startup_adapter.avatar_assignments,
				startup_adapter.name_assignments,
			)
		)
		_startup_panel.hide()
		_poker_table.show()
		return
	_render_errors()


func _on_tournament_quit_confirmed() -> void:
	_return_to_startup("Tournament ended: player quit.")


func _on_return_to_startup_requested() -> void:
	_return_to_startup("Tournament complete.")


func _return_to_startup(status_message: String) -> void:
	_poker_table.hide()
	startup_adapter.reset_to_defaults()
	_apply_defaults()
	_startup_panel.show()
	_form_status.text = status_message
	_set_error_visibility()


func _on_quit_application_pressed() -> void:
	get_tree().quit()


func _refresh_startup_layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var layout_profile: int = GuiLayoutProfileScript.classify(size, _layout_profile_override)
	var phone_layout: bool = GuiLayoutProfileScript.is_phone(layout_profile)
	var is_portrait: bool = size.y / size.x >= PORTRAIT_ASPECT_RATIO_THRESHOLD
	var full_width_guidance: bool = phone_layout and is_portrait
	var guidance_parent: Node = _startup_form if full_width_guidance else _guidance_field_parent
	if _phone_player_count_guidance.get_parent() != guidance_parent:
		_phone_player_count_guidance.reparent(guidance_parent)
	if full_width_guidance:
		_startup_form.move_child(_phone_player_count_guidance, _startup_fields.get_index() + 1)
	_phone_player_count_guidance.visible = phone_layout and is_portrait
	_phone_player_count_guidance.text = "Phone supports 2–7 players; 4 recommended. Default: 6."
	_phone_player_count_guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.visible = not (phone_layout and not is_portrait)
	_title.text = "Poker" if phone_layout else "Start a tournament"
	_description.visible = not phone_layout or not is_portrait
	_description.text = (
		"Phone supports 2–7 players; 4 recommended. Default: 6."
		if phone_layout
		else STARTUP_DESCRIPTION
	)
	_use_legacy_models_checkbox.text = (
		"Use legacy bots" if phone_layout else "Use legacy heuristic models"
	)
	_player_count_label.text = "Players (2–7)" if phone_layout else "Participants (2–9)"
	_starting_stack_label.text = "Stack" if phone_layout else "Starting stack"
	_small_blind_label.text = "Small blind"
	_big_blind_label.text = "Big blind"
	_start_button.text = "Start" if phone_layout else "Start tournament"
	_quit_application_button.text = "Quit" if phone_layout else "Quit game"
	var is_compact_landscape: bool = (
		not is_portrait
		and size.x < COMPACT_LANDSCAPE_MAX_WIDTH
		and size.y <= COMPACT_LANDSCAPE_MAX_HEIGHT
	)
	var is_compact_portrait: bool = is_portrait and (size.x < 960.0 or size.y < 1200.0)
	var compact_form: bool = is_compact_landscape or is_compact_portrait
	var form_margin := _startup_form_panel.get_node("Margin") as MarginContainer
	var compact_margin: int = 8 if phone_layout else (14 if compact_form else 28)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		form_margin.add_theme_constant_override(side, compact_margin)
	_startup_form.add_theme_constant_override("separation", 8 if compact_form else 18)
	_startup_fields.add_theme_constant_override("v_separation", 6 if compact_form else 10)
	_startup_fields.columns = (
		(2 if is_portrait else 4) if phone_layout else (1 if is_portrait else 2)
	)
	_startup_fields.add_theme_constant_override("h_separation", 6 if phone_layout else 24)
	if is_compact_landscape:
		_startup_form_panel.custom_minimum_size.x = (
			size.x * (0.94 if phone_layout else PORTRAIT_FORM_WIDTH_RATIO)
		)
		_set_startup_form_font_sizes(COMPACT_FONT_SCALE)
	elif is_portrait:
		_startup_form_panel.custom_minimum_size.x = (
			size.x * (0.94 if phone_layout else PORTRAIT_FORM_WIDTH_RATIO)
		)
		var portrait_scale: float = (
			COMPACT_FONT_SCALE
			if is_compact_portrait
			else clampf(minf(size.x / 960.0, size.y / 1920.0), 1.0, PORTRAIT_FONT_SCALE)
		)
		_set_startup_form_font_sizes(portrait_scale)
	else:
		_startup_form_panel.custom_minimum_size.x = clampf(
			size.x * DESKTOP_FORM_WIDTH_RATIO,
			DESKTOP_FORM_MIN_WIDTH,
			DESKTOP_FORM_MAX_WIDTH,
		)
		_set_startup_form_font_sizes(1.0)
	if _number_keypad != null and _number_keypad.visible:
		_number_keypad.refresh_layout(GuiMobileTableLayoutScript.content_scale(size))


## Supplies explicit device evidence to presentation tests and platform adapters.
func set_layout_profile_override(profile_override: int) -> void:
	if _layout_profile_override == profile_override:
		return
	_layout_profile_override = profile_override
	if is_node_ready():
		_refresh_startup_layout()


func _phone_player_count_is_valid() -> bool:
	var layout_profile: int = GuiLayoutProfileScript.classify(size, _layout_profile_override)
	if not GuiLayoutProfileScript.is_phone(layout_profile):
		return true
	var candidate: String = _player_count_input.text.strip_edges()
	if candidate.is_empty() or not candidate.is_valid_int():
		return true
	return candidate.to_int() <= PHONE_MAX_PLAYER_COUNT


func _set_startup_form_font_sizes(scale_factor: float) -> void:
	_set_startup_control_font_sizes(_startup_form, scale_factor)


func _set_startup_control_font_sizes(node: Node, scale_factor: float) -> void:
	if node is Control:
		var control := node as Control
		var default_font_size := (
			DEFAULT_TITLE_FONT_SIZE if control.name == &"Title" else DEFAULT_FORM_FONT_SIZE
		)
		control.add_theme_font_size_override(&"font_size", roundi(default_font_size * scale_factor))
		if control is LineEdit or control is Button or control is CheckBox:
			control.custom_minimum_size.y = maxf(48.0, STARTUP_TOUCH_TARGET_HEIGHT * scale_factor)
	for child: Node in node.get_children():
		_set_startup_control_font_sizes(child, scale_factor)


func _configure_numeric_inputs_for_mobile() -> void:
	for input: LineEdit in [
		_player_count_input,
		_starting_stack_input,
		_small_blind_input,
		_big_blind_input,
	]:
		# Use the same in-canvas keypad as the table to preserve the Web viewport.
		input.virtual_keyboard_enabled = false
		input.virtual_keyboard_show_on_focus = false
		input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		input.gui_input.connect(_on_numeric_input_gui_input.bind(input))
		input.text_submitted.connect(_on_numeric_input_submitted)


func _configure_startup_control_visuals() -> void:
	for input: LineEdit in [
		_player_count_input,
		_starting_stack_input,
		_small_blind_input,
		_big_blind_input,
	]:
		input.add_theme_stylebox_override(
			"normal", GuiTableStyleScript.box(Color("102d21"), Color("75c99a"), 2, 6)
		)
		input.add_theme_stylebox_override(
			"focus", GuiTableStyleScript.box(Color("1b4933"), Color("e7d39b"), 3, 6)
		)
		input.add_theme_stylebox_override(
			"read_only", GuiTableStyleScript.box(Color("0a1711"), Color("557665"), 2, 6)
		)
	for button: Button in [%StartButton, _quit_application_button]:
		button.add_theme_stylebox_override(
			"normal", GuiTableStyleScript.action_control_box(Color("102d21"), Color("75c99a"), 2)
		)
		button.add_theme_stylebox_override(
			"hover", GuiTableStyleScript.action_control_box(Color("1b4933"), Color("e7d39b"), 2)
		)
		button.add_theme_stylebox_override(
			"pressed", GuiTableStyleScript.action_control_box(Color("0b1d15"), Color("d9b56d"), 2)
		)
		button.add_theme_stylebox_override(
			"focus", GuiTableStyleScript.action_control_box(Color("102d21"), Color("e7d39b"), 2)
		)
		button.add_theme_stylebox_override(
			"disabled", GuiTableStyleScript.action_control_box(Color("0a1711"), Color("385443"), 2)
		)
		button.add_theme_color_override("font_disabled_color", Color("7e8a83"))
	_use_legacy_models_checkbox.add_theme_icon_override("unchecked", STARTUP_CHECKBOX_UNCHECKED)
	_use_legacy_models_checkbox.add_theme_icon_override("checked", STARTUP_CHECKBOX_CHECKED)
	_use_legacy_models_checkbox.add_theme_icon_override(
		"unchecked_disabled", STARTUP_CHECKBOX_UNCHECKED
	)
	_use_legacy_models_checkbox.add_theme_icon_override(
		"checked_disabled", STARTUP_CHECKBOX_CHECKED
	)
	_use_legacy_models_checkbox.add_theme_constant_override("h_separation", 12)


func show_numeric_keypad(input: LineEdit) -> void:
	if input == null or _number_keypad == null:
		return
	_number_keypad.open_number(input, GuiMobileTableLayoutScript.content_scale(size))


func _on_numeric_input_gui_input(event: InputEvent, input: LineEdit) -> void:
	if event is InputEventScreenTouch and event.pressed:
		show_numeric_keypad(input)
		accept_event()
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and _number_keypad.visible
	):
		# Pointer focus signals a transition back to ordinary LineEdit editing.
		# Cancel the touch draft and let Godot deliver the click to the field.
		_number_keypad.cancel()


func _on_numeric_input_submitted(_submitted_text: String) -> void:
	_on_start_pressed()


func _apply_defaults() -> void:
	_player_count_input.text = startup_adapter.player_count_text
	_starting_stack_input.text = startup_adapter.starting_stack_text
	_small_blind_input.text = startup_adapter.small_blind_text
	_big_blind_input.text = startup_adapter.big_blind_text
	_use_legacy_models_checkbox.button_pressed = startup_adapter.use_legacy_models
	_clear_errors()


func _clear_errors() -> void:
	_player_count_error.text = ""
	_starting_stack_error.text = ""
	_small_blind_error.text = ""
	_big_blind_error.text = ""
	_form_status.text = ""
	_set_error_visibility()


func _render_errors() -> void:
	_player_count_error.text = startup_adapter.error_for(&"player_count")
	_starting_stack_error.text = startup_adapter.error_for(&"starting_stack")
	_small_blind_error.text = startup_adapter.error_for(&"small_blind")
	_big_blind_error.text = startup_adapter.error_for(&"big_blind")
	_form_status.text = startup_adapter.error_for(&"form")
	_set_error_visibility()


func _set_error_visibility() -> void:
	for error_label: Label in [
		_player_count_error,
		_starting_stack_error,
		_small_blind_error,
		_big_blind_error,
	]:
		error_label.visible = not error_label.text.is_empty()
	_form_status.visible = not _form_status.text.is_empty()
