extends SceneTree

const BANK := preload("res://tests/support/strategy_aggression_decision_bank.gd")
const TOURNAMENTS := preload("res://tests/support/strategy_aggression_tournament_benchmark.gd")


func _initialize() -> void:
	var options: Dictionary = {}
	var args := OS.get_cmdline_user_args()
	for index: int in range(0, args.size(), 2):
		if index + 1 >= args.size():
			printerr("Expected --output PATH [--seed-start INTEGER] [--samples INTEGER].")
			quit(1)
			return
		options[args[index]] = args[index + 1]
	var output: String = options.get("--output", "")
	var seed_text: String = options.get("--seed-start", "151001")
	var sample_text: String = options.get("--samples", "32")
	var mode: String = options.get("--mode", "bank")
	var focal_text: String = options.get("--focal-limit", "15")
	if output.is_empty() or not seed_text.is_valid_int() or not sample_text.is_valid_int():
		printerr("Output, integer seed and sample count are required.")
		quit(1)
		return
	if (
		int(seed_text) <= 0
		or int(sample_text) < 1
		or int(sample_text) > 256
		or mode not in ["bank", "tournaments"]
		or not focal_text.is_valid_int()
		or int(focal_text) < 1
		or int(focal_text) > 15
	):
		printerr("Seed must be positive and sample count must be 1–256.")
		quit(1)
		return
	if FileAccess.file_exists(output):
		printerr("Refusing to overwrite evidence: ", output)
		quit(1)
		return
	var result: Dictionary = (
		BANK.run_bank(int(seed_text), int(sample_text))
		if mode == "bank"
		else TOURNAMENTS.run_cohort(int(seed_text), int(focal_text))
	)
	result.source_hashes["res://tests/manual/strategy_aggression_benchmark.gd"] = (
		FileAccess.get_sha256("res://tests/manual/strategy_aggression_benchmark.gd")
	)
	var directory: String = output.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory if not directory.is_empty() else ".") != OK:
		printerr("Cannot create evidence directory.")
		quit(1)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write decision-bank evidence.")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("BFCR aggression benchmark: ", mode, "; policy=", result.policy_version)
	var valid: bool = true
	if mode == "bank":
		for row: Dictionary in result.rows:
			valid = valid and row.valid
	else:
		for tournament: Dictionary in result.tournaments:
			valid = valid and tournament.completed and tournament.error.is_empty()
			valid = (
				valid
				and tournament.invalid_actions == 0
				and tournament.chip_total == tournament.expected_chip_total
			)
	quit(0 if valid else 1)
