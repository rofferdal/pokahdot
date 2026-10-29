class_name GuiTableActionControls
extends RefCounted

## Owns authored action rows and their reparenting, copy, visibility and styles.
## Node handles are resolved once; this component never submits poker actions.
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")
const GuiPhoneSeatLayoutScript := preload("res://scripts/gui/gui_phone_seat_layout.gd")

var margin: MarginContainer
var content: VBoxContainer
var rows: VBoxContainer
var primary: HBoxContainer
var wagers: HBoxContainer
var numeric_feedback: HBoxContainer
var more_spacer: Control
var _action_panel: PanelContainer
var _fold_button: Button
var _check_call_button: Button
var _min_wager_button: Button
var _pot_raise_button: Button
var _wager_button: Button
var _all_in_button: Button
var _quit_button: Button
var _wager_input: LineEdit
var _action_status: Label
var _phone_hero_summary: HBoxContainer
var _phone_hero_action_badge: Label
var _phone_player_count_notice: Label


func configure(root: Control) -> void:
	_action_panel = root.get_node("TableMargin/Felt/TableSurface/ActionPanel") as PanelContainer
	_fold_button = root.get_node("%FoldButton") as Button
	_check_call_button = root.get_node("%CheckCallButton") as Button
	_min_wager_button = root.get_node("%MinWagerButton") as Button
	_pot_raise_button = root.get_node("%PotRaiseButton") as Button
	_wager_button = root.get_node("%WagerButton") as Button
	_all_in_button = root.get_node("%AllInButton") as Button
	_quit_button = root.get_node("%QuitButton") as Button
	_wager_input = root.get_node("%WagerInput") as LineEdit
	_action_status = root.get_node("%ActionStatus") as Label
	_phone_hero_summary = root.get_node("%PhoneHeroSummary") as HBoxContainer
	_phone_hero_action_badge = root.get_node("%PhoneHeroActionBadge") as Label
	_phone_player_count_notice = root.get_node("%PhonePlayerCountNotice") as Label

	margin = _action_panel.get_node("Margin") as MarginContainer
	content = margin.get_node("Content") as VBoxContainer
	rows = content.get_node("ActionRows") as VBoxContainer
	primary = rows.get_node("PrimaryButtons") as HBoxContainer
	wagers = rows.get_node("WagerControls") as HBoxContainer


func apply_action_control_styles() -> void:
	var action_buttons: Array[Button] = [
		_fold_button,
		_check_call_button,
		_min_wager_button,
		_pot_raise_button,
		_wager_button,
		_all_in_button,
		_quit_button,
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
	for state: StringName in [&"normal", &"focus", &"read_only"]:
		var border := Color("e7d39b") if state == &"focus" else Color("75c99a")
		var background := Color("1b4933") if state == &"focus" else Color("102d21")
		if state == &"read_only":
			border = Color("557665")
			background = Color("0a1711")
		var field_style := GuiTableStyleScript.box(
			background, border, 2 if state == &"focus" else 1, 0
		)
		# Inset only the drawn face; the Container allocation and touch area stay intact.
		field_style.expand_margin_top = -4.0
		field_style.expand_margin_bottom = -4.0
		field_style.set_content_margin_all(2.0)
		_wager_input.add_theme_stylebox_override(state, field_style)
	for role: StringName in [&"font_color", &"caret_color", &"font_uneditable_color"]:
		_wager_input.add_theme_color_override(role, Color("b8c3bb"))
	_wager_input.add_theme_color_override("font_placeholder_color", Color("b8c3bb"))
	_wager_input.add_theme_color_override("selection_color", Color("75c99a"))
	_wager_input.add_theme_color_override("font_selected_color", Color("102d21"))


func configure_numeric_action_rows() -> void:
	_all_in_button.reparent(primary)
	for button: Button in [_min_wager_button, _pot_raise_button]:
		button.reparent(wagers)
	wagers.move_child(_min_wager_button, 0)
	wagers.move_child(_pot_raise_button, 1)
	_wager_input.hide()
	_min_wager_button.text = "Min"


func configure_action_control_copy(model: ActionBarViewModel, compact_copy: bool) -> void:
	_check_call_button.text = model.check_call_text
	_min_wager_button.text = model.minimum_text
	_pot_raise_button.text = model.pot_text
	_wager_button.text = model.wager_text
	_all_in_button.text = model.all_in_text
	_wager_input.placeholder_text = model.input_placeholder
	_wager_input.custom_minimum_size.x = 72.0 if compact_copy else 200.0


func configure_action_control_visibility(
	model: ActionBarViewModel, phone_layout: bool, player_count: int
) -> void:
	_phone_hero_summary.visible = phone_layout
	_phone_player_count_notice.visible = (
		phone_layout and player_count > GuiPhoneSeatLayoutScript.MAX_SUPPORTED_PLAYER_COUNT
	)
	if not phone_layout:
		rows.show()
		primary.show()
		wagers.show()
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
	_fold_button.visible = model.phone_fold_visible
	_check_call_button.visible = model.phone_check_call_visible
	_min_wager_button.hide()
	_pot_raise_button.hide()
	_wager_input.hide()
	_wager_button.visible = model.phone_wager_visible
	_all_in_button.visible = model.phone_all_in_visible
	primary.visible = _fold_button.visible or _check_call_button.visible
	wagers.visible = _wager_button.visible or _all_in_button.visible
	rows.visible = primary.visible or wagers.visible


func configure_phone_action_rows(single_row: bool) -> void:
	restore_phone_action_rows()
	if single_row:
		# The acting-seat badge and available buttons retain turn state in this
		# emergency landscape row; do not leave a clipped status allocation.
		_action_status.hide()
		if _action_status.get_parent() != _phone_hero_summary:
			_action_status.reparent(_phone_hero_summary)
		if _wager_button.get_parent() != primary:
			_wager_button.reparent(primary)
		if _all_in_button.get_parent() != primary:
			_all_in_button.reparent(primary)
		wagers.hide()


func restore_phone_action_rows() -> void:
	if not is_instance_valid(_action_panel):
		return
	_action_status.show()
	_action_status.custom_minimum_size.y = 0.0
	_action_status.max_lines_visible = 1
	if is_instance_valid(numeric_feedback):
		numeric_feedback.hide()
	if is_instance_valid(more_spacer):
		more_spacer.hide()
	if _phone_hero_action_badge.get_parent() != _phone_hero_summary:
		_phone_hero_action_badge.reparent(_phone_hero_summary)
	for button: Button in [_min_wager_button, _pot_raise_button]:
		if button.get_parent() != primary:
			button.reparent(primary)
	if _action_status.get_parent() != content:
		_action_status.reparent(content)
		content.move_child(_action_status, 1)
	if _all_in_button.get_parent() != wagers:
		_all_in_button.reparent(wagers)
	if _wager_button.get_parent() != wagers:
		_wager_button.reparent(wagers)
	wagers.move_child(_all_in_button, 0)
	wagers.move_child(_wager_button, wagers.get_child_count() - 1)


func render_enabled(model: ActionBarViewModel) -> void:
	_fold_button.disabled = not model.fold_enabled
	_check_call_button.disabled = not model.check_call_enabled
	_min_wager_button.disabled = not model.minimum_enabled
	_pot_raise_button.disabled = not model.pot_enabled
	_wager_input.editable = model.can_wager
	_wager_button.disabled = not model.wager_enabled
	_all_in_button.disabled = not model.all_in_enabled
