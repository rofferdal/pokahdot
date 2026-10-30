extends "res://tests/support/poker_gut_test.gd"

## Canonical tablet orientations, reduced-height, and observed-surface coverage.
const Matrix := preload("res://tests/support/gui_replacement_category_matrix.gd")


func test_replacement_ipad_matrix_satisfies_schema2_invariants() -> void:
	var failures: PackedStringArray = await Matrix.run(self, &"ipad")
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))
