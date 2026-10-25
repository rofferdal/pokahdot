extends "res://tests/support/poker_gut_test.gd"

const CliMatchFactoryScript := preload("res://scripts/cli/cli_match_factory.gd")
const GuiActionTimingConfigScript := preload("res://scripts/gui/gui_action_timing_config.gd")
const GuiMatchFactoryScript := preload("res://scripts/gui/gui_match_factory.gd")
const GuiStartupConfigAdapterScript := preload("res://scripts/gui/gui_startup_config_adapter.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")

const OUTCOME_SEED: int = 9123
const SCRIPTED_HUMAN_ACTIONS: PackedStringArray = [
	"check_or_call",
	"check_or_call",
	"check_or_call",
	"check_or_call",
]


func test_fixed_seed_and_scripted_actions_produce_equivalent_core_outcomes() -> void:
	var config := _config(2, 100, 5, 10, OUTCOME_SEED, false)
	var cli_factory := CliMatchFactoryScript.new()
	var gui_factory := GuiMatchFactoryScript.new()
	var cli_match: TournamentMatch = cli_factory.create(config)
	var gui_creation: GuiMatchCreationResult = gui_factory.create(config)
	assert_true(gui_creation.is_ok(), gui_creation.error_message)
	var gui_match: TournamentMatch = gui_creation.match_instance
	var human_seat: int = cli_factory.human_seat(config)

	assert_eq(cli_match.start().status, gui_match.start().status)
	assert_eq(_core_outcome(cli_match, human_seat), _core_outcome(gui_match, human_seat))

	var table: PokerTableController = PokerTableScene.instantiate() as PokerTableController
	add_child_autofree(table)
	_pause_gui_automation(table)
	table.bind_match(gui_match, human_seat, gui_creation.avatar_assignments)

	for scripted_action: String in SCRIPTED_HUMAN_ACTIONS:
		var cli_view: GameView = cli_match.get_view_for(human_seat)
		var gui_view: GameView = gui_match.get_view_for(human_seat)
		if cli_view.hand_complete or gui_view.hand_complete:
			break
		assert_eq(cli_view.acting_seat, human_seat, scripted_action)
		assert_eq(gui_view.acting_seat, human_seat, scripted_action)

		var cli_command: String = (
			"check" if PlayerAction.Kind.CHECK in cli_view.legal_actions else "call"
		)
		var parsed_command: CliCommand = CommandParser.new().parse(cli_command)
		assert_eq(parsed_command.kind, CliCommand.Kind.ACTION)
		var cli_result: StepResult = cli_match.submit_human_action(parsed_command.action)

		table.refresh_from_match()
		(table.get_node("%CheckCallButton") as Button).emit_signal("pressed")
		var gui_result: StepResult = gui_match.advance_until_blocked()

		assert_eq(cli_result.status, gui_result.status, scripted_action)
		assert_eq(
			_core_outcome(cli_match, human_seat),
			_core_outcome(gui_match, human_seat),
			scripted_action,
		)

	assert_eq(_player_action_count(cli_match, human_seat), SCRIPTED_HUMAN_ACTIONS.size())
	assert_eq(
		_player_action_count(cli_match, human_seat),
		_player_action_count(gui_match, human_seat),
	)


func test_equivalent_omissions_resolve_to_identical_core_configuration() -> void:
	var defaults := _startup_defaults()
	var cli_io := FakeCliIO.new()
	cli_io.queue_blank_line()
	var cli_result: StartupPromptResult = StartupConfigPrompt.new(cli_io).run(defaults)
	var gui_adapter := GuiStartupConfigAdapterScript.new(defaults)

	assert_true(cli_result.is_ready())
	assert_true(gui_adapter.try_start(), str(gui_adapter.field_errors))
	assert_eq(_config_values(cli_result.config), _config_values(gui_adapter.resolved_config))


func test_equivalent_explicit_selections_resolve_to_identical_core_configuration() -> void:
	var defaults := _startup_defaults()
	var cli_io := FakeCliIO.new()
	cli_io.queue_line("configure")
	for selected_value: String in ["4", "240", "12", "24"]:
		cli_io.queue_line(selected_value)
	var cli_result: StartupPromptResult = StartupConfigPrompt.new(cli_io).run(defaults, true)
	var gui_adapter := GuiStartupConfigAdapterScript.new(defaults)
	gui_adapter.player_count_text = "4"
	gui_adapter.starting_stack_text = "240"
	gui_adapter.small_blind_text = "12"
	gui_adapter.big_blind_text = "24"
	gui_adapter.use_legacy_models = true

	assert_true(cli_result.is_ready())
	assert_true(gui_adapter.try_start(), str(gui_adapter.field_errors))
	assert_eq(_config_values(cli_result.config), _config_values(gui_adapter.resolved_config))


func test_each_numeric_selection_matches_when_other_values_are_omitted() -> void:
	var cases: Array[Dictionary] = [
		{"field": &"player_count", "value": "4", "inputs": ["4", "", "", ""]},
		{"field": &"starting_stack", "value": "240", "inputs": ["", "240", "", ""]},
		{"field": &"small_blind", "value": "4", "inputs": ["", "", "4", ""]},
		{"field": &"big_blind", "value": "24", "inputs": ["", "", "", "24"]},
	]
	for case: Dictionary in cases:
		var defaults := _startup_defaults()
		var cli_io := FakeCliIO.new()
		cli_io.queue_line("configure")
		for input: String in case.inputs:
			cli_io.queue_line(input)
		var cli_result: StartupPromptResult = StartupConfigPrompt.new(cli_io).run(defaults)
		var gui_adapter := GuiStartupConfigAdapterScript.new(defaults)
		gui_adapter.set("%s_text" % case.field, case.value)

		assert_true(cli_result.is_ready(), case.field)
		assert_true(gui_adapter.try_start(), "%s: %s" % [case.field, gui_adapter.field_errors])
		assert_eq(
			_config_values(cli_result.config),
			_config_values(gui_adapter.resolved_config),
			case.field,
		)


func test_fixed_seed_config_selects_equivalent_families_and_one_human_in_both_interfaces() -> void:
	var config := _config(7, 1000, 5, 10, 441, true)
	var cli_factory := CliMatchFactoryScript.new()
	var gui_factory := GuiMatchFactoryScript.new()
	var cli_match: TournamentMatch = cli_factory.create(config)
	var gui_creation: GuiMatchCreationResult = gui_factory.create(config)
	assert_true(gui_creation.is_ok(), gui_creation.error_message)
	var gui_match: TournamentMatch = gui_creation.match_instance

	assert_eq(
		_bot_identity_by_seat(cli_match, config.player_count),
		_bot_identity_by_seat(gui_match, config.player_count),
	)
	assert_eq(_human_count(cli_match, config.player_count), 1)
	assert_eq(_human_count(gui_match, config.player_count), 1)
	assert_has(cli_factory.diagnostics(config), "Legacy heuristic models: included")
	assert_ne(cli_match.start().status, StepResult.Status.ERROR)
	assert_ne(gui_match.start().status, StepResult.Status.ERROR)


func _startup_defaults() -> TournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.player_count = 6
	defaults.starting_stack = 1000
	defaults.small_blind = 5
	defaults.big_blind = 10
	defaults.rng_seed = 20261026
	return defaults


func _config(
	player_count: int,
	starting_stack: int,
	small_blind: int,
	big_blind: int,
	rng_seed: int,
	use_legacy_models: bool,
) -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = rng_seed
	var overrides := StartupOverrides.new()
	overrides.set_player_count(player_count)
	overrides.set_starting_stack(starting_stack)
	overrides.set_small_blind(small_blind)
	overrides.set_big_blind(big_blind)
	overrides.set_use_legacy_models(use_legacy_models)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _pause_gui_automation(table: PokerTableController) -> void:
	var timing_config := GuiActionTimingConfigScript.new()
	timing_config.default_pause_seconds = 3600.0
	timing_config.showdown_pause_seconds = 3600.0
	table.set_action_timing_config(timing_config)


func _config_values(config: ResolvedTournamentConfig) -> Dictionary:
	return {
		"player_count": config.player_count,
		"starting_stack": config.starting_stack,
		"small_blind": config.small_blind,
		"big_blind": config.big_blind,
		"rng_seed": config.rng_seed,
		"tournament_mode": config.tournament_mode,
		"use_legacy_models": config.use_legacy_models,
		"seat_agents": config.seat_agents,
	}


func _core_outcome(match_instance: TournamentMatch, human_seat: int) -> Dictionary:
	var view: GameView = match_instance.get_view_for(human_seat)
	var seats: Array[Dictionary] = []
	for seat: PlayerView in view.seats:
		(
			seats
			. append(
				{
					"seat": seat.seat,
					"stack": seat.stack,
					"bet": seat.bet_this_round,
					"folded": seat.folded,
					"all_in": seat.all_in,
					"busted": seat.busted,
				}
			)
		)
	var actions: Array[Array] = []
	for record: PublicActionRecord in view.action_history:
		actions.append([record.record_kind, record.seat, record.kind, record.amount])
	var events: Array[Array] = []
	for event: DomainEvent in match_instance.get_events():
		events.append([event.kind, event.seat, event.amount])
	return {
		"state": match_instance.state,
		"end_reason": match_instance.end_reason,
		"winner_seat": match_instance.winner_seat,
		"hand_number": view.hand_number,
		"street": view.street,
		"acting_seat": view.acting_seat,
		"pot_amount": view.pot_amount,
		"hand_complete": view.hand_complete,
		"community_cards": _card_values(view.community_cards),
		"hero_hole_cards": _card_values(view.hero_hole_cards),
		"seats": seats,
		"actions": actions,
		"events": events,
	}


func _card_values(cards: Array[CardData]) -> Array[String]:
	var values: Array[String] = []
	for card: CardData in cards:
		values.append("%d:%d" % [card.rank, card.suit])
	return values


func _player_action_count(match_instance: TournamentMatch, seat: int) -> int:
	var count := 0
	for record: PublicActionRecord in match_instance.get_view_for(seat).action_history:
		if record.record_kind == PublicActionRecord.Kind.ACTION and record.seat == seat:
			count += 1
	return count


func _bot_identity_by_seat(
	match_instance: TournamentMatch, player_count: int
) -> Dictionary[int, StringName]:
	var identities: Dictionary[int, StringName] = {}
	for seat: int in range(player_count):
		var agent := match_instance.get_agent_for_simulation(seat)
		if agent is BotAgent:
			var bot := agent as BotAgent
			identities[seat] = StringName("%s:%s" % [bot.model_id, bot.profile_id])
	return identities


func _human_count(match_instance: TournamentMatch, player_count: int) -> int:
	var count := 0
	for seat: int in range(player_count):
		if match_instance.get_agent_for_simulation(seat) is HumanAgent:
			count += 1
	return count
