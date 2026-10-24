class_name CliStartupArguments
extends RefCounted

## Parses optional CLI-only startup switches supplied after Godot's `--` separator.

const USE_LEGACY_MODELS_FLAG := "--use-legacy-models"


static func use_legacy_models(arguments: PackedStringArray) -> bool:
	return USE_LEGACY_MODELS_FLAG in arguments
