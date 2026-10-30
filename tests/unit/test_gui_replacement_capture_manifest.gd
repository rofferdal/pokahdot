extends "res://tests/support/poker_gut_test.gd"

const Cases := preload("res://tests/support/gui_replacement_capture_cases.gd")
const Manifest := preload("res://tests/support/gui_replacement_visual_capture_manifest.gd")


func test_m3_capture_matrix_has_99_unique_replacement_case_identities() -> void:
	var cases: Array[Dictionary] = Manifest.cases(&"m3")
	var identities: Dictionary = {}
	assert_eq(cases.size(), 99)
	for case: Dictionary in cases:
		assert_false(identities.has(case.case_id), String(case.case_id))
		identities[case.case_id] = true
		assert_true(case.has("size"))
		assert_true(case.has("player_count"))
		assert_true(case.has("state_id"))
	assert_eq(identities.size(), 99)


func test_phone_ipad_and_desktop_categories_have_replacement_cases() -> void:
	for category: StringName in [&"phone", &"ipad", &"desktop"]:
		var cases: Array[Dictionary] = Manifest.cases(category)
		assert_gt(cases.size(), 0, String(category))
		for case: Dictionary in cases:
			if category == &"desktop":
				assert_true(case.category in [&"desktop", &"m3"], String(case.case_id))
			else:
				assert_eq(case.category, category, String(case.case_id))
			assert_true(case.size.x > 0 and case.size.y > 0, String(case.case_id))
	assert_eq(Cases.all_cases().size(), 99)


func test_manifest_records_engine_source_and_exact_case_identity() -> void:
	var cases: Array[Dictionary] = Manifest.cases(&"m3")
	var manifest: Dictionary = Manifest.new_manifest(
		&"m3",
		"abc123",
		"clean",
		PackedStringArray(),
		"4.7.2",
		"gl_compatibility",
		"2026-10-30T00:00:00Z",
		Manifest.matrix_checksum(cases),
		false
	)
	assert_eq(manifest.owner, "replacement_gui")
	assert_eq(manifest.source_sha, "abc123")
	assert_eq(manifest.godot_version, "4.7.2")
	assert_eq(manifest.case_matrix_sha256, Manifest.matrix_checksum(cases))
	assert_true(Manifest.filename("abcdef123456", cases[0]).begins_with("abcdef123456__"))
	assert_false(manifest.acceptance_eligible)


func test_capture_output_must_be_a_confined_localtmp_path() -> void:
	assert_true(Manifest.is_safe_output_path("localtmp/gui-review/candidate"))
	assert_false(Manifest.is_safe_output_path("artifacts/gui-review"))
	assert_false(Manifest.is_safe_output_path("localtmp/../artifacts"))
	assert_false(Manifest.is_safe_output_path("localtmp\\gui-review"))
