extends "res://tests/support/poker_gut_test.gd"

## Small-desktop and wide replacement coverage across all established M3 states.
const Matrix := preload("res://tests/support/gui_replacement_category_matrix.gd")


func test_replacement_desktop_matrix_satisfies_schema2_invariants() -> void:
	var failures: PackedStringArray = await Matrix.run(self, &"desktop")
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))
