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
		if IntegerBounds.fits_signed_64_bit_text(parts[1]) and parts[1].to_int() > 0:
			var kind := PlayerAction.Kind.BET if parts[0] == "bet" else PlayerAction.Kind.RAISE
			return CliCommand.new(
				CliCommand.Kind.ACTION, normalized, PlayerAction.new(kind, parts[1].to_int())
			)
	return CliCommand.new(CliCommand.Kind.UNKNOWN, normalized)


func _parse_simple_command(normalized: String) -> CliCommand:
	var commands: Dictionary[String, CliCommand.Kind] = {
		"state": CliCommand.Kind.STATE,
		"history": CliCommand.Kind.HISTORY,
		"continue": CliCommand.Kind.CONTINUE,
		"help": CliCommand.Kind.HELP,
		"quit": CliCommand.Kind.QUIT,
		"exit": CliCommand.Kind.QUIT,
		"potbet": CliCommand.Kind.POT_BET,
		"potraise": CliCommand.Kind.POT_RAISE,
	}
	return CliCommand.new(commands[normalized], normalized) if commands.has(normalized) else null
