extends GutTest


func test_center_copy_contains_exact_current_wagers_and_blind_progression() -> void:
	var view: GameView = _view()
	var model: CenterViewModel = CenterViewModel.build(view)
	assert_true(model.valid)
	assert_eq(model.board_title, "Community cards")
	assert_eq(model.pot_text, "Pot: 150 | SB 5 BB 10 | L2")
	assert_eq(model.phone_pot_text, "Pot: 150")
	assert_eq(model.wager_text, "Wagers  •  2 active")
	assert_eq(model.phone_wager_text, "Current wager: 60")
	assert_eq(model.blind_level_text, "Blinds 5 / 10  ·  Level 2  ·  7 hands to next level")
	assert_eq(model.board.cards.size(), 5)
	assert_false(model.large_values)


func test_large_values_use_exact_two_line_wide_copy_without_abbreviation() -> void:
	var view: GameView = _view()
	view.pot_amount = 123456789
	view.small_blind = 234567
	view.big_blind = 469134
	view._seats[1].bet_this_round = 9876543
	var model: CenterViewModel = CenterViewModel.build(view, GuiFitCandidate.Density.MINIMAL)
	assert_true(model.large_values)
	assert_eq(model.pot_text, "Pot: 123456789 | L2\nSB 234567 BB 469134")
	assert_eq(model.phone_pot_text, "Pot: 123456789")
	assert_eq(model.phone_wager_text, "Current wager: 9876543")
	assert_eq(model.current_wager, 9876543)
	assert_eq(model.wager_count, 2)


func test_large_value_detection_includes_each_displayed_numeric_source() -> void:
	for source: String in ["pot", "blind", "stack", "wager"]:
		var view: GameView = _view()
		match source:
			"pot":
				view.pot_amount = 1000000
			"blind":
				view.big_blind = 100000
			"stack":
				view._seats[0].stack = 100000
			"wager":
				view._seats[1].bet_this_round = 100000
		assert_true(CenterViewModel.uses_large_values(view), source)
	assert_false(CenterViewModel.uses_large_values(null))


func test_models_detach_copy_and_authorized_board_values_from_the_source() -> void:
	var view: GameView = _view()
	view._community_cards = [CardData.new(10, CardData.Suit.SPADES)]
	var model: CenterViewModel = CenterViewModel.build(view)
	view._community_cards.clear()
	view.pot_amount = 999
	assert_eq(model.phone_pot_text, "Pot: 150")
	assert_eq(model.board.cards[0].rank_text, "10")
	assert_eq(model.board.cards[0].suit_text, "♠")
	assert_false(CenterViewModel.build(null).valid)
	assert_false(CenterViewModel.build(null).error.is_empty())


func _view() -> GameView:
	var view := GameView.new()
	view.pot_amount = 150
	view.small_blind = 5
	view.big_blind = 10
	view.blind_level = 2
	view.hands_until_next_level = 7
	view._seats = [
		PlayerView.new(Player.new(&"human", "Human", 0, 1000, HumanAgent.new())),
		PlayerView.new(Player.new(&"bot", "Bot", 1, 1000)),
	]
	view._seats[0].bet_this_round = 30
	view._seats[1].bet_this_round = 60
	return view
