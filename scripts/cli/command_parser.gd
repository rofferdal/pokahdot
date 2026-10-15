class_name CommandParser
extends RefCounted

## Parses only shell-level commands. Poker actions are added in later milestones.


func parse(input: String) -> CliCommand:
	var normalized := input.strip_edges().to_lower()
	if normalized.is_empty():
		return CliCommand.new(CliCommand.Kind.EMPTY)
	if normalized == "help":
		return CliCommand.new(CliCommand.Kind.HELP, normalized)
	if normalized == "quit" or normalized == "exit":
		return CliCommand.new(CliCommand.Kind.QUIT, normalized)
	return CliCommand.new(CliCommand.Kind.UNKNOWN, normalized)
