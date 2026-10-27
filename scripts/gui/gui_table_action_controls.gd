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


func configure_numeric_action_rows() -> void:
	_all_in_button.reparent(primary)
	for button: Button in [_min_wager_button, _pot_raise_button]:
		button.reparent(wagers)
	wagers.move_child(_min_wager_button, 0)
	wagers.move_child(_pot_raise_button, 1)
	_wager_input.hide()
	_min_wager_button.text = "Min"


func configure_action_control_copy(
	view: GameView, legal: Array, compact_copy: bool, pot_target: PotWagerTargetResult
) -> void:
	if PlayerAction.Kind.CHECK in legal:
		_check_call_button.text = "Check"
	elif PlayerAction.Kind.CALL in legal:
		_check_call_button.text = "Call %d" % view.call_amount
	else:
		_check_call_button.text = "Call" if compact_copy else "Check / Call"
	var wager_name: String = "Bet" if PlayerAction.Kind.BET in legal else "Raise"
	_min_wager_button.text = (
		"Min %d" % view.minimum_wager_total
		if compact_copy
		else "Min %s %d" % [wager_name, view.minimum_wager_total]
	)
	_pot_raise_button.text = "Pot %d" % pot_target.contribution
	_wager_button.text = wager_name
	_wager_input.placeholder_text = "Total" if compact_copy else "Wager total"
	_wager_input.custom_minimum_size.x = 72.0 if compact_copy else 200.0


func configure_action_control_visibility(
	view: GameView, legal: Array, is_human_turn: bool, phone_layout: bool
) -> void:
	_phone_hero_summary.visible = phone_layout
	_phone_player_count_notice.visible = (
		phone_layout and view.seats.size() > GuiPhoneSeatLayoutScript.MAX_SUPPORTED_PLAYER_COUNT
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
