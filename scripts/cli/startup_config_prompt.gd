class_name StartupConfigPrompt
extends RefCounted

const CONFIGURE_COMMANDS: Array[String] = ["configure", "c"]
const QUIT_COMMANDS: Array[String] = ["quit", "exit"]
const SHORT_STACK_COMMANDS: Array[String] = ["short-stack", "short"]
const SHORT_STACK_PLAYER_COUNT: int = 3
const SHORT_STACK_STARTING_STACK: int = 20
const SHORT_STACK_SMALL_BLIND: int = 5
const SHORT_STACK_BIG_BLIND: int = 10
const SHORT_STACK_RNG_SEED: int = 991

var _io: CliIO
var _resolver: ConfigResolver


func _init(io: CliIO, resolver: ConfigResolver = null) -> void:
	_io = io
	_resolver = resolver if resolver != null else ConfigResolver.new()


# gdlint: disable=max-returns
func run(
	defaults: TournamentConfig, use_legacy_models: bool = false, configure: bool = false
) -> StartupPromptResult:
	_io.write_line("Pokahdot tournament setup")
	_io.write_line(_defaults_summary(defaults))
	if configure:
		return _run_custom_configuration(defaults, use_legacy_models)

	while true:
		_io.write_text("Press Enter to start, or type 'configure', 'short-stack', or 'quit': ")
		var input: CliInputLine = _io.read_line()
		if input.is_eof:
			_io.write_line("Input closed before startup completed.")
			return StartupPromptResult.new(StartupPromptResult.Status.EOF)

		var command := input.text.strip_edges().to_lower()
		if command.is_empty() or command == "start":
			return _resolve_and_report(defaults, _startup_overrides(use_legacy_models))
		if command in CONFIGURE_COMMANDS:
			return _run_custom_configuration(defaults, use_legacy_models)
		if command in SHORT_STACK_COMMANDS:
			return _resolve_short_stack_configuration(defaults, use_legacy_models)
		if command in QUIT_COMMANDS:
			_io.write_line("Startup cancelled.")
			return StartupPromptResult.new(StartupPromptResult.Status.QUIT)

		_io.write_line("Unknown setup option. Use Enter, configure, short-stack, or quit.")

	return StartupPromptResult.new(StartupPromptResult.Status.ERROR)


func _run_custom_configuration(
	defaults: TournamentConfig, use_legacy_models: bool
) -> StartupPromptResult:
	var edited := defaults.duplicate(true) as TournamentConfig
	var fields: Array[StringName] = [
		&"player_count", &"starting_stack", &"small_blind", &"big_blind"
	]
	var labels: Dictionary[StringName, String] = {
		&"player_count": "Players",
		&"starting_stack": "Starting stack",
		&"small_blind": "Small blind",
		&"big_blind": "Big blind",
	}
	while true:
		for field: StringName in fields:
			var value := _read_optional_integer(labels[field], int(edited.get(field)))
			var early_result := _handle_non_value_status(value)
			if early_result != null:
				return early_result
			if value.has_value:
				edited.set(field, value.value)
		var resolution := _resolver.resolve(edited, _startup_overrides(use_legacy_models))
		if resolution.is_ok():
			return _report_ready(resolution.get_config())
		_report_errors(resolution.get_errors())
		fields.clear()
		for error: ConfigError in resolution.get_errors():
			if not labels.has(error.field):
				return StartupPromptResult.new(StartupPromptResult.Status.ERROR)
			if error.field not in fields:
				fields.append(error.field)
		_io.write_line("Correct the invalid fields; other edits are retained.")
	return StartupPromptResult.new(StartupPromptResult.Status.ERROR)


func _resolve_and_report(
	defaults: TournamentConfig, overrides: StartupOverrides
) -> StartupPromptResult:
	var resolution: ConfigResolution = _resolver.resolve(defaults, overrides)
	if not resolution.is_ok():
		_report_errors(resolution.get_errors())
		return StartupPromptResult.new(StartupPromptResult.Status.ERROR)
	return _report_ready(resolution.get_config())


func _resolve_short_stack_configuration(
	defaults: TournamentConfig, use_legacy_models: bool = false
) -> StartupPromptResult:
	var deterministic_defaults := defaults.duplicate(true) as TournamentConfig
	if deterministic_defaults == null:
		_io.write_line("Unable to prepare the short-stack manual-test configuration.")
		return StartupPromptResult.new(StartupPromptResult.Status.ERROR)
	deterministic_defaults.rng_seed = SHORT_STACK_RNG_SEED
	var overrides := _startup_overrides(use_legacy_models)
	overrides.set_player_count(SHORT_STACK_PLAYER_COUNT)
	overrides.set_starting_stack(SHORT_STACK_STARTING_STACK)
	overrides.set_small_blind(SHORT_STACK_SMALL_BLIND)
	overrides.set_big_blind(SHORT_STACK_BIG_BLIND)
	_io.write_line("Short-stack manual-test preset selected (seed %d)." % SHORT_STACK_RNG_SEED)
	return _resolve_and_report(deterministic_defaults, overrides)


func _report_ready(config: ResolvedTournamentConfig) -> StartupPromptResult:
	_io.write_line("Tournament configuration:")
	_io.write_line("  Players: %d" % config.player_count)
	_io.write_line("  Starting stack: %d" % config.starting_stack)
	_io.write_line("  Blinds: %d/%d" % [config.small_blind, config.big_blind])
	_io.write_line(
		(
			"  Legacy heuristic models: %s"
			% ("included" if config.use_legacy_models else "not included")
		)
	)
	return StartupPromptResult.new(StartupPromptResult.Status.READY, config)


func _report_errors(errors: Array[ConfigError]) -> void:
	_io.write_line("Invalid tournament configuration:")
	for validation_error: ConfigError in errors:
		_io.write_line("  %s: %s" % [validation_error.field, validation_error.message])


func _defaults_summary(defaults: TournamentConfig) -> String:
	return (
		"Defaults: %d players, %d chips, blinds %d/%d"
		% [
			defaults.player_count,
			defaults.starting_stack,
			defaults.small_blind,
			defaults.big_blind,
		]
	)


func _startup_overrides(use_legacy_models: bool) -> StartupOverrides:
	var overrides := StartupOverrides.new()
	overrides.set_use_legacy_models(use_legacy_models)
	return overrides


func _read_optional_integer(label: String, default_value: int) -> OptionalIntegerInput:
	while true:
		_io.write_text("%s [%d]: " % [label, default_value])
		var input: CliInputLine = _io.read_line()
		if input.is_eof:
			_io.write_line("Input closed before startup completed.")
			return OptionalIntegerInput.eof()

		var value_text := input.text.strip_edges()
		if value_text.to_lower() in QUIT_COMMANDS:
			_io.write_line("Startup cancelled.")
			return OptionalIntegerInput.quit()
		if value_text.is_empty():
			return OptionalIntegerInput.omitted()
		if not IntegerBounds.fits_signed_64_bit_text(value_text):
			_io.write_line("Enter a whole number, leave blank for the default, or type quit.")
			continue
		return OptionalIntegerInput.with_value(value_text.to_int())

	return OptionalIntegerInput.eof()


func _handle_non_value_status(input: OptionalIntegerInput) -> StartupPromptResult:
	if input.status == OptionalIntegerInput.Status.EOF:
		return StartupPromptResult.new(StartupPromptResult.Status.EOF)
	if input.status == OptionalIntegerInput.Status.QUIT:
		return StartupPromptResult.new(StartupPromptResult.Status.QUIT)
	return null


class OptionalIntegerInput:
	extends RefCounted

	enum Status {
		OMITTED,
		VALUE,
		QUIT,
		EOF,
	}

	var status: Status
	var value: int
	var has_value: bool:
		get:
			return status == Status.VALUE

	func _init(input_status: Status, input_value: int = 0) -> void:
		status = input_status
		value = input_value

	static func omitted() -> OptionalIntegerInput:
		return OptionalIntegerInput.new(Status.OMITTED)

	static func with_value(value: int) -> OptionalIntegerInput:
		return OptionalIntegerInput.new(Status.VALUE, value)

	static func quit() -> OptionalIntegerInput:
		return OptionalIntegerInput.new(Status.QUIT)

	static func eof() -> OptionalIntegerInput:
		return OptionalIntegerInput.new(Status.EOF)
