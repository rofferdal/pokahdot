extends "res://tests/support/poker_gut_test.gd"

## Canonical and observed iPad diagnostic entry point.
const Runner := preload("res://tests/support/gui_invariant_matrix_runner.gd")
const Suites := preload("res://tests/support/gui_invariant_matrix_suites.gd")


func test_ipad_visual_matrix_satisfies_gui_invariants() -> void:
	var failures: PackedStringArray = await Runner.run_suite(self, Suites.Suite.IPAD)
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))
