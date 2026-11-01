extends RefCounted

## Private all-action metrics and complete raise-chain tails for BFCR follow-up.
const BANK := preload("res://tests/support/strategy_aggression_decision_bank.gd")


class DetailedCollector:
	extends RefCounted
	var legacy: RefCounted = BANK.OLD_BENCHMARK.Collector.new()
	var summaries: Dictionary = {}
	var street_key: String = ""
	var chain: int = 0
	var maximum_chain: int = 0
	var street_maximum: int = 0
	var street_tails: Array[int] = []
	var chain_lengths: Array[int] = []
	var decisions: int = 0

	func record(
		view: GameView, model: StrategyDecisionModel, profile_id: StringName, action: PlayerAction
	) -> void:
		var key := "%d:%s" % [view.hand_number, view.street]
		var prior_branch: String = (
			String(legacy.previous_aggression.get(view.hero_seat, "none"))
			if legacy.key == key
			else "none"
		)
		legacy.record(view, model, profile_id, action)
		if street_key != key:
			finish_street()
			street_key = key
		decisions += 1
		var trace: StrategyDecisionTrace = model.get_last_decision_trace_for_testing()
		var diagnostics: StrategyDecisionDiagnostics = trace.diagnostics
		var context := StrategyStreetContext.from_view(view)
		var category: String = "initial_value"
		if trace.selected_branch in [&"bluff_bet", &"bluff_raise"]:
			category = "initial_bluff"
			if context.hero_aggression_count > 0:
				category = "repeat_bluff"
			elif context.hero_action_count > 0:
				category = "delayed_bluff"
		elif context.hero_aggression_count > 0:
			category = (
				"post_bluff_response"
				if prior_branch in ["bluff_bet", "bluff_raise"]
				else "value_response"
			)
		elif context.hero_action_count > 0:
			category = "passive_response"
		var aggressive: bool = action.kind in [PlayerAction.Kind.BET, PlayerAction.Kind.RAISE]
		if action.kind == PlayerAction.Kind.ALL_IN:
			aggressive = (
				view.maximum_wager_total > model._hero_existing_wager(view) + view.call_amount
			)
		if aggressive and model._hero_existing_wager(view) + view.call_amount > 0:
			chain += 1
			street_maximum = maxi(street_maximum, chain)
			maximum_chain = maxi(maximum_chain, chain)
		else:
			if chain > 0:
				chain_lengths.append(chain)
			chain = 0
		var action_name: String = PlayerAction.Kind.keys()[action.kind]
		var groups: Array[String] = [
			"all",
			"profile:" + String(profile_id),
			"street:" + String(view.street),
			"category:" + category
		]
		if context.hero_aggression_count > 0 and view.call_amount > 0:
			groups.append("post_aggression")
			groups.append("prior:" + prior_branch)
		for group: String in groups:
			if not summaries.has(group):
				summaries[group] = {
					"decisions": 0,
					"actions": {},
					"branches": {},
					"legal_raise": 0,
					"legal_bet": 0,
					"value_eligible": 0,
					"bluff_eligible": 0,
					"post_aggression": 0,
				}
			var row: Dictionary = summaries[group]
			row.decisions += 1
			var branch: String = String(trace.selected_branch)
			row.branches[branch] = int(row.branches.get(branch, 0)) + 1
			row.actions[action_name] = int(row.actions.get(action_name, 0)) + 1
			row.legal_raise += int(PlayerAction.Kind.RAISE in view.legal_actions)
			row.legal_bet += int(PlayerAction.Kind.BET in view.legal_actions)
			row.value_eligible += int(diagnostics.value_raise_eligible)
			row.bluff_eligible += int(diagnostics.bluff_eligible)
			row.post_aggression += int(context.hero_aggression_count > 0 and view.call_amount > 0)

	func finish_street() -> void:
		if chain > 0:
			chain_lengths.append(chain)
		if not street_key.is_empty():
			street_tails.append(street_maximum)
		chain = 0
		street_maximum = 0


static func run_cohort(seed_start: int, focal_limit: int = 15) -> Dictionary:
	var started := Time.get_ticks_usec()
	var catalog: Array[BotProfile] = BANK.profiles(false)
	var tournaments: Array[Dictionary] = []
	for focal: int in range(mini(focal_limit, catalog.size())):
		for count: int in [2, 6, 9]:
			for stack: int in [100, 1000]:
				for mirrored: bool in [false, true]:
					tournaments.append(
						_tournament(
							catalog, focal, count, stack, mirrored, seed_start + tournaments.size()
						)
					)
	var hashes: Dictionary = BANK.source_hashes()
	hashes["res://tests/support/strategy_aggression_tournament_benchmark.gd"] = (
		FileAccess.get_sha256("res://tests/support/strategy_aggression_tournament_benchmark.gd")
	)
	return {
		"schema": "bfcr_aggression_tournaments_v1",
		"policy_version": String(StrategyDecisionModel.POLICY_VERSION),
		"seed_start": seed_start,
		"source_hashes": hashes,
		"tournaments": tournaments,
		"runtime_seconds": (Time.get_ticks_usec() - started) / 1000000.0,
	}


static func _tournament(
	catalog: Array[BotProfile], focal: int, count: int, stack: int, mirrored: bool, seed: int
) -> Dictionary:
	var collector := DetailedCollector.new()
	var seat_ids: Dictionary[int, StringName] = {}
	var agents: Dictionary[int, Agent] = {}
	var assigned: Array[String] = []
	for seat: int in range(count):
		var offset: int = count - 1 - seat if mirrored else seat
		var profile: BotProfile = catalog[(focal + offset) % catalog.size()]
		assigned.append(String(profile.profile_id))
		seat_ids[seat] = profile.profile_id
	var config := ResolvedTournamentConfig.new(count, stack, 5, 10, seed, &"single_table", seat_ids)
	var streams := RngStreamFactory.new(Callable(), RngStreamFactory.ALGORITHM_VERSION).create(
		config
	)
	for seat: int in range(count):
		var offset: int = count - 1 - seat if mirrored else seat
		agents[seat] = BANK.OLD_BENCHMARK.MeasuredAgent.new(
			catalog[(focal + offset) % catalog.size()], streams.get_bot_rng(seat), collector
		)
	var match_instance := TournamentMatch.new(
		config, agents, TournamentConstructionContract.simulation(), streams
	)
	var result := match_instance.start(1)
	var event_hand := 0
	var event_cursor := 0
	var rejections := 0
	var transitions := 0
	while true:
		if event_hand != match_instance.hand_number:
			event_hand = match_instance.hand_number
			event_cursor = 0
		var events: Array[DomainEvent] = match_instance.get_events()
		for index: int in range(event_cursor, events.size()):
			rejections += int(events[index].kind == DomainEvent.Kind.ACTION_REJECTED)
		event_cursor = events.size()
		if (
			result.status == StepResult.Status.ERROR
			or match_instance.state == TournamentMatch.State.FINISHED
		):
			break
		transitions += 1
		if transitions >= BANK.OLD_BENCHMARK.MAX_ACTIONS:
			break
		result = match_instance.advance_one_action()
	collector.finish_street()
	var histogram: Dictionary[String, int] = {}
	for length: int in collector.chain_lengths:
		var key := str(length)
		histogram[key] = histogram.get(key, 0) + 1
	var long_streets: int = 0
	for length: int in collector.street_tails:
		long_streets += int(length > 12)
	var chips := 0
	for player: PlayerView in match_instance.get_view_for(0).seats:
		chips += player.stack
	return {
		"seed": seed,
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
		"invalid_actions": rejections,
		"decisions": collector.decisions,
		"summaries": collector.summaries,
		"maximum_raise_chain": collector.maximum_chain,
		"betting_streets": collector.street_tails.size(),
		"streets_over_12_raises": long_streets,
		"raise_chain_histogram": histogram,
		"street_raise_tails": collector.street_tails,
		"response_summary": BANK.OLD_BENCHMARK.summarize(collector.legacy.responses),
		"long_chains": collector.legacy.long_chains,
		"repeated_weak_bluffs": collector.legacy.repeated_weak_bluffs,
	}
