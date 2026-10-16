extends "res://tests/support/poker_gut_test.gd"


func test_fresh_deck_contains_52_unique_cards() -> void:
	var deck := Deck.new()
	var cards: Array[CardData] = deck.cards()
	var card_ids: Array[String] = []

	for card: CardData in cards:
		card_ids.append(card.code())

	assert_eq(deck.remaining_count(), 52)
	assert_eq(card_ids.size(), 52)
	assert_unique_card_codes(card_ids)


func test_drawing_exhausts_deck_without_duplicates() -> void:
	var deck := Deck.new()
	var drawn_codes: Array[String] = []

	for _index: int in range(52):
		var card: CardData = deck.draw()
		assert_not_null(card)
		drawn_codes.append(card.code())

	assert_eq(deck.remaining_count(), 0)
	assert_unique_card_codes(drawn_codes)
	assert_null(deck.draw())


func test_reset_restores_a_full_deck() -> void:
	var deck := Deck.new()
	deck.draw()
	deck.draw()

	deck.reset()

	assert_eq(deck.remaining_count(), 52)
	assert_eq(deck.cards()[0].card_id, 0)


func test_same_seed_produces_same_shuffle_order() -> void:
	var first := Deck.new()
	var second := Deck.new()
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 12345
	second_rng.seed = 12345

	first.shuffle(first_rng)
	second.shuffle(second_rng)

	assert_eq(_codes(first), _codes(second))


func test_different_seed_changes_shuffle_order() -> void:
	var first := Deck.new()
	var second := Deck.new()
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 12345
	second_rng.seed = 54321

	first.shuffle(first_rng)
	second.shuffle(second_rng)

	assert_ne(_codes(first), _codes(second))


func _codes(deck: Deck) -> Array[String]:
	var result: Array[String] = []
	for card: CardData in deck.cards():
		result.append(card.code())
	return result
