extends "res://tests/support/poker_gut_test.gd"

const MODEL_SCRIPT := preload("res://scripts/core/agents/strategy_decision_model.gd")
const PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)


func test_configured_strategy_bot_trace_matches_action_and_profile() -> void:
	var profile := load("res://resources/bot_profiles/balanced.tres") as BotProfile
	var registry := DecisionModelRegistry.new()
	assert_true(registry.register_model(&"strategy_parameterized", MODEL_SCRIPT, PARAMETERS_SCRIPT))
	var creation: AgentCreationResult = AgentFactory.new(registry).create_bot(profile, _rng(811))
	assert_true(creation.is_ok())
	var bot := creation.agent as BotAgent
	var view: GameView = _check_view()

	var action: PlayerAction = bot.choose_action(view)
	var trace: Variant = bot.get_last_decision_trace_for_testing()

	assert_not_null(trace)
	assert_eq(trace.profile_id, &"balanced")
	assert_eq(trace.hand_potential_band, &"unknown")
	assert_eq(trace.selected_branch, &"free_check")
	assert_eq(trace.legal_alternatives, view.legal_actions)
	assert_eq(trace.requested_action.kind, action.kind)
	assert_eq(trace.requested_action.amount, action.amount)
	assert_ne(trace.requested_action, action)
	assert_false("decision_trace" in _property_names(view))


func _check_view() -> GameView:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	return GameView.for_preflop(table, 0, BettingRound.new(table, 0), PotManager.new(), [])


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _property_names(object: Object) -> Array[StringName]:
	var names: Array[StringName] = []
	for property: Dictionary in object.get_property_list():
		names.append(property.name)
	return names
