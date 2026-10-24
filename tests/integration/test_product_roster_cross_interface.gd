extends "res://tests/support/poker_gut_test.gd"

const CliMatchFactoryScript = preload("res://scripts/cli/cli_match_factory.gd")
const GuiMatchFactoryScript = preload("res://scripts/gui/gui_match_factory.gd")


func test_fixed_seed_config_selects_equivalent_families_and_one_human_in_both_interfaces() -> void:
	var config := _config(true)
	var cli_factory := CliMatchFactoryScript.new()
	var gui_factory := GuiMatchFactoryScript.new()
	var cli_match: TournamentMatch = cli_factory.create(config)
	var gui_match: TournamentMatch = gui_factory.create(config)

	assert_eq(_bot_identity_by_seat(cli_match), _bot_identity_by_seat(gui_match))
	assert_eq(_human_count(cli_match), 1)
	assert_eq(_human_count(gui_match), 1)
	assert_has(cli_factory.diagnostics(config), "Legacy heuristic models: included")
	assert_ne(cli_match.start().status, StepResult.Status.ERROR)
	assert_ne(gui_match.start().status, StepResult.Status.ERROR)


func _config(use_legacy_models: bool) -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.player_count = 7
	defaults.rng_seed = 441
	var overrides := StartupOverrides.new()
	overrides.set_use_legacy_models(use_legacy_models)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _bot_identity_by_seat(match_instance: TournamentMatch) -> Dictionary[int, StringName]:
	var identities: Dictionary[int, StringName] = {}
	for seat: int in range(7):
		var agent := match_instance.get_agent_for_simulation(seat)
		if agent is BotAgent:
			var bot := agent as BotAgent
			identities[seat] = StringName("%s:%s" % [bot.model_id, bot.profile_id])
	return identities


func _human_count(match_instance: TournamentMatch) -> int:
	var count := 0
	for seat: int in range(7):
		if match_instance.get_agent_for_simulation(seat) is HumanAgent:
			count += 1
	return count
