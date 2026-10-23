class_name SimulationManifest
extends RefCounted

## Versioned, typed simulation adapter input.
##
## JSON is accepted only at this boundary. Planning and execution operate on
## the typed snapshots held by this value.

const SUPPORTED_SCHEMA_VERSION: int = 2
const BLIND_PROGRESSION: StringName = &"normative_hand_based_v1"
const PLAN_SCRIPT := preload("res://scripts/simulation/simulation_evaluation_plan.gd")
const PARSE_RESULT_SCRIPT := preload("res://scripts/simulation/simulation_manifest_parse_result.gd")
const BATCH_PLAN_SCRIPT := preload("res://scripts/simulation/simulation_batch_plan.gd")
const STRATEGY_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)
const RANDOM_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/random_decision_model_parameters.gd"
)
const TIGHT_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/tight_passive_decision_model_parameters.gd"
)
const LOOSE_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/loose_aggressive_decision_model_parameters.gd"
)
const SUPPORTED_MODEL_IDS: Array[StringName] = [
	&"random", &"tight_passive", &"loose_aggressive", &"strategy_parameterized"
]

var schema_version: int = SUPPORTED_SCHEMA_VERSION
var batch_id: StringName
var seed_start: int
var profiles: Array[BotProfile] = []
var regimes: Array[SimulationRegime] = []
var matchups: Array[SimulationMatchup] = []
var evaluation_plans: Array[SimulationEvaluationPlan] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != SUPPORTED_SCHEMA_VERSION:
		errors.append("Unsupported simulation manifest schema version.")
	if batch_id.is_empty():
		errors.append("A simulation batch ID is required.")
	var profile_by_id: Dictionary = {}
	for profile: BotProfile in profiles:
		if profile == null:
			errors.append("Simulation profiles cannot be null.")
			continue
		if profile.profile_id.is_empty():
			errors.append("A simulation profile ID is required.")
		elif profile_by_id.has(profile.profile_id):
			errors.append("Simulation profile IDs must be unique.")
		else:
			profile_by_id[profile.profile_id] = profile
		if profile.model_id.is_empty():
			errors.append("Profile %s has no model ID." % profile.profile_id)
		elif profile.model_id not in SUPPORTED_MODEL_IDS:
			errors.append("Unknown simulation model ID: %s" % profile.model_id)
		if profile.parameters == null:
			errors.append("Profile %s has no parameters." % profile.profile_id)
		else:
			if not _parameters_match_model_id(profile.model_id, profile.parameters):
				errors.append(
					(
						"Profile %s parameters do not match model ID: %s."
						% [profile.profile_id, profile.model_id]
					)
				)
			errors.append_array(profile.parameters.validate())
	var regime_by_id: Dictionary = {}
	for regime: SimulationRegime in regimes:
		if regime == null:
			errors.append("Simulation regimes cannot be null.")
			continue
		if regime.regime_id.is_empty():
			errors.append("A simulation regime ID is required.")
		elif regime_by_id.has(regime.regime_id):
			errors.append("Simulation regime IDs must be unique.")
		else:
			regime_by_id[regime.regime_id] = regime
		if regime.blind_progression != BLIND_PROGRESSION:
			errors.append("Simulation regimes must use the normative hand-based blind progression.")
		errors.append_array(regime.validate())
	var matchup_by_id: Dictionary = {}
	for matchup: SimulationMatchup in matchups:
		if matchup == null:
			errors.append("Simulation matchups cannot be null.")
			continue
		if matchup_by_id.has(matchup.matchup_id):
			errors.append("Simulation matchup IDs must be unique.")
		else:
			matchup_by_id[matchup.matchup_id] = matchup
		errors.append_array(matchup.validate())
		for profile: BotProfile in matchup.get_profiles():
			if profile == null or not profile_by_id.has(profile.profile_id):
				errors.append("Matchup %s references an unknown profile." % matchup.matchup_id)
	var plan_ids: Dictionary = {}
	for plan: SimulationEvaluationPlan in evaluation_plans:
		if plan == null:
			errors.append("Evaluation plans cannot be null.")
			continue
		if plan_ids.has(plan.plan_id):
			errors.append("Evaluation plan IDs must be unique.")
		else:
			plan_ids[plan.plan_id] = true
		errors.append_array(plan.validate())
		if not regime_by_id.has(plan.regime_id):
			errors.append("Evaluation plan %s references an unknown regime." % plan.plan_id)
			continue
		var regime: SimulationRegime = regime_by_id[plan.regime_id]
		for matchup_id: StringName in plan.matchup_ids:
			if not matchup_by_id.has(matchup_id):
				errors.append("Evaluation plan %s references an unknown matchup." % plan.plan_id)
				continue
			var matchup: SimulationMatchup = matchup_by_id[matchup_id]
			if matchup.get_profiles().size() != regime.player_count:
				errors.append("Matchup %s does not fit regime %s." % [matchup_id, plan.regime_id])
	return errors


func build_plan(shard: SimulationShard = null) -> RefCounted:
	var errors := validate()
	if shard != null:
		errors.append_array(shard.validate())
	if not errors.is_empty():
		return BATCH_PLAN_SCRIPT.new([], errors)
	var selected_shard := SimulationShard.new() if shard == null else shard
	var regime_by_id: Dictionary = {}
	var matchup_by_id: Dictionary = {}
	for regime: SimulationRegime in regimes:
		regime_by_id[regime.regime_id] = regime
	for matchup: SimulationMatchup in matchups:
		matchup_by_id[matchup.matchup_id] = matchup
	var all_inputs: Array[SimulationTournamentInput] = []
	var global_index: int = 0
	for plan: SimulationEvaluationPlan in evaluation_plans:
		var regime: SimulationRegime = regime_by_id[plan.regime_id]
		for local_index: int in range(plan.tournament_count):
			var matchup_offset: int = local_index % plan.matchup_ids.size()
			var matchup_id: StringName = plan.matchup_ids[matchup_offset]
			var matchup: SimulationMatchup = matchup_by_id[matchup_id]
			var occurrence: int = local_index / plan.matchup_ids.size()
			var rotation: int = occurrence % regime.player_count
			(
				all_inputs
				. append(
					(
						SimulationTournamentInput
						. new(
							global_index,
							seed_start + global_index,
							matchup,
							_rotated_profiles(matchup.get_profiles(), rotation),
							occurrence,
							rotation,
							regime.regime_id,
							plan.plan_id,
							local_index,
							regime,
						)
					)
				)
			)
			global_index += 1
			if seed_start + global_index - 1 == 0:
				return BATCH_PLAN_SCRIPT.new([], ["Simulation effective seeds must be non-zero."])
	var filtered := SimulationBatchPlanner.new().filter_for_shard(
		all_inputs, selected_shard.index, selected_shard.count
	)
	return BATCH_PLAN_SCRIPT.new(filtered)


func canonical_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"batch_id": String(batch_id),
		"seed_start": seed_start,
		"profiles": _profiles_dictionary(),
		"regimes": _regimes_dictionary(),
		"matchups": _matchups_dictionary(),
		"evaluation_plans": _plans_dictionary(),
	}


func canonical_json() -> String:
	return JSON.stringify(canonical_dictionary(), "", true)


func checksum() -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical_json().to_utf8_buffer())
	return context.finish().hex_encode()


## The evaluation roster identity is derived only from immutable profile
## snapshots in this manifest. It deliberately does not rely on the product
## playable roster, which evaluations may extend with candidates.
func roster_provenance() -> Dictionary:
	var profiles_snapshot := _profiles_dictionary()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(profiles_snapshot, "", true).to_utf8_buffer())
	var profile_ids: Array[String] = []
	for profile: Dictionary in profiles_snapshot:
		profile_ids.append(profile.profile_id)
	return {
		"version": "manifest_profiles_v1:%s" % context.finish().hex_encode(),
		"profile_ids": profile_ids,
	}


static func parse(data: Dictionary) -> SimulationManifestParseResult:
	var errors := _unknown_fields(
		data,
		[
			"schema_version",
			"batch_id",
			"seed_start",
			"profiles",
			"regimes",
			"matchups",
			"evaluation_plans",
		]
	)
	if not data.has("schema_version") or not _is_integral(data.schema_version):
		errors.append("Manifest schema_version must be an integer.")
	if not data.has("batch_id") or typeof(data.batch_id) != TYPE_STRING:
		errors.append("Manifest batch_id must be a string.")
	if not data.has("seed_start") or not _is_integral(data.seed_start):
		errors.append("Manifest seed_start must be an integer.")
	for field: String in ["profiles", "regimes", "matchups", "evaluation_plans"]:
		if not data.has(field) or typeof(data[field]) != TYPE_ARRAY:
			errors.append("Manifest %s must be an array." % field)
	if not errors.is_empty():
		return PARSE_RESULT_SCRIPT.new(null, errors)
	var manifest := SimulationManifest.new()
	manifest.schema_version = int(data.schema_version)
	manifest.batch_id = StringName(data.batch_id)
	manifest.seed_start = int(data.seed_start)
	var profile_result := _parse_profiles(data.profiles)
	errors.append_array(profile_result.errors)
	manifest.profiles = profile_result.values
	var profiles_by_id: Dictionary = {}
	for profile: BotProfile in manifest.profiles:
		profiles_by_id[profile.profile_id] = profile
	for regime_data: Variant in data.regimes:
		if typeof(regime_data) != TYPE_DICTIONARY:
			errors.append("Every manifest regime must be an object.")
			continue
		var regime_errors := _unknown_fields(
			regime_data,
			[
				"regime_id",
				"player_count",
				"starting_stack",
				"starting_small_blind",
				"starting_big_blind",
				"blind_progression",
			]
		)
		for field: String in [
			"player_count", "starting_stack", "starting_small_blind", "starting_big_blind"
		]:
			if not regime_data.has(field) or not _is_integral(regime_data[field]):
				regime_errors.append("Regime %s must be an integer." % field)
		if not regime_errors.is_empty():
			errors.append_array(regime_errors)
			continue
		(
			manifest
			. regimes
			. append(
				(
					SimulationRegime
					. new(
						StringName(regime_data.get("regime_id", "")),
						int(regime_data.get("player_count", 0)),
						int(regime_data.get("starting_stack", 0)),
						int(regime_data.get("starting_small_blind", 0)),
						int(regime_data.get("starting_big_blind", 0)),
						StringName(regime_data.get("blind_progression", "")),
					)
				)
			)
		)
	var matchups_by_id: Dictionary = {}
	for matchup_data: Variant in data.matchups:
		if typeof(matchup_data) != TYPE_DICTIONARY:
			errors.append("Every manifest matchup must be an object.")
			continue
		var matchup_errors := _unknown_fields(matchup_data, ["matchup_id", "profile_ids"])
		if not matchup_errors.is_empty():
			errors.append_array(matchup_errors)
			continue
		var matchup_profiles: Array[BotProfile] = []
		if typeof(matchup_data.get("profile_ids")) != TYPE_ARRAY:
			errors.append("Matchup profile_ids must be an array.")
			continue
		for profile_id: Variant in matchup_data.profile_ids:
			if typeof(profile_id) != TYPE_STRING or not profiles_by_id.has(StringName(profile_id)):
				errors.append("Matchup references an unknown profile ID.")
			else:
				matchup_profiles.append(profiles_by_id[StringName(profile_id)])
		var matchup := SimulationMatchup.new(
			StringName(matchup_data.get("matchup_id", "")), matchup_profiles
		)
		manifest.matchups.append(matchup)
		matchups_by_id[matchup.matchup_id] = matchup
	for plan_data: Variant in data.evaluation_plans:
		if typeof(plan_data) != TYPE_DICTIONARY:
			errors.append("Every evaluation plan must be an object.")
			continue
		var plan_errors := _unknown_fields(
			plan_data,
			[
				"plan_id",
				"regime_id",
				"matchup_ids",
				"tournament_count",
				"seat_rotation",
				"minimum_profile_samples",
				"uncertainty_estimator",
			]
		)
		for field: String in ["tournament_count", "minimum_profile_samples"]:
			if not plan_data.has(field) or not _is_integral(plan_data[field]):
				plan_errors.append("Evaluation plan %s must be an integer." % field)
		if not plan_errors.is_empty():
			errors.append_array(plan_errors)
			continue
		var ids: Array[StringName] = []
		if typeof(plan_data.get("matchup_ids")) != TYPE_ARRAY:
			errors.append("Evaluation plan matchup_ids must be an array.")
		else:
			for matchup_id: Variant in plan_data.matchup_ids:
				ids.append(StringName(matchup_id))
		(
			manifest
			. evaluation_plans
			. append(
				(
					PLAN_SCRIPT
					. new(
						StringName(plan_data.get("plan_id", "")),
						StringName(plan_data.get("regime_id", "")),
						ids,
						int(plan_data.get("tournament_count", 0)),
						int(plan_data.get("minimum_profile_samples", 1)),
						StringName(plan_data.get("uncertainty_estimator", "normal_95")),
						StringName(plan_data.get("seat_rotation", "")),
					)
				)
			)
		)
	var validation_errors := manifest.validate()
	errors.append_array(validation_errors)
	return PARSE_RESULT_SCRIPT.new(manifest if errors.is_empty() else null, errors)


static func _parse_profiles(data: Array) -> Dictionary:
	var values: Array[BotProfile] = []
	var errors := PackedStringArray()
	for profile_data: Variant in data:
		if typeof(profile_data) != TYPE_DICTIONARY:
			errors.append("Every manifest profile must be an object.")
			continue
		var unknown := _unknown_fields(profile_data, ["profile_id", "model_id", "parameters"])
		errors.append_array(unknown)
		if not profile_data.has("profile_id") or typeof(profile_data.profile_id) != TYPE_STRING:
			errors.append("Profile profile_id must be a string.")
			continue
		if not profile_data.has("model_id") or typeof(profile_data.model_id) != TYPE_STRING:
			errors.append("Profile model_id must be a string.")
			continue
		var parameters: DecisionModelParameters = _parameters_for_model(
			StringName(profile_data.model_id)
		)
		if parameters == null:
			errors.append("Unknown simulation model ID: %s" % profile_data.model_id)
			continue
		if not profile_data.has("parameters") or typeof(profile_data.parameters) != TYPE_DICTIONARY:
			errors.append("Profile parameters must be an object.")
			continue
		var parameter_errors := _assign_parameters(parameters, profile_data.parameters)
		errors.append_array(parameter_errors)
		if not parameter_errors.is_empty():
			continue
		var profile := BotProfile.new()
		profile.profile_id = StringName(profile_data.profile_id)
		profile.model_id = StringName(profile_data.model_id)
		profile.parameters = parameters
		values.append(profile)
	return {"values": values, "errors": errors}


static func _parameters_for_model(model_id: StringName) -> DecisionModelParameters:
	if model_id == &"strategy_parameterized":
		return STRATEGY_PARAMETERS_SCRIPT.new()
	if model_id == &"random":
		return RANDOM_PARAMETERS_SCRIPT.new()
	if model_id == &"tight_passive":
		return TIGHT_PARAMETERS_SCRIPT.new()
	if model_id == &"loose_aggressive":
		return LOOSE_PARAMETERS_SCRIPT.new()
	return null


static func _parameters_match_model_id(
	model_id: StringName, parameters: DecisionModelParameters
) -> bool:
	if model_id == &"strategy_parameterized":
		return parameters is StrategyDecisionModelParameters
	if model_id == &"random":
		return parameters is RandomDecisionModelParameters
	if model_id == &"tight_passive":
		return parameters is TightPassiveDecisionModelParameters
	if model_id == &"loose_aggressive":
		return parameters is LooseAggressiveDecisionModelParameters
	return false


static func _assign_parameters(
	parameters: DecisionModelParameters, values: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	var expected_names := _parameter_names(parameters)
	for parameter_name: String in expected_names:
		if not values.has(parameter_name):
			errors.append("Missing parameter field: %s" % parameter_name)
	for key: Variant in values:
		if typeof(key) != TYPE_STRING or not key in expected_names:
			errors.append("Unknown parameter field: %s" % key)
			continue
		if not _is_integral(values[key]):
			errors.append("Parameter %s must be an integer." % key)
			continue
		parameters.set(StringName(key), int(values[key]))
	errors.append_array(parameters.validate())
	return errors


static func _parameter_names(parameters: DecisionModelParameters) -> Array[String]:
	if parameters is StrategyDecisionModelParameters:
		return ["tight_vs_loose", "passive_vs_aggressive", "call_vs_raise", "bluff_rate"]
	if parameters is RandomDecisionModelParameters:
		return ["fold_weight", "passive_weight", "aggressive_weight"]
	if parameters is TightPassiveDecisionModelParameters:
		return ["minimum_preflop_high_rank", "raise_frequency"]
	if parameters is LooseAggressiveDecisionModelParameters:
		return ["fold_frequency", "aggression_frequency"]
	return []


static func _unknown_fields(data: Dictionary, allowed: Array[String]) -> PackedStringArray:
	var errors := PackedStringArray()
	for key: Variant in data.keys():
		if not String(key) in allowed:
			errors.append("Unknown manifest field: %s" % key)
	return errors


static func _is_integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(value, floor(value))
	return false


func _rotated_profiles(source: Array[BotProfile], rotation: int) -> Dictionary[int, BotProfile]:
	var result: Dictionary[int, BotProfile] = {}
	for seat: int in range(source.size()):
		result[seat] = source[(seat + rotation) % source.size()]
	return result


func _profiles_dictionary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile: BotProfile in profiles:
		(
			result
			. append(
				{
					"profile_id": String(profile.profile_id),
					"model_id": String(profile.model_id),
					"parameters": _parameters_dictionary(profile.parameters),
				}
			)
		)
	return result


func _parameters_dictionary(parameters: DecisionModelParameters) -> Dictionary:
	var result: Dictionary = {}
	for name: String in _parameter_names(parameters):
		result[name] = parameters.get(name)
	return result


func _regimes_dictionary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for regime: SimulationRegime in regimes:
		result.append(regime.to_dictionary())
	return result


func _matchups_dictionary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for matchup: SimulationMatchup in matchups:
		var ids: Array[String] = []
		for profile: BotProfile in matchup.get_profiles():
			ids.append(String(profile.profile_id))
		result.append({"matchup_id": String(matchup.matchup_id), "profile_ids": ids})
	return result


func _plans_dictionary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for plan: SimulationEvaluationPlan in evaluation_plans:
		result.append(plan.to_dictionary())
	return result
