extends "res://tests/support/poker_gut_test.gd"


class TracedModel:
	extends DecisionModel
	var trace_reads: int = 0
	var action := PlayerAction.check_action()
	var trace := StrategyDecisionTrace.new(&"test", &"weak", &"original", [], null)

	func choose_action(_view: GameView) -> PlayerAction:
		return action

	func get_last_decision_trace_for_testing() -> RefCounted:
		trace_reads += 1
		return trace


func test_product_decisions_do_not_collect_or_request_diagnostics() -> void:
	var model := TracedModel.new()
	var bot := BotAgent.new(model, BotProfile.new())
	for _decision: int in range(10000):
		bot.choose_action(null)
	assert_eq(model.trace_reads, 0)
	assert_true(bot.drain_decisions_for_simulation().is_empty())


func test_opt_in_drain_transfers_isolated_snapshots_and_disable_clears() -> void:
	var model := TracedModel.new()
	model.trace._selected_branch = &"original"
	var bot := BotAgent.new(model, BotProfile.new())
	var view := GameView.new()
	view._legal_actions = [PlayerAction.Kind.CHECK]
	bot.set_simulation_diagnostics_enabled(true)
	bot.choose_action(view)
	var drained := bot.drain_decisions_for_simulation()
	assert_eq(drained.size(), 1)
	assert_true(bot.drain_decisions_for_simulation().is_empty())
	assert_not_same(drained[0].action, model.action)
	assert_not_same(drained[0].trace, model.trace)
	drained[0].legal_actions.clear()
	drained[0].trace._selected_branch = &"changed"
	drained[0].action._kind = PlayerAction.Kind.FOLD
	bot.choose_action(view)
	var next := bot.drain_decisions_for_simulation()
	assert_eq(next[0].legal_actions, [PlayerAction.Kind.CHECK])
	assert_eq(next[0].trace.selected_branch, &"original")
	assert_eq(next[0].action.kind, PlayerAction.Kind.CHECK)
	bot.choose_action(view)
	bot.set_simulation_diagnostics_enabled(false)
	assert_true(bot.drain_decisions_for_simulation().is_empty())
	bot.set_simulation_diagnostics_enabled(true)
	assert_true(bot.drain_decisions_for_simulation().is_empty())


func test_draining_keeps_long_run_pending_records_bounded() -> void:
	var bot := BotAgent.new(TracedModel.new(), BotProfile.new())
	bot.set_simulation_diagnostics_enabled(true)
	var measured: int = 0
	for _batch: int in range(200):
		for _decision: int in range(17):
			bot.choose_action(null)
		var drained := bot.drain_decisions_for_simulation()
		assert_eq(drained.size(), 17)
		measured += drained.size()
	assert_eq(measured, 3400)
	assert_true(bot.drain_decisions_for_simulation().is_empty())


func test_collection_does_not_change_actions_or_rng_consumption() -> void:
	var rngs: Array[RandomNumberGenerator] = [
		RandomNumberGenerator.new(), RandomNumberGenerator.new()
	]
	var bots: Array[BotAgent] = []
	for rng: RandomNumberGenerator in rngs:
		rng.seed = 62817
		var model := RandomDecisionModel.new()
		model.configure(RandomDecisionModelParameters.new(), rng)
		bots.append(BotAgent.new(model, BotProfile.new()))
	bots[0].set_simulation_diagnostics_enabled(true)
	var view := GameView.new()
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CHECK, PlayerAction.Kind.BET]
	view.minimum_wager_total = 10
	view.maximum_wager_total = 100
	for _decision: int in range(500):
		var captured := bots[0].choose_action(view)
		var product := bots[1].choose_action(view)
		assert_eq(captured.kind, product.kind)
		assert_eq(captured.amount, product.amount)
		bots[0].drain_decisions_for_simulation()
	assert_eq(rngs[0].state, rngs[1].state)
