extends "res://tests/support/poker_gut_test.gd"

const Reference := preload("res://scripts/cli/cli_rules_reference.gd")
const Document := preload("res://resources/presentation/tournament_rules.tres")


func test_rules_parser_is_exact_trimmed_case_insensitive_and_informational() -> void:
	for input: String in ["rules", "  RuLeS \t\n"]:
		var command: CliCommand = CommandParser.new().parse(input)
		assert_eq(command.kind, CliCommand.Kind.RULES)
		assert_eq(command.text, "rules")
		assert_null(command.action)
	for input: String in ["rules 1", "rules now", "rules\tnow", "--rules"]:
		assert_eq(CommandParser.new().parse(input).kind, CliCommand.Kind.UNKNOWN)


func test_cli_reference_uses_exact_shared_plain_text_and_reports_invalid_documents() -> void:
	var io := FakeCliIO.new()
	Reference.write_to(io)
	assert_eq(io.writes, [Document.render_plain_text().text])
	io.writes.clear()
	Reference.write_to(io, TournamentRulesDocument.new())
	assert_eq(io.writes.size(), 1)
	assert_string_contains(io.writes[0], "Unable to display tournament rules:")
	assert_false(io.contains_write(Document.render_plain_text().text))
	io.writes.clear()
	Reference.write_to(io, null)
	assert_eq(io.writes, ["Unable to display tournament rules: document is missing."])


func test_shell_rules_repeats_with_argument_recovery_and_quit() -> void:
	var io := FakeCliIO.new()
	io.queue_line(" rules ").queue_line("rules now").queue_line("RULES").queue_line("quit")
	assert_eq(CliCommandLoop.new(io).run(), CliCommandLoop.Status.QUIT)
	assert_eq(io.count_writes_containing(Document.render_plain_text().text), 2)
	assert_eq(io.count_writes_containing("Unknown command 'rules now'"), 1)
	assert_eq(io.count_writes_containing("No active tournament"), 0)


func test_rules_at_human_turn_and_between_hands_never_request_view_or_advance() -> void:
	for phase: StepResult.Status in [
		StepResult.Status.WAITING_FOR_HUMAN, StepResult.Status.HAND_COMPLETED
	]:
		var io := FakeCliIO.new()
		io.queue_line("rules").queue_line("RuLeS").queue_line("rules now").queue_line("quit")
		var game := InspectionMatch.new(phase)
		assert_eq(
			CliCommandLoop.new(io, null, null, true).run_match(game, 0), CliCommandLoop.Status.QUIT
		)
		assert_eq(io.count_writes_containing(Document.render_plain_text().text), 2)
		assert_eq(game.starts, 1)
		assert_eq(game.views, 2, "Only initial and quit render may request views")
		assert_eq(game.actions, 0)
		assert_eq(game.advances, 0)
		assert_eq(game.quits, 1)


func test_completed_match_exits_without_consuming_rules_input() -> void:
	var io := FakeCliIO.new()
	io.queue_line("rules")
	var game := InspectionMatch.new(StepResult.Status.TOURNAMENT_FINISHED)
	assert_eq(CliCommandLoop.new(io).run_match(game, 0), CliCommandLoop.Status.COMPLETED)
	assert_eq(io.read_line().text, "rules")
	assert_eq(io.count_writes_containing(Document.render_plain_text().text), 0)


func test_rules_at_setup_does_not_resolve_before_start_or_change_defaults() -> void:
	var io := FakeCliIO.new()
	io.queue_line("RuLeS").queue_line("rules now").queue_line("rules").queue_line("quit")
	var resolver := CountingResolver.new()
	var defaults := TournamentConfig.new()
	var result := StartupConfigPrompt.new(io, resolver).run(defaults, true)
	assert_eq(result.status, StartupPromptResult.Status.QUIT)
	assert_null(result.config)
	assert_eq(resolver.resolutions, 0)
	assert_eq(io.count_writes_containing(Document.render_plain_text().text), 2)
	assert_eq(io.count_writes_containing("Unknown setup option"), 1)
	assert_eq(defaults.player_count, 6)
	assert_false(defaults.use_legacy_models)


func test_rules_during_partial_and_invalid_configuration_repeats_same_field_with_edits() -> void:
	var io := FakeCliIO.new()
	for input: String in ["configure", "3", "rules", "rules 1", "200", "20", "10", "rules", "5"]:
		io.queue_line(input)
	var resolver := CountingResolver.new()
	var defaults := TournamentConfig.new()
	var result := StartupConfigPrompt.new(io, resolver).run(defaults, true)
	assert_true(result.is_ready())
	assert_eq(result.config.player_count, 3)
	assert_eq(result.config.starting_stack, 200)
	assert_eq(result.config.small_blind, 5)
	assert_eq(result.config.big_blind, 10)
	assert_true(result.config.use_legacy_models)
	assert_eq(resolver.resolutions, 2, "Only completed numeric edits trigger validation")
	assert_eq(io.count_writes_containing("Starting stack [1000]:"), 3)
	assert_eq(io.count_writes_containing("Small blind [20]:"), 2)
	assert_eq(io.count_writes_containing(Document.render_plain_text().text), 2)
	assert_eq(defaults.starting_stack, 1000)
	assert_eq(defaults.small_blind, 5)


func test_rules_at_numeric_prompt_keeps_eof_exit_without_resolving_configuration() -> void:
	var io := FakeCliIO.new()
	io.queue_line("rules").queue_eof()
	var resolver := CountingResolver.new()
	var result := StartupConfigPrompt.new(io, resolver).run(TournamentConfig.new(), false, true)
	assert_eq(result.status, StartupPromptResult.Status.EOF)
	assert_null(result.config)
	assert_eq(resolver.resolutions, 0)
	assert_true(io.contains_write(Document.render_plain_text().text))


func test_rules_is_discoverable_in_help_and_usage_without_a_new_flag() -> void:
	var io := FakeCliIO.new()
	io.queue_line("help").queue_line("quit")
	CliCommandLoop.new(io).run()
	assert_true(io.contains_write("  rules - read Pokahdot tournament rules"))
	assert_string_contains(CliStartupArguments.usage(), "Type rules at setup or play prompts")
	assert_false(CliStartupArguments.parse(PackedStringArray(["--rules"])).errors.is_empty())


class CountingResolver:
	extends ConfigResolver

	var resolutions: int = 0

	func resolve(defaults: TournamentConfig, overrides: StartupOverrides) -> ConfigResolution:
		resolutions += 1
		return super.resolve(defaults, overrides)


class InspectionMatch:
	extends TournamentMatch

	var phase: StepResult.Status
	var starts: int = 0
	var actions: int = 0
	var advances: int = 0
	var views: int = 0
	var quits: int = 0

	func _init(initial_phase: StepResult.Status) -> void:
		super(null, {})
		phase = initial_phase

	func start(_max_transitions: int = 32) -> StepResult:
		starts += 1
		return StepResult.new(phase)

	func advance_until_blocked(_max_transitions: int = 32) -> StepResult:
		advances += 1
		return StepResult.new(phase)

	func submit_human_action(_action: PlayerAction) -> StepResult:
		actions += 1
		return StepResult.new(phase)

	func get_view_for(_seat: int) -> GameView:
		views += 1
		return null

	func request_quit() -> StepResult:
		quits += 1
		return StepResult.new(StepResult.Status.TOURNAMENT_FINISHED)
