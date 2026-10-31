extends GutTest

## Prevent CI sharding from silently omitting a test group or bypassing release checks.
const CHARACTERIZATION := "res://tests/manual/gui_replacement_matrix_runner.gd"
const NATIVE_WORKFLOW := "res://.github/workflows/check-native-layouts.yml"
const QUALITY_WORKFLOW := "res://.github/workflows/check-quality.yml"
const PR_WORKFLOW := "res://.github/workflows/check-pr.yml"


func test_characterization_targets_cover_every_original_test_exactly_once() -> void:
	var tests := RegEx.new()
	assert_eq(tests.compile("(?m)^func (test_[^(]+)\\("), OK)
	var expected: Array[String] = []
	for found: RegExMatch in tests.search_all(_read(CHARACTERIZATION)):
		expected.append(found.get_string(1))
	var mappings := RegEx.new()
	assert_eq(
		mappings.compile(
			"(?m)^gui-characterization-[a-z-]+: GUI_CHARACTERIZATION_TEST := (test_\\w+)$"
		),
		OK
	)
	var selected: Array[String] = []
	for found: RegExMatch in mappings.search_all(_read("res://Makefile")):
		selected.append(found.get_string(1))
	expected.sort()
	selected.sort()
	assert_eq(expected.size(), 4)
	assert_eq(selected, expected, "Every test must run in exactly one shard")
	assert_string_contains(_read("res://Makefile"), "-gunit_test_name=$(GUI_CHARACTERIZATION_TEST)")


func test_native_workflow_runs_all_characterization_and_invariant_groups() -> void:
	var workflow: String = _read(NATIVE_WORKFLOW)
	var expected: Array[String] = [
		"gui-characterization-supported",
		"gui-characterization-wide",
		"gui-characterization-phone",
		"gui-characterization-large-values",
		"gui-phone-table-layout-gate",
		"gui-m3-supported-invariant-gate",
		"gui-m3-wide-invariant-gate",
		"gui-m3-phone-invariant-gate",
		"gui-phone-invariant-gate",
		"gui-ipad-invariant-gate",
		"gui-desktop-invariant-gate",
	]
	var choices := RegEx.new()
	assert_eq(
		(
			choices
			. compile(
				"(?s)fromJSON\\(inputs.run-matrix-tests\\s*&&\\s*'([^']+)'\\s*\\|\\|\\s*'([^']+)'\\s*\\)"
			)
		),
		OK
	)
	var selection: RegExMatch = choices.search(workflow)
	assert_not_null(selection)
	if selection == null:
		return
	assert_eq(JSON.parse_string(selection.get_string(1)), expected)
	assert_eq(JSON.parse_string(selection.get_string(2)), ["gui-phone-table-layout-gate"])
	assert_string_contains(workflow, "type: boolean\n        default: false")
	assert_string_contains(workflow, "fail-fast: false")
	assert_string_contains(workflow, "workflow_call:")
	assert_string_contains(workflow, "GODOT_RELEASE: 4.7.2-stable")
	assert_string_contains(workflow, "godot --headless --path . --import")
	assert_string_contains(
		workflow,
		(
			"make require-clean-worktree\n"
			+ "          mkdir -p localtmp/ci-layout\n"
			+ '          make "$LAYOUT_TARGET" GUT_REPORT=res://localtmp/ci-layout/layout.xml\n'
			+ "          make require-clean-worktree"
		)
	)
	for caller: String in [PR_WORKFLOW, "res://.github/workflows/deploy-web.yml"]:
		assert_string_contains(
			_read(caller), "run-matrix-tests: ${{ vars.RUN_GUI_MATRIX_TESTS == 'true' }}"
		)
	assert_false("continue-on-error" in workflow)


func test_pr_status_fails_on_failed_cancelled_or_skipped_dependencies() -> void:
	var workflow: String = _read(PR_WORKFLOW)
	assert_string_contains(workflow, "name: Checks and current layouts")
	assert_string_contains(workflow, "needs: [quality, native-layouts]")
	assert_string_contains(workflow, "if: always()")
	assert_string_contains(workflow, "QUALITY_RESULT: ${{ needs.quality.result }}")
	assert_string_contains(workflow, "LAYOUT_RESULT: ${{ needs.native-layouts.result }}")
	assert_string_contains(workflow, 'test "$QUALITY_RESULT" = success')
	assert_string_contains(workflow, 'test "$LAYOUT_RESULT" = success')
	assert_string_contains(workflow, "uses: ./.github/workflows/check-quality.yml")
	assert_string_contains(workflow, "uses: ./.github/workflows/check-native-layouts.yml")
	assert_false("continue-on-error" in workflow)


func test_local_full_check_and_shared_quality_keep_the_complete_non_matrix_suite() -> void:
	var makefile: String = _read("res://Makefile")
	assert_string_contains(
		makefile,
		(
			"check:\n\t$(MAKE) --no-print-directory check-without-layout-characterization\n"
			+ "\t$(MAKE) --no-print-directory gui-layout-characterization"
		)
	)
	var quality: String = _read(QUALITY_WORKFLOW)
	assert_string_contains(
		quality,
		(
			"make require-clean-worktree\n"
			+ "          make ci-quality-check\n"
			+ "          make require-clean-worktree"
		)
	)
	for target: String in [
		"docs-check",
		"profile-evolution-test",
		"web-lan-test",
		"web-layout-test",
		"cli-process-test"
	]:
		assert_string_contains(makefile, "$(MAKE) --no-print-directory " + target)
	assert_string_contains(makefile, "$(GDLINT) scripts tests")
	assert_string_contains(makefile, "$(GDFORMAT) --check scripts tests")
	assert_string_contains(makefile, "\n\t$(GUT_COMMAND)\n")


func test_m3_ci_shards_cover_all_original_case_ids_once() -> void:
	var all_cases: Array[Dictionary] = GuiReplacementCaptureCases.all_cases()
	var groups: Array = [
		GuiReplacementCaptureCases.supported_layout_cases(),
		GuiReplacementCaptureCases.wide_state_cases(),
		GuiReplacementCaptureCases.phone_state_cases(),
	]
	var expected: Array[String] = []
	for case: Dictionary in all_cases:
		expected.append(case.case_id)
	var selected: Array[String] = []
	var sizes: Array[int] = []
	for group: Array in groups:
		sizes.append(group.size())
		for case: Dictionary in group:
			assert_false(case.case_id in selected, "A fixture must not run in two shards")
			selected.append(case.case_id)
	expected.sort()
	selected.sort()
	assert_eq(sizes, [27, 40, 32])
	assert_eq(selected, expected)


func test_m3_targets_select_every_invariant_test_once() -> void:
	var tests := RegEx.new()
	assert_eq(tests.compile("(?m)^func (test_[^(]+)\\("), OK)
	var expected: Array[String] = []
	for found: RegExMatch in tests.search_all(
		_read("res://tests/manual/gui_invariant_matrix_runner.gd")
	):
		expected.append(found.get_string(1))
	var mappings := RegEx.new()
	assert_eq(mappings.compile("(?m)^gui-m3-[a-z-]+: GUI_M3_TEST := (test_\\w+)$"), OK)
	var selected: Array[String] = []
	for found: RegExMatch in mappings.search_all(_read("res://Makefile")):
		selected.append(found.get_string(1))
	expected.sort()
	selected.sort()
	assert_eq(expected.size(), 3)
	assert_eq(selected, expected)


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
