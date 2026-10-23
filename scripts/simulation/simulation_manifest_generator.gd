class_name SimulationManifestGenerator
extends RefCounted

## Builds an isolated Schema 2 simulation manifest from the curated roster.
##
## This adapter service only composes typed values. It never reads arguments,
## writes artifacts, or exposes the roster's catalog Resources to the manifest.

const RESULT_SCRIPT := preload("res://scripts/simulation/simulation_manifest_generation_result.gd")
const SETTINGS_SCRIPT := preload("res://scripts/simulation/simulation_roster_manifest_settings.gd")


func generate(
	roster: PlayableBotRoster,
	settings: SimulationRosterManifestSettings = null,
) -> SimulationManifestGenerationResult:
	var errors := PackedStringArray()
	if roster == null:
		errors.append("A playable bot roster is required for manifest generation.")
	else:
		errors.append_array(roster.validate())
		var selected_settings: SimulationRosterManifestSettings = (
			SETTINGS_SCRIPT.new() if settings == null else settings
		)
		errors.append_array(selected_settings.validate())
		var roster_profiles: Array[BotProfile] = roster.get_catalog_profiles()
		_validate_inputs(roster_profiles, selected_settings, errors)
		if errors.is_empty():
			var manifest := _build_manifest(roster, roster_profiles, selected_settings)
			errors.append_array(manifest.validate())
			var plan: SimulationBatchPlan = manifest.build_plan() as SimulationBatchPlan
			errors.append_array(plan.errors)
			if errors.is_empty():
				return RESULT_SCRIPT.new(manifest)
	return RESULT_SCRIPT.new(null, errors)


func _validate_inputs(
	roster_profiles: Array[BotProfile],
	settings: SimulationRosterManifestSettings,
	errors: PackedStringArray,
) -> void:
	if roster_profiles.size() < 2 or roster_profiles.size() > 9:
		errors.append("A roster manifest requires between 2 and 9 active bot profiles.")
		return
	if settings.tournament_count % roster_profiles.size() != 0:
		errors.append("Roster manifest tournament count must be divisible by the roster size.")
	if settings.minimum_profile_samples > settings.tournament_count / roster_profiles.size():
		errors.append("Roster manifest minimum profile samples exceed per-profile tournaments.")


func _build_manifest(
	roster: PlayableBotRoster,
	roster_profiles: Array[BotProfile],
	settings: SimulationRosterManifestSettings,
) -> SimulationManifest:
	var manifest := SimulationManifest.new()
	manifest.batch_id = _resolve_batch_id(roster, settings)
	manifest.seed_start = settings.seed_start
	for profile: BotProfile in roster_profiles:
		manifest.profiles.append(profile.duplicate(true) as BotProfile)
	var regime_id := StringName("roster_%d_max" % roster_profiles.size())
	var matchup_id: StringName = &"active_roster"
	manifest.regimes = [
		(
			SimulationRegime
			. new(
				regime_id,
				roster_profiles.size(),
				settings.starting_stack,
				settings.starting_small_blind,
				settings.starting_big_blind,
			)
		)
	]
	manifest.matchups = [SimulationMatchup.new(matchup_id, manifest.profiles)]
	manifest.evaluation_plans = [
		(
			SimulationEvaluationPlan
			. new(
				&"roster_baseline",
				regime_id,
				[matchup_id],
				settings.tournament_count,
				settings.minimum_profile_samples,
			)
		)
	]
	return manifest


func _resolve_batch_id(
	roster: PlayableBotRoster, settings: SimulationRosterManifestSettings
) -> StringName:
	if not settings.batch_id.is_empty():
		return settings.batch_id
	return StringName("roster_%s" % roster.get_roster_version())
