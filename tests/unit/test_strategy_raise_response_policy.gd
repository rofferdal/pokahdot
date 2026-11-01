# gdlint: disable=max-public-methods
extends "res://tests/support/poker_gut_test.gd"

## Policy sequences use legal core transitions and complete public wager history.
const MODEL := preload("res://scripts/core/agents/strategy_decision_model.gd")
const PARAMETERS := preload("res://scripts/core/agents/strategy_decision_model_parameters.gd")
const BANK := preload("res://tests/support/strategy_aggression_decision_bank.gd")


func test_missing_or_empty_views_return_explicit_typed_no_action_trace() -> void:
	var unconfigured := MODEL.new()
	assert_null(unconfigured.choose_action(null))
	var first_trace: StrategyDecisionTrace = unconfigured.get_last_decision_trace_for_testing()
	assert_eq(first_trace.selected_branch, &"no_legal_action")
	assert_true(first_trace.legal_alternatives.is_empty())
	assert_null(first_trace.requested_action)
	assert_null(first_trace.diagnostics)
	var configured := _model(100, 100, 100, 0)
	for view: GameView in [null, GameView.new()]:
		assert_null(configured.choose_action(view))
		var trace: StrategyDecisionTrace = configured.get_last_decision_trace_for_testing()
		assert_eq(trace.selected_branch, &"no_legal_action")
		assert_true(trace.legal_alternatives.is_empty())
		assert_null(trace.requested_action)
		assert_null(trace.diagnostics)


func test_non_bluff_raise_calls_small_all_in_reraise_with_unchanged_hand() -> void:
	var fixture := _preflop(["JS 8S", "3C 2D"], [30, 30])
	var profile := load("res://resources/bot_profiles/loose_aggressive.tres") as BotProfile
	var model := MODEL.new()
	assert_true(model.configure(profile.parameters, _rng(2)).is_empty())
	var opening: PlayerAction = model.choose_action(_view(fixture, 0))
	assert_eq(opening.kind, PlayerAction.Kind.RAISE)
	assert_eq(opening.amount, 20)
	_apply(fixture, 0, opening)
	_apply(fixture, 1, PlayerAction.raise_to(30))
	var view := _view(fixture, 0)
	assert_has(view.legal_actions, PlayerAction.Kind.CALL)
	assert_does_not_have(view.legal_actions, PlayerAction.Kind.RAISE)

	var action: PlayerAction = model.choose_action(view)
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(action.kind, PlayerAction.Kind.CALL)
	assert_eq(diagnostics.score, 33)
	assert_true(diagnostics.call_viable)
	assert_false(diagnostics.value_raise_eligible)
	assert_lt(diagnostics.call_threshold, diagnostics.raise_threshold)
	_apply(fixture, 0, action)
	assert_true(fixture.round.is_complete())
	_assert_conservation(fixture, 60)


func test_weak_bluff_does_not_repeat_after_opponent_reraise_or_force_call() -> void:
	var fixture := _preflop(["7S 2H", "8C 3D"], [1000, 1000])
	var model := _model(100, 100, 100, 100)
	var first: PlayerAction = model.choose_action(_view(fixture, 0))
	assert_eq(first.kind, PlayerAction.Kind.RAISE)
	assert_eq(model.get_last_decision_trace_for_testing().selected_branch, &"bluff_raise")
	_apply(fixture, 0, first)
	_apply(fixture, 1, PlayerAction.raise_to(_view(fixture, 1).minimum_wager_total))
	var action: PlayerAction = model.choose_action(_view(fixture, 0))
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)

	assert_eq(action.kind, PlayerAction.Kind.FOLD)
	assert_false(diagnostics.bluff_eligible)
	assert_false(diagnostics.call_viable)
	assert_eq(diagnostics.hero_action_count, 1)
	assert_eq(diagnostics.hero_aggression_count, 1)
	assert_true(diagnostics.opponent_aggression_after_hero)
	_apply(fixture, 0, action)
	_assert_conservation(fixture, 2000)


func test_weak_first_action_cannot_bluff_after_two_opponents_raise() -> void:
	var fixture := _preflop(["AS QH", "KC JD", "7S 2H"], [100, 100, 100])
	_apply(fixture, 0, PlayerAction.raise_to(20))
	_apply(fixture, 1, PlayerAction.raise_to(30))
	var model := _model(100, 100, 100, 100)
	var view := _view(fixture, 2)
	assert_has(view.legal_actions, PlayerAction.Kind.RAISE)
	assert_eq(StrategyStreetContext.from_view(view).aggression_count, 2)

	var action: PlayerAction = model.choose_action(view)
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(action.kind, PlayerAction.Kind.FOLD)
	assert_eq(diagnostics.hero_action_count, 0)
	assert_false(diagnostics.bluff_eligible)
	assert_eq(diagnostics.bluff_reason, &"selective_street")
	_apply(fixture, 2, action)
	_assert_conservation(fixture, 300)


func test_weak_first_action_can_bluff_after_only_one_opponent_raise() -> void:
	var fixture := _preflop(["AS QH", "KC JD", "7S 2H"], [100, 100, 100])
	_apply(fixture, 0, PlayerAction.raise_to(20))
	_apply(fixture, 1, PlayerAction.call_action())
	var model := _model(100, 100, 100, 100)
	var view := _view(fixture, 2)
	assert_eq(StrategyStreetContext.from_view(view).aggression_count, 1)

	var action: PlayerAction = model.choose_action(view)
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(action.kind, PlayerAction.Kind.RAISE)
	assert_eq(diagnostics.hero_action_count, 0)
	assert_true(diagnostics.bluff_eligible)
	assert_eq(model.get_last_decision_trace_for_testing().selected_branch, &"bluff_raise")
	_apply(fixture, 2, action)
	_assert_conservation(fixture, 300)


func test_strong_first_action_can_value_raise_after_two_opponents_raise() -> void:
	var fixture := _preflop(["QS KH", "JC 10D", "AS AH"], [100, 100, 100])
	_apply(fixture, 0, PlayerAction.raise_to(20))
	_apply(fixture, 1, PlayerAction.raise_to(30))
	var model := _model(100, 100, 100, 0)
	var view := _view(fixture, 2)
	assert_eq(StrategyStreetContext.from_view(view).aggression_count, 2)

	var action: PlayerAction = model.choose_action(view)
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(action.kind, PlayerAction.Kind.RAISE)
	assert_eq(diagnostics.hero_action_count, 0)
	assert_true(diagnostics.value_raise_eligible)
	assert_eq(model.get_last_decision_trace_for_testing().selected_branch, &"continue_aggressive")
	_apply(fixture, 2, action)
	_assert_conservation(fixture, 300)


func test_prior_check_does_not_make_a_hopeless_hand_a_delayed_bluff() -> void:
	var fixture := _preflop(["7S 2H", "8C 3D"], [1000, 1000], 1)
	_apply(fixture, 1, PlayerAction.call_action())
	_apply(fixture, 0, PlayerAction.check_action())
	_start_flop(fixture)
	_apply(fixture, 0, PlayerAction.check_action())
	_apply(fixture, 1, PlayerAction.bet_to(10))
	var model := _model(100, 100, 100, 100)
	var view := _view(fixture, 0)
	assert_has(view.legal_actions, PlayerAction.Kind.RAISE)

	var action: PlayerAction = model.choose_action(view)
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(action.kind, PlayerAction.Kind.FOLD)
	assert_false(diagnostics.bluff_eligible)
	assert_eq(diagnostics.hero_action_count, 1)
	assert_eq(diagnostics.hero_aggression_count, 0)
	_apply(fixture, 0, action)
	_assert_conservation(fixture, 2000)


func test_new_street_and_new_hand_restore_weak_bluff_eligibility() -> void:
	var fixture := _preflop(["7S 2H", "8C 3D"], [1000, 1000])
	var model := _model(100, 100, 100, 100)
	_apply(fixture, 0, model.choose_action(_view(fixture, 0)))
	_apply(fixture, 1, PlayerAction.call_action())
	_start_flop(fixture)
	_apply(fixture, 1, PlayerAction.check_action())

	var flop_action: PlayerAction = model.choose_action(_view(fixture, 0))
	var flop_diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(flop_action.kind, PlayerAction.Kind.BET)
	assert_true(flop_diagnostics.bluff_eligible)
	assert_eq(flop_diagnostics.hero_action_count, 0)
	_apply(fixture, 0, flop_action)
	_assert_conservation(fixture, 2000)

	var next_hand := _preflop(["7S 2H", "8C 3D"], [1000, 1000])
	next_hand.hand_number = 2
	var next_action: PlayerAction = model.choose_action(_view(next_hand, 0))
	var next_diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(next_action.kind, PlayerAction.Kind.RAISE)
	assert_true(next_diagnostics.bluff_eligible)
	assert_eq(next_diagnostics.hero_action_count, 0)
	_apply(next_hand, 0, next_action)
	_assert_conservation(next_hand, 2000)


func test_strong_value_hand_can_reraise_after_opponent_resistance() -> void:
	var fixture := _preflop(["AS AH", "8C 3D"], [1000, 1000])
	var model := _model(100, 100, 100, 0)
	_apply(fixture, 0, model.choose_action(_view(fixture, 0)))
	_apply(fixture, 1, PlayerAction.raise_to(30))
	var action: PlayerAction = model.choose_action(_view(fixture, 0))
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)

	assert_eq(action.kind, PlayerAction.Kind.RAISE)
	assert_true(diagnostics.value_raise_eligible)
	assert_true(diagnostics.opponent_aggression_after_hero)
	_apply(fixture, 0, action)
	_assert_conservation(fixture, 2000)


func test_expensive_call_still_folds_after_earlier_value_raise() -> void:
	var fixture := _preflop(["JS 8S", "3C 2D"], [100, 100])
	var model := _model(100, 100, 100, 0)
	_apply(fixture, 0, model.choose_action(_view(fixture, 0)))
	_apply(fixture, 1, PlayerAction.raise_to(80))
	var action: PlayerAction = model.choose_action(_view(fixture, 0))
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)

	assert_eq(action.kind, PlayerAction.Kind.FOLD)
	assert_false(diagnostics.call_viable)
	assert_gt(diagnostics.call_price, 0.25)
	assert_almost_eq(diagnostics.call_threshold, diagnostics.raise_threshold, 0.0001)
	_apply(fixture, 0, action)
	_assert_conservation(fixture, 200)


func test_missed_river_draw_does_not_gain_cheap_call_credit() -> void:
	var fixture := _preflop(["AS KS", "8C 3D"], [1000, 1000])
	_apply(fixture, 0, PlayerAction.raise_to(50))
	_apply(fixture, 1, PlayerAction.call_action())
	_start_street(fixture, &"flop", "2S 7S 9D")
	_apply(fixture, 1, PlayerAction.check_action())
	_apply(fixture, 0, PlayerAction.check_action())
	_start_street(fixture, &"turn", "2S 7S 9D 4H")
	_apply(fixture, 1, PlayerAction.check_action())
	_apply(fixture, 0, PlayerAction.check_action())
	_start_street(fixture, &"river", "2S 7S 9D 4H JC")
	_apply(fixture, 1, PlayerAction.bet_to(10))
	var model := _model(100, 100, 100, 0)

	var action: PlayerAction = model.choose_action(_view(fixture, 0))
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(action.kind, PlayerAction.Kind.FOLD)
	assert_lt(diagnostics.score, 30)
	assert_lt(diagnostics.call_price, 0.25)
	assert_false(diagnostics.call_viable)
	assert_almost_eq(diagnostics.call_threshold, diagnostics.raise_threshold, 0.0001)
	_apply(fixture, 0, action)
	_assert_conservation(fixture, 2000)


func test_short_all_in_does_not_reopen_raising_but_viable_call_survives() -> void:
	var fixture := _preflop(["AS AH", "8C 3D", "7D 2C"], [100, 100, 35])
	_apply(fixture, 0, PlayerAction.raise_to(30))
	_apply(fixture, 1, PlayerAction.call_action())
	_apply(fixture, 2, PlayerAction.all_in_action())
	var view := _view(fixture, 0)
	assert_eq(view.call_amount, 5)
	assert_has(view.legal_actions, PlayerAction.Kind.CALL)
	assert_does_not_have(view.legal_actions, PlayerAction.Kind.RAISE)
	var model := _model(100, 100, 100, 0)

	var action: PlayerAction = model.choose_action(view)
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(action.kind, PlayerAction.Kind.CALL)
	assert_true(diagnostics.call_viable)
	assert_false(diagnostics.value_raise_eligible)
	assert_true(diagnostics.opponent_aggression_after_hero)
	_apply(fixture, 0, action)
	_assert_conservation(fixture, 235)


func test_capped_call_uses_prospective_contestable_pot_not_opponents_side_pot() -> void:
	var fixture := _preflop(["JS 8S", "8C 3D", "7D 2C"], [40, 100, 100])
	_apply(fixture, 0, PlayerAction.raise_to(20))
	_apply(fixture, 1, PlayerAction.raise_to(40))
	_apply(fixture, 2, PlayerAction.raise_to(80))
	var view := _view(fixture, 0)
	assert_eq(view.pot_amount, 140)
	assert_eq(view.call_amount, 20)
	var model := _model(100, 100, 100, 0)

	var action: PlayerAction = model.choose_action(view)
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(action.kind, PlayerAction.Kind.CALL)
	assert_true(diagnostics.pot_is_reliable)
	assert_eq(diagnostics.contestable_pot, 100)
	assert_almost_eq(diagnostics.call_price, 20.0 / 120.0, 0.0001)
	_apply(fixture, 0, action)
	_apply(fixture, 1, PlayerAction.call_action())
	var pots: Array[PotLayer] = fixture.pots.derive_pots(fixture.table.players)
	assert_eq(pots.size(), 2)
	assert_eq(pots[0].amount, 120)
	assert_has(pots[0].eligible_seats, 0)
	assert_eq(pots[1].amount, 80)
	assert_does_not_have(pots[1].eligible_seats, 0)
	_assert_conservation(fixture, 240)


func test_marginal_value_reraises_remain_profile_sensitive_after_resistance() -> void:
	var raises: Dictionary[int, int] = {0: 0, 50: 0, 100: 0}
	for seed_value: int in range(151001, 151033):
		var selected: Dictionary[int, bool] = {}
		for percentage: int in [0, 50, 100]:
			var fixture: Dictionary = BANK.fixture(_resistance_spec())
			var view: GameView = BANK.view(fixture)
			var model := _model_with_seed(percentage, seed_value)
			assert_has(view.legal_actions, PlayerAction.Kind.RAISE)
			var action: PlayerAction = model.choose_action(view)
			var diagnostics: StrategyDecisionDiagnostics = (
				model.get_last_decision_trace_for_testing().diagnostics
			)
			assert_eq(diagnostics.score, 49)
			assert_true(diagnostics.call_viable)
			assert_true(diagnostics.value_raise_eligible)
			assert_true(diagnostics.opponent_aggression_after_hero)
			assert_true(action.kind in [PlayerAction.Kind.CALL, PlayerAction.Kind.RAISE])
			assert_between(diagnostics.value_raise_percentage, 0.0, float(percentage))
			selected[percentage] = action.kind == PlayerAction.Kind.RAISE
			if selected[percentage]:
				raises[percentage] += 1
			BANK.apply(fixture, fixture.hero, action)
			_assert_conservation(fixture, 2000)
		assert_false(selected[0])
		if selected[50]:
			assert_true(selected[100], "Coupled seed must preserve raising monotonicity")
	assert_eq(raises[0], 0)
	assert_gt(float(raises[50]) / 32.0, 0.05)
	assert_between(float(raises[100]) / 32.0, 0.20, 0.85)
	assert_lt(raises[50], raises[100])


func test_resistance_reduces_marginal_raise_probability_without_removing_choice() -> void:
	var fixture: Dictionary = BANK.fixture(_resistance_spec())
	var view: GameView = BANK.view(fixture)
	var model := _model_with_seed(100, 151001)
	model.choose_action(view)
	var diagnostics: StrategyDecisionDiagnostics = (
		model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_true(diagnostics.value_raise_eligible)
	assert_between(diagnostics.resistance_factor, 0.15, 0.85)
	assert_gt(diagnostics.value_raise_percentage, 0.0)
	assert_lt(diagnostics.value_raise_percentage, 100.0)
	assert_false(diagnostics.raise_reason.is_empty())


func test_selected_backdoor_windows_restore_first_bluffs_after_passive_actions_or_pressure(
) -> void:
	for scenario: String in ["delayed_backdoor", "prior_call_backdoor", "two_increases_backdoor"]:
		for bluff_rate: int in [0, 100]:
			var fixture: Dictionary = BANK.fixture(_bluff_spec(scenario))
			var configured := _bluff_configuration(bluff_rate, 151001)
			var view: GameView = BANK.view(fixture)
			var action: PlayerAction = configured.model.choose_action(view)
			var trace: StrategyDecisionTrace = (
				configured.model.get_last_decision_trace_for_testing()
			)
			var diagnostics: StrategyDecisionDiagnostics = trace.diagnostics
			assert_eq(diagnostics.score, 24, scenario)
			assert_true(diagnostics.pot_is_reliable, scenario)
			assert_lte(diagnostics.call_price, 0.20, scenario)
			assert_true(diagnostics.bluff_eligible, scenario)
			assert_eq(
				diagnostics.bluff_window,
				&"pressure_entry" if scenario == "two_increases_backdoor" else &"delayed"
			)
			assert_eq(
				action.kind,
				PlayerAction.Kind.RAISE if bluff_rate == 100 else PlayerAction.Kind.FOLD
			)
			assert_eq(trace.selected_branch, &"bluff_raise" if bluff_rate == 100 else &"fold")
			var copied: StrategyDecisionTrace = trace.copy()
			var detached: StrategyDecisionDiagnostics = copied.diagnostics
			detached.bluff_window = &"mutated"
			assert_eq(copied.diagnostics.bluff_window, diagnostics.bluff_window)
			assert_does_not_have(_property_names(view), &"bluff_window")
			BANK.apply(fixture, fixture.hero, action)
			_assert_conservation(fixture, fixture.spec.player_count * 1000)


func test_selective_bluffs_reject_expensive_river_and_multiway_context_without_rng() -> void:
	for control: String in ["expensive", "river", "multiway"]:
		var fixture: Dictionary
		if control == "expensive":
			fixture = _preflop(["AS 2S", "KC QH"], [1000, 1000], 1)
			fixture.hero = 0
			fixture.players = fixture.table.players
			fixture.spec = {"id": "expensive", "player_count": 2}
			_apply(fixture, 1, PlayerAction.call_action())
			_apply(fixture, 0, PlayerAction.check_action())
			_start_street(fixture, &"flop", "8S 9D JH")
			_apply(fixture, 0, PlayerAction.check_action())
			_apply(fixture, 1, PlayerAction.bet_to(80))
		else:
			var spec := _bluff_spec("delayed_backdoor")
			if control == "river":
				spec.street = &"river"
			else:
				spec.player_count = 6
			fixture = BANK.fixture(spec)
		var configured := _bluff_configuration(50, 151001)
		var before: int = configured.rng.state
		var view: GameView = BANK.view(fixture)
		var action: PlayerAction = configured.model.choose_action(view)
		var diagnostics: StrategyDecisionDiagnostics = (
			configured.model.get_last_decision_trace_for_testing().diagnostics
		)
		assert_eq(action.kind, PlayerAction.Kind.FOLD, control)
		assert_false(diagnostics.bluff_eligible, control)
		assert_eq(diagnostics.bluff_window, &"none", control)
		assert_eq(configured.rng.state, before, control)
		if control == "expensive":
			assert_eq(diagnostics.bluff_reason, &"expensive_bluff")
		elif control == "river":
			assert_eq(diagnostics.bluff_reason, &"selective_street")
		else:
			assert_eq(diagnostics.bluff_reason, &"too_many_opponents")
		BANK.apply(fixture, view.hero_seat, action)


func test_two_prior_passive_actions_exhaust_the_selective_bluff_window() -> void:
	var fixture := _backdoor_flop()
	_apply(fixture, 0, PlayerAction.check_action())
	_apply(fixture, 1, PlayerAction.bet_to(10))
	_apply(fixture, 2, PlayerAction.raise_to(20))
	_apply(fixture, 0, PlayerAction.call_action())
	_apply(fixture, 1, PlayerAction.raise_to(30))
	_apply(fixture, 2, PlayerAction.call_action())
	var configured := _bluff_configuration(50, 151001)
	var before: int = configured.rng.state
	var view := _view(fixture, 0)
	var action: PlayerAction = configured.model.choose_action(view)
	var diagnostics: StrategyDecisionDiagnostics = (
		configured.model.get_last_decision_trace_for_testing().diagnostics
	)
	assert_eq(diagnostics.hero_action_count, 2)
	assert_eq(diagnostics.hero_aggression_count, 0)
	assert_eq(diagnostics.bluff_reason, &"action_window_closed")
	assert_false(diagnostics.bluff_eligible)
	assert_eq(action.kind, PlayerAction.Kind.FOLD)
	assert_eq(configured.rng.state, before)
	_apply(fixture, 0, action)
	_assert_conservation(fixture, 3000)


func test_failed_initial_roll_can_receive_one_new_delayed_opportunity_after_check() -> void:
	var exercised: int = 0
	for seed_value: int in range(151001, 151033):
		var fixture := _backdoor_flop()
		var configured := _bluff_configuration(50, seed_value)
		var first: PlayerAction = configured.model.choose_action(_view(fixture, 0))
		if first.kind != PlayerAction.Kind.CHECK:
			continue
		exercised += 1
		assert_eq(
			configured.model.get_last_decision_trace_for_testing().diagnostics.bluff_window,
			&"initial"
		)
		_apply(fixture, 0, first)
		_apply(fixture, 1, PlayerAction.bet_to(10))
		_apply(fixture, 2, PlayerAction.call_action())
		var second: PlayerAction = configured.model.choose_action(_view(fixture, 0))
		var diagnostics: StrategyDecisionDiagnostics = (
			configured.model.get_last_decision_trace_for_testing().diagnostics
		)
		assert_eq(diagnostics.bluff_window, &"delayed")
		assert_true(diagnostics.bluff_eligible)
		assert_eq(diagnostics.hero_action_count, 1)
		assert_true(second.kind in [PlayerAction.Kind.FOLD, PlayerAction.Kind.RAISE])
		_apply(fixture, 0, second)
		_assert_conservation(fixture, 3000)
	assert_gt(exercised, 0)


func test_selective_bluff_sequences_reproduce_with_same_seed_and_applied_history() -> void:
	var first: Array[String] = []
	var second: Array[String] = []
	for seed_value: int in range(151001, 151033):
		for output: Array[String] in [first, second]:
			var fixture: Dictionary = BANK.fixture(_bluff_spec("delayed_backdoor"))
			var configured := _bluff_configuration(50, seed_value)
			var action: PlayerAction = configured.model.choose_action(BANK.view(fixture))
			output.append("%d:%d" % [action.kind, action.amount])
			BANK.apply(fixture, fixture.hero, action)
	assert_eq(first, second)
	assert_has(first, "%d:%d" % [PlayerAction.Kind.FOLD, 0])
	assert_has(first, "%d:%d" % [PlayerAction.Kind.RAISE, 25])
	assert_has(first, "%d:%d" % [PlayerAction.Kind.RAISE, 50])


func _bluff_spec(scenario: String) -> Dictionary:
	return {
		"id": scenario,
		"scenario": scenario,
		"street": &"flop",
		"player_count": 2 if scenario == "delayed_backdoor" else 3,
		"starting_stack": 1000,
	}


func _bluff_configuration(rate: int, seed_value: int) -> Dictionary:
	var parameters := PARAMETERS.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = 100
	parameters.bluff_rate = rate
	var rng := _rng(seed_value)
	var model := MODEL.new()
	assert_true(model.configure(parameters, rng).is_empty())
	return {"model": model, "rng": rng}


func _backdoor_flop() -> Dictionary:
	var fixture := _preflop(["AS 2S", "KC QH", "6C 5H"], [1000, 1000, 1000], 2)
	while not fixture.round.is_complete():
		var seat: int = fixture.round.acting_seat
		var legal: Array[PlayerAction.Kind] = fixture.round.legal_actions(seat)
		_apply(
			fixture,
			seat,
			(
				PlayerAction.check_action()
				if PlayerAction.Kind.CHECK in legal
				else PlayerAction.call_action()
			)
		)
	_start_street(fixture, &"flop", "8S 9D JH")
	return fixture


func _resistance_spec() -> Dictionary:
	return {
		"id": "value_resistance/preflop/p2/s1000",
		"scenario": "value_resistance",
		"street": &"preflop",
		"player_count": 2,
		"starting_stack": 1000,
	}


func _model_with_seed(raising: int, seed_value: int) -> StrategyDecisionModel:
	var parameters := PARAMETERS.new()
	parameters.tight_vs_loose = 100
	parameters.passive_vs_aggressive = 100
	parameters.call_vs_raise = raising
	parameters.bluff_rate = 0
	var model := MODEL.new()
	assert_true(model.configure(parameters, _rng(seed_value)).is_empty())
	return model


func test_private_decision_diagnostics_are_detached_from_public_view() -> void:
	var fixture := _preflop(["JS 8S", "3C 2D"], [30, 30])
	_apply(fixture, 0, PlayerAction.raise_to(20))
	_apply(fixture, 1, PlayerAction.raise_to(30))
	var model := _model(100, 100, 100, 0)
	var view := _view(fixture, 0)
	var action: PlayerAction = model.choose_action(view)
	var trace: StrategyDecisionTrace = model.get_last_decision_trace_for_testing()
	var diagnostics: StrategyDecisionDiagnostics = trace.diagnostics
	assert_not_null(diagnostics)
	assert_eq(diagnostics.policy_version, MODEL.POLICY_VERSION)
	diagnostics.score = -100
	assert_eq(model.get_last_decision_trace_for_testing().diagnostics.score, 33)
	assert_eq(view.hero_hole_cards.size(), 2)
	assert_does_not_have(_property_names(view), &"diagnostics")
	assert_does_not_have(_property_names(view), &"call_threshold")
	for record: PublicActionRecord in view.action_history:
		assert_does_not_have(_property_names(record), &"diagnostics")
		assert_does_not_have(_property_names(record), &"bluff_intent")
	_apply(fixture, 0, action)
	_assert_conservation(fixture, 60)


func _preflop(cards: Array[String], stacks: Array[int], button: int = 0) -> Dictionary:
	var players: Array[Player] = []
	for seat: int in range(cards.size()):
		var player := Player.new(StringName("seat%d" % seat), "Player", seat, stacks[seat])
		for card: CardData in _cards(cards[seat]):
			player.add_hole_card(card)
		players.append(player)
	var table := Table.new(players, 5, 10)
	table.button_seat = button
	var pots := PotManager.new()
	var history: Array[PublicActionRecord] = []
	var small_blind_seat: int = table.small_blind_seat()
	var big_blind_seat: int = table.big_blind_seat()
	var small_posted: int = players[small_blind_seat].commit_chips(5)
	var big_posted: int = players[big_blind_seat].commit_chips(10)
	pots.record_contribution(small_blind_seat, small_posted)
	pots.record_contribution(big_blind_seat, big_posted)
	history.append(PublicActionRecord.blind(small_blind_seat, small_posted, true))
	history.append(PublicActionRecord.blind(big_blind_seat, big_posted, false))
	var first_seat: int = button if players.size() == 2 else (big_blind_seat + 1) % players.size()
	return {
		"table": table,
		"round": BettingRound.new(table, first_seat, 10),
		"pots": pots,
		"history": history,
		"street": &"preflop",
		"board": [] as Array[CardData],
		"hand_number": 1,
	}


func _apply(fixture: Dictionary, seat: int, action: PlayerAction) -> void:
	var result: ActionValidationResult = fixture.round.apply_action(seat, action)
	assert_true(result.is_ok(), result.message)
	if not result.is_ok():
		return
	fixture.pots.record_contribution(seat, result.chips_committed)
	var player: Player = fixture.table.get_player(seat)
	fixture.history.append(
		PublicActionRecord.new(
			seat, action.kind, player.bet_this_round, PublicActionRecord.Kind.ACTION, fixture.street
		)
	)


func _start_flop(fixture: Dictionary) -> void:
	_start_street(fixture, &"flop", "4C 9D KH")


func _start_street(fixture: Dictionary, street: StringName, board: String) -> void:
	assert_true(fixture.round.is_complete())
	for player: Player in fixture.table.players:
		player.reset_betting_round()
	fixture.street = street
	fixture.board = _cards(board)
	var first_seat: int = (fixture.table.button_seat + 1) % fixture.table.players.size()
	fixture.round = BettingRound.new(fixture.table, first_seat)


func _view(fixture: Dictionary, seat: int) -> GameView:
	return (
		GameView
		. for_hand(
			fixture.table,
			seat,
			fixture.round,
			fixture.pots,
			fixture.history,
			fixture.street,
			fixture.board,
			[],
			{},
			fixture.hand_number,
		)
	)


func _model(tightness: int, opening: int, raising: int, bluff: int) -> StrategyDecisionModel:
	var parameters := PARAMETERS.new()
	parameters.tight_vs_loose = tightness
	parameters.passive_vs_aggressive = opening
	parameters.call_vs_raise = raising
	parameters.bluff_rate = bluff
	var model := MODEL.new()
	assert_true(model.configure(parameters, _rng(2)).is_empty())
	return model


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _assert_conservation(fixture: Dictionary, expected: int) -> void:
	var total: int = fixture.pots.total_amount
	for player: Player in fixture.table.players:
		total += player.stack
	assert_eq(total, expected)


func _property_names(object: Object) -> Array[StringName]:
	var names: Array[StringName] = []
	for property: Dictionary in object.get_property_list():
		names.append(property.name)
	return names


func _cards(text: String) -> Array[CardData]:
	var result: Array[CardData] = []
	var faces := {"A": 14, "K": 13, "Q": 12, "J": 11}
	var suits := {
		"C": CardData.Suit.CLUBS,
		"D": CardData.Suit.DIAMONDS,
		"H": CardData.Suit.HEARTS,
		"S": CardData.Suit.SPADES,
	}
	for token: String in text.split(" "):
		var rank_text: String = token.left(-1)
		var rank: int = faces.get(rank_text, rank_text.to_int())
		result.append(CardData.new(rank, suits[token.right(1)]))
	return result
