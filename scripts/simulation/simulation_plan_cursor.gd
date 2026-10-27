class_name SimulationPlanCursor
extends RefCounted

## A private manifest snapshot and arithmetic shard cursor, independent of batch size.

var errors := PackedStringArray()
var assigned_count: int = 0
var _manifest: SimulationManifest
var _shard: SimulationShard
var _next_index: int
var _total: int


func _init(manifest: SimulationManifest, shard: SimulationShard = null) -> void:
	if manifest == null:
		errors.append("A simulation manifest is required.")
		return
	errors = manifest.validate()
	_shard = (
		SimulationShard.new() if shard == null else SimulationShard.new(shard.index, shard.count)
	)
	errors.append_array(_shard.validate())
	if not errors.is_empty():
		return
	# Parsing the canonical snapshot preserves ownership without copying a global plan.
	_manifest = SimulationManifest.parse(manifest.canonical_dictionary()).manifest
	_total = _manifest.tournament_count()
	_next_index = _shard.index
	if _total > _next_index:
		assigned_count = 1 + (_total - 1 - _next_index) / _shard.count


func has_next() -> bool:
	return errors.is_empty() and _next_index < _total


func next_input() -> SimulationTournamentInput:
	if not has_next():
		return null
	var input := _manifest.input_at(_next_index)
	# Avoid an overflowing final addition for extremely sparse shards.
	_next_index = _total if _shard.count >= _total - _next_index else _next_index + _shard.count
	return input
