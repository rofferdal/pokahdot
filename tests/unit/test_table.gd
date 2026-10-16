extends "res://tests/support/poker_gut_test.gd"


func test_active_seat_traversal_wraps_and_skips_busted_players() -> void:
	var players: Array[Player] = _players(5)
	players[1].commit_chips(players[1].stack)
	players[1].update_busted_status()
	players[3].commit_chips(players[3].stack)
	players[3].update_busted_status()
	var table := Table.new(players, 5, 10)

	assert_eq(table.active_seats(), [0, 2, 4])
	assert_eq(table.next_active_seat(0), 2)
	assert_eq(table.next_active_seat(2), 4)
	assert_eq(table.next_active_seat(4), 0)


func test_initial_button_is_deterministic_and_always_active() -> void:
	var first_players: Array[Player] = _players(6)
	var second_players: Array[Player] = _players(6)
	_bust(first_players[2])
	_bust(second_players[2])
	var first := Table.new(first_players, 5, 10)
	var second := Table.new(second_players, 5, 10)
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 2468
	second_rng.seed = 2468

	assert_eq(first.choose_initial_button(first_rng), second.choose_initial_button(second_rng))
	assert_true(first.button_seat in first.active_seats())
	assert_ne(first.button_seat, 2)


func test_button_advances_clockwise_skipping_busted_seats() -> void:
	var players: Array[Player] = _players(4)
	_bust(players[2])
	var table := Table.new(players, 5, 10)
	table.button_seat = 1

	assert_eq(table.advance_button(), 3)
	assert_eq(table.advance_button(), 0)


func test_multiway_blinds_and_action_order_are_clockwise_from_button() -> void:
	var table := Table.new(_players(4), 5, 10)
	table.button_seat = 1

	assert_eq(table.small_blind_seat(), 2)
	assert_eq(table.big_blind_seat(), 3)
	assert_eq(table.first_to_receive_card(), 2)
	assert_eq(table.first_to_act_preflop(), 0)
	assert_eq(table.first_to_act_postflop(), 2)


func test_heads_up_button_posts_small_blind_and_acts_first_preflop() -> void:
	var table := Table.new(_players(2), 5, 10)
	table.button_seat = 1

	assert_eq(table.small_blind_seat(), 1)
	assert_eq(table.big_blind_seat(), 0)
	assert_eq(table.first_to_receive_card(), 1)
	assert_eq(table.first_to_act_preflop(), 1)
	assert_eq(table.first_to_act_postflop(), 0)


func test_position_helpers_skip_busted_seats() -> void:
	var players: Array[Player] = _players(5)
	_bust(players[1])
	_bust(players[3])
	var table := Table.new(players, 5, 10)
	table.button_seat = 0

	assert_eq(table.small_blind_seat(), 2)
	assert_eq(table.big_blind_seat(), 4)
	assert_eq(table.first_to_act_preflop(), 0)


func _players(count: int) -> Array[Player]:
	var result: Array[Player] = []
	for seat: int in range(count):
		result.append(Player.new(StringName("player_%d" % seat), "Player %d" % seat, seat, 100))
	return result


func _bust(player: Player) -> void:
	player.commit_chips(player.stack)
	player.update_busted_status()
