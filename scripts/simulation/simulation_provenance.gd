class_name SimulationProvenance
extends RefCounted

## Captures executable source and algorithm identity for simulation reports.

const ALGORITHM_VERSIONS := {
	"aggregate_statistics": "normal_95_v1",
	"rng_streams": RngStreamFactory.ALGORITHM_VERSION,
	"simulation_runner": "tournament_match_v1",
	"tournament_metrics": "elimination_history_v1",
}
const SOURCE_PATHS := ["scripts", "resources", "addons", "project.godot"]


static func capture() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var revision_output: Array = []
	var revision_status := OS.execute(
		"git", PackedStringArray(["-C", root, "rev-parse", "HEAD"]), revision_output, true
	)
	var revision := "unavailable"
	if revision_status == 0 and not revision_output.is_empty():
		revision = String(revision_output[0]).strip_edges()
	var status_output: Array = []
	var status_code := (
		OS
		. execute(
			"git",
			PackedStringArray(
				(
					["-C", root, "status", "--porcelain=v1", "--untracked-files=all", "--"]
					+ Array(SOURCE_PATHS)
				)
			),
			status_output,
			true,
		)
	)
	var state := "unavailable"
	var fingerprint := ""
	if status_code == 0:
		var status_text := String(status_output[0]) if not status_output.is_empty() else ""
		state = "clean" if status_text.strip_edges().is_empty() else "dirty"
		if state == "dirty" and revision != "unavailable":
			fingerprint = _dirty_fingerprint(root, status_text)
			if fingerprint.is_empty():
				state = "unavailable"
	return {
		"algorithm_versions": ALGORITHM_VERSIONS.duplicate(true),
		"code_revision": revision,
		"dirty_source_fingerprint": fingerprint,
		"engine_version": String(Engine.get_version_info().get("string", "unknown")),
		"source_state": state,
	}


static func unavailable() -> Dictionary:
	return {
		"algorithm_versions": ALGORITHM_VERSIONS.duplicate(true),
		"code_revision": "unavailable",
		"dirty_source_fingerprint": "",
		"engine_version": String(Engine.get_version_info().get("string", "unknown")),
		"source_state": "unavailable",
	}


static func mismatches(left: Dictionary, right: Dictionary) -> Array[Dictionary]:
	var differences: Array[Dictionary] = []
	for field: String in [
		"algorithm_versions",
		"code_revision",
		"dirty_source_fingerprint",
		"engine_version",
		"source_state"
	]:
		if left.get(field) != right.get(field):
			differences.append(
				{"field": field, "source": left.get(field), "current": right.get(field)}
			)
	return differences


static func is_available(value: Dictionary) -> bool:
	return value.get("source_state") in ["clean", "dirty"] and validate(value).is_empty()


static func validate(value: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var expected := [
		"algorithm_versions",
		"code_revision",
		"dirty_source_fingerprint",
		"engine_version",
		"source_state"
	]
	if value.keys().size() != expected.size():
		errors.append("Simulation provenance fields are invalid.")
	for field: String in expected:
		if not value.has(field):
			errors.append("Simulation provenance is missing field: %s" % field)
	if typeof(value.get("algorithm_versions")) != TYPE_DICTIONARY:
		errors.append("Simulation algorithm versions must be an object.")
	else:
		var algorithms: Dictionary = value.algorithm_versions
		var expected_algorithms := ALGORITHM_VERSIONS.duplicate()
		var rng_value: Variant = algorithms.get("rng_streams")
		var rng_algorithm: String = rng_value if typeof(rng_value) == TYPE_STRING else ""
		expected_algorithms["rng_streams"] = rng_algorithm
		if (
			algorithms != expected_algorithms
			or not RngStreamFactory.is_supported_algorithm(rng_algorithm)
		):
			errors.append("Simulation algorithm versions are unsupported.")
	for field: String in [
		"code_revision", "dirty_source_fingerprint", "engine_version", "source_state"
	]:
		if typeof(value.get(field)) != TYPE_STRING:
			errors.append("Simulation provenance field has invalid type: %s" % field)
	if not errors.is_empty():
		return errors
	var revision := String(value.get("code_revision", ""))
	if revision.length() not in [40, 64] or not _is_lower_hex(revision):
		errors.append("Simulation code revision must be a Git object ID.")
	if String(value.get("engine_version", "")).is_empty():
		errors.append("Simulation engine version is required.")
	var state := String(value.get("source_state", ""))
	if state not in ["clean", "dirty"]:
		errors.append("Simulation source state is invalid.")
	var fingerprint := String(value.get("dirty_source_fingerprint", ""))
	if state == "dirty" and (fingerprint.length() != 64 or not fingerprint.is_valid_hex_number()):
		errors.append("Dirty simulation source requires a SHA-256 fingerprint.")
	if state != "dirty" and not fingerprint.is_empty():
		errors.append("Clean simulation source cannot have a dirty fingerprint.")
	return errors


static func _dirty_fingerprint(root: String, status_text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(status_text.to_utf8_buffer())
	var diff_output: Array = []
	if (
		(
			OS
			. execute(
				"git",
				PackedStringArray(
					(
						["-C", root, "diff", "--no-ext-diff", "--binary", "HEAD", "--"]
						+ Array(SOURCE_PATHS)
					)
				),
				diff_output,
				true,
			)
		)
		!= 0
	):
		return ""
	context.update((String(diff_output[0]) if not diff_output.is_empty() else "").to_utf8_buffer())
	for line: String in status_text.split("\n", false):
		if not line.begins_with("?? "):
			continue
		var relative_path := line.substr(3)
		var file := FileAccess.open(root.path_join(relative_path), FileAccess.READ)
		if file != null:
			context.update(relative_path.to_utf8_buffer())
			context.update(file.get_buffer(file.get_length()))
		else:
			return ""
	return context.finish().hex_encode()


static func _is_lower_hex(value: String) -> bool:
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true
