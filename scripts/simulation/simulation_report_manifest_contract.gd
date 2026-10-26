class_name SimulationReportManifestContract
extends RefCounted

## Checks untrusted JSON shapes before the typed manifest parser can convert
## identifiers or numeric values. No tournament plan is materialized here.

const MANIFEST_FIELDS := {
	"schema_version": TYPE_INT,
	"batch_id": TYPE_STRING,
	"seed_start": TYPE_INT,
	"profiles": TYPE_ARRAY,
	"regimes": TYPE_ARRAY,
	"matchups": TYPE_ARRAY,
	"evaluation_plans": TYPE_ARRAY,
}
const COLLECTION_FIELDS := {
	"profiles": {"profile_id": TYPE_STRING, "model_id": TYPE_STRING, "parameters": TYPE_DICTIONARY},
	"regimes":
	{
		"regime_id": TYPE_STRING,
		"player_count": TYPE_INT,
		"starting_stack": TYPE_INT,
		"starting_small_blind": TYPE_INT,
		"starting_big_blind": TYPE_INT,
		"blind_progression": TYPE_STRING,
	},
	"matchups": {"matchup_id": TYPE_STRING, "profile_ids": TYPE_ARRAY},
	"evaluation_plans":
	{
		"plan_id": TYPE_STRING,
		"regime_id": TYPE_STRING,
		"matchup_ids": TYPE_ARRAY,
		"tournament_count": TYPE_INT,
		"seat_rotation": TYPE_STRING,
		"minimum_profile_samples": TYPE_INT,
		"uncertainty_estimator": TYPE_STRING,
	},
}


static func parse(data: Dictionary) -> SimulationManifestParseResult:
	var errors := PackedStringArray()
	validate_fields(data, MANIFEST_FIELDS, "Report manifest", errors)
	for collection: String in COLLECTION_FIELDS:
		if typeof(data.get(collection)) != TYPE_ARRAY:
			continue
		if data[collection].is_empty():
			errors.append("Report manifest %s must not be empty." % collection)
		for item: Variant in data[collection]:
			if typeof(item) != TYPE_DICTIONARY:
				errors.append("Report manifest %s entries must be objects." % collection)
				continue
			validate_fields(item, COLLECTION_FIELDS[collection], collection, errors)
			for array_field: String in ["profile_ids", "matchup_ids"]:
				if typeof(item.get(array_field)) == TYPE_ARRAY:
					for identifier: Variant in item[array_field]:
						if typeof(identifier) != TYPE_STRING:
							errors.append("Report manifest ID arrays require strings.")
			if typeof(item.get("parameters")) == TYPE_DICTIONARY:
				for key: Variant in item.parameters:
					if typeof(key) != TYPE_STRING or not is_integer(item.parameters[key]):
						errors.append("Report manifest parameters require integral values.")
	if not errors.is_empty():
		return SimulationManifestParseResult.new(null, errors)
	return SimulationManifest.parse(data)


static func validate_fields(
	data: Dictionary, fields: Dictionary, context: String, errors: PackedStringArray
) -> void:
	for field: String in fields:
		var expected: int = fields[field]
		var value: Variant = data.get(field)
		if (
			(expected == TYPE_INT and not is_integer(value))
			or (expected != TYPE_INT and typeof(value) != expected)
		):
			errors.append("%s has missing or invalid field: %s" % [context, field])
	for field: Variant in data:
		if not fields.has(field):
			errors.append("%s has unknown field: %s" % [context, field])


static func is_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return (
		typeof(value) == TYPE_FLOAT
		and is_finite(value)
		and value == floor(value)
		and value >= -9223372036854775808.0
		and value < 9223372036854775808.0
	)
