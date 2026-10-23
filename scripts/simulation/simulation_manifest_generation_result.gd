class_name SimulationManifestGenerationResult
extends RefCounted

## Typed outcome of constructing a roster-backed simulation manifest.

## A failed generation never exposes a partial manifest to callers.

var manifest: SimulationManifest
var errors: PackedStringArray


func _init(
	generated_manifest: SimulationManifest = null, generation_errors: PackedStringArray = []
) -> void:
	manifest = generated_manifest
	errors = generation_errors.duplicate()


func is_ok() -> bool:
	return manifest != null and errors.is_empty()
