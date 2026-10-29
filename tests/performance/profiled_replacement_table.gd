extends "res://scripts/gui/gui_replacement_table_controller.gd"

## Test-only synchronous model observer. Deferred settlement is measured by the fixture.
var recording: bool = false
var census: bool = false
var refresh_usec: Array[int] = []
var visual_usec: Array[int] = []
var layout_usec: Array[int] = []
var node_churn: Array[Dictionary] = []
var counter_samples: Array[Dictionary] = []


func _refresh_model() -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_model()
	if recording:
		refresh_usec.append(Time.get_ticks_usec() - started)


func _hold_advance(_callback: Callable) -> bool:
	# Only automatic pacing is suppressed. Explicit public controller steps run normally.
	return true


func record_census(
	operation: String, before: Dictionary[int, bool], previous: Dictionary, current: Dictionary
) -> void:
	var after: Dictionary[int, bool] = node_ids(self)
	var created: int = 0
	var removed: int = 0
	for id: int in after:
		if not before.has(id):
			created += 1
	for id: int in before:
		if not after.has(id):
			removed += 1
	var changes: Dictionary = {}
	for key: String in previous:
		changes[key] = current[key] - previous[key]
	(
		node_churn
		. append(
			{
				"operation": operation,
				"new_node_ids": created,
				"removed_node_ids": removed,
				"before_nodes": before.size(),
				"after_nodes": after.size(),
				"render_counter_change": changes,
			}
		)
	)


static func counters() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"static_memory_peak_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
	}


static func node_ids(node: Node) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {node.get_instance_id(): true}
	for child: Node in node.get_children():
		result.merge(node_ids(child))
	return result
