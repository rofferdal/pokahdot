extends "res://tests/support/poker_gut_test.gd"

const Fixture := preload("res://tests/support/gui_browser_capture_fixture.gd")


func test_capture_fixture_preserves_public_state_and_privacy() -> void:
	var descriptor: Dictionary = Fixture.descriptor()
	var view: GameView = descriptor.view
	assert_eq(view.hero_seat, 0)
	assert_eq(view.button_seat, 0)
	assert_eq(view.small_blind_seat, 1)
	assert_eq(view.big_blind_seat, 2)
	assert_eq(view.acting_seat, 0)
	assert_eq(view.pot_amount, 65)
	assert_eq(view.call_amount, 30)
	assert_eq(view.minimum_wager_total, 40)
	assert_eq(view.maximum_wager_total, 1000)
	assert_eq(view.hero_hole_cards[0].rank, 4)
	assert_eq(view.hero_hole_cards[0].suit, CardData.Suit.SPADES)
	assert_eq(view.hero_hole_cards[1].rank, 8)
	assert_eq(view.hero_hole_cards[1].suit, CardData.Suit.DIAMONDS)
	assert_eq(view.revealed_hole_cards.size(), 0)
	assert_eq(view.community_cards.size(), 0)
	assert_eq(view.action_history.size(), 5)
	assert_eq(descriptor.events.size(), 6)
	assert_eq(descriptor.names.values(), ["Human", "Yael", "Chidi", "Wei", "Haruto", "Youssef"])
	var total: int = view.pot_amount
	for seat: PlayerView in view.seats:
		total += seat.stack
		assert_eq(seat.seat, int(String(seat.player_id).get_slice("_", 2)))
		assert_eq(seat.folded, seat.seat == 4)
		assert_eq(seat.is_human, seat.seat == 0)
	assert_eq(total, 6000)


func test_fixture_calls_return_independent_snapshots() -> void:
	var first: Dictionary = Fixture.descriptor()
	var second: Dictionary = Fixture.descriptor()
	first.view._seats[0].stack = 1
	first.names[1] = "Changed"
	assert_eq(second.view.seats[0].stack, 1000)
	assert_eq(second.names[1], "Yael")
