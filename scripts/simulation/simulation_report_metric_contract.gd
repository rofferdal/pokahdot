class_name SimulationReportMetricContract
extends RefCounted

## Validates completed tournament metrics from primitive counters and stacks.

const COUNT_FIELDS := [
	"seat",
	"finishing_position",
	"starting_stack",
	"final_stack",
	"hands_survived",
	"tournament_hand_count",
	"hands_observed",
	"vpip_hands",
	"pfr_hands",
	"bet_actions",
	"raise_actions",
	"aggressive_actions",
	"call_actions",
	"bet_raise_opportunities",
	"check_bet_opportunities",
	"bets_at_check_bet_opportunity",
	"call_raise_opportunities",
	"calls_at_call_raise_opportunity",
	"raises_at_call_raise_opportunity",
	"eligible_bluff_opportunities",
	"bluff_actions",
	"invalid_action_fallbacks",
]
const COUNT_BOUNDS := [
	["hands_survived", "tournament_hand_count"],
	["vpip_hands", "hands_observed"],
	["pfr_hands", "hands_observed"],
	["pfr_hands", "vpip_hands"],
	["aggressive_actions", "bet_raise_opportunities"],
	["bets_at_check_bet_opportunity", "check_bet_opportunities"],
	["calls_at_call_raise_opportunity", "call_raise_opportunities"],
	["raises_at_call_raise_opportunity", "call_raise_opportunities"],
	["bluff_actions", "eligible_bluff_opportunities"],
]


static func validate(tournament: Dictionary, regime: SimulationRegime) -> PackedStringArray:
	var errors := PackedStringArray()
	if not tournament.diagnostics.is_empty() or tournament.tournament_hand_count <= 0:
		errors.append("Completed simulation tournaments require positive hands and no diagnostics.")
	var results: Array = tournament.profile_results
	if results.size() != regime.player_count:
		errors.append("Simulation profile result count does not match its regime.")
	var seen: Dictionary[int, bool] = {}
	var positions: Dictionary[int, int] = {}
	var winners: Array[String] = []
	var total: int = regime.player_count * regime.starting_stack
	var final_total: int = 0
	for row: Dictionary in results:
		var seat: int = int(row.seat)
		if seat < 0 or seat >= regime.player_count or seen.has(seat):
			errors.append("Simulation profile result seats are invalid or duplicated.")
			continue
		seen[seat] = true
		if row.profile_id != tournament.seat_map[seat].profile_id:
			errors.append("Simulation profile result does not match its planned seat.")
		_validate_row(row, regime, int(tournament.tournament_hand_count), errors)
		var position: int = int(row.finishing_position)
		positions[position] = positions.get(position, 0) + 1
		if row.final_stack < 0 or row.final_stack > total:
			errors.append("Simulation terminal stack is outside its tournament chip total.")
		elif final_total > total - int(row.final_stack):
			errors.append("Simulation terminal stacks exceed the tournament chip total.")
		else:
			final_total += int(row.final_stack)
		if row.won_tournament:
			winners.append(row.profile_id)
			if row.final_stack != total:
				errors.append("Simulation winner must own every tournament chip.")
		elif row.final_stack != 0:
			errors.append("Eliminated simulation players must have zero terminal chips.")
	if winners != [tournament.winner_profile_id]:
		errors.append("Simulation winner fields are inconsistent.")
	if final_total != total:
		errors.append("Simulation terminal stacks do not conserve chips.")
	var next_position: int = 1
	while next_position <= regime.player_count:
		if not positions.has(next_position):
			errors.append("Simulation finishing positions must use competition ranking.")
			break
		next_position += positions[next_position]
	return errors


static func _validate_row(
	row: Dictionary, regime: SimulationRegime, hand_count: int, errors: PackedStringArray
) -> void:
	for field: String in COUNT_FIELDS:
		if row[field] < 0:
			errors.append("Simulation metric %s cannot be negative." % field)
	var position: int = int(row.finishing_position)
	if position < 1 or position > regime.player_count:
		errors.append("Simulation finishing position is outside its regime.")
	if row.starting_stack != regime.starting_stack or row.tournament_hand_count != hand_count:
		errors.append("Simulation metric settings do not match its tournament.")
	if row.won_tournament != (position == 1):
		errors.append("Simulation win indicator does not match its finishing position.")
	if row.top_third != (position <= ceili(float(regime.player_count) / 3.0)):
		errors.append("Simulation top-third indicator does not match its finishing position.")
	if row.hands_observed != row.hands_survived:
		errors.append("Simulation observed and survived hand counts disagree.")
	if row.chip_differential != row.final_stack - row.starting_stack:
		errors.append("Simulation chip differential does not match its terminal stacks.")
	for pair: Array in COUNT_BOUNDS:
		if row[pair[0]] > row[pair[1]]:
			errors.append("Simulation metric %s exceeds %s." % [pair[0], pair[1]])
	if (
		float(row.calls_at_call_raise_opportunity) + float(row.raises_at_call_raise_opportunity)
		> float(row.call_raise_opportunities)
	):
		errors.append("Simulation call and raise counts exceed shared opportunities.")
	if float(row.aggressive_actions) != float(row.bet_actions) + float(row.raise_actions):
		errors.append("Simulation aggressive action count does not match bet and raise counts.")
	_validate_derived(row, hand_count, errors)


static func _validate_derived(row: Dictionary, hand_count: int, errors: PackedStringArray) -> void:
	var expected := {
		"survival_ratio": _ratio(row.hands_survived, hand_count),
		"bnc_per_100": _ratio(float(row.blind_normalized_chip_sum) * 100.0, row.hands_observed),
		"vpip_rate": _ratio(row.vpip_hands, row.hands_observed),
		"pfr_rate": _ratio(row.pfr_hands, row.hands_observed),
		"aggression_factor": _ratio(row.aggressive_actions, row.call_actions),
		"bet_raise_frequency": _ratio(row.aggressive_actions, row.bet_raise_opportunities),
		"bet_frequency": _ratio(row.bets_at_check_bet_opportunity, row.check_bet_opportunities),
		"raise_share":
		_ratio(
			row.raises_at_call_raise_opportunity,
			float(row.calls_at_call_raise_opportunity) + float(row.raises_at_call_raise_opportunity)
		),
		"eligible_bluff_frequency": _ratio(row.bluff_actions, row.eligible_bluff_opportunities),
	}
	for field: String in expected:
		var value: float = row[field]
		var calculated: float = expected[field]
		if (
			not is_finite(calculated)
			or absf(value - calculated) > maxf(1e-12, absf(calculated) * 1e-12)
		):
			errors.append("Simulation derived metric %s does not match its counts." % field)


static func _ratio(numerator: float, denominator: float) -> float:
	return numerator / denominator if denominator > 0.0 else 0.0
