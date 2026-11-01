extends SceneTree

const BENCHMARK := preload("res://tests/support/bot_raise_response_benchmark.gd")


func _initialize() -> void:
	var options: Dictionary = {}
	var args := OS.get_cmdline_user_args()
	for index: int in range(0, args.size(), 2):
		if index + 1 >= args.size():
			printerr("Expected --output PATH --seed-start INTEGER [--focal-limit INTEGER].")
			quit(1)
			return
		options[args[index]] = args[index + 1]
	var output: String = options.get("--output", "")
	var seed_text: String = options.get("--seed-start", "")
	if output.is_empty() or not seed_text.is_valid_int() or int(seed_text) <= 0:
		printerr("A new output path and positive --seed-start are required.")
		quit(1)
		return
	if FileAccess.file_exists(output):
		printerr("Refusing to overwrite benchmark evidence: ", output)
		quit(1)
		return
	var result: Dictionary = BENCHMARK.run_cohort(
		int(seed_text), int(options.get("--focal-limit", "15"))
	)
	result["policy_version"] = String(StrategyDecisionModel.POLICY_VERSION)
	result["engine_version"] = Engine.get_version_info().string
	for path: String in [
		"res://scripts/core/agents/strategy_street_context.gd",
		"res://scripts/core/agents/strategy_decision_diagnostics.gd",
		"res://scripts/core/public_action_record.gd",
		"res://scripts/core/hand_controller.gd",
		"res://scripts/core/agents/strategy_decision_model_parameters.gd",
	]:
		result.source_hashes[path] = FileAccess.get_sha256(path)
	result["controlled_published"] = BENCHMARK.controlled_round(true, 1)
	result["controlled_loose"] = BENCHMARK.controlled_round(false, 191)
	result["controlled_value"] = BENCHMARK.controlled_round(false, 1, true)
	if DirAccess.make_dir_recursive_absolute(output.get_base_dir()) != OK:
		printerr("Cannot create evidence directory.")
		quit(1)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write benchmark evidence.")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	var valid: bool = result.invalid_actions == 0
	for tournament: Dictionary in result.tournaments:
		valid = (
			valid
			and tournament.completed
			and tournament.chip_total == tournament.expected_chip_total
		)
	print(
		"BFCR: ",
		result.tournaments.size(),
		" tournaments; ",
		result.decisions,
		" decisions; ",
		result.responses.size(),
		" responses; ",
		result.long_chains,
		" long raise chains; valid=",
		valid
	)
	quit(0 if valid else 1)
