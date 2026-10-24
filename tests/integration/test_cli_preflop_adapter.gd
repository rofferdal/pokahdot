extends "res://tests/support/poker_gut_test.gd"

const CliMatchFactoryScript = preload("res://scripts/cli/cli_match_factory.gd")
const CliCardFormatterScript = preload("res://scripts/cli/cli_card_formatter.gd")


func test_match_loop_renders_before_prompt_rejects_without_losing_turn_and_settles() -> void:
	var io := FakeCliIO.new()
	io.queue_line("nonsense").queue_line("raise 1").queue_line("raise 20")
	var match_instance := TournamentMatch.new(_config(3, 1000, 5, 10), _folding_agents(3))

	var status := CliCommandLoop.new(io).run_match(match_instance, 0)

	assert_eq(status, CliCommandLoop.Status.EOF)
	assert_true(io.writes.find("Hand 1 - preflop") < io.writes.find("pokahdot> "))
	assert_true(
		io.contains_write("Unknown command 'nonsense'. Type 'help' for available commands.")
	)
	assert_true(
		io.contains_write("Action rejected: The wager is below the minimum full bet or raise.")
	)
	assert_true(io.count_writes_containing("Hand 1 -") >= 3)
	assert_true(io.contains_write("Hand complete. Seat 0 wins by folds."))
	assert_true(io.contains_write("  Seat 0 raises to 20"))
	_assert_no_bot_cards_are_rendered(io, match_instance)


func test_quit_routes_through_match_and_renders_player_quit() -> void:
	var io := FakeCliIO.new()
	io.queue_line("quit")
	var match_instance := TournamentMatch.new(_config(2, 100, 5, 10), _passive_agents())

	var status := CliCommandLoop.new(io).run_match(match_instance, 0)

	assert_eq(status, CliCommandLoop.Status.QUIT)
	assert_eq(match_instance.state, TournamentMatch.State.FINISHED)
	assert_eq(match_instance.end_reason, &"player_quit")
	assert_true(io.contains_write("Tournament ended: player_quit"))


func test_match_loop_plays_a_complete_checked_down_hand_to_showdown() -> void:
	var io := FakeCliIO.new()
	for _street: int in range(4):
		# One of these is accepted for every passive turn. A rejected action must
		# preserve the turn, so the following command completes it deterministically.
		io.queue_line("call").queue_line("check")
	var match_instance := TournamentMatch.new(_config(2, 100, 5, 10), _showdown_agents())

	var status := CliCommandLoop.new(io).run_match(match_instance, 0)
	var view: GameView = match_instance.get_view_for(0)

	assert_eq(status, CliCommandLoop.Status.EOF)
	assert_true(io.contains_write("Hand 1 - hand_end"))
	assert_true(io.contains_write("Hand 1 - flop"))
	assert_true(io.contains_write("Hand 1 - turn"))
	assert_true(io.contains_write("Hand 1 - river"))
	assert_true(io.contains_write("Hand 1 - hand_end"))
	assert_true(io.count_writes_containing("Board: [ ") >= 4)
	assert_true(io.contains_write("Showdown:"))
	assert_true(io.contains_write("Awards:"))


func test_match_factory_uses_resolved_non_default_configuration() -> void:
	var config := _config(4, 240, 12, 24)
	var factory := CliMatchFactoryScript.new()
	var match_instance: TournamentMatch = factory.create(config)

	var result: StepResult = match_instance.start()
	var view: GameView = match_instance.get_view_for(factory.human_seat(config))

	assert_ne(result.status, StepResult.Status.ERROR)
	assert_eq(view.seats.size(), 4)
	assert_eq(view.pot_amount, 36)
	assert_eq(view.hero_hole_cards.size(), 2)
	assert_eq(view.seats[view.small_blind_seat].bet_this_round, 12)
	assert_eq(view.seats[view.big_blind_seat].bet_this_round, 24)
	assert_true(view.seats[factory.human_seat(config)].is_human)
	var diagnostics: PackedStringArray = factory.diagnostics(config)
	assert_has(diagnostics, "Bot roster version: curated_v1")
	assert_has(diagnostics, "Legacy heuristic models: not included")
	var has_selected_profile_ids := false
	for line: String in diagnostics:
		has_selected_profile_ids = (
			has_selected_profile_ids or line.begins_with("Selected bot profile IDs: ")
		)
	assert_true(has_selected_profile_ids)
	var selected_profiles: Dictionary[String, bool] = {}
	for line: String in diagnostics:
		assert_false(line.contains("parameters"))
		assert_false(line.contains("rng"))
		if line.contains("profile="):
			selected_profiles[line.get_slice("profile=", 1)] = true
	assert_eq(selected_profiles.size(), config.player_count - 1)
	for model_family: String in _selected_model_families(diagnostics):
		assert_eq(model_family, "strategy_parameterized")


func test_match_factory_selects_the_legacy_mixed_roster_only_when_enabled() -> void:
	var factory := CliMatchFactoryScript.new()
	var default_diagnostics := factory.diagnostics(_config(6, 240, 12, 24))
	var legacy_diagnostics := factory.diagnostics(_config(6, 240, 12, 24, true))
	var legacy_match := factory.create(_config(6, 240, 12, 24, true))

	assert_has(default_diagnostics, "Legacy heuristic models: not included")
	assert_has(legacy_diagnostics, "Legacy heuristic models: included")
	assert_eq(_diagnostic_profile_count(legacy_diagnostics), 5)
	assert_ne(legacy_match.start().status, StepResult.Status.ERROR)
	var human_view := legacy_match.get_view_for(0)
	assert_eq(human_view.hero_hole_cards.size(), 2)
	assert_true(human_view.revealed_hole_cards.is_empty())
	for line: String in legacy_diagnostics:
		assert_false(line.contains("experimental"))


func test_match_factory_legacy_selection_has_the_shared_family_split_for_every_table_size() -> void:
	var factory := CliMatchFactoryScript.new()
	for player_count: int in range(2, 10):
		var config := _config(player_count, 240, 12, 24, true)
		var model_families := _selected_model_families(factory.diagnostics(config))
		var legacy_count := 0
		for model_family: String in model_families:
			if model_family != "strategy_parameterized":
				legacy_count += 1
		assert_eq(model_families.size(), player_count - 1)
		assert_eq(legacy_count, player_count / 2)
		assert_eq(factory.human_seat(config), 0)


func test_match_factory_repeats_legacy_profile_selection_for_a_fixed_seed() -> void:
	var factory := CliMatchFactoryScript.new()
	var first_config := _config(7, 240, 12, 24, true)
	var second_config := _config(7, 240, 12, 24, true)

	assert_eq(factory.diagnostics(first_config), factory.diagnostics(second_config))


func test_default_and_non_default_tables_mark_exactly_one_human_across_snapshots() -> void:
	for count: int in [TournamentConfig.new().player_count, 3]:
		var io := FakeCliIO.new()
		io.queue_line("raise 20")
		var match_instance := TournamentMatch.new(
			_config(count, 1000, 5, 10), _folding_agents(count)
		)

		CliCommandLoop.new(io).run_match(match_instance, 0)

		assert_true(io.count_writes_containing("Hand 1 -") >= 2)
		assert_true(io.count_writes_containing("(you)") >= io.count_writes_containing("Hand 1 -"))
		assert_true(io.count_writes_containing("Seat 0: Player 1 (you) -") >= 1)
		for seat: int in range(1, count):
			assert_eq(io.count_writes_containing("Seat %d: Player %d (you)" % [seat, seat + 1]), 0)


func test_cli_runs_seeded_short_stack_tournament_to_a_displayed_winner() -> void:
	var config := _config(3, 20, 5, 10)
	var factory := CliMatchFactoryScript.new()
	var io := FakeCliIO.new()
	for _input_pair: int in range(400):
		io.queue_line("fold").queue_blank_line()
	var match_instance: TournamentMatch = factory.create(config)

	var status := CliCommandLoop.new(io).run_match(match_instance, factory.human_seat(config))

	assert_eq(status, CliCommandLoop.Status.EOF)
	assert_eq(match_instance.state, TournamentMatch.State.FINISHED)
	assert_eq(match_instance.end_reason, &"winner")
	assert_true(match_instance.winner_seat >= 0)
	assert_true(io.count_writes_containing("Hand 2 -") >= 1)
	assert_true(io.contains_write("Tournament winner: seat %d" % match_instance.winner_seat))


func _config(
	count: int, stack: int, small_blind: int, big_blind: int, use_legacy_models: bool = false
) -> ResolvedTournamentConfig:
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 4242
	var overrides := StartupOverrides.new()
	overrides.set_player_count(count)
	overrides.set_starting_stack(stack)
	overrides.set_small_blind(small_blind)
	overrides.set_big_blind(big_blind)
	overrides.set_use_legacy_models(use_legacy_models)
	return ConfigResolver.new().resolve(defaults, overrides).get_config()


func _folding_agents(count: int) -> Dictionary[int, Agent]:
	var agents: Dictionary[int, Agent] = {0: HumanAgent.new()}
	for seat: int in range(1, count):
		agents[seat] = ScriptedAgent.new([PlayerAction.call_action(), PlayerAction.fold_action()])
	return agents


func _passive_agents() -> Dictionary[int, Agent]:
	return {
		0: HumanAgent.new(),
		1: ScriptedAgent.new([PlayerAction.call_action(), PlayerAction.check_action()]),
	}


func _showdown_agents() -> Dictionary[int, Agent]:
	return {
		0: HumanAgent.new(),
		1:
		(
			ScriptedAgent
			. new(
				[
					PlayerAction.check_action(),
					PlayerAction.check_action(),
					PlayerAction.check_action(),
					PlayerAction.check_action(),
				]
			)
		),
	}


func _assert_no_bot_cards_are_rendered(io: FakeCliIO, match_instance: TournamentMatch) -> void:
	var hero_cards: PackedStringArray = []
	for card: CardData in match_instance.get_view_for(0).hero_hole_cards:
		hero_cards.append(CliCardFormatterScript.format_card(card))
	for write: String in io.writes:
		if not write.begins_with("Your cards:"):
			continue
		assert_true(write.begins_with("Your cards: [ "))
		for token: String in write.trim_prefix("Your cards: [ ").trim_suffix(" ]").split(" | "):
			assert_true(token in hero_cards)
			assert_false(token.contains(":"))


func _diagnostic_profile_count(diagnostics: PackedStringArray) -> int:
	var profile_ids: Dictionary[String, bool] = {}
	for line: String in diagnostics:
		if line.contains("profile="):
			profile_ids[line.get_slice("profile=", 1)] = true
	return profile_ids.size()


func _selected_model_families(diagnostics: PackedStringArray) -> PackedStringArray:
	for line: String in diagnostics:
		if line.begins_with("Selected bot model families: "):
			return line.trim_prefix("Selected bot model families: ").split(",", false)
	return PackedStringArray()
