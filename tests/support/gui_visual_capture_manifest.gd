class_name GuiVisualCaptureManifest
extends RefCounted

## Deterministic naming and manifest metadata for rendered GUI evidence.

const Suites := preload("res://tests/support/gui_invariant_matrix_suites.gd")

const SCHEMA_VERSION: int = 1
const SUITE_VERSION: String = "milestone-3-v2"
const PHONE_SUITE_VERSION: String = "milestone-4-phone-v2"
const MILESTONE_3_CAPTURE_COUNT: int = 348
const PHONE_CAPTURE_COUNT: int = 406
const MILESTONE_3_PLAYER_COUNTS: Array[int] = Suites.MILESTONE_3_PLAYER_COUNTS
const PHONE_PLAYER_COUNTS: Array[int] = Suites.PHONE_PLAYER_COUNTS
const PHONE_EXCLUDED_STATE_IDS: Array[StringName] = Suites.PHONE_EXCLUDED_STATE_IDS
const MILESTONE_3_VIEWPORT_IDS: Array[StringName] = Suites.MILESTONE_3_VIEWPORT_IDS
const PHONE_VIEWPORT_IDS: Array[StringName] = Suites.PHONE_VIEWPORT_IDS
const MATRIX_SOURCE_PATHS: PackedStringArray = [
	"res://tests/support/gui_viewport_fixtures.gd",
	"res://tests/support/gui_visual_state_fixtures.gd",
	"res://tests/support/gui_scene_harness.gd",
	"res://tests/support/gui_reference_fixture_driver.gd",
	"res://tests/support/gui_invariant_assertions.gd",
	"res://tests/support/gui_snapshot_content_assertions.gd",
	"res://tests/support/gui_snapshot_region_assertions.gd",
	"res://tests/support/gui_invariant_matrix_suites.gd",
	"res://tests/support/gui_invariant_matrix_runner.gd",
	"res://tests/support/gui_phone_matrix_contract.gd",
]


static func milestone_three_cases(
	viewport_id: StringName = &"", state_id: StringName = &"", player_count: int = -1
) -> Array[Dictionary]:
	# Explicit development captures may select newer registered viewports without
	# changing the frozen full Milestone 3 matrix.
	return Suites.cases(Suites.Suite.MILESTONE_THREE, viewport_id, state_id, player_count, true)


static func phone_cases(
	viewport_id: StringName = &"", state_id: StringName = &"", player_count: int = -1
) -> Array[Dictionary]:
	return Suites.cases(Suites.Suite.PHONE, viewport_id, state_id, player_count)


static func capture_filename(source_sha: String, case: Dictionary) -> String:
	var viewport: Dictionary = case.viewport
	var descriptor: Dictionary = case.descriptor
	return (
		"%s__%s__%dx%d-%s__p%d__%s.png"
		% [
			source_sha.left(12),
			viewport.key,
			viewport.size.x,
			viewport.size.y,
			viewport.orientation,
			descriptor.player_count,
			descriptor.id,
		]
	)


static func capture_id(case: Dictionary) -> String:
	return (
		"%s__p%d__%s"
		% [
			case.viewport.key,
			case.descriptor.player_count,
			case.descriptor.id,
		]
	)


static func matrix_checksum(cases: Array[Dictionary]) -> String:
	var identities: Array[Dictionary] = []
	for case: Dictionary in cases:
		var viewport: Dictionary = case.viewport
		var descriptor: Dictionary = case.descriptor
		(
			identities
			. append(
				{
					"viewport_id": String(viewport.key),
					"width": viewport.size.x,
					"height": viewport.size.y,
					"profile": String(viewport.profile),
					"orientation": String(viewport.orientation),
					"player_count": descriptor.player_count,
					"state_id": String(descriptor.id),
					"fixture_seed": descriptor.fixed_seed,
				}
			)
		)
	return sha256_text(
		JSON.stringify({"cases": identities, "source_sha256": matrix_source_checksums()})
	)


static func matrix_source_checksums() -> Dictionary:
	var checksums: Dictionary = {}
	for source_path: String in MATRIX_SOURCE_PATHS:
		checksums[source_path] = FileAccess.get_sha256(ProjectSettings.globalize_path(source_path))
	return checksums


static func base_manifest(
	source_sha: String,
	tree_state: String,
	dirty_paths: PackedStringArray,
	godot_version: String,
	renderer: String,
	captured_at_utc: String,
	matrix_sha256: String,
	development: bool,
	suite_version: String = SUITE_VERSION,
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"visual_suite_version": suite_version,
		"source_sha": source_sha,
		"source_tree_state": tree_state,
		"dirty_paths": dirty_paths,
		"acceptance_eligible": false,
		"development_capture": development,
		"godot_version": godot_version,
		"renderer": renderer,
		"captured_at_utc": captured_at_utc,
		"fixture_matrix_sha256": matrix_sha256,
		"captures": [],
	}


static func acceptance_eligible(
	tree_state: String, development: bool, full_m3: bool, captures: Array
) -> bool:
	if tree_state != "clean" or development or not full_m3:
		return false
	if captures.size() != MILESTONE_3_CAPTURE_COUNT:
		return false
	for capture: Dictionary in captures:
		if not capture.invariants.passed:
			return false
	return true


static func phone_acceptance_eligible(
	tree_state: String, development: bool, full_phone: bool, captures: Array
) -> bool:
	if tree_state != "clean" or development or not full_phone:
		return false
	if captures.size() != PHONE_CAPTURE_COUNT:
		return false
	for capture: Dictionary in captures:
		if not capture.invariants.passed:
			return false
	return true


static func sha256_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()
