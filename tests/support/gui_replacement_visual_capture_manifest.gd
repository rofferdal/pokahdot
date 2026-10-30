class_name GuiReplacementVisualCaptureManifest
extends RefCounted

## Deterministic identities and provenance for replacement-only visual captures.
const Cases := preload("res://tests/support/gui_replacement_capture_cases.gd")
const SCHEMA_VERSION: int = 1
const CASE_SOURCE_PATHS: PackedStringArray = [
	"tests/support/gui_replacement_capture_cases.gd",
	"tests/support/gui_replacement_matrix_support.gd",
	"tests/support/gui_replacement_invariant_assertions.gd",
	"tests/support/gui_snapshot_content_assertions.gd",
	"tests/support/gui_visual_state_fixtures.gd",
	"tests/manual/gui_replacement_matrix_runner.gd",
]


static func cases(category: StringName) -> Array[Dictionary]:
	return Cases.cases_for_category(category)


static func filename(source_sha: String, case: Dictionary) -> String:
	var identity: String = String(case.case_id).replace("/", "__").replace(" ", "_")
	return "%s__%s.png" % [source_sha.left(12), identity]


static func is_safe_output_path(path: String) -> bool:
	if not path.begins_with("localtmp/") or path.contains("\\"):
		return false
	for segment: String in path.split("/"):
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	var absolute := ProjectSettings.globalize_path("res://" + path.simplify_path())
	var localtmp := ProjectSettings.globalize_path("res://localtmp").simplify_path()
	var project_access := DirAccess.open(ProjectSettings.globalize_path("res://"))
	if project_access == null or not absolute.begins_with(localtmp + "/"):
		return false
	var current := "localtmp"
	if project_access.is_link(current):
		return false
	for segment: String in path.trim_prefix("localtmp/").split("/"):
		current = current.path_join(segment)
		if project_access.is_link(current):
			return false
	return true


static func source_checksums() -> Dictionary:
	var result: Dictionary = {}
	for path: String in CASE_SOURCE_PATHS:
		result[path] = FileAccess.get_sha256(ProjectSettings.globalize_path("res://" + path))
	return result


static func new_manifest(
	category: StringName,
	source_sha: String,
	tree_state: String,
	dirty_paths: PackedStringArray,
	engine_version: String,
	renderer: String,
	captured_at_utc: String,
	cases_sha256: String,
	development: bool
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"owner": "replacement_gui",
		"category": String(category),
		"source_sha": source_sha,
		"source_tree_state": tree_state,
		"dirty_paths": Array(dirty_paths),
		"development_capture": development,
		"acceptance_eligible": false,
		"godot_version": engine_version,
		"renderer": renderer,
		"captured_at_utc": captured_at_utc,
		"case_matrix_sha256": cases_sha256,
		"case_source_sha256": source_checksums(),
		"case_count": 0,
		"captures": [],
	}


static func matrix_checksum(cases: Array[Dictionary]) -> String:
	var identities: Array[Dictionary] = []
	for case: Dictionary in cases:
		(
			identities
			. append(
				{
					"case_id": case.case_id,
					"category": String(case.category),
					"size": [case.size.x, case.size.y],
					"player_count": case.player_count,
					"state_id": String(case.state_id),
					"expected_ready": case.expected_ready,
				}
			)
		)
	var payload := {
		"cases": identities,
		"source_sha256": source_checksums(),
	}
	return sha256_text(JSON.stringify(payload))


static func sha256_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()
