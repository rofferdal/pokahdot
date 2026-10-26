class_name GuiStartupConfigAdapter
extends RefCounted

const GuiMatchFactoryScript := preload("res://scripts/gui/gui_match_factory.gd")
const GuiMatchCreationResultScript := preload("res://scripts/gui/gui_match_creation_result.gd")

## Presentation adapter for the GUI startup form.
##
## It accepts editable text, exposes field-specific feedback, and constructs a
## match only after ConfigResolver has produced an immutable configuration.

var player_count_text: String
var starting_stack_text: String
var small_blind_text: String
var big_blind_text: String
var use_legacy_models: bool = false
var field_errors: Dictionary[StringName, String] = {}
var resolved_config: ResolvedTournamentConfig
var match_instance: TournamentMatch
var start_result: StepResult
var name_assignments: Dictionary[int, String]:
	get:
		return _name_assignments.duplicate()
var avatar_assignments: Dictionary[int, String]:
	get:
		return _avatar_assignments.duplicate()
var effective_seed: int:
	get:
		return _effective_seed

var _defaults: TournamentConfig
var _match_factory
var _name_assignments: Dictionary[int, String] = {}
var _avatar_assignments: Dictionary[int, String] = {}
var _effective_seed: int = 0


func _init(
	defaults: TournamentConfig = null,
	match_factory = null,
) -> void:
	if defaults == null:
		_defaults = TournamentConfig.new()
	else:
		_defaults = defaults.duplicate(true) as TournamentConfig
	_match_factory = GuiMatchFactoryScript.new() if match_factory == null else match_factory
	reset_to_defaults()


func reset_to_defaults() -> void:
	player_count_text = str(_defaults.player_count)
	starting_stack_text = str(_defaults.starting_stack)
	small_blind_text = str(_defaults.small_blind)
	big_blind_text = str(_defaults.big_blind)
	use_legacy_models = false
	field_errors.clear()
	resolved_config = null
	match_instance = null
	start_result = null
	_name_assignments.clear()
	_avatar_assignments.clear()
	_effective_seed = 0


func try_start() -> bool:
	field_errors.clear()
	resolved_config = null
	match_instance = null
	start_result = null
	_name_assignments.clear()
	_avatar_assignments.clear()
	_effective_seed = 0
	var overrides := StartupOverrides.new()
	var player_count := _parse_integer(player_count_text, &"player_count", "Player count")
	var starting_stack := _parse_integer(starting_stack_text, &"starting_stack", "Starting stack")
	var small_blind := _parse_integer(small_blind_text, &"small_blind", "Small blind")
	var big_blind := _parse_integer(big_blind_text, &"big_blind", "Big blind")
	if not field_errors.is_empty():
		return false

	overrides.set_player_count(player_count)
	overrides.set_starting_stack(starting_stack)
	overrides.set_small_blind(small_blind)
	overrides.set_big_blind(big_blind)
	overrides.set_use_legacy_models(use_legacy_models)
	var resolution: ConfigResolution = ConfigResolver.new().resolve(_defaults, overrides)
	if not resolution.is_ok():
		for error: ConfigError in resolution.get_errors():
			field_errors[error.field] = error.message
		return false

	resolved_config = resolution.get_config()
	var creation: GuiMatchCreationResultScript = _match_factory.create(resolved_config)
	if not creation.is_ok():
		field_errors[&"form"] = creation.error_message
		resolved_config = null
		return false
	match_instance = creation.match_instance
	_name_assignments = creation.name_assignments
	_avatar_assignments = creation.avatar_assignments
	_effective_seed = creation.effective_seed
	start_result = match_instance.start(1)
	if start_result.status == StepResult.Status.ERROR:
		field_errors[&"form"] = start_result.message
		match_instance = null
		resolved_config = null
		_name_assignments.clear()
		_avatar_assignments.clear()
		_effective_seed = 0
		return false
	return true


func error_for(field: StringName) -> String:
	return field_errors.get(field, "")


func _parse_integer(value: String, field: StringName, label: String) -> int:
	var trimmed: String = value.strip_edges()
	if not IntegerBounds.fits_signed_64_bit_text(trimmed):
		field_errors[field] = "%s must be a whole number." % label
		return 0
	return trimmed.to_int()
