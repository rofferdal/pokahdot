class_name CliStartupArguments
extends RefCounted

## Strict CLI-only options supplied after Godot's `--` separator.

const USE_LEGACY_MODELS_FLAG := "--use-legacy-models"
const NUMBER_OPTIONS: PackedStringArray = [
	"--players", "--stack", "--small-blind", "--big-blind", "--seed"
]

var show_help: bool = false
var configure: bool = false
var legacy_models: bool = false
var errors: PackedStringArray = []
var _values: Dictionary[String, int] = {}


static func parse(arguments: PackedStringArray) -> CliStartupArguments:
	var result := CliStartupArguments.new()
	var seen: Dictionary[String, bool] = {}
	var index := 0
	while index < arguments.size():
		var option := arguments[index]
		if seen.has(option):
			result.errors.append("Duplicate option: %s" % option)
			return result
		seen[option] = true
		match option:
			"--help":
				result.show_help = true
			"--configure":
				result.configure = true
			USE_LEGACY_MODELS_FLAG:
				result.legacy_models = true
			_:
				if option not in NUMBER_OPTIONS:
					result.errors.append("Unknown option: %s" % option)
					return result
				index += 1
				if (
					index >= arguments.size()
					or not IntegerBounds.fits_signed_64_bit_text(arguments[index])
				):
					result.errors.append("%s requires a signed 64-bit whole number." % option)
					return result
				result._values[option] = arguments[index].to_int()
		index += 1
	return result


func apply_to(defaults: TournamentConfig) -> TournamentConfig:
	var configured := defaults.duplicate(true) as TournamentConfig
	for option: String in _values:
		match option:
			"--players":
				configured.player_count = _values[option]
			"--stack":
				configured.starting_stack = _values[option]
			"--small-blind":
				configured.small_blind = _values[option]
			"--big-blind":
				configured.big_blind = _values[option]
			"--seed":
				configured.rng_seed = _values[option]
	configured.use_legacy_models = legacy_models or defaults.use_legacy_models
	return configured


static func usage() -> String:
	return (
		"Usage: godot --headless --path . --script res://scripts/cli/cli_app.gd -- [options]\n"
		+ "Options: --help --configure --players 2..9 --stack 1..1000000 "
		+ "--small-blind 1..1000000 --big-blind 1..1000000 --seed INTEGER "
		+ "--use-legacy-models\n"
		+ "Seed 0 chooses a time seed; other signed 64-bit seeds reproduce play. "
		+ "Press Enter to start; --configure opens setup directly.\n"
		+ "Type rules at setup or play prompts to read Pokahdot tournament rules."
	)


static func use_legacy_models(arguments: PackedStringArray) -> bool:
	return USE_LEGACY_MODELS_FLAG in arguments
