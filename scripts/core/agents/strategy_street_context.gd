class_name StrategyStreetContext
extends RefCounted

## Public betting context derived from a detached, recipient-safe snapshot.
## No private bluff intent or prior model state is retained between decisions.

const BETTING_STREETS: Array[StringName] = [&"preflop", &"flop", &"turn", &"river"]

var hero_action_count: int = 0
var hero_last_action_kind: int = -1
var hero_aggression_count: int = 0
var opponent_aggression_after_hero: bool = false
var aggression_count: int = 0
var latest_wager_increase: int = 0
var contestable_pot_before_call: int = 0
var pot_is_reliable: bool = false
var call_price: float = 0.0


static func from_view(view: GameView) -> StrategyStreetContext:
	var result := StrategyStreetContext.new()
	if view == null:
		return result
	var history: Array[PublicActionRecord] = view.action_history
	result._count_street_actions(view, history)
	result._calculate_contestable_pot(view, history)
	if view.call_amount > 0:
		var pot_after_call: int = result.contestable_pot_before_call + view.call_amount
		result.call_price = (
			clampf(float(view.call_amount) / float(pot_after_call), 0.0, 1.0)
			if pot_after_call > 0
			else 1.0
		)
	return result


func _count_street_actions(view: GameView, history: Array[PublicActionRecord]) -> void:
	# A short-posted big blind still establishes the nominal preflop call total.
	var current_wager: int = view.big_blind if view.street == &"preflop" else 0
	for record: PublicActionRecord in history:
		if record.street != view.street:
			continue
		if record.record_kind == PublicActionRecord.Kind.ACTION:
			if record.seat == view.hero_seat:
				hero_action_count += 1
				hero_last_action_kind = record.kind
			var aggressive: bool = (
				(
					record.kind
					in [PlayerAction.Kind.BET, PlayerAction.Kind.RAISE, PlayerAction.Kind.ALL_IN]
				)
				and record.amount > current_wager
			)
			if aggressive:
				latest_wager_increase = record.amount - current_wager
				aggression_count += 1
				if record.seat == view.hero_seat:
					hero_aggression_count += 1
				elif hero_aggression_count > 0:
					opponent_aggression_after_hero = true
		current_wager = maxi(current_wager, record.amount)


func _calculate_contestable_pot(view: GameView, history: Array[PublicActionRecord]) -> void:
	var targets: Dictionary[StringName, Dictionary] = {}
	var complete_history: bool = true
	for record: PublicActionRecord in history:
		if record.street not in BETTING_STREETS or record.amount < 0:
			complete_history = false
			continue
		if not targets.has(record.street):
			targets[record.street] = {}
		var street_targets: Dictionary = targets[record.street]
		street_targets[record.seat] = maxi(int(street_targets.get(record.seat, 0)), record.amount)
	var contributions: Dictionary[int, int] = {}
	var reconstructed_total: int = 0
	for street_targets: Dictionary in targets.values():
		for seat: int in street_targets:
			var amount: int = street_targets[seat]
			contributions[seat] = contributions.get(seat, 0) + amount
			reconstructed_total += amount
	if complete_history and reconstructed_total == view.pot_amount:
		var hero_cap: int = contributions.get(view.hero_seat, 0) + view.call_amount
		for amount: int in contributions.values():
			contestable_pot_before_call += mini(amount, hero_cap)
		pot_is_reliable = true
		return
	# Old synthetic snapshots may provide a scalar pot without matching history.
	# A visible inaccessible side pot prevents treating that scalar as call value.
	contestable_pot_before_call = maxi(0, view.pot_amount)
	pot_is_reliable = true
	if view.pots.size() > 1:
		pot_is_reliable = false
		contestable_pot_before_call = 0
		return
	for pot: PotLayer in view.pots:
		if view.hero_seat not in pot.eligible_seats:
			pot_is_reliable = false
			contestable_pot_before_call = 0
			return
