extends "res://tests/support/poker_gut_test.gd"

## The M3 replacement gate exercises the complete 99-case native matrix.
const Matrix := preload("res://tests/support/gui_replacement_category_matrix.gd")


func test_m3_replacement_matrix_satisfies_schema2_invariants() -> void:
	var failures: PackedStringArray = await Matrix.run(self, &"m3")
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))
