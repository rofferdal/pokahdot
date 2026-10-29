extends GutTest


func test_all_faces_preserve_rank_ten_and_each_suit_without_core_references() -> void:
	var suits: Array[String] = ["♣", "♦", "♥", "♠"]
	var ranks: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
	for rank: int in range(2, 15):
		for suit: int in range(4):
			var card := CardData.new(rank, suit)
			var reference: WeakRef = weakref(card)
			var model: CardViewModel = CardViewModel.face(card)
			card = null
			assert_null(reference.get_ref(), "face models must not retain CardData")
			assert_eq(model.state, CardViewModel.State.FACE)
			assert_eq(model.rank, rank)
			assert_eq(model.suit, suit)
			assert_eq(model.rank_text, ranks[rank - 2])
			assert_eq(model.suit_text, suits[suit])


func test_back_empty_and_null_faces_have_no_rank_or_suit_identity() -> void:
	for model: CardViewModel in [
		CardViewModel.back(), CardViewModel.empty(), CardViewModel.face(null)
	]:
		assert_ne(model.state, CardViewModel.State.FACE)
		assert_eq(model.rank, 0)
		assert_eq(model.suit, -1)
		assert_eq(model.rank_text, "")
		assert_eq(model.suit_text, "")


func test_board_always_has_five_slots_and_copies_visible_cards_only() -> void:
	for count: int in range(6):
		var view: GameView = _view()
		for index: int in count:
			view._community_cards.append(CardData.new(10 + index, CardData.Suit.HEARTS))
		var row: CardRowViewModel = CardRowViewModel.board(view)
		assert_eq(row.cards.size(), 5)
		for index: int in 5:
			assert_eq(
				row.cards[index].state,
				CardViewModel.State.FACE if index < count else CardViewModel.State.EMPTY
			)
		var reference: WeakRef = weakref(view)
		view = null
		assert_null(reference.get_ref(), "board rows must not retain GameView")
	assert_eq(CardRowViewModel.board(null).cards.size(), 5)


func test_hidden_opponents_are_identity_free_and_only_revealed_seats_show_faces() -> void:
	var view: GameView = _view()
	view._hero_hole_cards = [
		CardData.new(14, CardData.Suit.SPADES), CardData.new(10, CardData.Suit.HEARTS)
	]
	view._revealed_hole_cards[2] = [CardData.new(2), CardData.new(3)]
	var hero: CardRowViewModel = CardRowViewModel.for_seat(view, 0)
	var hidden: CardRowViewModel = CardRowViewModel.for_seat(view, 1)
	var shown: CardRowViewModel = CardRowViewModel.for_seat(view, 2)
	assert_eq(hero.cards[0].rank_text, "A")
	assert_eq(hero.cards[1].rank_text, "10")
	for card: CardViewModel in hidden.cards:
		assert_eq(card.state, CardViewModel.State.BACK)
		assert_eq(card.rank, 0)
		assert_eq(card.suit, -1)
	assert_eq(shown.cards[0].rank, 2)
	assert_eq(shown.cards[1].rank, 3)
	view._revealed_hole_cards[1] = [CardData.new(13)]
	assert_eq(CardRowViewModel.for_seat(view, 1).cards[0].state, CardViewModel.State.BACK)
	view._hero_hole_cards.clear()
	view._revealed_hole_cards.clear()
	view = null
	assert_eq(hero.cards[0].rank, 14)
	assert_eq(shown.cards[1].rank, 3)


func test_folded_busted_and_unknown_seats_have_two_empty_slots_even_if_cards_are_present() -> void:
	var view: GameView = _view()
	view._hero_hole_cards = [CardData.new(14), CardData.new(13)]
	view._revealed_hole_cards[1] = [CardData.new(12), CardData.new(11)]
	view._seats[0].folded = true
	view._seats[1].busted = true
	for seat: int in [0, 1, 99]:
		var row: CardRowViewModel = CardRowViewModel.for_seat(view, seat)
		assert_eq(row.cards.size(), 2)
		for card: CardViewModel in row.cards:
			assert_eq(card.state, CardViewModel.State.EMPTY)
			assert_eq(card.rank, 0)
			assert_eq(card.suit, -1)
	assert_eq(CardRowViewModel.for_seat(null, 0).cards.size(), 2)


func _view() -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	for seat: int in 3:
		view._seats.append(
			PlayerView.new(Player.new(StringName("p%d" % seat), "Player", seat, 1000))
		)
	return view
