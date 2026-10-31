extends "res://tests/support/poker_gut_test.gd"

## Three independently selectable groups preserve the complete 99-case M3 matrix.
const Matrix := preload("res://tests/support/gui_replacement_category_matrix.gd")
const Cases := preload("res://tests/support/gui_replacement_capture_cases.gd")


func test_m3_supported_layout_invariants() -> void:
	var failures: PackedStringArray = await Matrix.run_cases(
		self, Cases.supported_layout_cases(), "invariant/m3/supported"
	)
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))


func test_m3_wide_state_invariants() -> void:
	var failures: PackedStringArray = await Matrix.run_cases(
		self, Cases.wide_state_cases(), "invariant/m3/wide"
	)
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))


func test_m3_phone_state_invariants() -> void:
	var failures: PackedStringArray = await Matrix.run_cases(
		self, Cases.phone_state_cases(), "invariant/m3/phone"
	)
	assert_eq(failures, PackedStringArray(), "\n" + "\n".join(failures))
