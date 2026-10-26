class_name CommandParser
extends RefCounted

## Maps terminal text to shell commands or core PlayerAction values.


func parse(input: String) -> CliCommand:
	var normalized := input.strip_edges().to_lower()
	if normalized.is_empty():
		return CliCommand.new(CliCommand.Kind.EMPTY)
	var simple_command: CliCommand = _parse_simple_command(normalized)
	if simple_command != null:
		return simple_command
	var parts: PackedStringArray = normalized.split(" ", false)
	var fixed_actions: Dictionary[String, PlayerAction.Kind] = {
		"fold": PlayerAction.Kind.FOLD,
		"check": PlayerAction.Kind.CHECK,
		"call": PlayerAction.Kind.CALL,
		"allin": PlayerAction.Kind.ALL_IN,
	}
	if parts.size() == 1 and fixed_actions.has(parts[0]):
		return CliCommand.new(
			CliCommand.Kind.ACTION, normalized, PlayerAction.new(fixed_actions[parts[0]])
		)
	if parts.size() == 2 and (parts[0] == "bet" or parts[0] == "raise"):
		if parts[1].is_valid_int() and int(parts[1]) > 0:
			var kind := PlayerAction.Kind.BET if parts[0] == "bet" else PlayerAction.Kind.RAISE
			return CliCommand.new(
				CliCommand.Kind.ACTION, normalized, PlayerAction.new(kind, int(parts[1]))
			)
	return CliCommand.new(CliCommand.Kind.UNKNOWN, normalized)


func _parse_simple_command(normalized: String) -> CliCommand:
	if normalized == "help":
		return CliCommand.new(CliCommand.Kind.HELP, normalized)
	if normalized == "quit" or normalized == "exit":
		return CliCommand.new(CliCommand.Kind.QUIT, normalized)
	if normalized == "potbet":
		return CliCommand.new(CliCommand.Kind.POT_BET, normalized)
	if normalized == "potraise":
		return CliCommand.new(CliCommand.Kind.POT_RAISE, normalized)
	return null
