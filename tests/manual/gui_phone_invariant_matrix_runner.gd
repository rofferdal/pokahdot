extends "res://tests/support/poker_gut_test.gd"

## Phone portrait, landscape, reduced-height, privacy, and resize coverage.
const Matrix := preload("res://tests/support/gui_replacement_category_matrix.gd")


func test_replacement_phone_matrix_satisfies_schema2_invariants() -> void:
	var failures: PackedStringArray = await Matrix.run(self, &"phone")
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))
