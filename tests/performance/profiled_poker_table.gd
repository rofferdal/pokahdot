extends "res://scripts/gui/poker_table_controller.gd"

## Test-only observer. Production rendering, view binding and input handlers run
## unchanged; the fixture supplies each step instead of waiting for pacing timers.
var recording: bool = false
var census: bool = false
var refresh_usec: Array[int] = []
var visual_usec: Array[int] = []
var layout_usec: Array[int] = []
var node_churn: Array[Dictionary] = []
var counter_samples: Array[Dictionary] = []


func refresh_from_match() -> void:
	var started: int = Time.get_ticks_usec()
	super.refresh_from_match()
	if recording:
		refresh_usec.append(Time.get_ticks_usec() - started)


func _refresh_visuals() -> void:
	var before: Dictionary[int, bool] = {}
	if census:
		before = _node_ids(self)
	var started: int = Time.get_ticks_usec()
	super._refresh_visuals()
	var elapsed: int = Time.get_ticks_usec() - started
	if recording:
		visual_usec.append(elapsed)
	if census:
		var after: Dictionary[int, bool] = _node_ids(self)
		var created: int = 0
		for instance_id: int in after:
			if not before.has(instance_id):
				created += 1
		node_churn.append(
			{
				"operation": "refresh",
				"new_node_ids": created,
				"before_nodes": before.size(),
				"after_nodes": after.size()
			}
		)


func _layout_table(usable_size: Vector2, generation: int) -> void:
	var before: Dictionary[int, bool] = {}
	if census:
		before = _node_ids(self)
	var started: int = Time.get_ticks_usec()
	super._layout_table(usable_size, generation)
	if recording:
		layout_usec.append(Time.get_ticks_usec() - started)
	if census:
		var after: Dictionary[int, bool] = _node_ids(self)
		var created: int = 0
		for instance_id: int in after:
			if not before.has(instance_id):
				created += 1
		node_churn.append(
			{
				"operation": "layout",
				"new_node_ids": created,
				"before_nodes": before.size(),
				"after_nodes": after.size()
			}
		)


func _schedule_after_latest_action() -> void:
	pass


func _schedule_next_action(_actor_seat: int) -> void:
	pass


func _schedule_after_completed_hand() -> void:
	pass


static func counters() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"static_memory_peak_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
	}


static func _node_ids(node: Node) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {node.get_instance_id(): true}
	for child: Node in node.get_children():
		result.merge(_node_ids(child))
	return result
