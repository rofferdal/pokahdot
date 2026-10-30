class_name GuiModalGuard
extends Node

## Presentation-only modal input ownership and deferred match advancement.

var _host: Control
var _backdrop: Control
var _active: bool = false
var _root: Node
var _dismiss: Callable
var _fallback_focus: Control
var _previous_focus: WeakRef
var _pending_advance: Callable
var _saved_quit_on_back: bool
var _owns_back_policy: bool = false


func configure(host: Control, surface: Control, backdrop: Control) -> bool:
	if host == null or surface == null or backdrop == null or backdrop.get_parent() != surface:
		push_error("Modal guard requires an authored backdrop owned by its surface.")
		return false
	_host = host
	_backdrop = backdrop
	_backdrop.z_index = 499
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.hide()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return true


func begin(root: Node, dismiss: Callable, focus: Control, fallback: Control) -> void:
	if not is_instance_valid(_host) or not is_instance_valid(_backdrop):
		push_error("Modal guard must be configured before activation.")
		return
	if not is_active():
		var current: Control = _host.get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(current) if current != null else null
		_saved_quit_on_back = get_tree().quit_on_go_back
		get_tree().quit_on_go_back = false
		_owns_back_policy = true
	_active = true
	_root = root
	_dismiss = dismiss
	_fallback_focus = fallback
	_backdrop.show()
	focus.grab_focus()


func finish() -> void:
	if not is_active():
		return
	_active = false
	_root = null
	_dismiss = Callable()
	_backdrop.hide()
	_restore_back_policy()
	var previous: Control = (
		_previous_focus.get_ref() as Control if _previous_focus != null else null
	)
	var restore: Control = previous if _can_focus(previous) else _fallback_focus
	if _can_focus(restore):
		restore.grab_focus()
	_previous_focus = null
	# Defer until the closing input event has finished; never feed it into the
	# next hand or resume transiently while switching between modal surfaces.
	call_deferred("_resume_if_closed")


func is_active() -> bool:
	return _active


func hold_advance(callback: Callable) -> bool:
	if not is_active():
		return false
	_pending_advance = callback
	return true


func cancel_advance() -> void:
	_pending_advance = Callable()


func _resume_if_closed() -> void:
	if is_active() or not _pending_advance.is_valid():
		return
	var callback: Callable = _pending_advance
	_pending_advance = Callable()
	callback.call()


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	if event.is_action_pressed("ui_cancel"):
		_host.get_viewport().set_input_as_handled()
		_dismiss.call()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls: Array[Control] = []
		_collect_focus_controls(_root, controls)
		if not controls.is_empty():
			var owner: Control = _root.get_viewport().gui_get_focus_owner()
			var index: int = controls.find(owner)
			var direction: int = -1 if event.is_action_pressed("ui_focus_prev") else 1
			controls[posmod(index + direction, controls.size())].grab_focus()
		_host.get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var owner: Control = _root.get_viewport().gui_get_focus_owner()
		if owner == null or not _root.is_ancestor_of(owner):
			_host.get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_active():
		_dismiss.call()
	elif what == NOTIFICATION_EXIT_TREE:
		_restore_back_policy()


func _unhandled_input(_event: InputEvent) -> void:
	if is_active():
		_host.get_viewport().set_input_as_handled()


func _restore_back_policy() -> void:
	if _owns_back_policy:
		get_tree().quit_on_go_back = _saved_quit_on_back
		_owns_back_policy = false


func _collect_focus_controls(node: Node, controls: Array[Control]) -> void:
	if node is Control and _can_focus(node as Control):
		controls.append(node as Control)
	for child: Node in node.get_children():
		_collect_focus_controls(child, controls)


func _can_focus(control: Control) -> bool:
	return (
		is_instance_valid(control)
		and control.is_visible_in_tree()
		and control.focus_mode != Control.FOCUS_NONE
		and not (control is BaseButton and (control as BaseButton).disabled)
	)
