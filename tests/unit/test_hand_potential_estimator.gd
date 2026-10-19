extends "res://tests/support/poker_gut_test.gd"

const ESTIMATOR_SCRIPT := preload("res://scripts/core/agents/hand_potential_estimator.gd")
const CONTEXT_SCRIPT := preload("res://scripts/core/agents/hand_potential_context.gd")


func test_estimator_accepts_only_explicit_cards_board_and_context() -> void:
	var context: HandPotentialContext = CONTEXT_SCRIPT.new(&"flop", 2, 3, 120, 20, 400, 10)
	var hero_cards: Array[CardData] = _cards("AS KH")
	var board: Array[CardData] = _cards("2C 7D 9S")
	var estimate: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		hero_cards, board, context
	)

	assert_not_null(estimate)
	assert_true(estimate.score >= 0 and estimate.score <= 100)
	assert_eq(estimate.hero_cards.size(), 2)
	assert_eq(estimate.public_board.size(), 3)
	assert_eq(estimate.context.street, &"flop")
	assert_eq(estimate.context.position, 2)
	assert_eq(estimate.context.pot_size, 120)


func test_estimate_copies_inputs_and_rejects_invalid_or_duplicate_cards() -> void:
	var hero_cards: Array[CardData] = _cards("AS KH")
	var board: Array[CardData] = _cards("2C 7D 9S")
	var context := CONTEXT_SCRIPT.new()
	var estimate: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		hero_cards, board, context
	)

	hero_cards.clear()
	board.clear()
	context.pot_size = 999
	assert_eq(estimate.hero_cards.size(), 2)
	assert_eq(estimate.public_board.size(), 3)
	assert_eq(estimate.context.pot_size, 0)

	assert_null(ESTIMATOR_SCRIPT.new().estimate(_cards("AS AS"), [], CONTEXT_SCRIPT.new()))
	assert_null(
		ESTIMATOR_SCRIPT.new().estimate(
			_cards("AS KH"), _cards("2C 7D 9S TC JC QH"), CONTEXT_SCRIPT.new()
		)
	)
	assert_null(
		ESTIMATOR_SCRIPT.new().estimate(
			_cards("AS KH"), _cards("2C 7D 9S AS"), CONTEXT_SCRIPT.new()
		)
	)


func test_estimate_is_independent_of_opponent_cards_and_deck_order() -> void:
	var estimator := ESTIMATOR_SCRIPT.new()
	var hero_cards: Array[CardData] = _cards("AS KH")
	var board: Array[CardData] = _cards("2C 7D 9S")
	var context := CONTEXT_SCRIPT.new(&"flop", 2, 3, 120, 20, 400, 10)
	var baseline: HandPotentialEstimate = estimator.estimate(hero_cards, board, context)

	# Opponent cards and undealt-card order are deliberately not estimator inputs.
	var opponent_cards: Array[CardData] = _cards("AC AD")
	var alternate_opponent_cards: Array[CardData] = _cards("2H 2S")
	var deck := Deck.new()
	var alternate_deck := Deck.new()
	var shuffle_rng := RandomNumberGenerator.new()
	shuffle_rng.seed = 9
	alternate_deck.shuffle(shuffle_rng)
	assert_eq(opponent_cards.size(), alternate_opponent_cards.size())
	assert_ne(deck.cards(), alternate_deck.cards())

	var repeated: HandPotentialEstimate = estimator.estimate(hero_cards, board, context)
	assert_eq(repeated.score, baseline.score)
	assert_eq(repeated.made_hand_class, baseline.made_hand_class)
	assert_eq(repeated.improvement_potential, baseline.improvement_potential)
	assert_eq(repeated.flush_draw_quality, baseline.flush_draw_quality)
	assert_eq(repeated.straight_draw_quality, baseline.straight_draw_quality)


func test_estimate_does_not_retain_mutable_core_references() -> void:
	var estimator := ESTIMATOR_SCRIPT.new()
	var players: Array[Player] = [
		Player.new(&"hero", "Hero", 0, 100),
		Player.new(&"opponent", "Opponent", 1, 100),
	]
	players[1].add_hole_card(CardData.new(14, CardData.Suit.CLUBS))
	players[1].add_hole_card(CardData.new(14, CardData.Suit.DIAMONDS))
	var table := Table.new(players, 5, 10)
	var deck := Deck.new()
	var hero_cards: Array[CardData] = _cards("AS KH")
	var board: Array[CardData] = _cards("2C 7D 9S")
	var context := CONTEXT_SCRIPT.new(&"flop", 0, 1, 30, 10, 90, 10)
	var estimate: HandPotentialEstimate = estimator.estimate(hero_cards, board, context)

	table.get_player(1).fold()
	table.get_player(0).commit_chips(90)
	deck.draw()
	context.pot_size = 999
	assert_eq(estimate.score, 21)
	assert_eq(estimate.context.pot_size, 30)
	assert_eq(estimate.hero_cards[0].code(), "14:3")
	assert_eq(estimate.public_board[0].code(), "2:0")


func test_preflop_score_orders_pairs_suited_connectors_and_weak_offsuit() -> void:
	var estimator := ESTIMATOR_SCRIPT.new()
	var early: HandPotentialContext = CONTEXT_SCRIPT.new(&"preflop", 0, 5)
	var premium_pair: HandPotentialEstimate = estimator.estimate(_cards("AS AH"), [], early)
	var suited_connectors: HandPotentialEstimate = estimator.estimate(_cards("9S 8S"), [], early)
	var weak_offsuit: HandPotentialEstimate = estimator.estimate(_cards("7S 2H"), [], early)

	assert_true(premium_pair.score > suited_connectors.score)
	assert_true(suited_connectors.score > weak_offsuit.score)
	assert_true(premium_pair.score >= 60)
	assert_true(weak_offsuit.score >= 0 and weak_offsuit.score <= 100)


func test_preflop_score_calibration_covers_premium_pairs_and_high_cards() -> void:
	var estimator := ESTIMATOR_SCRIPT.new()
	var early: HandPotentialContext = CONTEXT_SCRIPT.new(&"preflop", 0, 5)

	var aces: HandPotentialEstimate = estimator.estimate(_cards("AS AH"), [], early)
	var kings: HandPotentialEstimate = estimator.estimate(_cards("KS KH"), [], early)
	var ace_king: HandPotentialEstimate = estimator.estimate(_cards("AS KH"), [], early)
	var queen_jack: HandPotentialEstimate = estimator.estimate(_cards("QS JH"), [], early)

	assert_eq(aces.score, 75)
	assert_eq(kings.score, 70)
	assert_eq(ace_king.score, 39)
	assert_eq(queen_jack.score, 34)
	assert_true(aces.score > kings.score)
	assert_true(ace_king.score > queen_jack.score)


func test_preflop_score_calibration_distinguishes_suited_connectors_and_weak_offsuit() -> void:
	var estimator := ESTIMATOR_SCRIPT.new()
	var early: HandPotentialContext = CONTEXT_SCRIPT.new(&"preflop", 0, 5)

	var suited_connector: HandPotentialEstimate = estimator.estimate(_cards("9S 8S"), [], early)
	var one_gap_suited: HandPotentialEstimate = estimator.estimate(_cards("TS 8S"), [], early)
	var weak_offsuit: HandPotentialEstimate = estimator.estimate(_cards("7S 2H"), [], early)
	var wheel_offsuit: HandPotentialEstimate = estimator.estimate(_cards("AS 2H"), [], early)

	assert_eq(suited_connector.score, 36)
	assert_eq(one_gap_suited.score, 35)
	assert_eq(weak_offsuit.score, 6)
	assert_eq(wheel_offsuit.score, 22)
	assert_true(suited_connector.score > weak_offsuit.score)
	assert_true(wheel_offsuit.score > weak_offsuit.score)


func test_preflop_score_remains_within_documented_boundaries_at_extremes() -> void:
	var estimator := ESTIMATOR_SCRIPT.new()
	var earliest: HandPotentialContext = CONTEXT_SCRIPT.new(&"preflop", 0, 0)
	var latest: HandPotentialContext = CONTEXT_SCRIPT.new(&"preflop", 9, 9)

	var weakest: HandPotentialEstimate = estimator.estimate(_cards("2S 3H"), [], earliest)
	var strongest: HandPotentialEstimate = estimator.estimate(_cards("AS AH"), [], latest)

	assert_eq(weakest.score, 11)
	assert_eq(strongest.score, 80)
	assert_true(weakest.score >= 0)
	assert_true(strongest.score <= 100)
	assert_true(weakest.score <= strongest.score)


func test_preflop_score_applies_later_position_adjustment() -> void:
	var estimator := ESTIMATOR_SCRIPT.new()
	var early: HandPotentialEstimate = estimator.estimate(
		_cards("QS JH"), [], CONTEXT_SCRIPT.new(&"preflop", 0, 5)
	)
	var late: HandPotentialEstimate = estimator.estimate(
		_cards("QS JH"), [], CONTEXT_SCRIPT.new(&"preflop", 5, 5)
	)

	assert_eq(late.score - early.score, 5)


func test_preflop_score_position_adjustment_is_zero_to_five_points() -> void:
	var estimator := ESTIMATOR_SCRIPT.new()
	var earliest: HandPotentialEstimate = estimator.estimate(
		_cards("QS JH"), [], CONTEXT_SCRIPT.new(&"preflop", 0, 5)
	)
	var middle: HandPotentialEstimate = estimator.estimate(
		_cards("QS JH"), [], CONTEXT_SCRIPT.new(&"preflop", 3, 5)
	)
	var latest: HandPotentialEstimate = estimator.estimate(
		_cards("QS JH"), [], CONTEXT_SCRIPT.new(&"preflop", 5, 5)
	)

	assert_eq(earliest.score, 34)
	assert_eq(middle.score, 37)
	assert_eq(latest.score, 39)
	assert_eq(middle.score - earliest.score, 3)
	assert_eq(latest.score - earliest.score, 5)


func test_postflop_reports_made_hand_class_and_stable_category_name() -> void:
	var estimator := ESTIMATOR_SCRIPT.new()
	var context: HandPotentialContext = CONTEXT_SCRIPT.new(&"flop", 2, 2)
	var pair: HandPotentialEstimate = estimator.estimate(
		_cards("AS AH"), _cards("2C 7D 9S"), context
	)
	var trips: HandPotentialEstimate = estimator.estimate(
		_cards("9H 9D"), _cards("2C 7D 9S"), context
	)

	assert_eq(pair.made_hand_class, HandRank.Category.ONE_PAIR)
	assert_eq(pair.made_hand_category, HandRank.Category.ONE_PAIR)
	assert_eq(pair.made_hand_class_name, &"one_pair")
	assert_eq(trips.made_hand_class, HandRank.Category.THREE_OF_A_KIND)
	assert_eq(trips.made_hand_class_name, &"three_of_a_kind")
	assert_true(trips.score > pair.score)


func test_postflop_reports_flush_draw_quality_and_known_card_outs() -> void:
	var estimate: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("AS 5S"), _cards("2S 7S KD"), CONTEXT_SCRIPT.new(&"flop", 1, 2)
	)

	assert_eq(estimate.flush_draw_quality, 85)
	assert_eq(estimate.improvement_outs, 9)
	assert_true(estimate.has_flush_draw)
	assert_true(estimate.improvement_potential >= estimate.flush_draw_quality - 5)

	var backdoor: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("AS 5S"), _cards("2S 7D KC"), CONTEXT_SCRIPT.new(&"flop", 1, 2)
	)
	assert_eq(backdoor.flush_draw_quality, 25)
	assert_true(backdoor.flush_draw_quality < estimate.flush_draw_quality)


func test_postflop_reports_straight_draw_quality_for_open_ended_and_gutshot() -> void:
	var open_ended: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("8S 7H"), _cards("6D 5C KC"), CONTEXT_SCRIPT.new(&"flop", 1, 2)
	)
	var gutshot: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("9S 7H"), _cards("8D 5C 2C"), CONTEXT_SCRIPT.new(&"flop", 1, 2)
	)

	assert_eq(open_ended.straight_draw_quality, 80)
	assert_eq(open_ended.improvement_outs, 8)
	assert_true(open_ended.has_straight_draw)
	assert_eq(gutshot.straight_draw_quality, 55)
	assert_eq(gutshot.improvement_outs, 4)
	assert_true(open_ended.straight_draw_quality > gutshot.straight_draw_quality)


func test_postflop_counts_ace_as_a_wheel_straight_draw_out() -> void:
	var wheel_draw: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("2S 3H"), _cards("4D 5C KC"), CONTEXT_SCRIPT.new(&"flop", 1, 2)
	)

	assert_eq(wheel_draw.straight_draw_quality, 80)
	assert_eq(wheel_draw.improvement_outs, 8)


func test_postflop_marks_paired_and_coordinated_public_boards() -> void:
	var paired: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("AS KH"), _cards("8C 8D 2S"), CONTEXT_SCRIPT.new(&"flop", 1, 2)
	)
	var coordinated: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("AS KH"), _cards("8C 9D TS"), CONTEXT_SCRIPT.new(&"flop", 1, 2)
	)
	var coordinated_suits: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("AS KH"), _cards("2S 7S 9S"), CONTEXT_SCRIPT.new(&"flop", 1, 2)
	)

	assert_true(paired.is_paired_board)
	assert_true(paired.paired_board)
	assert_false(paired.is_coordinated_board)
	assert_false(coordinated.is_paired_board)
	assert_true(coordinated.is_coordinated_board)
	assert_true(coordinated_suits.is_coordinated_board)


func test_postflop_detects_board_only_made_hand_and_no_river_improvement() -> void:
	var estimate: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("2C 3D"), _cards("AS KD QH JS TS"), CONTEXT_SCRIPT.new(&"river", 1, 1)
	)

	assert_eq(estimate.made_hand_class, HandRank.Category.STRAIGHT)
	assert_true(estimate.is_board_only_hand)
	assert_true(estimate.board_only_hand)
	assert_eq(estimate.improvement_potential, 0)
	assert_eq(estimate.flush_draw_quality, 0)
	assert_eq(estimate.straight_draw_quality, 0)


func test_postflop_overcard_improvement_is_bounded_and_river_is_closed() -> void:
	var turn_estimate: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("AS KH"), _cards("2C 7D 9S 4H"), CONTEXT_SCRIPT.new(&"turn", 1, 2)
	)
	var river_estimate: HandPotentialEstimate = ESTIMATOR_SCRIPT.new().estimate(
		_cards("AS KH"), _cards("2C 7D 9S 4H JC"), CONTEXT_SCRIPT.new(&"river", 1, 2)
	)

	assert_true(turn_estimate.improvement_potential > 0)
	assert_true(turn_estimate.improvement_potential < 60)
	assert_eq(river_estimate.improvement_potential, 0)


func _cards(description: String) -> Array[CardData]:
	var result: Array[CardData] = []
	for token: String in description.split(" ", false):
		var rank_text: String = token.left(token.length() - 1)
		var suit_text: String = token.right(1)
		result.append(CardData.new(_rank(rank_text), _suit(suit_text)))
	return result


func _rank(value: String) -> int:
	var named_ranks: Dictionary = {"T": 10, "J": 11, "Q": 12, "K": 13, "A": 14}
	return int(named_ranks.get(value, int(value)))


func _suit(value: String) -> CardData.Suit:
	var suits: Dictionary = {
		"C": CardData.Suit.CLUBS,
		"D": CardData.Suit.DIAMONDS,
		"H": CardData.Suit.HEARTS,
		"S": CardData.Suit.SPADES,
	}
	return suits[value] as CardData.Suit
