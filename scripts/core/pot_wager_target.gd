class_name PotWagerTarget
extends RefCounted

## Resolves the exact pot-sized convenience target from recipient-safe values.

const AVAILABLE: StringName = &"available"
const INVALID_INPUT: StringName = &"invalid_input"
const OVERFLOW: StringName = &"overflow"
const OUTSIDE_LEGAL_RANGE: StringName = &"outside_legal_range"
const MAX_INT_64: int = 9223372036854775807


static func resolve(
	pot_amount: int,
	existing_wager: int,
	call_amount: int,
	minimum_total: int,
	maximum_total: int,
) -> PotWagerTargetResult:
	if minimum_total < 0 or maximum_total < minimum_total:
		return PotWagerTargetResult.new(0, false, INVALID_INPUT)
	var calculated: PotWagerTargetResult = calculate_fraction(
		pot_amount, existing_wager, call_amount, 1
	)
	if not calculated.available:
		return calculated
	var available: bool = calculated.total >= minimum_total and calculated.total <= maximum_total
	return PotWagerTargetResult.new(
		calculated.total, available, AVAILABLE if available else OUTSIDE_LEGAL_RANGE
	)


static func calculate_fraction(
	pot_amount: int, existing_wager: int, call_amount: int, pot_fraction_divisor: int
) -> PotWagerTargetResult:
	if pot_amount < 0 or existing_wager < 0 or call_amount < 0 or pot_fraction_divisor <= 0:
		return PotWagerTargetResult.new(0, false, INVALID_INPUT)

	@warning_ignore("integer_division")
	var pot_fraction: int = pot_amount / pot_fraction_divisor
	if pot_fraction > MAX_INT_64 - existing_wager:
		return PotWagerTargetResult.new(0, false, OVERFLOW)
	return PotWagerTargetResult.new(existing_wager + pot_fraction, true, AVAILABLE)
