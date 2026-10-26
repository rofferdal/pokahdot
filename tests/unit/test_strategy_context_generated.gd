extends "res://tests/support/poker_gut_test.gd"


func test_generated_real_views_preserve_street_position_and_public_context() -> void:
	var rng := RandomNumberGenerator.new()
	var model := StrategyDecisionModel.new()
	for replay_seed: int in [7, 23, 104729]:
		rng.seed = replay_seed
		for count: int in range(2, 10):
			var players: Array[Player] = []
			for seat: int in range(count):
				var player := Player.new(
					StringName("p%d" % seat), "Player %d" % seat, seat, rng.randi_range(1, 1000000)
				)
				player.add_hole_card(CardData.new(2 + seat, CardData.Suit.CLUBS))
				player.add_hole_card(CardData.new(2 + seat, CardData.Suit.DIAMONDS))
				players.append(player)
			var table := Table.new(players, 5, 10)
			table.button_seat = rng.randi_range(0, count - 1)
			# Fold a non-blind seat after positions are fixed. The button can fold
			# while it remains the positional anchor for this hand.
			if count > 2:
				players[table.button_seat].fold()
			for street: StringName in [&"preflop", &"flop"]:
				var start: int = (table.button_seat + 1) % count
				if street == &"preflop":
					start = table.button_seat if count == 2 else (table.button_seat + 3) % count
				var order: Array[int] = []
				for offset: int in range(count):
					var seat: int = (start + offset) % count
					if not players[seat].folded:
						order.append(seat)
				for hero: int in order:
					var board: Array[CardData] = []
					if street == &"flop":
						board = [
							CardData.new(12, CardData.Suit.HEARTS),
							CardData.new(13, CardData.Suit.SPADES),
							CardData.new(14, CardData.Suit.HEARTS)
						]
					var view := GameView.for_hand(
						table,
						hero,
						BettingRound.new(table, hero, 30),
						PotManager.new(),
						[],
						street,
						board,
						[],
						{}
					)
					var largest_opponent: int = 0
					for opponent: int in order:
						if opponent != hero:
							largest_opponent = maxi(largest_opponent, players[opponent].stack)
					var context: HandPotentialContext = model._estimate(view).context
					var replay: String = (
						"seed=%d count=%d button=%d street=%s hero=%d order=%s"
						% [replay_seed, count, table.button_seat, street, hero, order]
					)
					assert_eq(context.position, order.find(hero), replay)
					assert_eq(context.active_opponents, order.size() - 1, replay)
					assert_eq(
						context.effective_stack, mini(players[hero].stack, largest_opponent), replay
					)
					assert_eq(context.big_blind, 10, replay)
					assert_eq(view.minimum_wager_total, 40, replay)


func test_river_draw_value_stays_zero_under_all_suit_rotations() -> void:
	for suit_offset: int in range(4):
		var hero: Array[CardData] = [
			CardData.new(14, suit_offset as CardData.Suit),
			CardData.new(13, suit_offset as CardData.Suit)
		]
		var board: Array[CardData] = [
			CardData.new(2, suit_offset as CardData.Suit),
			CardData.new(7, suit_offset as CardData.Suit),
			CardData.new(9, ((suit_offset + 1) % 4) as CardData.Suit),
			CardData.new(4, ((suit_offset + 2) % 4) as CardData.Suit),
			CardData.new(11, ((suit_offset + 3) % 4) as CardData.Suit),
		]
		var estimate: HandPotentialEstimate = HandPotentialEstimator.new().estimate(
			hero, board, HandPotentialContext.new(&"river", 0, 1, 100, 10, 100, 10)
		)
		var replay: String = "river suit_offset=%d hero=%s board=%s" % [suit_offset, hero, board]
		assert_eq(estimate.flush_draw_quality, 0, replay)
		assert_eq(estimate.straight_draw_quality, 0, replay)
		assert_eq(estimate.improvement_outs, 0, replay)
		assert_eq(estimate.improvement_potential, 0, replay)
