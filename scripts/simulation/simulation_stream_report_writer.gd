class_name SimulationStreamReportWriter
extends RefCounted

## Publishes canonical schema-4 JSON without retaining tournament arrays.

var error_message: String = ""


# gdlint: disable=max-returns
func write(
	path: String,
	store: SimulationCheckpointStore,
	manifest: SimulationManifest,
	shard: SimulationShard,
	aggregates: Dictionary,
	overwrite: bool,
) -> Dictionary:
	var target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(target) and not overwrite:
		return _failure("Output already exists; pass --overwrite to replace it.")
	var temporary := "%s.tmp.%d.%d" % [target, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("Unable to create temporary report: %s" % temporary)
	var document := store.report_metadata(aggregates, Time.get_datetime_string_from_system(true))
	var keys := document.keys()
	keys.sort()
	file.store_string("{")
	for key_index: int in range(keys.size()):
		var key: String = keys[key_index]
		if key_index > 0:
			file.store_string(",")
		file.store_string(JSON.stringify(key) + ":")
		if key in ["tournaments", "traces"]:
			if not _write_array(file, key, store, manifest, shard):
				file.close()
				DirAccess.remove_absolute(temporary)
				return {"success": false}
		else:
			file.store_string(JSON.stringify(document[key], "", true, true))
	file.store_string("}")
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		DirAccess.remove_absolute(temporary)
		return _failure("Unable to finish report data: %s" % path)
	if FileAccess.file_exists(target) and not overwrite:
		DirAccess.remove_absolute(temporary)
		return _failure("Output already exists; pass --overwrite to replace it.")
	if DirAccess.rename_absolute(temporary, target) != OK:
		DirAccess.remove_absolute(temporary)
		return _failure("Unable to atomically finalize report: %s" % path)
	return {
		"success": true,
		"report_path": path,
		"report_checksum": file_checksum(target),
		"manifest_checksum": manifest.checksum(),
		"shard": shard.to_dictionary(),
		"tournament_count": manifest.create_cursor(shard).assigned_count,
	}


func _write_array(
	file: FileAccess,
	key: String,
	store: SimulationCheckpointStore,
	manifest: SimulationManifest,
	shard: SimulationShard,
) -> bool:
	var cursor := manifest.create_cursor(shard)
	var first: bool = true
	file.store_string("[")
	while cursor.has_next():
		var input := cursor.next_input()
		var record := store.load_record(input.tournament_index)
		if record.is_empty():
			error_message = store.error_message
			return false
		var content: String = record.tournament_json
		if key == "traces":
			if record.traces.is_empty():
				continue
			var array_json := String(record.traces_json).strip_edges()
			content = array_json.substr(1, array_json.length() - 2)
		if not first:
			file.store_string(",")
		file.store_string(content)
		first = false
	file.store_string("]")
	return true


func _failure(message: String) -> Dictionary:
	error_message = message
	return {"success": false}


static func file_checksum(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		context.update(file.get_buffer(65536))
	return context.finish().hex_encode()
