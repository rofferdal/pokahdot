extends SceneTree

## Headless entry point. Run with:
##   godot --headless --path . --script res://scripts/cli/cli_app.gd
## Keep this layer to stdin/stdout. Game rules belong in scripts/core/.


func _initialize() -> void:
	print("Pokahdot CLI")
	print("Terminal UI er ikke implementert ennå.")
	quit()
