class_name PokerGutTest
extends GutTest

## Shared assertions for poker-domain tests.
##
## Keeping these checks in one base class makes the domain invariants readable in
## unit and integration tests without coupling the tests to production classes.


func assert_chip_total(stacks: Array[int], expected_total: int, context: String = "") -> void:
	var actual_total: int = 0
	for stack: int in stacks:
		actual_total += stack

	assert_eq(
		actual_total,
		expected_total,
		"%s chip total" % _context_prefix(context),
	)


func assert_unique_card_codes(card_codes: Array[String], context: String = "") -> void:
	var seen_codes: Dictionary = {}
	var duplicate_codes: Array[String] = []

	for card_code: String in card_codes:
		if seen_codes.has(card_code):
			duplicate_codes.append(card_code)
		else:
			seen_codes[card_code] = true

	assert_eq(
		duplicate_codes,
		[],
		"%s duplicate card codes" % _context_prefix(context),
	)


func _context_prefix(context: String) -> String:
	if context.is_empty():
		return ""
	return "%s:" % context
