extends "res://tests/support/poker_gut_test.gd"

const PROVENANCE_SCRIPT := preload("res://scripts/simulation/simulation_provenance.gd")


func test_clean_and_dirty_provenance_validation_is_strict() -> void:
	var clean := _provenance()
	assert_true(PROVENANCE_SCRIPT.validate(clean).is_empty())
	clean.code_revision = ""
	assert_has(
		PROVENANCE_SCRIPT.validate(clean),
		"Simulation code revision must be a Git object ID.",
	)

	var dirty := _provenance()
	dirty.source_state = "dirty"
	dirty.dirty_source_fingerprint = "b".repeat(64)
	assert_true(PROVENANCE_SCRIPT.validate(dirty).is_empty())
	dirty.dirty_source_fingerprint = "short"
	assert_has(
		PROVENANCE_SCRIPT.validate(dirty),
		"Dirty simulation source requires a SHA-256 fingerprint.",
	)


func test_mismatches_explain_source_and_current_values() -> void:
	var source := _provenance()
	var current := _provenance()
	current.engine_version = "4.other"
	var mismatches: Array[Dictionary] = PROVENANCE_SCRIPT.mismatches(source, current)

	assert_eq(mismatches.size(), 1)
	assert_eq(mismatches[0].field, "engine_version")
	assert_eq(mismatches[0].source, "4.test")
	assert_eq(mismatches[0].current, "4.other")


func _provenance() -> Dictionary:
	return {
		"algorithm_versions": PROVENANCE_SCRIPT.ALGORITHM_VERSIONS.duplicate(true),
		"code_revision": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"dirty_source_fingerprint": "",
		"engine_version": "4.test",
		"source_state": "clean",
	}
