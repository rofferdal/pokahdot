extends SceneTree

## Dedicated non-interactive simulation CLI process entry point.
##
## This adapter never invokes the interactive CLI, prompts, or stdin. It only
## converts command-line/filesystem data into typed simulation contracts.

const ARGUMENT_PARSER_SCRIPT := preload(
	"res://scripts/simulation/simulation_cli_argument_parser.gd"
)
const MANIFEST_SCRIPT := preload("res://scripts/simulation/simulation_manifest.gd")
const REPORT_SCRIPT := preload("res://scripts/simulation/simulation_report.gd")
const PROVENANCE_SCRIPT := preload("res://scripts/simulation/simulation_provenance.gd")
const MANIFEST_GENERATOR_SCRIPT := preload(
	"res://scripts/simulation/simulation_manifest_generator.gd"
)
const ROSTER_MANIFEST_SETTINGS_SCRIPT := preload(
	"res://scripts/simulation/simulation_roster_manifest_settings.gd"
)

const EXIT_OK: int = 0
const EXIT_INVALID: int = 2
const EXIT_IO: int = 3
const EXIT_SIMULATION: int = 4


func _initialize() -> void:
	var parse_result := ARGUMENT_PARSER_SCRIPT.new().parse(OS.get_cmdline_user_args())
	if not parse_result.is_ok():
		_print_errors(parse_result.errors)
		printerr(_usage())
		quit(EXIT_INVALID)
		return
	var options: SimulationCommandOptions = parse_result.options
	var exit_code := _run_command(options)
	quit(exit_code)


func _run_command(options: SimulationCommandOptions) -> int:
	if options.command == &"help":
		print(_usage())
		return EXIT_OK
	if options.command == &"export-roster-manifest":
		return _export_roster_manifest(options)
	if options.command in [&"validate", &"run"]:
		return _run_manifest_command(options)
	if options.command == &"inspect":
		return _inspect_report(options)
	if options.command == &"replay":
		return _replay_report(options)
	return EXIT_INVALID


func _export_roster_manifest(options: SimulationCommandOptions) -> int:
	var roster := PlayableBotRoster.new()
	var settings: SimulationRosterManifestSettings = ROSTER_MANIFEST_SETTINGS_SCRIPT.new()
	settings.batch_id = options.batch_id
	settings.seed_start = options.seed_start
	settings.tournament_count = options.tournament_count
	settings.regime_preset = options.regime_preset
	var generated := MANIFEST_GENERATOR_SCRIPT.new().generate(roster, settings)
	if not generated.is_ok():
		_print_errors(generated.errors)
		return EXIT_INVALID
	var manifest: SimulationManifest = generated.manifest
	if not _write_dictionary(
		options.output_path, manifest.canonical_dictionary(), options.overwrite
	):
		return EXIT_IO
	_print_document(
		{
			"manifest_path": options.output_path,
			"batch_id": String(manifest.batch_id),
			"schema_version": manifest.schema_version,
			"manifest_checksum": manifest.checksum(),
			"profile_count": manifest.profiles.size(),
			"tournament_count": manifest.evaluation_plans[0].tournament_count,
		},
		options.format
	)
	return EXIT_OK


# gdlint: disable=max-returns
func _run_manifest_command(options: SimulationCommandOptions) -> int:
	var manifest_result := _load_manifest(options.config_path)
	if not manifest_result.is_ok():
		_print_errors(manifest_result.errors)
		return EXIT_INVALID
	var manifest: SimulationManifest = manifest_result.manifest
	var cursor := manifest.create_cursor(options.shard)
	if not cursor.errors.is_empty():
		_print_errors(cursor.errors)
		return EXIT_INVALID
	if options.command == &"validate":
		_print_document(
			_plan_document(manifest, options.shard, manifest.build_plan(options.shard).inputs),
			options.format
		)
		return EXIT_OK
	if options.dry_run:
		_print_document(
			_plan_document(manifest, options.shard, manifest.build_plan(options.shard).inputs),
			options.format
		)
		return EXIT_OK
	if FileAccess.file_exists(options.output_path) and not options.overwrite:
		printerr("Output already exists; pass --overwrite to replace it.")
		return EXIT_IO
	var base_config := _base_config(manifest)
	if base_config == null:
		printerr("The manifest has no resolvable simulation regime.")
		return EXIT_INVALID
	var execution_provenance: Dictionary = PROVENANCE_SCRIPT.capture()
	if not PROVENANCE_SCRIPT.is_available(execution_provenance):
		printerr(
			(
				"Cannot capture executable provenance; run simulations from a Git worktree "
				+ "with readable source state."
			)
		)
		return EXIT_IO
	var store := SimulationCheckpointStore.new()
	var checkpoint_path := options.checkpoint_path
	if checkpoint_path.is_empty():
		checkpoint_path = options.output_path + ".checkpoint"
	if not store.initialize(
		checkpoint_path,
		manifest,
		options.shard,
		execution_provenance,
		options.trace_config(),
		options.resume
	):
		printerr(store.error_message)
		return EXIT_IO
	var accumulator := SimulationAggregateAccumulator.new()
	var minimums := _minimum_samples_by_plan(manifest)
	var runner := SimulationBatchRunner.new()
	var trace_config := options.trace_config()
	var current_plan_id := &""
	var started_ticks := Time.get_ticks_usec()
	var last_progress_ticks := started_ticks
	var completed := 0
	_print_progress(completed, cursor.assigned_count, started_ticks)
	var had_failure: bool = false
	while cursor.has_next():
		var input := cursor.next_input()
		if input.plan_id != current_plan_id:
			current_plan_id = input.plan_id
			printerr("Evaluation plan: %s" % current_plan_id)
		var tournament: Dictionary
		if store.has_record(input.tournament_index):
			var record := store.load_record(input.tournament_index)
			if record.is_empty():
				printerr(store.error_message)
				return EXIT_IO
			tournament = record.tournament
		else:
			var outcome := runner.run_one(base_config, input, 256, trace_config)
			if not store.save_outcome(outcome):
				printerr(store.error_message)
				return EXIT_IO
			tournament = REPORT_SCRIPT._tournament_dictionary(outcome)
		if tournament.termination_reason != "winner":
			had_failure = true
			for diagnostic: Dictionary in tournament.diagnostics:
				printerr("Tournament %d: %s" % [input.tournament_index, diagnostic.message])
		accumulator.add_tournament(tournament, int(minimums.get(input.plan_id, 1)))
		completed += 1
		var now := Time.get_ticks_usec()
		if now - last_progress_ticks >= 1_000_000 or completed == cursor.assigned_count:
			_print_progress(completed, cursor.assigned_count, started_ticks)
			last_progress_ticks = now
	var writer := SimulationStreamReportWriter.new()
	var summary := writer.write(
		options.output_path,
		store,
		manifest,
		options.shard,
		accumulator.summarize(),
		options.overwrite
	)
	if not summary.success:
		printerr(writer.error_message)
		return EXIT_IO
	summary.erase("success")
	if had_failure:
		return EXIT_SIMULATION
	_print_document(summary, options.format)
	return EXIT_OK


func _print_progress(completed: int, total: int, started_ticks: int) -> void:
	var elapsed := maxf(float(Time.get_ticks_usec() - started_ticks) / 1_000_000.0, 0.000001)
	printerr(
		(
			"Completed %d/%d | elapsed %.2fs | throughput %.2f tournaments/s"
			% [completed, total, elapsed, float(completed) / elapsed]
		)
	)


func _minimum_samples_by_plan(manifest: SimulationManifest) -> Dictionary:
	var minimums: Dictionary = {}
	for evaluation_plan: SimulationEvaluationPlan in manifest.evaluation_plans:
		minimums[evaluation_plan.plan_id] = evaluation_plan.minimum_profile_samples
	return minimums


func _inspect_report(options: SimulationCommandOptions) -> int:
	var result := _load_report(options.report_path)
	if not result.is_ok():
		_print_errors(result.errors)
		return EXIT_IO
	var report: RefCounted = result.report
	_print_document(_inspection_document(report), options.format)
	return EXIT_OK


func _replay_report(options: SimulationCommandOptions) -> int:
	var report_result := _load_report(options.report_path)
	if not report_result.is_ok():
		_print_errors(report_result.errors)
		return EXIT_IO
	var report: RefCounted = report_result.report
	var manifest_result := MANIFEST_SCRIPT.parse(report.manifest)
	if not manifest_result.is_ok():
		_print_errors(manifest_result.errors)
		return EXIT_INVALID
	var selected_input: SimulationTournamentInput = manifest_result.manifest.input_at(
		options.tournament_index
	)
	if selected_input == null:
		printerr("The report manifest does not contain that tournament index.")
		return EXIT_INVALID
	var source_tournament: Dictionary
	for tournament: Dictionary in report.tournaments:
		if int(tournament.get("tournament_index", -1)) == options.tournament_index:
			source_tournament = tournament
			break
	if source_tournament.is_empty():
		printerr("The report does not contain that tournament record.")
		return EXIT_INVALID
	var base_config := _base_config(manifest_result.manifest)
	var rng_algorithm := String(
		report.execution_provenance.get("algorithm_versions", {}).get("rng_streams", "")
	)
	var replay_factory := SimulationMatchFactory.new(
		null, RngStreamFactory.new(Callable(), rng_algorithm)
	)
	var batch: SimulationBatchResult = SimulationBatchRunner.new(replay_factory).run(
		base_config, [selected_input], 256, options.trace_config()
	)
	if not batch.is_success():
		_print_errors(_batch_errors(batch))
		return EXIT_SIMULATION
	var current_provenance: Dictionary = PROVENANCE_SCRIPT.capture()
	if not PROVENANCE_SCRIPT.is_available(current_provenance):
		printerr(
			(
				"Cannot capture executable provenance; replay requires a Git worktree "
				+ "with readable source state."
			)
		)
		return EXIT_IO
	var replay_report: RefCounted = REPORT_SCRIPT.from_batch(
		manifest_result.manifest, SimulationShard.new(), batch, "", "", current_provenance
	)
	var replay_tournament: Dictionary = replay_report.tournaments[0]
	var source_digest := REPORT_SCRIPT.tournament_digest(source_tournament)
	var replay_digest := REPORT_SCRIPT.tournament_digest(replay_tournament)
	var provenance_mismatches: Array[Dictionary] = PROVENANCE_SCRIPT.mismatches(
		report.execution_provenance, current_provenance
	)
	var outcome_match: bool = source_digest == replay_digest
	var comparison := {
		"tournament_index": options.tournament_index,
		"source_digest": source_digest,
		"replay_digest": replay_digest,
		"outcome_match": outcome_match,
		"provenance_match": provenance_mismatches.is_empty(),
		"provenance_mismatches": provenance_mismatches,
		"match": outcome_match and provenance_mismatches.is_empty(),
		"trace_count": replay_report.traces.size(),
	}
	if not options.output_path.is_empty():
		var replay_artifact := {
			"replay_schema_version": 1,
			"source_report_manifest_checksum": report.manifest_checksum,
			"tournament_index": options.tournament_index,
			"comparison": comparison,
			"tournament": replay_tournament,
			"traces": replay_report.traces,
			"trace_policy":
			{
				"mode": SimulationTraceConfig.Mode.keys()[options.trace_mode].to_lower(),
				"max_entries_per_tournament": options.trace_sample_count,
			},
		}
		if not _write_dictionary(options.output_path, replay_artifact, options.overwrite):
			return EXIT_IO
	_print_document(comparison, options.format)
	return EXIT_OK if comparison.match else EXIT_SIMULATION


func _load_manifest(path: String) -> RefCounted:
	var result := ManifestLoadResult.new()
	if not FileAccess.file_exists(path):
		result.errors.append("Manifest file does not exist: %s" % path)
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.errors.append("Unable to read manifest file: %s" % path)
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		result.errors.append("Manifest must contain a JSON object.")
		return result
	var manifest_result := MANIFEST_SCRIPT.parse(parsed)
	result.manifest = manifest_result.manifest
	result.errors = manifest_result.errors
	return result


func _load_report(path: String) -> RefCounted:
	var result := ReportLoadResult.new()
	if not FileAccess.file_exists(path):
		result.errors.append("Report file does not exist: %s" % path)
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.errors.append("Unable to read report file: %s" % path)
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		result.errors.append("Report must contain a JSON object.")
		return result
	var report: RefCounted = REPORT_SCRIPT.from_dictionary(parsed)
	result.report = report
	result.errors = report.validate()
	return result


func _base_config(manifest: SimulationManifest) -> ResolvedTournamentConfig:
	if manifest.regimes.is_empty():
		return null
	var resolution := manifest.regimes[0].resolve(manifest.seed_start)
	return resolution.get_config() if resolution.is_ok() else null


func _write_dictionary(path: String, document: Dictionary, overwrite: bool) -> bool:
	if FileAccess.file_exists(path) and not overwrite:
		printerr("Output already exists; pass --overwrite to replace it.")
		return false
	var temporary_path := "%s.tmp.%d" % [path, Time.get_ticks_usec()]
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		printerr("Unable to create temporary report: %s" % temporary_path)
		return false
	file.store_string(JSON.stringify(document, "", true, true))
	file.close()
	var absolute_temp := ProjectSettings.globalize_path(temporary_path)
	var absolute_target := ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(absolute_temp, absolute_target) != OK:
		printerr("Unable to atomically finalize report: %s" % path)
		return false
	return true


func _plan_document(
	manifest: SimulationManifest, shard: SimulationShard, inputs: Array[SimulationTournamentInput]
) -> Dictionary:
	var planned: Array[Dictionary] = []
	for input: SimulationTournamentInput in inputs:
		var seat_map: Array[Dictionary] = []
		var profiles := input.get_seat_profile_ids()
		for seat: int in profiles:
			seat_map.append({"seat": seat, "profile_id": String(profiles[seat])})
		(
			planned
			. append(
				{
					"tournament_index": input.tournament_index,
					"plan_id": String(input.plan_id),
					"plan_tournament_index": input.plan_tournament_index,
					"regime_id": String(input.regime_id),
					"matchup_id": String(input.matchup.matchup_id),
					"matchup_occurrence": input.matchup_occurrence,
					"rotation": input.rotation,
					"effective_seed": input.effective_seed,
					"seat_map": seat_map,
				}
			)
		)
	return {
		"manifest": manifest.canonical_dictionary(),
		"manifest_checksum": manifest.checksum(),
		"shard": shard.to_dictionary(),
		"tournaments": planned,
	}


func _inspection_document(report: RefCounted) -> Dictionary:
	return {
		"report_schema_version": report.report_schema_version,
		"manifest_checksum": report.manifest_checksum,
		"execution_provenance": report.execution_provenance,
		"batch_id": report.manifest.get("batch_id", ""),
		"shard": report.shard.to_dictionary(),
		"tournament_count": report.tournaments.size(),
		"tournament_indexes": _indexes(report.tournaments),
		"aggregates": report.aggregates,
	}


func _indexes(tournaments: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for tournament: Dictionary in tournaments:
		result.append(int(tournament.get("tournament_index", -1)))
	return result


func _batch_errors(batch: SimulationBatchResult) -> PackedStringArray:
	var errors := PackedStringArray()
	for outcome: SimulationTournamentOutcome in batch.outcomes:
		for diagnostic: SimulationDiagnostic in outcome.diagnostics:
			errors.append("Tournament %d: %s" % [outcome.tournament_index, diagnostic.message])
	return errors


func _print_document(document: Dictionary, format: SimulationCommandOptions.OutputFormat) -> void:
	if format == SimulationCommandOptions.OutputFormat.JSON:
		print(JSON.stringify(document, "", true, true))
		return
	for key: Variant in document:
		print("%s: %s" % [key, document[key]])


func _print_errors(errors: PackedStringArray) -> void:
	for error: String in errors:
		printerr(error)


func _usage() -> String:
	return (
		"Usage: godot --headless --path . --script "
		+ "res://scripts/simulation/simulation_cli_app.gd -- <command> [options]\n"
		+ "Commands: help, validate, run, inspect, replay, export-roster-manifest\n"
		+ "Options: --config PATH --output PATH --report PATH --format json|text "
		+ "--shard INDEX/COUNT --trace none|errors|sampled --trace-sample COUNT "
		+ "--dry-run --overwrite --tournament-index INDEX --checkpoint DIR --resume\n"
		+ "export-roster-manifest: --output PATH [--overwrite] [--batch-id ID] "
		+ "[--seed INTEGER] [--tournament-count COUNT] [--regime-preset standard] "
		+ "[--format json|text]"
	)


class ManifestLoadResult:
	extends RefCounted
	var manifest: SimulationManifest
	var errors: PackedStringArray = []

	func is_ok() -> bool:
		return manifest != null and errors.is_empty()


class ReportLoadResult:
	extends RefCounted
	var report: RefCounted
	var errors: PackedStringArray = []

	func is_ok() -> bool:
		return report != null and errors.is_empty()
