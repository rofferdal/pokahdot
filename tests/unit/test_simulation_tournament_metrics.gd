extends "res://tests/support/poker_gut_test.gd"

const METRICS_SCRIPT := preload("res://scripts/simulation/simulation_tournament_metrics.gd")


func test_handcrafted_public_events_produce_documented_hand_and_tournament_metrics() -> void:
	var metrics := METRICS_SCRIPT.new({0: &"alpha", 1: &"beta"}, {0: 100, 1: 100})
	metrics.observe_hand(
		[0, 1], {0: 100, 1: 100}, {0: 130, 1: 70}, 10,
		[PublicActionRecord.new(0, PlayerAction.Kind.RAISE, 20), PublicActionRecord.new(1, PlayerAction.Kind.CALL, 20)],
		[DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0), DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1)],
	)
	metrics.observe_hand(
		[0, 1], {0: 130, 1: 70}, {0: 200, 1: 0}, 20,
		[PublicActionRecord.new(0, PlayerAction.Kind.CHECK), PublicActionRecord.new(1, PlayerAction.Kind.FOLD)],
		[DomainEvent.new(DomainEvent.Kind.ACTION_REJECTED, 1), DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0), DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1)],
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
	assert_eq(alpha.calls, 0)
	assert_eq(beta.invalid_action_fallbacks, 1)
	assert_eq(beta.vpip_hands, 1)
	assert_eq(beta.calls, 1)
	assert_almost_eq(beta.aggression_factor, 0.0, 0.0001)
