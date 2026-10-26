class_name SimulationEvaluationPlan
extends RefCounted

## A named, ordered evaluation plan from a simulation manifest.

const CYCLIC_ROTATION: StringName = &"cyclic"

var plan_id: StringName
var regime_id: StringName
var matchup_ids: Array[StringName] = []
var tournament_count: int
var seat_rotation: StringName = CYCLIC_ROTATION
var minimum_profile_samples: int
var uncertainty_estimator: StringName


func _init(
	id: StringName = &"",
	selected_regime_id: StringName = &"",
	selected_matchup_ids: Array[StringName] = [],
	count: int = 0,
	minimum_samples: int = 1,
	estimator: StringName = &"normal_95",
	rotation_mode: StringName = CYCLIC_ROTATION,
) -> void:
	plan_id = id
	regime_id = selected_regime_id
	matchup_ids = selected_matchup_ids.duplicate()
	tournament_count = count
	seat_rotation = rotation_mode
	minimum_profile_samples = minimum_samples
	uncertainty_estimator = estimator


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if plan_id.is_empty():
		errors.append("An evaluation plan ID is required.")
	if regime_id.is_empty():
		errors.append("An evaluation plan regime ID is required.")
	if matchup_ids.is_empty():
		errors.append("An evaluation plan requires at least one matchup ID.")
	if tournament_count <= 0:
		errors.append("Evaluation plan tournament count must be positive.")
	if seat_rotation != CYCLIC_ROTATION:
		errors.append("Only cyclic seat rotation is supported.")
	if minimum_profile_samples <= 0:
		errors.append("Minimum profile samples must be positive.")
	if uncertainty_estimator != &"normal_95":
		errors.append("Only the normal_95 uncertainty estimator is supported.")
	var seen: Dictionary = {}
	for matchup_id: StringName in matchup_ids:
		if matchup_id.is_empty():
			errors.append("Evaluation plan matchup IDs cannot be empty.")
		elif seen.has(matchup_id):
			errors.append("Evaluation plan matchup IDs must be unique.")
		else:
			seen[matchup_id] = true
	return errors


func to_dictionary() -> Dictionary:
	return {
		"plan_id": String(plan_id),
		"regime_id": String(regime_id),
		"matchup_ids": _string_array(matchup_ids),
		"tournament_count": tournament_count,
		"seat_rotation": String(seat_rotation),
		"minimum_profile_samples": minimum_profile_samples,
		"uncertainty_estimator": String(uncertainty_estimator),
	}


func _string_array(values: Array[StringName]) -> Array[String]:
	var output: Array[String] = []
	for value: StringName in values:
		output.append(String(value))
	return output
