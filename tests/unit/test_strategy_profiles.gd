extends "res://tests/support/poker_gut_test.gd"

const STRATEGY_MODEL_SCRIPT := preload("res://scripts/core/agents/strategy_decision_model.gd")
const STRATEGY_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)


func test_strategy_profiles_have_documented_ids_model_and_parameters() -> void:
	var expected_profiles := {
		&"nit_caller": [60, 20, 20, 2],
		&"tight_aggressive": [65, 75, 70, 8],
		&"loose_passive": [100, 25, 15, 5],
		&"loose_aggressive": [100, 85, 85, 22],
		&"balanced": [70, 55, 50, 12],
	}

	for profile_id: StringName in expected_profiles:
		var profile := load("res://resources/bot_profiles/%s.tres" % profile_id) as BotProfile
		var parameters := profile.parameters as DecisionModelParameters

		assert_not_null(profile)
		assert_eq(profile.profile_id, profile_id)
		assert_eq(profile.model_id, &"strategy_parameterized")
		assert_eq(
			[
				parameters.get("tight_vs_loose"),
				parameters.get("passive_vs_aggressive"),
				parameters.get("call_vs_bet"),
				parameters.get("bluff_rate"),
			],
			expected_profiles[profile_id]
		)


func test_registry_creates_fresh_strategy_models_for_strategy_parameters() -> void:
	var registry := DecisionModelRegistry.new()

	assert_true(
		registry.register_model(
			&"strategy_parameterized", STRATEGY_MODEL_SCRIPT, STRATEGY_PARAMETERS_SCRIPT
		)
	)
	assert_true(
		registry.accepts_parameters(&"strategy_parameterized", _balanced_profile().parameters)
	)
	assert_false(
		registry.accepts_parameters(&"strategy_parameterized", RandomDecisionModelParameters.new())
	)
	assert_ne(
		registry.create_model(&"strategy_parameterized"),
		registry.create_model(&"strategy_parameterized")
	)


func test_loose_profiles_continue_a_medium_hand_that_tight_aggressive_folds() -> void:
	var view := _call_view("QS JH")
	for loose_profile_id: StringName in [&"loose_passive", &"loose_aggressive"]:
		assert_eq(
			_model_for_profile(loose_profile_id).choose_action(view).kind,
			PlayerAction.Kind.CALL,
			"%s should voluntarily continue this medium-strength hand." % loose_profile_id,
		)
	assert_eq(
		_model_for_profile(&"tight_aggressive").choose_action(view).kind,
		PlayerAction.Kind.FOLD,
		"Tight Aggressive should retain a meaningfully narrower continuation range.",
	)


func test_recalibrated_nit_and_tight_profiles_offer_stronger_opposition() -> void:
	assert_eq(
		_model_for_profile(&"nit_caller").choose_action(_call_view("AS KS")).kind,
		PlayerAction.Kind.CALL,
		"Nit Caller should continue with a premium suited ace-king.",
	)
	assert_eq(
		_model_for_profile(&"tight_aggressive").choose_action(_call_view("KS QS")).kind,
		PlayerAction.Kind.CALL,
		"Tight Aggressive should continue with a strong suited broadway hand.",
	)


func _balanced_profile() -> BotProfile:
	return load("res://resources/bot_profiles/balanced.tres") as BotProfile


func _model_for_profile(profile_id: StringName) -> DecisionModel:
	var profile := load("res://resources/bot_profiles/%s.tres" % profile_id) as BotProfile
	var rng := RandomNumberGenerator.new()
	rng.seed = 700
	var model: DecisionModel = STRATEGY_MODEL_SCRIPT.new()
	assert_true(model.configure(profile.parameters.duplicate(true), rng).is_empty())
	return model


func _call_view(card_codes: String) -> GameView:
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	for card: CardData in _cards(card_codes):
		players[0].add_hole_card(card)
	var table := Table.new(players, 5, 10)
	table.button_seat = 0
	var view := GameView.for_preflop(table, 0, BettingRound.new(table, 0, 1), PotManager.new(), [])
	view.pot_amount = 100
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL]
	return view


func _cards(card_codes: String) -> Array[CardData]:
	var cards: Array[CardData] = []
	for token: String in card_codes.split(" "):
		var rank_text := token.substr(0, token.length() - 1)
		var rank: int = int(rank_text)
		if rank_text == "A":
			rank = 14
		elif rank_text == "K":
			rank = 13
		elif rank_text == "Q":
			rank = 12
		elif rank_text == "J":
			rank = 11
		var suit: CardData.Suit = CardData.Suit.CLUBS
		match token.right(1):
			"C":
				suit = CardData.Suit.CLUBS
			"D":
				suit = CardData.Suit.DIAMONDS
			"H":
				suit = CardData.Suit.HEARTS
			"S":
				suit = CardData.Suit.SPADES
		cards.append(CardData.new(rank, suit))
	return cards
