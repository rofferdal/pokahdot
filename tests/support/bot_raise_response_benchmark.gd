extends RefCounted

## Private, deterministic policy evidence. No adapter or public trace contract changes.
const MODEL := preload("res://scripts/core/agents/strategy_decision_model.gd")
const PUBLISHED := (
	"res://resources/bot_profiles/published/"
	+ "candidate_g1_mut_0004_23c4aa0775d54bec__20261024_r3b0.tres"
)
const MAX_ACTIONS := 100000


class MeasuredAgent:
	extends Agent
	var model: StrategyDecisionModel
	var collector: RefCounted
	var profile_id: StringName

	func _init(profile: BotProfile, rng: RandomNumberGenerator, evidence: RefCounted) -> void:
		model = MODEL.new()
		assert(model.configure(profile.parameters, rng).is_empty())
		model.set_profile_id_for_testing(profile.profile_id)
		profile_id = profile.profile_id
		collector = evidence

	func choose_action(view: GameView) -> PlayerAction:
		var action := model.choose_action(view)
		collector.record(view, model, profile_id, action)
		return action

	func observe(record: PublicActionRecord) -> void:
		model.observe(record)


class Collector:
	extends RefCounted
	var decisions: int = 0
	var responses: Array[Dictionary] = []
	var branches: Dictionary = {}
	var previous_aggression: Dictionary = {}
	var key: String = ""
	var raise_run: int = 0
	var long_chains: int = 0
	var repeated_weak_bluffs: int = 0
	var last_bluff_seats: Dictionary = {}

	func record(
		view: GameView, model: StrategyDecisionModel, profile_id: StringName, action: PlayerAction
	) -> void:
		var next_key := "%d:%s" % [view.hand_number, view.street]
		if key != next_key:
			key = next_key
			previous_aggression.clear()
			last_bluff_seats.clear()
			raise_run = 0
		decisions += 1
		var trace: StrategyDecisionTrace = model.get_last_decision_trace_for_testing()
		var branch: String = trace.selected_branch
		branches[branch] = int(branches.get(branch, 0)) + 1
		var estimate: HandPotentialEstimate = model._estimate(view)
		var stack: int = model._hero_stack(view)
		var price: float = model._call_price(view)
		var threshold: float = (
			75.0
			- 0.45 * float(model._parameters.tight_vs_loose)
			+ price * 8.0
			+ model._stack_pressure(view) * 4.0
			- float(mini(model._position_ordinal(view), 5))
		)
		if previous_aggression.has(view.hero_seat) and PlayerAction.Kind.CALL in view.legal_actions:
			(
				responses
				. append(
					{
						"profile": String(profile_id),
						"hand": view.hand_number,
						"street": String(view.street),
						"seat": view.hero_seat,
						"previous_branch": previous_aggression[view.hero_seat],
						"branch": branch,
						"action": PlayerAction.Kind.keys()[action.kind],
						"call": view.call_amount,
						"pot": view.pot_amount,
						"call_price": price,
						"stack_pressure": model._stack_pressure(view),
						"stack": stack,
						"opponents": model._active_opponent_count(view),
						"score": estimate.score,
						"legacy_threshold": threshold,
						"cheap": price <= 0.20,
						"expensive": price >= 0.40,
						"weak": estimate.score < 30,
						"threshold_crossing": estimate.score < threshold,
					}
				)
			)
		var aggressive: bool = action.kind in [PlayerAction.Kind.BET, PlayerAction.Kind.RAISE]
		if action.kind == PlayerAction.Kind.ALL_IN:
			aggressive = (
				view.maximum_wager_total > view.call_amount + model._hero_existing_wager(view)
			)
		if aggressive:
			previous_aggression[view.hero_seat] = branch
			var opening: bool = action.kind == PlayerAction.Kind.BET
			if action.kind == PlayerAction.Kind.ALL_IN:
				opening = view.call_amount + model._hero_existing_wager(view) == 0
			raise_run = 0 if opening else raise_run + 1
			if raise_run == 3:
				long_chains += 1
		else:
			raise_run = 0
		if branch in ["bluff_bet", "bluff_raise"]:
			if last_bluff_seats.has(view.hero_seat):
				repeated_weak_bluffs += 1
			last_bluff_seats[view.hero_seat] = true


static func profiles() -> Array[BotProfile]:
	var result: Array[BotProfile] = []
	for path: String in PlayableBotRoster.DEFAULT_PROFILE_PATHS:
		var profile: BotProfile = load(path)
		if profile.model_id == &"strategy_parameterized":
			result.append(profile)
	return result


static func run_cohort(seed_start: int, focal_limit: int = 15) -> Dictionary:
	var started := Time.get_ticks_usec()
	var catalog := profiles()
	var tournaments: Array[Dictionary] = []
	var rows: Array[Dictionary] = []
	var all_branches: Dictionary = {}
	var total_decisions := 0
	var total_chains := 0
	var total_repeats := 0
	var total_rejections := 0
	var source_hashes: Dictionary = {}
	for path: String in [
		"res://scripts/core/agents/strategy_decision_model.gd",
		"res://scripts/core/agents/hand_potential_estimate.gd",
		"res://scripts/core/agents/strategy_decision_trace.gd",
		"res://tests/support/bot_raise_response_benchmark.gd",
	]:
		source_hashes[path] = FileAccess.get_sha256(path)
	var profile_hashes: Dictionary = {}
	for profile: BotProfile in catalog:
		profile_hashes[String(profile.profile_id)] = FileAccess.get_sha256(profile.resource_path)
	for focal: int in range(mini(focal_limit, catalog.size())):
		for count: int in [2, 6, 9]:
			for stack: int in [100, 1000]:
				for mirrored: bool in [false, true]:
					var seed_value: int = seed_start + tournaments.size()
					var measured := run_tournament(
						catalog, focal, count, stack, mirrored, seed_value
					)
					for row: Dictionary in measured.responses:
						row["tournament"] = tournaments.size()
						rows.append(row)
					for branch: String in measured.branches:
						all_branches[branch] = (
							int(all_branches.get(branch, 0)) + int(measured.branches[branch])
						)
					total_decisions += int(measured.decisions)
					total_chains += int(measured.long_chains)
					total_repeats += int(measured.repeated_weak_bluffs)
					total_rejections += int(measured.invalid_actions)
					measured.erase("responses")
					measured.erase("branches")
					tournaments.append(measured)
	return {
		"schema": "bfcr_behavior_v1",
		"seed_start": seed_start,
		"source_hashes": source_hashes,
		"profile_hashes": profile_hashes,
		"tournaments": tournaments,
		"responses": rows,
		"branches": all_branches,
		"decisions": total_decisions,
		"long_chains": total_chains,
		"repeated_weak_bluffs": total_repeats,
		"invalid_actions": total_rejections,
		"response_summary": summarize(rows),
		"runtime_seconds": (Time.get_ticks_usec() - started) / 1000000.0,
	}


static func run_tournament(
	catalog: Array[BotProfile], focal: int, count: int, stack: int, mirrored: bool, seed_value: int
) -> Dictionary:
	var collector := Collector.new()
	var seat_ids: Dictionary[int, StringName] = {}
	var agents: Dictionary[int, Agent] = {}
	var assigned: Array[String] = []
	for seat: int in range(count):
		var offset: int = count - 1 - seat if mirrored else seat
		var profile: BotProfile = catalog[(focal + offset) % catalog.size()]
		assigned.append(String(profile.profile_id))
		seat_ids[seat] = profile.profile_id
	var config := ResolvedTournamentConfig.new(
		count, stack, 5, 10, seed_value, &"single_table", seat_ids
	)
	var streams := RngStreamFactory.new(Callable(), RngStreamFactory.ALGORITHM_VERSION).create(
		config
	)
	for seat: int in range(count):
		var offset: int = count - 1 - seat if mirrored else seat
		agents[seat] = MeasuredAgent.new(
			catalog[(focal + offset) % catalog.size()], streams.get_bot_rng(seat), collector
		)
	var match_instance := TournamentMatch.new(
		config, agents, TournamentConstructionContract.simulation(), streams
	)
	var result := match_instance.start(1)
	var rejection_count := 0
	var rejected_folds := 0
	var event_hand := 0
	var event_cursor := 0
	var transitions := 0
	while true:
		if event_hand != match_instance.hand_number:
			event_hand = match_instance.hand_number
			event_cursor = 0
		var events := match_instance.get_events()
		for index: int in range(event_cursor, events.size()):
			if events[index].kind == DomainEvent.Kind.ACTION_REJECTED:
				rejection_count += 1
				if events[index].applied_action_kind == PlayerAction.Kind.FOLD:
					rejected_folds += 1
		event_cursor = events.size()
		if (
			result.status == StepResult.Status.ERROR
			or match_instance.state == TournamentMatch.State.FINISHED
		):
			break
		transitions += 1
		if transitions >= MAX_ACTIONS:
			break
		result = match_instance.advance_one_action()
	var final_view := match_instance.get_view_for(0)
	var chips := 0
	for player: PlayerView in final_view.seats:
		chips += player.stack
	return {
		"seed": seed_value,
		"player_count": count,
		"starting_stack": stack,
		"mirrored": mirrored,
		"seat_profiles": assigned,
		"winner": match_instance.winner_seat,
		"hands": match_instance.hand_number,
		"completed": match_instance.end_reason == &"winner",
		"chip_total": chips,
		"expected_chip_total": count * stack,
		"error": result.message if result.status == StepResult.Status.ERROR else "",
		"decisions": collector.decisions,
		"long_chains": collector.long_chains,
		"repeated_weak_bluffs": collector.repeated_weak_bluffs,
		"invalid_actions": rejection_count,
		"fallback_folds": rejected_folds,
		"responses": collector.responses,
		"branches": collector.branches,
	}


static func summarize(rows: Array[Dictionary]) -> Dictionary:
	var groups: Dictionary = {}
	for row: Dictionary in rows:
		for key: String in [
			"all",
			"profile:" + row.profile,
			"street:" + row.street,
			"prior:" + row.previous_branch,
			"cheap" if row.cheap else "other_price",
			"expensive" if row.expensive else "not_expensive",
			"weak" if row.weak else "nonweak",
			"opponents:%d" % row.opponents,
			"pressure:high" if row.stack_pressure >= 0.25 else "pressure:low",
			"cheap_nonweak" if row.cheap and not row.weak else "outside_cheap_nonweak",
			"cheap_weak" if row.cheap and row.weak else "outside_cheap_weak"
		]:
			if not groups.has(key):
				groups[key] = {"opportunities": 0, "FOLD": 0, "CALL": 0, "RAISE": 0, "other": 0}
			var group: Dictionary = groups[key]
			group.opportunities += 1
			var action: String = row.action
			group[action if action in ["FOLD", "CALL", "RAISE"] else "other"] += 1
	for key: String in groups:
		var group: Dictionary = groups[key]
		var n: float = group.opportunities
		var p: float = float(group.FOLD) / n
		var denominator: float = 1.0 + 3.8416 / n
		var center: float = (p + 1.9208 / n) / denominator
		var half: float = 1.96 * sqrt(p * (1.0 - p) / n + 0.9604 / (n * n)) / denominator
		group["fold_rate"] = p
		group["fold_wilson95"] = [maxf(0, center - half), minf(1, center + half)]
	return groups


static func controlled_round(
	published: bool, seed_value: int, short_value: bool = false
) -> Array[Dictionary]:
	var stack: int = 30 if short_value else 1000
	var players: Array[Player] = [Player.new(&"a", "A", 0, stack), Player.new(&"b", "B", 1, stack)]
	players[0].add_hole_card(CardData.new(11 if short_value else 7, CardData.Suit.SPADES))
	players[0].add_hole_card(
		CardData.new(
			8 if short_value else 2, CardData.Suit.SPADES if short_value else CardData.Suit.HEARTS
		)
	)
	players[1].add_hole_card(CardData.new(3 if short_value else 8, CardData.Suit.CLUBS))
	players[1].add_hole_card(CardData.new(2 if short_value else 3, CardData.Suit.DIAMONDS))
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var pots := PotManager.new()
	pots.record_contribution(0, players[0].commit_chips(5))
	pots.record_contribution(1, players[1].commit_chips(10))
	var round := BettingRound.new(table, 0, 10)
	var models: Array[StrategyDecisionModel] = []
	for seat: int in range(2):
		var profile: BotProfile = load(
			PUBLISHED if published else "res://resources/bot_profiles/loose_aggressive.tres"
		)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 2 + seat
		var model := StrategyDecisionModel.new()
		assert(model.configure(profile.parameters, rng).is_empty())
		models.append(model)
	var history: Array[PublicActionRecord] = [
		PublicActionRecord.blind(0, 5, true), PublicActionRecord.blind(1, 10, false)
	]
	var rows: Array[Dictionary] = []
	while not round.is_complete() and rows.size() < 20:
		var seat := round.acting_seat
		var view := GameView.for_preflop(table, seat, round, pots, history)
		var model := models[seat]
		var action := model.choose_action(view)
		var branch: String = model.get_last_decision_trace_for_testing().selected_branch
		if short_value and seat == 1:
			action = PlayerAction.raise_to(view.minimum_wager_total)
			branch = "scripted_min_raise"
		var applied := round.apply_action(seat, action)
		rows.append(
			{
				"seat": seat,
				"score": model._estimate(view).score,
				"pot": view.pot_amount,
				"call": view.call_amount,
				"action": PlayerAction.Kind.keys()[action.kind],
				"target": action.amount,
				"branch": branch,
				"legal": applied.is_ok(),
				"error": applied.message
			}
		)
		if not applied.is_ok():
			break
		pots.record_contribution(seat, applied.chips_committed)
		history.append(PublicActionRecord.new(seat, action.kind, players[seat].bet_this_round))
	return rows
