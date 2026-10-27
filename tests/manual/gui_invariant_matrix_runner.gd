extends "res://tests/support/poker_gut_test.gd"

## Historical Milestone 3 diagnostic entry point; suite identity is preserved.
const Runner := preload("res://tests/support/gui_invariant_matrix_runner.gd")
const Suites := preload("res://tests/support/gui_invariant_matrix_suites.gd")


func test_milestone_three_visual_matrix_satisfies_gui_invariants() -> void:
	var failures: PackedStringArray = await Runner.run_suite(self, Suites.Suite.MILESTONE_THREE)
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))
