extends SceneTree

const CliMatchFactoryScript = preload("res://scripts/cli/cli_match_factory.gd")

## Headless entry point. Run with:
##   godot --headless --path . --script res://scripts/cli/cli_app.gd
## Keep this layer to stdin/stdout. Game rules belong in scripts/core/.


func _initialize() -> void:
	var io := TerminalIO.new()
	io.write_line("Pokahdot CLI")

	var defaults := load("res://resources/default_tournament_config.tres") as TournamentConfig
	if defaults == null:
		io.write_line("Unable to load the default tournament configuration.")
		quit(1)
		return

	var prompt := StartupConfigPrompt.new(io)
	var result: StartupPromptResult = prompt.run(defaults)
	if result.status == StartupPromptResult.Status.ERROR:
		quit(1)
		return
	if not result.is_ready():
		quit()
		return

	var match_factory := CliMatchFactoryScript.new()
	var match_instance: TournamentMatch = match_factory.create(result.config)
	var command_loop := CliCommandLoop.new(io)
	command_loop.run_match(match_instance, match_factory.human_seat(result.config))
	quit()
