class_name StartupConfigController
extends Control

const GuiStartupConfigAdapterScript := preload("res://scripts/gui/gui_startup_config_adapter.gd")

const PHONE_MAX_PLAYER_COUNT := 7
const PHONE_PLAYER_COUNT_ERROR := (
	"Phone layouts support 2–7 players. " + "Enlarge the window to start with 8 or 9."
)

## Binds the startup controls to the GUI configuration adapter.

var startup_adapter
var _number_input: LineEdit
var _layout_mode_override: int = GuiSizeClass.AUTOMATIC
var _startup_layout: GuiStartupLayout

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
@onready var _brand_logo: TextureRect = %BrandLogo
@onready var _background: ColorRect = $Background
@onready var _startup_form_panel: PanelContainer = %Panel
@onready var _startup_form: VBoxContainer = %Form
@onready var _startup_fields: GridContainer = %Fields
@onready var _poker_table: Control = $PokerTable
@onready var _quit_application_button: Button = %QuitApplicationButton
@onready var _viewport_adapter: GuiViewportAdapter = $ViewportAdapter
@onready var _startup_overlay: GuiOverlayHost = $StartupOverlay


## Instantiate the table before child readiness and bindings.
func _enter_tree() -> void:
	if has_node("PokerTable"):
		return
	var scene := load("res://scenes/gui/ReplacementPokerTable.tscn") as PackedScene
	assert(scene != null, "The table scene must be available.")
	var table := scene.instantiate() as Control
	assert(table != null, "The selected table scene must be a Control.")
	table.name = "PokerTable"
	table.hide()
	add_child(table)


func get_table_controller() -> Control:
	return get_node_or_null("PokerTable") as Control


## The active table delegates to its own public semantic measurement contract.
func get_layout_snapshot() -> GuiLayoutSnapshot:
	if not is_node_ready():
		return GuiLayoutSnapshot.new()
	if _poker_table.is_visible_in_tree():
		var table_snapshot: GuiLayoutSnapshot = (
			_poker_table.call("get_layout_snapshot") as GuiLayoutSnapshot
		)
		table_snapshot.pending = table_snapshot.pending or _viewport_adapter.is_pending()
		table_snapshot.ready = (
			table_snapshot.ready
			and _viewport_adapter.get_geometry().valid
			and not table_snapshot.pending
		)
		return table_snapshot
	var controls: Dictionary[StringName, Control] = {
		&"title": _title,
		&"description": _description,
		&"form": _startup_form_panel,
		&"player_count": _player_count_input,
		&"starting_stack": _starting_stack_input,
		&"small_blind": _small_blind_input,
		&"big_blind": _big_blind_input,
		&"player_count_label": _player_count_label,
		&"starting_stack_label": _starting_stack_label,
		&"small_blind_label": _small_blind_label,
		&"big_blind_label": _big_blind_label,
		&"legacy_models": _use_legacy_models_checkbox,
		&"player_count_error": _player_count_error,
		&"starting_stack_error": _starting_stack_error,
		&"small_blind_error": _small_blind_error,
		&"big_blind_error": _big_blind_error,
		&"guidance": _phone_player_count_guidance,
		&"status": _form_status,
		&"start": _start_button,
		&"quit": _quit_application_button,
	}
	var snapshot := GuiStartupSnapshotProducer.capture(
		self, _startup_panel, controls, _startup_overlay
	)
	snapshot.profile = GuiSnapshotMeasurement.profile_for_mode(
		GuiSizeClass.classify(_usable_size(), _layout_mode_override).mode
	)
	var geometry: GuiViewportGeometry = _viewport_adapter.get_geometry()
	snapshot.usable_rect = get_global_transform_with_canvas() * geometry.usable_rect
	snapshot.pending = _viewport_adapter.is_pending()
	snapshot.ready = snapshot.ready and geometry.valid and not snapshot.pending
	return snapshot


func get_viewport_adapter() -> GuiViewportAdapter:
	return _viewport_adapter


func _ready() -> void:
	_startup_layout = GuiStartupLayout.new(self)
	startup_adapter = GuiStartupConfigAdapterScript.new(
		load("res://resources/default_tournament_config.tres") as TournamentConfig
	)
	_configure_numeric_inputs_for_mobile()
	_startup_overlay.number_committed.connect(_on_startup_number_committed)
	_startup_overlay.number_cancelled.connect(_on_startup_number_cancelled)
	_apply_defaults()
	%StartButton.pressed.connect(_on_start_pressed)
	_poker_table.tournament_quit_confirmed.connect(_on_tournament_quit_confirmed)
	_poker_table.return_to_startup_requested.connect(_on_return_to_startup_requested)
	_poker_table.visibility_changed.connect(_refresh_startup_layout)
	_quit_application_button.pressed.connect(_on_quit_application_pressed)
	resized.connect(_refresh_startup_layout)
	_viewport_adapter.geometry_changed.connect(_on_viewport_geometry_changed)
	_viewport_adapter.bind(self, _startup_panel, _poker_table)
	call_deferred("_refresh_startup_layout")


func _usable_size() -> Vector2:
	if _viewport_adapter != null and _viewport_adapter.get_geometry().valid:
		return _viewport_adapter.get_geometry().usable_rect.size
	return size


func _on_viewport_geometry_changed(geometry: GuiViewportGeometry) -> void:
	if not geometry.valid:
		return
	_startup_overlay.set_usable_rect(geometry.usable_rect)
	_refresh_startup_layout()


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
		if GuiSizeClass.classify(_usable_size(), _layout_mode_override).is_phone():
			GuiBrowserFullscreen.request()
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
	if _startup_layout == null:
		return
	var available: Vector2 = _usable_size()
	_startup_layout.apply(
		available, GuiSizeClass.classify(available, _layout_mode_override), _poker_table.visible
	)


## Supplies explicit device evidence to presentation tests and platform adapters.
func set_layout_profile_override(profile_override: int) -> void:
	# Translate existing fixture profiles to the unified layout modes.
	var modes: Dictionary[int, int] = {
		0: GuiSizeClass.LayoutMode.PHONE,
		1: GuiSizeClass.LayoutMode.PHONE_LANDSCAPE,
		2: GuiSizeClass.LayoutMode.WIDE_COMPACT,
		3: GuiSizeClass.LayoutMode.WIDE_COMPACT,
		4: GuiSizeClass.LayoutMode.WIDE,
	}
	var mode: int = modes.get(profile_override, GuiSizeClass.AUTOMATIC)
	if _layout_mode_override == mode:
		return
	_layout_mode_override = mode
	if is_node_ready():
		_refresh_startup_layout()


func _phone_player_count_is_valid() -> bool:
	var size_class: GuiSizeClass = GuiSizeClass.classify(_usable_size(), _layout_mode_override)
	if not size_class.is_phone():
		return true
	var candidate: String = _player_count_input.text.strip_edges()
	if candidate.is_empty() or not candidate.is_valid_int():
		return true
	return candidate.to_int() <= PHONE_MAX_PLAYER_COUNT


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
	_player_count_input.max_length = 1
	for input: LineEdit in [_starting_stack_input, _small_blind_input, _big_blind_input]:
		input.max_length = 7


func show_numeric_keypad(input: LineEdit) -> void:
	if input == null:
		return
	var geometry: GuiViewportGeometry = _viewport_adapter.get_geometry()
	if geometry.valid:
		_startup_overlay.set_usable_rect(geometry.usable_rect)
	_number_input = input
	var model := NumberEntryViewModel.new()
	model.title = "Enter number"
	model.value = input.text
	model.minimum = 0
	model.maximum = (
		ConfigResolver.MAX_PLAYER_COUNT
		if input == _player_count_input
		else ConfigResolver.MAX_STARTUP_CHIPS
	)
	_startup_overlay.set_fallback_focus(input)
	_startup_overlay.open_number(model)


func _on_startup_number_committed(value: String) -> void:
	if is_instance_valid(_number_input):
		_number_input.text = value
	_number_input = null


func _on_startup_number_cancelled() -> void:
	_number_input = null


func _on_numeric_input_gui_input(event: InputEvent, input: LineEdit) -> void:
	if event is InputEventScreenTouch and event.pressed:
		show_numeric_keypad(input)
		accept_event()
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and _startup_overlay.is_active()
	):
		# Pointer focus signals a transition back to ordinary LineEdit editing.
		# Cancel the touch draft and let Godot deliver the click to the field.
		_startup_overlay.close()


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
