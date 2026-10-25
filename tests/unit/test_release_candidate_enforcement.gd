extends "res://tests/support/poker_gut_test.gd"

const MAKEFILE_PATH := "res://Makefile"
const WORKFLOW_PATH := "res://.github/workflows/deploy-web.yml"


func test_release_candidate_gate_has_one_ordered_recursive_contract() -> void:
	var makefile := _read_text(MAKEFILE_PATH)
	var gate := _section(makefile, "release-candidate-gate:", "gui-visual-capture:")
	var first_clean: int = gate.find("$(MAKE) --no-print-directory require-clean-worktree")
	var check: int = gate.find("$(MAKE) --no-print-directory check")
	var invariant: int = gate.find("$(MAKE) --no-print-directory gui-visual-invariant-gate")
	var final_clean: int = gate.rfind("$(MAKE) --no-print-directory require-clean-worktree")

	assert_gte(first_clean, 0)
	assert_gt(check, first_clean)
	assert_gt(invariant, check)
	assert_gt(final_clean, invariant)
	assert_string_contains(makefile, "gui-visual-capture: release-candidate-gate")
	assert_string_contains(makefile, "web-release: release-candidate-gate")
	var web_release := _section(makefile, "web-release:", "verify-web-release-output:")
	assert_false("$(MAKE) --no-print-directory check" in web_release)
	assert_false("$(MAKE) --no-print-directory require-clean-worktree" in web_release)


func test_deploy_workflow_requires_exact_reviewed_main_candidate() -> void:
	var workflow := _read_text(WORKFLOW_PATH)
	assert_string_contains(workflow, "  workflow_dispatch:")
	assert_false("  push:" in workflow)
	assert_string_contains(workflow, "candidate_sha:")
	assert_string_contains(workflow, "reviewed_local_evidence_url:")
	assert_gte(workflow.count("required: true"), 2)
	assert_string_contains(workflow, "ref: ${{ inputs.candidate_sha }}")
	assert_string_contains(workflow, "fetch-depth: 0")
	assert_string_contains(workflow, "persist-credentials: false")
	assert_string_contains(workflow, "WORKFLOW_REF: ${{ github.ref }}")
	assert_string_contains(workflow, 'test "$WORKFLOW_REF" = "refs/heads/main"')
	assert_string_contains(workflow, '[[ "$CANDIDATE_SHA" =~ ^[0-9a-f]{40}$ ]]')
	assert_string_contains(
		workflow, '[[ "$REVIEWED_LOCAL_EVIDENCE_URL" =~ ^https://[^[:space:]]+$ ]]'
	)
	assert_string_contains(workflow, 'test "$(git rev-parse HEAD)" = "$CANDIDATE_SHA"')
	assert_string_contains(workflow, 'test -z "$(git status --porcelain)"')
	assert_string_contains(workflow, 'git merge-base --is-ancestor "$CANDIDATE_SHA" origin/main')
	assert_string_contains(workflow, "run: make release-candidate-gate web-release")
	assert_false("gui-visual-capture" in workflow)


func test_deploy_workflow_keeps_pages_authority_on_the_deploy_job() -> void:
	var workflow := _read_text(WORKFLOW_PATH)
	var build := _section(workflow, "  build:", "  deploy:")
	var deploy: String = workflow.substr(workflow.find("  deploy:"))
	assert_string_contains(build, "permissions:\n      contents: read")
	assert_string_contains(build, "pages: read")
	assert_false("pages: write" in build)
	assert_false("id-token: write" in build)
	assert_string_contains(deploy, "pages: write")
	assert_string_contains(deploy, "id-token: write")
	assert_string_contains(deploy, "environment:\n      name: github-pages")
	assert_string_contains(workflow, "cancel-in-progress: false")
	assert_string_contains(workflow, "GITHUB_STEP_SUMMARY")


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, path)
	return file.get_as_text()


func _section(contents: String, start_marker: String, end_marker: String) -> String:
	var start: int = contents.find(start_marker)
	var end: int = contents.find(end_marker, start + start_marker.length())
	assert_gte(start, 0, start_marker)
	assert_gt(end, start, end_marker)
	return contents.substr(start, end - start)
