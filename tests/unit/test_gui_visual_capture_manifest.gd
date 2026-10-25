extends "res://tests/support/poker_gut_test.gd"

const CaptureManifestScript := preload("res://tests/support/gui_visual_capture_manifest.gd")


func test_capture_filename_matches_the_documented_stable_shape() -> void:
	var cases: Array[Dictionary] = CaptureManifestScript.milestone_three_cases(
		&"small_desktop_950x532", &"showdown-long", 6
	)
	assert_eq(cases.size(), 1)
	assert_eq(
		CaptureManifestScript.capture_filename(
			"88122bd46ef01234567890123456789012345678", cases[0]
		),
		"88122bd46ef0__small_desktop_950x532__950x532-landscape__p6__showdown-long.png",
	)
	assert_eq(
		CaptureManifestScript.capture_id(cases[0]),
		"small_desktop_950x532__p6__showdown-long",
	)


func test_milestone_three_capture_matrix_is_complete_unique_and_deterministic() -> void:
	var cases: Array[Dictionary] = CaptureManifestScript.milestone_three_cases()
	assert_eq(cases.size(), CaptureManifestScript.MILESTONE_3_CAPTURE_COUNT)
	var ids: Dictionary = {}
	for case: Dictionary in cases:
		ids[CaptureManifestScript.capture_id(case)] = true
	assert_eq(ids.size(), cases.size())
	assert_eq(
		CaptureManifestScript.matrix_checksum(cases),
		CaptureManifestScript.matrix_checksum(CaptureManifestScript.milestone_three_cases()),
	)
	assert_eq(CaptureManifestScript.matrix_checksum(cases).length(), 64)
	for checksum: String in CaptureManifestScript.matrix_source_checksums().values():
		assert_eq(checksum.length(), 64)
	assert_eq(CaptureManifestScript.milestone_three_cases(&"", &"startup", 0).size(), 6)
	assert_eq(CaptureManifestScript.milestone_three_cases(&"", &"keypad-open", 0).size(), 6)
	assert_eq(CaptureManifestScript.milestone_three_cases(&"", &"startup", 2).size(), 0)


func test_manifest_marks_only_clean_gate_evidence_as_acceptance_eligible() -> void:
	var clean: Dictionary = CaptureManifestScript.base_manifest(
		"abcdef", "clean", PackedStringArray(), "4.7.2", "gl_compatibility", "utc", "matrix", false
	)
	assert_eq(clean.schema_version, CaptureManifestScript.SCHEMA_VERSION)
	assert_eq(clean.visual_suite_version, CaptureManifestScript.SUITE_VERSION)
	assert_false(clean.acceptance_eligible)
	assert_eq(clean.captures, [])
	var passing_captures: Array = []
	for _index: int in range(CaptureManifestScript.MILESTONE_3_CAPTURE_COUNT):
		passing_captures.append({"invariants": {"passed": true}})
	assert_true(CaptureManifestScript.acceptance_eligible("clean", false, true, passing_captures))
	assert_false(CaptureManifestScript.acceptance_eligible("clean", false, false, passing_captures))
	passing_captures[0].invariants.passed = false
	assert_false(CaptureManifestScript.acceptance_eligible("clean", false, true, passing_captures))

	var dirty: Dictionary = (
		CaptureManifestScript
		. base_manifest(
			"abcdef",
			"dirty",
			PackedStringArray([" M example.gd"]),
			"4.7.2",
			"gl_compatibility",
			"utc",
			"matrix",
			true,
		)
	)
	assert_false(dirty.acceptance_eligible)
	assert_true(dirty.development_capture)
	assert_eq(dirty.dirty_paths, PackedStringArray([" M example.gd"]))
