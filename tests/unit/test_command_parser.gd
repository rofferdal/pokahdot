extends "res://tests/support/poker_gut_test.gd"


func test_parser_normalizes_whitespace_and_case_for_help() -> void:
	var command := CommandParser.new().parse("  HeLp  ")

	assert_eq(command.kind, CliCommand.Kind.HELP)
	assert_eq(command.text, "help")


func test_parser_normalizes_whitespace_and_case_for_quit_and_exit() -> void:
	var parser := CommandParser.new()
	var quit_command := parser.parse("  QUIT ")
	var exit_command := parser.parse("\texit\n")

	assert_eq(quit_command.kind, CliCommand.Kind.QUIT)
	assert_eq(quit_command.text, "quit")
	assert_eq(exit_command.kind, CliCommand.Kind.QUIT)
	assert_eq(exit_command.text, "exit")


func test_parser_maps_whitespace_only_input_to_empty() -> void:
	var command := CommandParser.new().parse(" \t\n ")

	assert_eq(command.kind, CliCommand.Kind.EMPTY)
	assert_eq(command.text, "")


func test_parser_preserves_normalized_unknown_command_text() -> void:
	var command := CommandParser.new().parse("  deal NOW  ")

	assert_eq(command.kind, CliCommand.Kind.UNKNOWN)
	assert_eq(command.text, "deal now")


func test_parser_maps_fixed_poker_actions() -> void:
	var expected: Dictionary[String, PlayerAction.Kind] = {
		"fold": PlayerAction.Kind.FOLD,
		"check": PlayerAction.Kind.CHECK,
		"call": PlayerAction.Kind.CALL,
		"allin": PlayerAction.Kind.ALL_IN,
	}
	for text: String in expected:
		var command := CommandParser.new().parse(text)
		assert_eq(command.kind, CliCommand.Kind.ACTION)
		assert_eq(command.action.kind, expected[text])
		assert_eq(command.action.amount, 0)


func test_parser_maps_bet_and_raise_target_totals() -> void:
	var bet := CommandParser.new().parse(" BET 25 ")
	var raise := CommandParser.new().parse("raise 60")

	assert_eq(bet.kind, CliCommand.Kind.ACTION)
	assert_eq(bet.action.kind, PlayerAction.Kind.BET)
	assert_eq(bet.action.amount, 25)
	assert_eq(raise.kind, CliCommand.Kind.ACTION)
	assert_eq(raise.action.kind, PlayerAction.Kind.RAISE)
	assert_eq(raise.action.amount, 60)


func test_parser_maps_exact_pot_commands_to_explicit_intents() -> void:
	var pot_bet_kind: int = CliCommand.Kind.keys().find("POT_BET")
	var pot_raise_kind: int = CliCommand.Kind.keys().find("POT_RAISE")
	var pot_bet := CommandParser.new().parse("  POTBET  ")
	var pot_raise := CommandParser.new().parse("potraise")

	assert_gte(pot_bet_kind, 0)
	assert_gte(pot_raise_kind, 0)
	assert_eq(pot_bet.kind, pot_bet_kind)
	assert_eq(pot_bet.text, "potbet")
	assert_null(pot_bet.action)
	assert_eq(pot_raise.kind, pot_raise_kind)
	assert_eq(pot_raise.text, "potraise")
	assert_null(pot_raise.action)


func test_parser_rejects_numeric_arguments_for_pot_commands() -> void:
	for text: String in ["potbet 20", "potraise 30"]:
		assert_eq(CommandParser.new().parse(text).kind, CliCommand.Kind.UNKNOWN, text)


func test_parser_rejects_missing_non_integer_and_non_positive_amounts() -> void:
	for text: String in ["bet", "raise nope", "bet 0", "raise -5", "call 10"]:
		assert_eq(CommandParser.new().parse(text).kind, CliCommand.Kind.UNKNOWN, text)
