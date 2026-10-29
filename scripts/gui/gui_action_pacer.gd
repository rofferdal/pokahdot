class_name GuiActionPacer
extends RefCounted

## Schedules presentation-only pauses without blocking the scene tree.

var _scene_tree: SceneTree
var _timing_config: Resource
var _request_id: int = 0
var _is_waiting: bool = false


func configure(scene_tree: SceneTree, timing_config: Resource) -> void:
	_scene_tree = scene_tree
	_timing_config = timing_config


func schedule_after_action(actor_seat: int, advance_callback: Callable) -> void:
	schedule_delay(_pause_seconds_for(actor_seat), advance_callback)


func schedule_after_completed_hand(advance_callback: Callable) -> void:
	var pause_seconds: float = 5.0 if _timing_config == null else _timing_config.showdown_pause()
	schedule_delay(pause_seconds, advance_callback)


func schedule_delay(pause_seconds: float, advance_callback: Callable) -> void:
	_request_id += 1
	var request_id: int = _request_id
	if pause_seconds <= 0.0:
		_is_waiting = false
		advance_callback.call()
		return
	_is_waiting = true
	_wait_then_advance(request_id, pause_seconds, advance_callback)


func cancel() -> void:
	_request_id += 1
	_is_waiting = false


func is_waiting() -> bool:
	return _is_waiting


func _pause_seconds_for(actor_seat: int) -> float:
	return 2.0 if _timing_config == null else _timing_config.pause_for_seat(actor_seat)


func _wait_then_advance(request_id: int, pause_seconds: float, advance_callback: Callable) -> void:
	await _scene_tree.create_timer(pause_seconds).timeout
	if request_id == _request_id:
		_is_waiting = false
		advance_callback.call()
