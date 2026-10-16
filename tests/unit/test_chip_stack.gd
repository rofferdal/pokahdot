extends "res://tests/support/poker_gut_test.gd"


func test_debit_removes_requested_chips_when_available() -> void:
	var stack := ChipStack.new(100)

	assert_eq(stack.debit(40), 40)
	assert_eq(stack.amount, 60)


func test_debit_returns_actual_amount_for_short_all_in() -> void:
	var stack := ChipStack.new(25)

	assert_eq(stack.debit(100), 25)
	assert_eq(stack.amount, 0)


func test_non_positive_debit_is_rejected_without_changing_stack() -> void:
	var stack := ChipStack.new(100)

	assert_eq(stack.debit(0), 0)
	assert_eq(stack.debit(-10), 0)
	assert_eq(stack.amount, 100)


func test_credit_adds_chips_and_rejects_negative_amount() -> void:
	var stack := ChipStack.new(100)

	assert_true(stack.credit(25))
	assert_eq(stack.amount, 125)
	assert_false(stack.credit(-1))
	assert_eq(stack.amount, 125)


func test_credit_rejects_integer_overflow() -> void:
	var stack := ChipStack.new((1 << 63) - 2)

	assert_false(stack.credit(2))
	assert_eq(stack.amount, (1 << 63) - 2)
