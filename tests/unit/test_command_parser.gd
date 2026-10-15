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
