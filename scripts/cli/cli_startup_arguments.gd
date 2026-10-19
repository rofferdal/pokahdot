class_name CliStartupArguments
extends RefCounted

## Parses optional CLI-only startup switches supplied after Godot's `--` separator.

const ALLOW_EXPERIMENTAL_MODELS_FLAG := "--allow-experimental-models"


static func allow_experimental_models(arguments: PackedStringArray) -> bool:
	return ALLOW_EXPERIMENTAL_MODELS_FLAG in arguments
