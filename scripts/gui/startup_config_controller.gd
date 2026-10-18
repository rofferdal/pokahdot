class_name StartupConfigController
extends Control

const GuiStartupConfigAdapterScript := preload("res://scripts/gui/gui_startup_config_adapter.gd")

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
@onready var _poker_table: Control = $PokerTable


func _ready() -> void:
	startup_adapter = GuiStartupConfigAdapterScript.new(
		load("res://resources/default_tournament_config.tres") as TournamentConfig
	)
	_apply_defaults()
	%StartButton.pressed.connect(_on_start_pressed)


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
				"bind_view",
				startup_adapter.match_instance.get_view_for(0),
				avatar_result.assignments,
			)
		)
		_startup_panel.hide()
		_poker_table.show()
		return
	_render_errors()


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
