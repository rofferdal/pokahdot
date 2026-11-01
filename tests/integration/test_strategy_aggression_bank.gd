extends "res://tests/support/poker_gut_test.gd"

const BANK := preload("res://tests/support/strategy_aggression_decision_bank.gd")
const TOURNAMENTS := preload("res://tests/support/strategy_aggression_tournament_benchmark.gd")


func test_bank_snapshots_are_legal_detached_and_cover_required_regimes() -> void:
	var streets: Dictionary = {}
	var counts: Dictionary = {}
	var stacks: Dictionary = {}
	for spec: Dictionary in BANK.specifications():
		var fixture: Dictionary = BANK.fixture(spec)
		var view: GameView = BANK.view(fixture)
		assert_eq(view.acting_seat, fixture.hero, spec.id)
		assert_false(view.legal_actions.is_empty(), spec.id)
		assert_eq(view.hero_hole_cards.size(), 2, spec.id)
		var context := StrategyStreetContext.from_view(view)
		assert_true(context.pot_is_reliable, spec.id)
		streets[spec.street] = true
		counts[spec.player_count] = true
		stacks[spec.starting_stack] = true
	assert_eq(streets.size(), 4)
	for count: int in [2, 6, 9]:
		assert_true(counts.has(count))
	for stack: int in [100, 1000]:
		assert_true(stacks.has(stack))
	var expected_ids: Array[StringName] = []
	for profile: BotProfile in PlayableBotRoster.new().get_catalog_profiles():
		if profile.model_id == &"strategy_parameterized":
			expected_ids.append(profile.profile_id)
	assert_false(expected_ids.is_empty())
	var product_profiles: Array[BotProfile] = BANK.profiles(false)
	assert_eq(product_profiles.size(), expected_ids.size())
	for profile: BotProfile in product_profiles:
		assert_has(expected_ids, profile.profile_id)
	var all_profiles: Array[BotProfile] = BANK.profiles()
	assert_eq(all_profiles.size(), expected_ids.size() + 5)
	var control_ids: Array[StringName] = []
	for profile: BotProfile in all_profiles:
		if not expected_ids.has(profile.profile_id):
			control_ids.append(profile.profile_id)
	for control_id: StringName in [
		&"control_raise_0",
		&"control_raise_50",
		&"control_raise_100",
		&"control_bluff_0",
		&"control_bluff_100"
	]:
		assert_has(control_ids, control_id)


func test_fixed_j8_all_in_fixture_recreates_public_call_price() -> void:
	var spec: Dictionary = {}
	for candidate: Dictionary in BANK.specifications():
		if candidate.scenario == "j8_small_all_in":
			spec = candidate
	var view: GameView = BANK.view(BANK.fixture(spec))
	assert_eq(view.call_amount, 10)
	assert_eq(view.pot_amount, 50)
	assert_has(view.legal_actions, PlayerAction.Kind.CALL)
	assert_does_not_have(view.legal_actions, PlayerAction.Kind.RAISE)


func test_backdoor_examples_have_weak_potential_and_a_reliably_cheap_price() -> void:
	for scenario: String in ["delayed_backdoor", "two_increases_backdoor", "prior_call_backdoor"]:
		var count: int = 2 if scenario == "delayed_backdoor" else 3
		var fixture: Dictionary = BANK.fixture(
			{
				"id": scenario,
				"scenario": scenario,
				"street": &"flop",
				"player_count": count,
				"starting_stack": 1000
			}
		)
		var view: GameView = BANK.view(fixture)
		var estimate: HandPotentialEstimate = StrategyDecisionModel.new()._estimate(view)
		var context := StrategyStreetContext.from_view(view)
		assert_lt(estimate.score, 30, scenario)
		assert_gte(maxi(estimate.flush_draw_quality, estimate.straight_draw_quality), 25, scenario)
		assert_true(context.pot_is_reliable, scenario)
		assert_lte(context.call_price, 0.20, scenario)
		assert_has(view.legal_actions, PlayerAction.Kind.RAISE)


func test_bank_reconciles_actions_and_keeps_cards_out_of_serialized_evidence() -> void:
	var result: Dictionary = BANK.run_bank(151001, 1)
	assert_eq(result.rows.size(), result.cases * BANK.profiles().size())
	for row: Dictionary in result.rows:
		var count: int = 0
		for selected: int in row.actions.values():
			count += selected
		assert_eq(count, row.samples, row.case_id)
		assert_true(row.valid, row.case_id)
	var encoded: String = JSON.stringify(result)
	assert_false(encoded.contains("hero_hole_cards"))
	assert_false(encoded.contains("public_board"))
	assert_false(encoded.contains("opponent_cards"))


func test_complete_tournament_has_reconciled_all_action_and_tail_metrics() -> void:
	var tournament: Dictionary = TOURNAMENTS._tournament(
		BANK.profiles(false), 0, 2, 100, false, 201001
	)
	assert_true(tournament.completed)
	assert_eq(tournament.invalid_actions, 0)
	assert_eq(tournament.chip_total, tournament.expected_chip_total)
	var all: Dictionary = tournament.summaries.all
	assert_eq(all.decisions, tournament.decisions)
	var actions: int = 0
	for count: int in all.actions.values():
		actions += count
	assert_eq(actions, tournament.decisions)
	assert_eq(tournament.betting_streets, tournament.street_raise_tails.size())
	var max_tail: int = 0
	var long_streets: int = 0
	for tail: int in tournament.street_raise_tails:
		max_tail = maxi(max_tail, tail)
		long_streets += int(tail > 12)
	assert_eq(tournament.maximum_raise_chain, max_tail)
	assert_eq(tournament.streets_over_12_raises, long_streets)
	assert_lte(all.value_eligible, all.legal_raise + all.legal_bet)
	assert_lte(all.bluff_eligible, all.legal_raise + all.legal_bet)
