class_name IntegerBounds
extends RefCounted

## Shared checked-integer helpers for text and arithmetic boundaries.

const MAX_INT_64: int = 9223372036854775807
const MIN_INT_64_TEXT: String = "9223372036854775808"
const MAX_INT_64_TEXT: String = "9223372036854775807"


static func fits_signed_64_bit_text(value_text: String) -> bool:
	if value_text.is_empty() or not value_text.is_valid_int():
		return false
	var digit_start: int = 0
	var is_negative: bool = value_text.begins_with("-")
	if is_negative or value_text.begins_with("+"):
		digit_start = 1
	var digits: String = value_text.substr(digit_start)
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)
	var limit: String = MIN_INT_64_TEXT if is_negative else MAX_INT_64_TEXT
	if digits.length() != limit.length():
		return digits.length() < limit.length()
	return digits <= limit


static func can_add_nonnegative(base: int, increment: int) -> bool:
	return increment >= 0 and base <= MAX_INT_64 - increment
