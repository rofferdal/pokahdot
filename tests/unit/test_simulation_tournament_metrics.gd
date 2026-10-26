extends "res://tests/support/poker_gut_test.gd"

const METRICS_SCRIPT := preload("res://scripts/simulation/simulation_tournament_metrics.gd")


func test_handcrafted_public_events_produce_documented_hand_and_tournament_metrics() -> void:
	var metrics := METRICS_SCRIPT.new({0: &"alpha", 1: &"beta"}, {0: 100, 1: 100})
	(
		metrics
		. observe_hand(
			[0, 1],
			{0: 100, 1: 100},
			{0: 130, 1: 70},
			10,
			[
				PublicActionRecord.blind(0, 5, true),
				PublicActionRecord.blind(1, 10, false),
				PublicActionRecord.new(0, PlayerAction.Kind.RAISE, 20),
				PublicActionRecord.new(1, PlayerAction.Kind.CALL, 20)
			],
			[
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1)
			],
		)
	)
	(
		metrics
		. observe_hand(
			[0, 1],
			{0: 130, 1: 70},
			{0: 200, 1: 0},
			20,
			[
				PublicActionRecord.new(0, PlayerAction.Kind.CHECK),
				PublicActionRecord.new(1, PlayerAction.Kind.FOLD)
			],
			[
				DomainEvent.new(DomainEvent.Kind.ACTION_REJECTED, 1),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1)
			],
		)
	)
	metrics.finish({0: 200, 1: 0}, 0, 2)

	var by_seat := metrics.get_seat_metrics()
	var alpha = by_seat[0]
	var beta = by_seat[1]
	assert_eq(alpha.finishing_position, 1)
	assert_true(alpha.won_tournament)
	assert_eq(alpha.chip_differential, 100)
	assert_eq(alpha.hands_survived, 2)
	assert_almost_eq(alpha.survival_ratio, 1.0, 0.0001)
	assert_almost_eq(alpha.blind_normalized_chip_sum, 6.5, 0.0001)
	assert_almost_eq(alpha.bnc_per_100, 325.0, 0.0001)
	assert_eq(alpha.vpip_hands, 1)
	assert_eq(alpha.pfr_hands, 1)
	assert_eq(alpha.aggressive_actions, 1)
	assert_eq(alpha.call_actions, 0)
	assert_eq(beta.invalid_action_fallbacks, 1)
	assert_eq(beta.vpip_hands, 1)
	assert_eq(beta.call_actions, 1)
	assert_almost_eq(beta.aggression_factor, 0.0, 0.0001)


func test_finishing_positions_follow_elimination_history_instead_of_seat_order() -> void:
	var metrics := (
		METRICS_SCRIPT
		. new(
			{0: &"winner", 1: &"third", 2: &"fourth", 3: &"second"},
			{0: 100, 1: 100, 2: 100, 3: 100},
		)
	)
	_observe_elimination(metrics, [0, 1, 2, 3], {0: 140, 1: 120, 2: 0, 3: 140})
	_observe_elimination(metrics, [0, 1, 3], {0: 220, 1: 0, 2: 0, 3: 180})
	_observe_elimination(metrics, [0, 3], {0: 400, 1: 0, 2: 0, 3: 0})

	metrics.finish({0: 400, 1: 0, 2: 0, 3: 0}, 0, 3)

	var by_seat := metrics.get_seat_metrics()
	assert_eq(by_seat[0].finishing_position, 1)
	assert_eq(by_seat[3].finishing_position, 2)
	assert_eq(by_seat[1].finishing_position, 3)
	assert_eq(by_seat[2].finishing_position, 4)


func test_same_hand_eliminations_share_competition_rank_and_top_third_status() -> void:
	var metrics := (
		METRICS_SCRIPT
		. new(
			{0: &"winner", 1: &"tied", 2: &"earlier", 3: &"tied"},
			{0: 100, 1: 100, 2: 100, 3: 100},
		)
	)
	_observe_elimination(metrics, [0, 1, 2, 3], {0: 150, 1: 125, 2: 0, 3: 125})
	_observe_elimination(metrics, [0, 1, 3], {0: 400, 1: 0, 2: 0, 3: 0})

	metrics.finish({0: 400, 1: 0, 2: 0, 3: 0}, 0, 2)

	var by_seat := metrics.get_seat_metrics()
	assert_eq(by_seat[1].finishing_position, 2)
	assert_eq(by_seat[3].finishing_position, 2)
	assert_eq(by_seat[2].finishing_position, 4)
	assert_true(by_seat[1].top_third)
	assert_true(by_seat[3].top_third)
	assert_false(by_seat[2].top_third)


func _observe_elimination(
	metrics: RefCounted, active_at_start: Array[int], stacks_after: Dictionary[int, int]
) -> void:
	var stacks_before: Dictionary[int, int] = {}
	for seat: int in stacks_after:
		stacks_before[seat] = 100 if seat in active_at_start else 0
	var actions: Array[PublicActionRecord] = []
	var events: Array[DomainEvent] = []
	metrics.observe_hand(active_at_start, stacks_before, stacks_after, 10, actions, events)


func test_style_metrics_deduplicate_preflop_hands_and_include_postflop_actions() -> void:
	var metrics := METRICS_SCRIPT.new({0: &"alpha", 1: &"beta"}, {0: 100, 1: 100})
	(
		metrics
		. observe_hand(
			[0, 1],
			{0: 100, 1: 100},
			{0: 120, 1: 80},
			10,
			[
				PublicActionRecord.blind(0, 5, true),
				PublicActionRecord.blind(1, 10, false),
				PublicActionRecord.new(0, PlayerAction.Kind.RAISE, 20),
				PublicActionRecord.new(1, PlayerAction.Kind.RAISE, 30),
				PublicActionRecord.new(0, PlayerAction.Kind.CALL, 30),
				PublicActionRecord.new(0, PlayerAction.Kind.BET, 20),
				PublicActionRecord.new(1, PlayerAction.Kind.CALL, 20),
			],
			[
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0),
				DomainEvent.new(DomainEvent.Kind.STREET_CHANGED),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1),
			],
		)
	)
	metrics.finish({0: 120, 1: 80}, 0, 1)

	var alpha = metrics.get_seat_metrics()[0]
	var beta = metrics.get_seat_metrics()[1]
	assert_eq(alpha.vpip_hands, 1)
	assert_eq(alpha.pfr_hands, 1)
	assert_eq(alpha.bet_actions, 1)
	assert_eq(alpha.raise_actions, 1)
	assert_eq(alpha.call_actions, 1)
	assert_eq(beta.vpip_hands, 1)
	assert_eq(beta.pfr_hands, 1)
	assert_eq(beta.raise_actions, 1)
	assert_eq(beta.call_actions, 1)


func test_decision_metrics_record_opportunities_splits_and_eligible_bluffs() -> void:
	var metrics := METRICS_SCRIPT.new({0: &"alpha"}, {0: 100})
	var bluff_trace := (
		StrategyDecisionTrace
		. new(
			&"alpha",
			StrategyDecisionTrace.WEAK_BAND,
			&"bluff_bet",
			[PlayerAction.Kind.CHECK, PlayerAction.Kind.BET],
			PlayerAction.bet_to(10),
		)
	)
	(
		metrics
		. observe_decision(
			0,
			[PlayerAction.Kind.CHECK, PlayerAction.Kind.BET],
			PlayerAction.bet_to(10),
			bluff_trace,
		)
	)
	(
		metrics
		. observe_decision(
			0,
			[PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL, PlayerAction.Kind.RAISE],
			PlayerAction.call_action(),
		)
	)
	metrics.finish({0: 100}, 0, 1)

	var alpha = metrics.get_seat_metrics()[0]
	assert_eq(alpha.bet_raise_opportunities, 2)
	assert_eq(alpha.check_bet_opportunities, 1)
	assert_eq(alpha.bets_at_check_bet_opportunity, 1)
	assert_eq(alpha.call_raise_opportunities, 1)
	assert_eq(alpha.calls_at_call_raise_opportunity, 1)
	assert_eq(alpha.raises_at_call_raise_opportunity, 0)
	assert_eq(alpha.eligible_bluff_opportunities, 1)
	assert_eq(alpha.bluff_actions, 1)
	assert_almost_eq(alpha.bet_frequency, 1.0, 0.0001)
	assert_almost_eq(alpha.raise_share, 0.0, 0.0001)
	assert_almost_eq(alpha.eligible_bluff_frequency, 1.0, 0.0001)


func test_all_in_actions_are_classified_as_calls_bets_or_raises() -> void:
	var metrics := METRICS_SCRIPT.new({0: &"raiser", 1: &"caller"}, {0: 100, 1: 100})
	(
		metrics
		. observe_hand(
			[0, 1],
			{0: 100, 1: 100},
			{0: 0, 1: 200},
			10,
			[
				PublicActionRecord.blind(0, 5, true),
				PublicActionRecord.blind(1, 10, false),
				PublicActionRecord.new(0, PlayerAction.Kind.ALL_IN, 100),
				PublicActionRecord.new(1, PlayerAction.Kind.ALL_IN, 100),
			],
			[
				DomainEvent.new(DomainEvent.Kind.BLIND_POSTED, 0, 5),
				DomainEvent.new(DomainEvent.Kind.BLIND_POSTED, 1, 10),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0, 100),
				DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1, 100),
			],
		)
	)
	(
		metrics
		. observe_decision(
			0,
			[
				PlayerAction.Kind.FOLD,
				PlayerAction.Kind.CALL,
				PlayerAction.Kind.RAISE,
				PlayerAction.Kind.ALL_IN
			],
			PlayerAction.all_in_action(),
		)
	)
	(
		metrics
		. observe_decision(
			1,
			[PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL, PlayerAction.Kind.ALL_IN],
			PlayerAction.all_in_action(),
		)
	)
	metrics.finish({0: 0, 1: 200}, 1, 1)

	var raiser = metrics.get_seat_metrics()[0]
	var caller = metrics.get_seat_metrics()[1]
	assert_eq(raiser.pfr_hands, 1)
	assert_eq(raiser.raise_actions, 1)
	assert_eq(raiser.raises_at_call_raise_opportunity, 1)
	assert_eq(caller.pfr_hands, 0)
	assert_eq(caller.call_actions, 1)
	assert_eq(caller.calls_at_call_raise_opportunity, 0)


func test_short_all_in_raise_is_an_aggression_opportunity() -> void:
	var metrics := METRICS_SCRIPT.new({0: &"short_raiser"}, {0: 15})
	(
		metrics
		. observe_hand(
			[0],
			{0: 15},
			{0: 0},
			10,
			[PublicActionRecord.new(0, PlayerAction.Kind.ALL_IN, 15)],
			[DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0, 15)],
		)
	)
	(
		metrics
		. observe_decision(
			0,
			[PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL, PlayerAction.Kind.ALL_IN],
			PlayerAction.all_in_action(),
			null,
			PlayerAction.Kind.RAISE,
		)
	)
	metrics.finish({0: 0}, Table.NO_SEAT, 1)

	var metric = metrics.get_seat_metrics()[0]
	assert_eq(metric.aggressive_actions, 1)
	assert_eq(metric.bet_raise_opportunities, 1)
	assert_eq(metric.call_raise_opportunities, 1)
	assert_eq(metric.raises_at_call_raise_opportunity, 1)
	assert_almost_eq(metric.bet_raise_frequency, 1.0, 0.0001)
	assert_almost_eq(metric.raise_share, 1.0, 0.0001)
