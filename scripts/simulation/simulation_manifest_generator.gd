class_name SimulationManifestGenerator
extends RefCounted

## Builds an isolated Schema 2 simulation manifest from the curated roster.
##
## This adapter service only composes typed values. It never reads arguments,
## writes artifacts, or exposes the roster's catalog Resources to the manifest.

const RESULT_SCRIPT := preload("res://scripts/simulation/simulation_manifest_generation_result.gd")
const SETTINGS_SCRIPT := preload("res://scripts/simulation/simulation_roster_manifest_settings.gd")
const MAX_TABLE_PROFILE_COUNT := 9
## Product policy permits 25 strategic profiles plus the three retained legacy profiles.
const MAX_TRANSLATED_PROFILE_COUNT := 28
const MAX_SCHEDULE_ATTEMPTS := 100000


func generate(
	roster: PlayableBotRoster,
	settings: SimulationRosterManifestSettings = null,
) -> SimulationManifestGenerationResult:
	var errors := PackedStringArray()
	if roster == null:
		errors.append("A playable bot roster is required for manifest generation.")
	else:
		errors.append_array(roster.validate_for_simulation())
		var selected_settings: SimulationRosterManifestSettings = (
			SETTINGS_SCRIPT.new() if settings == null else settings
		)
		errors.append_array(selected_settings.validate())
		var roster_profiles: Array[BotProfile] = roster.get_catalog_profiles()
		var schedule_blocks := _schedule_blocks(
			roster_profiles.size(), selected_settings.seed_start
		)
		_validate_inputs(roster_profiles, selected_settings, schedule_blocks, errors)
		if errors.is_empty():
			var manifest := _build_manifest(
				roster, roster_profiles, selected_settings, schedule_blocks
			)
			errors.append_array(manifest.validate())
			var plan: SimulationBatchPlan = manifest.build_plan() as SimulationBatchPlan
			errors.append_array(plan.errors)
			if errors.is_empty():
				return RESULT_SCRIPT.new(manifest)
	return RESULT_SCRIPT.new(null, errors)


func _validate_inputs(
	roster_profiles: Array[BotProfile],
	settings: SimulationRosterManifestSettings,
	schedule_blocks: Array[PackedInt32Array],
	errors: PackedStringArray,
) -> void:
	if roster_profiles.size() < 2 or roster_profiles.size() > MAX_TRANSLATED_PROFILE_COUNT:
		errors.append(
			(
				"A roster manifest requires between 2 and %d active bot profiles."
				% MAX_TRANSLATED_PROFILE_COUNT
			)
		)
		return
	if schedule_blocks.is_empty():
		errors.append("A deterministic pair-covering roster schedule could not be generated.")
	if settings.tournament_count % roster_profiles.size() != 0:
		errors.append("Roster manifest tournament count must be divisible by the roster size.")
	var profile_samples := settings.tournament_count
	if roster_profiles.size() > MAX_TABLE_PROFILE_COUNT:
		profile_samples = (
			settings.tournament_count / roster_profiles.size() * MAX_TABLE_PROFILE_COUNT
		)
	if settings.minimum_profile_samples > profile_samples:
		errors.append("Roster manifest minimum profile samples exceed per-profile tournaments.")


func _build_manifest(
	roster: PlayableBotRoster,
	roster_profiles: Array[BotProfile],
	settings: SimulationRosterManifestSettings,
	schedule_blocks: Array[PackedInt32Array],
) -> SimulationManifest:
	var manifest := SimulationManifest.new()
	manifest.batch_id = _resolve_batch_id(roster, settings)
	manifest.seed_start = settings.seed_start
	for profile: BotProfile in roster_profiles:
		manifest.profiles.append(profile.duplicate(true) as BotProfile)
	var table_profile_count := mini(roster_profiles.size(), MAX_TABLE_PROFILE_COUNT)
	var regime_id := StringName("roster_%d_max" % table_profile_count)
	manifest.regimes = [
		(
			SimulationRegime
			. new(
				regime_id,
				table_profile_count,
				settings.starting_stack,
				settings.starting_small_blind,
				settings.starting_big_blind,
			)
		)
	]
	var matchup_ids: Array[StringName] = []
	for block_index: int in range(schedule_blocks.size()):
		var matchup_id := StringName(
			"active_roster" if schedule_blocks.size() == 1 else "active_roster_%02d" % block_index
		)
		var matchup_profiles: Array[BotProfile] = []
		for profile_index: int in schedule_blocks[block_index]:
			matchup_profiles.append(manifest.profiles[profile_index])
		matchup_ids.append(matchup_id)
		manifest.matchups.append(SimulationMatchup.new(matchup_id, matchup_profiles))
	manifest.evaluation_plans = [
		(
			SimulationEvaluationPlan
			. new(
				&"roster_baseline",
				regime_id,
				matchup_ids,
				settings.tournament_count,
				settings.minimum_profile_samples,
			)
		)
	]
	return manifest


## A cyclic translate of a difference-covering base block gives every profile
## equal matchup appearances and covers every unordered profile pair. Keeping
## base-block order stable also balances aggregate seats under cyclic rotation.
func _schedule_blocks(profile_count: int, schedule_seed: int) -> Array[PackedInt32Array]:
	var blocks: Array[PackedInt32Array] = []
	if profile_count < 2 or profile_count > MAX_TRANSLATED_PROFILE_COUNT:
		return blocks
	var table_profile_count := mini(profile_count, MAX_TABLE_PROFILE_COUNT)
	if profile_count <= MAX_TABLE_PROFILE_COUNT:
		var complete_block := PackedInt32Array()
		for profile_index: int in range(profile_count):
			complete_block.append(profile_index)
		blocks.append(complete_block)
		return blocks

	var base_block := _find_difference_cover(profile_count, table_profile_count, schedule_seed)
	if base_block.is_empty():
		return blocks
	for translation: int in range(profile_count):
		var translated_block := PackedInt32Array()
		for profile_index: int in base_block:
			translated_block.append((profile_index + translation) % profile_count)
		blocks.append(translated_block)
	return blocks


func _find_difference_cover(
	profile_count: int, block_size: int, schedule_seed: int
) -> PackedInt32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = schedule_seed
	for _attempt: int in range(MAX_SCHEDULE_ATTEMPTS):
		var pool: Array[int] = []
		for profile_index: int in range(profile_count):
			pool.append(profile_index)
		for block_index: int in range(block_size):
			var swap_index := rng.randi_range(block_index, pool.size() - 1)
			var selected_index := pool[block_index]
			pool[block_index] = pool[swap_index]
			pool[swap_index] = selected_index
		var candidate := PackedInt32Array()
		for block_index: int in range(block_size):
			candidate.append(pool[block_index])
		if _covers_all_differences(candidate, profile_count):
			return candidate
	return PackedInt32Array()


func _covers_all_differences(block: PackedInt32Array, profile_count: int) -> bool:
	var differences: Dictionary[int, bool] = {}
	for left: int in block:
		for right: int in block:
			if left != right:
				differences[(left - right + profile_count) % profile_count] = true
	return differences.size() == profile_count - 1


func _resolve_batch_id(
	roster: PlayableBotRoster, settings: SimulationRosterManifestSettings
) -> StringName:
	if not settings.batch_id.is_empty():
		return settings.batch_id
	return StringName("roster_%s" % roster.get_roster_version())
