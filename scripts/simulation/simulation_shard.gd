class_name SimulationShard
extends RefCounted

## Global-index shard descriptor. A shard filters a completed global plan.

var index: int
var count: int


func _init(shard_index: int = 0, shard_count: int = 1) -> void:
	index = shard_index
	count = shard_count


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if count <= 0:
		errors.append("Shard count must be positive.")
	if index < 0 or index >= count:
		errors.append("Shard index must be between zero and shard count minus one.")
	return errors


func contains(tournament_index: int) -> bool:
	return validate().is_empty() and tournament_index % count == index


func to_dictionary() -> Dictionary:
	return {"index": index, "count": count}
