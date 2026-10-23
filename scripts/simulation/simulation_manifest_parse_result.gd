class_name SimulationManifestParseResult
extends RefCounted

## Result of parsing untrusted manifest data at the adapter boundary.

var manifest: SimulationManifest
var errors: PackedStringArray


func _init(
	parsed_manifest: SimulationManifest = null, parse_errors: PackedStringArray = []
) -> void:
	manifest = parsed_manifest
	errors = parse_errors.duplicate()


func is_ok() -> bool:
	return manifest != null and errors.is_empty()
