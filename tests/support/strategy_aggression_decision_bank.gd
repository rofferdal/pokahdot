extends RefCounted

## Reproducible private evidence from identical legal betting situations.
const MODEL := preload("res://scripts/core/agents/strategy_decision_model.gd")
const OLD_BENCHMARK := preload("res://tests/support/bot_raise_response_benchmark.gd")
const STREETS: Array[StringName] = [&"preflop", &"flop", &"turn", &"river"]


static func specifications() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for street: StringName in STREETS:
		for count: int in [2, 6, 9]:
			for stack: int in [100, 1000]:
				for scenario: String in [
					"initial_value",
					"value_resistance",
					"strong_resistance",
					"weak_repeat",
					"initial_bluff",
					"expensive_value",
				]:
					result.append(_spec(scenario, street, count, stack))
				if street != &"preflop":
					for scenario: String in [
						"delayed_bluff", "delayed_gutshot", "delayed_backdoor", "missed_draw"
					]:
						if scenario != "missed_draw" or street == &"river":
							result.append(_spec(scenario, street, count, stack))
					if count > 2:
						result.append(_spec("prior_call_bluff", street, count, stack))
				if count > 2:
					result.append(_spec("two_increases_weak", street, count, stack))
	result.append(_spec("j8_small_all_in", &"preflop", 2, 30))
	for stack: int in [100, 1000]:
		result.append(_spec("two_increases_backdoor", &"flop", 3, stack))
		result.append(_spec("prior_call_backdoor", &"flop", 3, stack))
	return result


static func _spec(scenario: String, street: StringName, count: int, stack: int) -> Dictionary:
	return {
		"id": "%s/%s/p%d/s%d" % [scenario, street, count, stack],
		"scenario": scenario,
		"street": street,
		"player_count": count,
		"starting_stack": stack,
	}


static func profiles(include_controls: bool = true) -> Array[BotProfile]:
	var result: Array[BotProfile] = OLD_BENCHMARK.profiles()
	if include_controls:
		for percentage: int in [0, 50, 100]:
			result.append(_control("control_raise_%d" % percentage, percentage, 0))
		for percentage: int in [0, 100]:
			result.append(_control("control_bluff_%d" % percentage, 0, percentage))
	return result


static func _control(id: String, raising: int, bluffing: int) -> BotProfile:
	var result := BotProfile.new()
	result.profile_id = StringName(id)
	result.model_id = &"strategy_parameterized"
	var parameters := StrategyDecisionModelParameters.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 50
	parameters.call_vs_raise = raising
	parameters.bluff_rate = bluffing
	result.parameters = parameters
	return result


static func fixture(spec: Dictionary) -> Dictionary:
	var count: int = spec.player_count
	var scenario: String = spec.scenario
	var street: StringName = spec.street
	var hero: int = 2 if scenario in ["two_increases_weak", "two_increases_backdoor"] else 0
	if scenario in ["prior_call_bluff", "prior_call_backdoor"]:
		hero = 1
	var hero_codes: String = _hero_cards(scenario, street)
	var board_codes: String = "2C 7D QS 4H JC"
	if scenario == "strong_resistance":
		board_codes = "2C 7D 9S 4H JC"
	elif scenario == "delayed_gutshot":
		board_codes = "2C 5D 9S KH JC"
	elif scenario in ["delayed_backdoor", "two_increases_backdoor", "prior_call_backdoor"]:
		board_codes = "8S 9D JH 4C QC"
	elif scenario == "missed_draw":
		board_codes = "2S 7S 9D 4H JC"
	var full_board := cards(board_codes)
	var players: Array[Player] = []
	var reserved: Dictionary[int, bool] = {}
	for card: CardData in cards(hero_codes) + full_board:
		reserved[card.card_id] = true
	var available: Array[CardData] = []
	for rank: int in range(2, 15):
		for suit: int in range(4):
			var card := CardData.new(rank, suit as CardData.Suit)
			if not reserved.has(card.card_id):
				available.append(card)
	for seat: int in range(count):
		var player := Player.new(StringName("p%d" % seat), "Player", seat, spec.starting_stack)
		var dealt: Array[CardData] = []
		if seat == hero:
			dealt = cards(hero_codes)
		else:
			dealt.append(available.pop_back())
			dealt.append(available.pop_back())
		for card: CardData in dealt:
			player.add_hole_card(card)
		players.append(player)
	var table := Table.new(players, 5, 10)
	table.button_seat = (0 if count == 2 else count - 3) if street == &"preflop" else count - 1
	var result := {
		"spec": spec,
		"hero": hero,
		"table": table,
		"players": players,
		"pots": PotManager.new(),
		"history": [] as Array[PublicActionRecord],
		"street": &"preflop",
		"board": [] as Array[CardData],
		"round": null,
	}
	for small: bool in [true, false]:
		var seat: int = table.small_blind_seat() if small else table.big_blind_seat()
		var amount: int = players[seat].commit_chips(5 if small else 10)
		result.pots.record_contribution(seat, amount)
		result.history.append(PublicActionRecord.blind(seat, amount, small))
	result.round = BettingRound.new(table, table.first_to_act_preflop(), 10)
	if street != &"preflop":
		if scenario in ["delayed_backdoor", "two_increases_backdoor", "prior_call_backdoor"]:
			apply(result, result.round.acting_seat, PlayerAction.raise_to(20))
		_finish_passive_round(result)
		for next_street: StringName in [&"flop", &"turn", &"river"]:
			for player: Player in players:
				player.reset_betting_round()
			result.street = next_street
			var board_size: int = (
				3 if next_street == &"flop" else (4 if next_street == &"turn" else 5)
			)
			result.board = full_board.slice(0, board_size)
			result.round = BettingRound.new(table, table.first_to_act_postflop())
			if next_street == street:
				break
			apply(result, result.round.acting_seat, PlayerAction.bet_to(10))
			_finish_passive_round(result)
	_prepare_decision(result)
	assert(result.round.acting_seat == hero, spec.id)
	return result


static func _hero_cards(scenario: String, street: StringName) -> String:
	if (
		scenario
		in [
			"weak_repeat",
			"initial_bluff",
			"delayed_bluff",
			"prior_call_bluff",
			"two_increases_weak"
		]
	):
		return "8H 3H"
	if scenario == "delayed_gutshot":
		return "3H 6H"
	if scenario in ["delayed_backdoor", "two_increases_backdoor", "prior_call_backdoor"]:
		return "AS 2S"
	if scenario == "missed_draw":
		return "AS KS"
	if scenario == "strong_resistance":
		return "AS AH" if street == &"preflop" else "9H 9D"
	if scenario in ["j8_small_all_in", "expensive_value"]:
		return "JS 8S"
	return "AS KS" if street == &"preflop" else "QH 10D"


static func _prepare_decision(fixture_data: Dictionary) -> void:
	var scenario: String = fixture_data.spec.scenario
	var count: int = fixture_data.spec.player_count
	var opening: bool = fixture_data.street != &"preflop"
	if scenario in ["initial_value", "initial_bluff"]:
		return
	if scenario in ["delayed_bluff", "delayed_gutshot", "delayed_backdoor", "missed_draw"]:
		apply(fixture_data, 0, PlayerAction.check_action())
		while fixture_data.round.acting_seat != count - 1:
			apply(fixture_data, fixture_data.round.acting_seat, PlayerAction.check_action())
		apply(fixture_data, count - 1, PlayerAction.bet_to(10))
		return
	if (
		scenario
		in [
			"two_increases_weak",
			"two_increases_backdoor",
			"prior_call_bluff",
			"prior_call_backdoor"
		]
	):
		apply(fixture_data, 0, PlayerAction.bet_to(10) if opening else PlayerAction.raise_to(20))
		if scenario in ["prior_call_bluff", "prior_call_backdoor"]:
			apply(fixture_data, 1, PlayerAction.call_action())
			while fixture_data.round.acting_seat != count - 1:
				apply(fixture_data, fixture_data.round.acting_seat, PlayerAction.call_action())
			apply(fixture_data, count - 1, PlayerAction.raise_to(20))
			apply(fixture_data, 0, PlayerAction.call_action())
		else:
			apply(fixture_data, 1, PlayerAction.raise_to(20 if opening else 30))
		return
	apply(fixture_data, 0, PlayerAction.bet_to(10) if opening else PlayerAction.raise_to(20))
	while fixture_data.round.acting_seat != count - 1:
		apply(fixture_data, fixture_data.round.acting_seat, PlayerAction.call_action())
	var target: int = fixture_data.round.minimum_wager_total()
	if scenario == "expensive_value":
		target = mini(
			fixture_data.round.maximum_wager_total(count - 1),
			80 if fixture_data.spec.starting_stack == 100 else 400
		)
	apply(fixture_data, count - 1, PlayerAction.raise_to(target))


static func _finish_passive_round(fixture_data: Dictionary) -> void:
	while not fixture_data.round.is_complete():
		var seat: int = fixture_data.round.acting_seat
		var legal: Array[PlayerAction.Kind] = fixture_data.round.legal_actions(seat)
		apply(
			fixture_data,
			seat,
			(
				PlayerAction.check_action()
				if PlayerAction.Kind.CHECK in legal
				else PlayerAction.call_action()
			)
		)


static func apply(fixture_data: Dictionary, seat: int, action: PlayerAction) -> void:
	var result: ActionValidationResult = fixture_data.round.apply_action(seat, action)
	assert(result.is_ok(), "%s: %s" % [fixture_data.spec.id, result.message])
	fixture_data.pots.record_contribution(seat, result.chips_committed)
	fixture_data.history.append(
		PublicActionRecord.new(
			seat,
			action.kind,
			fixture_data.players[seat].bet_this_round,
			PublicActionRecord.Kind.ACTION,
			fixture_data.street
		)
	)


static func view(fixture_data: Dictionary) -> GameView:
	return GameView.for_hand(
		fixture_data.table,
		fixture_data.hero,
		fixture_data.round,
		fixture_data.pots,
		fixture_data.history,
		fixture_data.street,
		fixture_data.board,
		[],
		{}
	)


static func cards(codes: String) -> Array[CardData]:
	var result: Array[CardData] = []
	for token: String in codes.split(" "):
		var rank_text := token.left(-1)
		var rank: int = {"A": 14, "K": 13, "Q": 12, "J": 11}.get(rank_text, int(rank_text))
		var suit: CardData.Suit = {
			"C": CardData.Suit.CLUBS,
			"D": CardData.Suit.DIAMONDS,
			"H": CardData.Suit.HEARTS,
			"S": CardData.Suit.SPADES
		}[token.right(1)]
		result.append(CardData.new(rank, suit))
	return result


static func run_bank(seed_start: int = 151001, samples: int = 32) -> Dictionary:
	var started := Time.get_ticks_usec()
	var rows: Array[Dictionary] = []
	var specs := specifications()
	for spec: Dictionary in specs:
		var fixture_data := fixture(spec)
		var snapshot := view(fixture_data)
		var estimate: HandPotentialEstimate = MODEL.new()._estimate(snapshot)
		var checked: Dictionary[String, bool] = {}
		for profile: BotProfile in profiles():
			var row := {
				"case_id": spec.id,
				"scenario": spec.scenario,
				"street": String(spec.street),
				"player_count": spec.player_count,
				"starting_stack": spec.starting_stack,
				"profile": String(profile.profile_id),
				"samples": samples,
				"legal_raise": PlayerAction.Kind.RAISE in snapshot.legal_actions,
				"legal_bet": PlayerAction.Kind.BET in snapshot.legal_actions,
				"actions": {},
				"branches": {},
				"value_eligible": 0,
				"bluff_eligible": 0,
				"valid": true,
				"draw_outs": estimate.improvement_outs,
				"draw_quality": maxi(estimate.flush_draw_quality, estimate.straight_draw_quality),
			}
			for sample: int in range(samples):
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_start + sample
				var model := MODEL.new()
				assert(model.configure(profile.parameters, rng).is_empty())
				var action: PlayerAction = model.choose_action(snapshot)
				var trace: StrategyDecisionTrace = model.get_last_decision_trace_for_testing()
				var diagnostics: StrategyDecisionDiagnostics = trace.diagnostics
				var action_name: String = PlayerAction.Kind.keys()[action.kind]
				row.actions[action_name] = int(row.actions.get(action_name, 0)) + 1
				var branch: String = trace.selected_branch
				row.branches[branch] = int(row.branches.get(branch, 0)) + 1
				row.value_eligible += int(diagnostics.value_raise_eligible)
				row.bluff_eligible += int(diagnostics.bluff_eligible)
				row["score"] = diagnostics.score
				row["call_price"] = diagnostics.call_price
				row["bluff_reason"] = String(diagnostics.bluff_reason)
				row["raise_percentage"] = _diagnostic_value(
					diagnostics,
					&"value_raise_percentage",
					(
						float(profile.parameters.call_vs_raise)
						if diagnostics.value_raise_eligible
						else 0.0
					)
				)
				var signature := "%d:%d" % [action.kind, action.amount]
				if not checked.has(signature):
					var fresh := fixture(spec)
					var validation: ActionValidationResult = fresh.round.apply_action(
						fresh.hero, action
					)
					row.valid = validation.is_ok() and _conserved(fresh, validation.chips_committed)
					assert(row.valid, spec.id)
					checked[signature] = true
			rows.append(row)
	return {
		"schema": "bfcr_aggression_bank_v1",
		"policy_version": String(MODEL.POLICY_VERSION),
		"seed_start": seed_start,
		"samples": samples,
		"cases": specs.size(),
		"rows": rows,
		"source_hashes": source_hashes(),
		"runtime_seconds": (Time.get_ticks_usec() - started) / 1000000.0,
	}


static func _diagnostic_value(diagnostics: Object, key: StringName, fallback: float) -> float:
	for property: Dictionary in diagnostics.get_property_list():
		if property.name == key:
			return float(diagnostics.get(key))
	return fallback


static func _conserved(fixture_data: Dictionary, committed: int) -> bool:
	var total: int = fixture_data.pots.total_amount + committed
	for player: Player in fixture_data.players:
		total += player.stack
	return total == fixture_data.spec.starting_stack * fixture_data.spec.player_count


static func source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [
		"res://scripts/core/agents/strategy_decision_model.gd",
		"res://scripts/core/agents/strategy_decision_diagnostics.gd",
		"res://scripts/core/agents/strategy_street_context.gd",
		"res://tests/support/strategy_aggression_decision_bank.gd",
	]:
		result[path] = FileAccess.get_sha256(path)
	for profile: BotProfile in OLD_BENCHMARK.profiles():
		result[profile.resource_path] = FileAccess.get_sha256(profile.resource_path)
	return result
