class_name GuiStartupLayout
extends RefCounted

## Owns responsive startup presentation; configuration and actions remain in Main.

const PORTRAIT_FORM_WIDTH_RATIO := 0.84
const DESKTOP_FORM_WIDTH_RATIO := 0.46
const DESKTOP_FORM_MIN_WIDTH := 720.0
const DESKTOP_FORM_MAX_WIDTH := 900.0
const PORTRAIT_TARGET_SCALE := 2.0
const COMPACT_TARGET_SCALE := 0.625
const STARTUP_TOUCH_TARGET_HEIGHT := 64.0
const STARTUP_DESCRIPTION := (
	"Strategic models are used by default. Enable legacy heuristic models below "
	+ "to include them."
)

var _player_count_input: LineEdit
var _title: Label
var _description: Label
var _player_count_label: Label
var _starting_stack_label: Label
var _small_blind_label: Label
var _big_blind_label: Label
var _starting_stack_input: LineEdit
var _small_blind_input: LineEdit
var _big_blind_input: LineEdit
var _use_legacy_models_checkbox: CheckBox
var _player_count_error: Label
var _phone_player_count_guidance: Label
var _starting_stack_error: Label
var _small_blind_error: Label
var _big_blind_error: Label
var _form_status: Label
var _rules_button: Button
var _start_button: Button
var _startup_panel: CenterContainer
var _brand_logo: TextureRect
var _background: ColorRect
var _startup_form_panel: PanelContainer
var _startup_form: VBoxContainer
var _startup_fields: GridContainer
var _quit_application_button: Button


func _init(root: Control) -> void:
	_player_count_input = root.get_node("%PlayerCountInput") as LineEdit
	_title = root.get_node("%Title") as Label
	_description = root.get_node("%Description") as Label
	_player_count_label = root.get_node("%PlayerCountLabel") as Label
	_starting_stack_label = root.get_node("%StartingStackLabel") as Label
	_small_blind_label = root.get_node("%SmallBlindLabel") as Label
	_big_blind_label = root.get_node("%BigBlindLabel") as Label
	_starting_stack_input = root.get_node("%StartingStackInput") as LineEdit
	_small_blind_input = root.get_node("%SmallBlindInput") as LineEdit
	_big_blind_input = root.get_node("%BigBlindInput") as LineEdit
	_use_legacy_models_checkbox = root.get_node("%UseLegacyModelsCheckBox") as CheckBox
	_player_count_error = root.get_node("%PlayerCountError") as Label
	_phone_player_count_guidance = root.get_node("%PhonePlayerCountGuidance") as Label
	_starting_stack_error = root.get_node("%StartingStackError") as Label
	_small_blind_error = root.get_node("%SmallBlindError") as Label
	_big_blind_error = root.get_node("%BigBlindError") as Label
	_form_status = root.get_node("%FormStatus") as Label
	_start_button = root.get_node("%StartButton") as Button
	_rules_button = root.get_node("%RulesButton") as Button
	_startup_panel = root.get_node("Center") as CenterContainer
	_brand_logo = root.get_node("%BrandLogo") as TextureRect
	_background = root.get_node("Background") as ColorRect
	_startup_form_panel = root.get_node("%Panel") as PanelContainer
	_startup_form = root.get_node("%Form") as VBoxContainer
	_startup_fields = root.get_node("%Fields") as GridContainer
	_quit_application_button = root.get_node("%QuitApplicationButton") as Button


func apply(available: Vector2, size_class: GuiSizeClass, table_visible: bool) -> void:
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var phone_layout: bool = size_class.is_phone()
	_background.color = (
		Color("075c35")
		if table_visible and size_class.mode == GuiSizeClass.LayoutMode.PHONE
		else Color(0.035, 0.09, 0.07, 1.0)
	)
	var is_portrait: bool = not size_class.landscape
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
	var compact_form: bool = (
		size_class.width_class != GuiSizeClass.Width.EXPANDED
		or size_class.height_class != GuiSizeClass.Height.TALL
	)
	var is_compact_landscape: bool = not is_portrait and compact_form
	var is_compact_portrait: bool = is_portrait and compact_form
	_brand_logo.custom_minimum_size.y = (
		(80.0 if is_portrait else 64.0) if phone_layout else clampf(available.y * 0.18, 64.0, 128.0)
	)
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
			available.x * (0.94 if phone_layout else PORTRAIT_FORM_WIDTH_RATIO)
		)
		_set_startup_touch_targets(COMPACT_TARGET_SCALE)
	elif is_portrait:
		_startup_form_panel.custom_minimum_size.x = (
			available.x * (0.94 if phone_layout else PORTRAIT_FORM_WIDTH_RATIO)
		)
		var target_scale: float = (
			COMPACT_TARGET_SCALE
			if is_compact_portrait
			else clampf(minf(available.x / 960.0, available.y / 1920.0), 1.0, PORTRAIT_TARGET_SCALE)
		)
		_set_startup_touch_targets(target_scale)
	else:
		_startup_form_panel.custom_minimum_size.x = clampf(
			available.x * DESKTOP_FORM_WIDTH_RATIO,
			DESKTOP_FORM_MIN_WIDTH,
			DESKTOP_FORM_MAX_WIDTH,
		)
		_set_startup_touch_targets(1.0)
	_apply_startup_typography(compact_form)
	_fit_startup_header(available)


func _fit_startup_header(available: Vector2) -> void:
	var height: float = maxf(0.0, available.y - 24.0)
	# Keep every field and action; optional header copy yields before the logo.
	if _startup_form_panel.get_minimum_size().y > height:
		_description.hide()
	if _startup_form_panel.get_minimum_size().y > height:
		_title.hide()
	var overflow: float = maxf(0.0, _startup_form_panel.get_minimum_size().y - height)
	_brand_logo.custom_minimum_size.y = maxf(24.0, _brand_logo.custom_minimum_size.y - overflow)
	for container: Container in [
		_startup_panel, _startup_form_panel, _startup_form.get_parent(), _startup_form
	]:
		container.queue_sort()


func _apply_startup_typography(compact: bool) -> void:
	_startup_form.theme = GuiTypography.for_density(
		GuiFitCandidate.Density.COMPACT if compact else GuiFitCandidate.Density.FULL
	)
	_title.remove_theme_font_size_override("font_size")
	_title.theme_type_variation = &"HeadingText"
	for label: Label in [
		_description,
		_player_count_label,
		_starting_stack_label,
		_small_blind_label,
		_big_blind_label,
		_phone_player_count_guidance,
		_player_count_error,
		_starting_stack_error,
		_small_blind_error,
		_big_blind_error,
		_form_status,
	]:
		label.theme_type_variation = &"BodyText"


func _set_startup_touch_targets(geometry_scale: float) -> void:
	for control: Control in [
		_player_count_input,
		_starting_stack_input,
		_small_blind_input,
		_big_blind_input,
		_use_legacy_models_checkbox,
		_start_button,
		_rules_button,
		_quit_application_button,
	]:
		control.custom_minimum_size.y = maxf(48.0, STARTUP_TOUCH_TARGET_HEIGHT * geometry_scale)
