class_name StartupConfigController
extends Control

const GuiStartupConfigAdapterScript := preload("res://scripts/gui/gui_startup_config_adapter.gd")

const PORTRAIT_ASPECT_RATIO_THRESHOLD := 1.15
const PORTRAIT_FORM_WIDTH_RATIO := 0.84
const PORTRAIT_FONT_SCALE := 1.6
const DEFAULT_FORM_FONT_SIZE := 29
const DEFAULT_TITLE_FONT_SIZE := 50

## Binds the startup controls to the GUI configuration adapter.

var startup_adapter
var _avatar_assignment_service := AvatarAssignmentService.new()

@onready var _player_count_input: LineEdit = %PlayerCountInput
@onready var _starting_stack_input: LineEdit = %StartingStackInput
@onready var _small_blind_input: LineEdit = %SmallBlindInput
@onready var _big_blind_input: LineEdit = %BigBlindInput
@onready var _player_count_error: Label = %PlayerCountError
@onready var _starting_stack_error: Label = %StartingStackError
@onready var _small_blind_error: Label = %SmallBlindError
@onready var _big_blind_error: Label = %BigBlindError
@onready var _form_status: Label = %FormStatus
@onready var _startup_panel: CenterContainer = $Center
@onready var _startup_form_panel: PanelContainer = %Panel
@onready var _startup_form: VBoxContainer = %Form
@onready var _poker_table: Control = $PokerTable
@onready var _quit_application_button: Button = %QuitApplicationButton


func _ready() -> void:
	startup_adapter = GuiStartupConfigAdapterScript.new(
		load("res://resources/default_tournament_config.tres") as TournamentConfig
	)
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
	if startup_adapter.try_start():
		var avatar_result = (
			_avatar_assignment_service
			. assign_for_tournament(
				startup_adapter.resolved_config.player_count,
				startup_adapter.resolved_config.rng_seed,
			)
		)
		if not avatar_result.is_ok():
			startup_adapter.match_instance.request_quit()
			startup_adapter.field_errors[&"form"] = avatar_result.error_message
			_render_errors()
			return
		_clear_errors()
		(
			_poker_table
			. call(
				"bind_match",
				startup_adapter.match_instance,
				0,
				avatar_result.assignments,
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
	_startup_panel.show()
	_form_status.text = status_message


func _on_quit_application_pressed() -> void:
	get_tree().quit()


func _refresh_startup_layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var is_portrait: bool = size.y / size.x >= PORTRAIT_ASPECT_RATIO_THRESHOLD
	if is_portrait:
		_startup_form_panel.custom_minimum_size.x = size.x * PORTRAIT_FORM_WIDTH_RATIO
		_set_startup_form_font_sizes(PORTRAIT_FONT_SCALE)
		return
	_startup_form_panel.custom_minimum_size.x = 0.0
	_set_startup_form_font_sizes(1.0)


func _set_startup_form_font_sizes(scale_factor: float) -> void:
	for child: Node in _startup_form.get_children():
		if not child is Control:
			continue
		var control := child as Control
		var default_font_size := DEFAULT_FORM_FONT_SIZE
		if control.name == &"Title":
			default_font_size = DEFAULT_TITLE_FONT_SIZE
		control.add_theme_font_size_override(&"font_size", roundi(default_font_size * scale_factor))


func _apply_defaults() -> void:
	_player_count_input.text = startup_adapter.player_count_text
	_starting_stack_input.text = startup_adapter.starting_stack_text
	_small_blind_input.text = startup_adapter.small_blind_text
	_big_blind_input.text = startup_adapter.big_blind_text
	_clear_errors()


func _clear_errors() -> void:
	_player_count_error.text = ""
	_starting_stack_error.text = ""
	_small_blind_error.text = ""
	_big_blind_error.text = ""
	_form_status.text = ""


func _render_errors() -> void:
	_player_count_error.text = startup_adapter.error_for(&"player_count")
	_starting_stack_error.text = startup_adapter.error_for(&"starting_stack")
	_small_blind_error.text = startup_adapter.error_for(&"small_blind")
	_big_blind_error.text = startup_adapter.error_for(&"big_blind")
	_form_status.text = startup_adapter.error_for(&"form")
