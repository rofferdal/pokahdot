extends "res://tests/support/poker_gut_test.gd"

const StrategyModelScript := preload("res://scripts/core/agents/strategy_decision_model.gd")
const StrategyParametersScript := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)


func test_configuration_rejects_missing_mismatched_and_invalid_parameters() -> void:
	var model: DecisionModel = StrategyModelScript.new()
	var invalid_parameters := StrategyParametersScript.new()
	invalid_parameters.bluff_rate = 101

	assert_false(model.configure(null, _rng(1)).is_empty())
	assert_false(model.configure(RandomDecisionModelParameters.new(), _rng(1)).is_empty())
	assert_false(model.configure(invalid_parameters, _rng(1)).is_empty())
	assert_false(model.configure(StrategyParametersScript.new(), null).is_empty())


func test_same_seed_and_view_produce_same_legal_action_sequence() -> void:
	var first := _model(9876)
	var second := _model(9876)
	var view := _view_for_actor()
	var first_actions: Array[String] = []
	var second_actions: Array[String] = []

	for _index: int in range(20):
		first_actions.append(_action_signature(first.choose_action(view)))
		second_actions.append(_action_signature(second.choose_action(view)))

	assert_eq(first_actions, second_actions)
	for action_signature: String in first_actions:
		assert_ne(action_signature, "null")


func test_baseline_prefers_check_then_call_then_fold() -> void:
	var model := _model(42)
	var check_view := _view_for_check()
	var call_view := _view_for_actor()

	assert_eq(model.choose_action(check_view).kind, PlayerAction.Kind.CHECK)
	assert_eq(model.choose_action(call_view).kind, PlayerAction.Kind.CALL)


func test_every_strategy_decision_is_legal_and_wager_is_in_range() -> void:
	var model := _model(1234)
	var view := _view_for_actor()

	for _index: int in range(100):
		var action: PlayerAction = model.choose_action(view)
		assert_has(view.legal_actions, action.kind)
		if action.has_wager_amount():
			assert_between(action.amount, view.minimum_wager_total, view.maximum_wager_total)


func _model(seed_value: int) -> DecisionModel:
	var model: DecisionModel = StrategyModelScript.new()
	assert_true(model.configure(StrategyParametersScript.new(), _rng(seed_value)).is_empty())
	return model


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _view_for_actor() -> GameView:
	var players: Array[Player] = []
	for seat: int in range(3):
		players.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	players[1].commit_chips(5)
	players[2].commit_chips(10)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	return GameView.for_preflop(table, 0, BettingRound.new(table, 0, 10), PotManager.new(), [])


func _view_for_check() -> GameView:
	var players: Array[Player] = []
	for seat: int in range(2):
		players.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	return GameView.for_preflop(table, 0, BettingRound.new(table, 0), PotManager.new(), [])


func _action_signature(action: PlayerAction) -> String:
	if action == null:
		return "null"
	return "%d:%d" % [action.kind, action.amount]
