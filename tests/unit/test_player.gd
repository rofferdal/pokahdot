extends "res://tests/support/poker_gut_test.gd"


func test_player_starts_with_identity_stack_and_clean_hand_state() -> void:
	var player := Player.new(&"player_2", "Ada", 2, 1000)

	assert_eq(player.player_id, &"player_2")
	assert_eq(player.display_name, "Ada")
	assert_eq(player.seat, 2)
	assert_eq(player.stack, 1000)
	assert_eq(player.hole_cards, [])
	assert_false(player.folded)
	assert_false(player.all_in)
	assert_false(player.busted)
	assert_eq(player.bet_this_round, 0)
	assert_eq(player.total_contribution, 0)


func test_commit_tracks_round_and_hand_contributions() -> void:
	var player := Player.new(&"player_0", "Ada", 0, 100)

	assert_eq(player.commit_chips(30), 30)
	assert_eq(player.stack, 70)
	assert_eq(player.bet_this_round, 30)
	assert_eq(player.total_contribution, 30)

	player.reset_betting_round()
	assert_eq(player.bet_this_round, 0)
	assert_eq(player.total_contribution, 30)


func test_short_commit_marks_player_all_in_without_negative_stack() -> void:
	var player := Player.new(&"player_0", "Ada", 0, 25)

	assert_eq(player.commit_chips(100), 25)
	assert_eq(player.stack, 0)
	assert_true(player.all_in)
	assert_false(player.busted)


func test_hole_card_collection_is_limited_and_returned_as_a_copy() -> void:
	var player := Player.new(&"player_0", "Ada", 0, 100)
	var first := CardData.new(14, CardData.Suit.SPADES)
	var second := CardData.new(13, CardData.Suit.HEARTS)

	assert_true(player.add_hole_card(first))
	assert_true(player.add_hole_card(second))
	assert_false(player.add_hole_card(CardData.new(2, CardData.Suit.CLUBS)))
	var returned_cards: Array[CardData] = player.hole_cards
	returned_cards.clear()
	assert_eq(player.hole_cards.size(), 2)


func test_reset_for_hand_clears_transient_state_but_preserves_busted() -> void:
	var player := Player.new(&"player_0", "Ada", 0, 50)
	player.add_hole_card(CardData.new(14, CardData.Suit.SPADES))
	player.commit_chips(50)
	player.fold()
	player.update_busted_status()

	player.reset_for_hand()

	assert_eq(player.hole_cards, [])
	assert_false(player.folded)
	assert_false(player.all_in)
	assert_eq(player.bet_this_round, 0)
	assert_eq(player.total_contribution, 0)
	assert_true(player.busted)


func test_award_chips_is_the_only_player_stack_credit_path() -> void:
	var player := Player.new(&"player_0", "Ada", 0, 100)

	assert_true(player.award_chips(50))
	assert_eq(player.stack, 150)
	assert_false(player.award_chips(-1))
	assert_eq(player.stack, 150)
