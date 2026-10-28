extends "res://tests/support/poker_gut_test.gd"

## Bounded property runs: replay using the seat count, seed, initial stacks and
## complete action prefix included in every assertion message.

const SEEDS: Array[int] = [1, 7, 23, 104729, 2147483646, 900001]
const MAX_STEPS: int = 128


func test_seeded_legal_and_illegal_sequences_preserve_rule_invariants() -> void:
	for count: int in range(2, 10):
		for replay_seed: int in SEEDS:
			_run_sequence(count, replay_seed)


func test_generated_short_all_ins_never_reopen_previous_callers() -> void:
	for count: int in range(3, 10):
		for replay_seed: int in SEEDS:
			var rng := RandomNumberGenerator.new()
			rng.seed = replay_seed
			var short_seat: int = rng.randi_range(0, count - 1)
			var short_stack: int = rng.randi_range(11, 19)
			var players: Array[Player] = []
			for seat: int in range(count):
				players.append(
					Player.new(
						StringName("p%d" % seat),
						"Player %d" % seat,
						seat,
						short_stack if seat == short_seat else 100
					)
				)
			var table := Table.new(players, 5, 10)
			var first: int = (short_seat + 1) % count
			var round := BettingRound.new(table, first)
			var trace: Array[String] = []
			for offset: int in range(count):
				var seat: int = (first + offset) % count
				var action: PlayerAction = PlayerAction.call_action()
				if offset == 0:
					action = PlayerAction.bet_to(10)
				elif seat == short_seat:
					action = PlayerAction.all_in_action()
				trace.append("%d:%d(%d)" % [seat, action.kind, action.amount])
				assert_true(
					round.apply_action(seat, action).is_ok(),
					(
						"count=%d seed=%d short=%d/%d actions=%s"
						% [count, replay_seed, short_seat, short_stack, trace]
					)
				)
			for offset: int in range(count - 1):
				var seat: int = (first + offset) % count
				var context: String = (
					"count=%d seed=%d short=%d/%d actions=%s"
					% [count, replay_seed, short_seat, short_stack, trace]
				)
				assert_eq(round.acting_seat, seat, context)
				assert_false(round.can_raise(seat), context)
				assert_does_not_have(round.legal_actions(seat), PlayerAction.Kind.ALL_IN, context)
				_assert_rejected_unchanged(
					table, round, seat, PlayerAction.all_in_action(), context
				)
				_assert_rejected_unchanged(table, round, seat, PlayerAction.raise_to(30), context)
				trace.append("%d:CALL(0)" % seat)
				assert_true(round.apply_action(seat, PlayerAction.call_action()).is_ok(), context)
			assert_true(round.is_complete(), "seed=%d actions=%s" % [replay_seed, trace])


func _run_sequence(count: int, replay_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = replay_seed
	var players: Array[Player] = []
	var stacks: Array[int] = []
	var rights: Dictionary[int, bool] = {}
	for seat: int in range(count):
		var stack: int = rng.randi_range(1, 100)
		if replay_seed == 900001:
			stack = 1000000
		stacks.append(stack)
		var player := Player.new(StringName("p%d" % seat), "Player %d" % seat, seat, stack)
		player.add_hole_card(CardData.new(2 + seat, CardData.Suit.CLUBS))
		player.add_hole_card(CardData.new(2 + seat, CardData.Suit.DIAMONDS))
		players.append(player)
		rights[seat] = true
	var table := Table.new(players, 5, 10)
	table.button_seat = rng.randi_range(0, count - 1)
	var initial_bet: int = 0
	if replay_seed in [7, 104729, 900001]:
		players[table.small_blind_seat()].commit_chips(5)
		players[table.big_blind_seat()].commit_chips(10)
		initial_bet = 10
	var round := BettingRound.new(table, rng.randi_range(0, count - 1), initial_bet)
	var trace: Array[String] = []
	var expected_increment: int = 10
	var expected_bet: int = initial_bet
	for step: int in range(MAX_STEPS):
		var context: String = (
			"count=%d seed=%d stacks=%s initial_bet=%d actions=%s"
			% [count, replay_seed, stacks, initial_bet, trace]
		)
		assert_eq(round.current_bet, expected_bet, context)
		assert_eq(round.minimum_wager_total(), expected_bet + expected_increment, context)
		_assert_conservation(players, stacks, context)
		_assert_private_views(table, round, context)
		if round.is_complete():
			return
		_assert_rights(table, round, rights, expected_increment, context)
		var seat: int = round.acting_seat
		var player: Player = players[seat]
		var maximum: int = player.stack + player.bet_this_round
		var minimum: int = expected_bet + expected_increment
		assert_eq(round.minimum_wager_total(), minimum, context)
		_probe_rejections(table, round, minimum, context)
		# Independent action candidates use public chip values and our own ledger.
		var options: Array[PlayerAction] = [
			(
				PlayerAction.check_action()
				if player.bet_this_round == round.current_bet
				else PlayerAction.call_action()
			)
		]
		if step < 16:
			options.append(PlayerAction.fold_action())
			if maximum <= round.current_bet or rights.has(seat):
				options.append(PlayerAction.all_in_action())
			if rights.has(seat) and maximum >= minimum:
				var target: int = rng.randi_range(minimum, maximum)
				options.append(
					(
						PlayerAction.bet_to(target)
						if round.current_bet == 0
						else PlayerAction.raise_to(target)
					)
				)
		var action: PlayerAction = options[rng.randi_range(0, options.size() - 1)]
		var target: int = player.bet_this_round
		match action.kind:
			PlayerAction.Kind.BET, PlayerAction.Kind.RAISE:
				target = action.amount
			PlayerAction.Kind.ALL_IN:
				target = maximum
			PlayerAction.Kind.CALL:
				target += mini(player.stack, expected_bet - player.bet_this_round)
		var increase: int = maxi(0, target - expected_bet)
		var previous_stack: int = player.stack
		trace.append("%d:%s(%d)" % [seat, PlayerAction.Kind.keys()[action.kind], action.amount])
		context += " next=" + trace[-1]
		var result: ActionValidationResult = round.apply_action(seat, action)
		assert_true(result.is_ok(), context)
		if not result.is_ok():
			return
		assert_eq(result.chips_committed, previous_stack - player.stack, context)
		rights.erase(seat)
		if increase >= expected_increment:
			expected_increment = increase
			for other: Player in players:
				if other.seat != seat and not other.folded and not other.all_in:
					rights[other.seat] = true
		expected_bet = maxi(expected_bet, target)
		assert_eq(round.current_bet, expected_bet, context)
		assert_eq(round.minimum_wager_total(), expected_bet + expected_increment, context)
		_assert_conservation(players, stacks, context)
	assert_true(
		round.is_complete(), "sequence budget exceeded: seed=%d actions=%s" % [replay_seed, trace]
	)


func _probe_rejections(table: Table, round: BettingRound, minimum: int, context: String) -> void:
	var seat: int = round.acting_seat
	var player: Player = table.get_player(seat)
	var invalid: Array[PlayerAction] = [
		null,
		PlayerAction.new(PlayerAction.Kind.FOLD, 1),
		PlayerAction.bet_to(-1),
		PlayerAction.raise_to(player.stack + player.bet_this_round + 1),
		(
			PlayerAction.call_action()
			if player.bet_this_round == round.current_bet
			else PlayerAction.check_action()
		),
	]
	invalid.append(
		(
			PlayerAction.bet_to(minimum - 1)
			if round.current_bet == 0
			else PlayerAction.raise_to(minimum - 1)
		)
	)
	if not round.can_raise(seat) and player.stack + player.bet_this_round > round.current_bet:
		invalid.append(PlayerAction.all_in_action())
	for action: PlayerAction in invalid:
		_assert_rejected_unchanged(table, round, seat, action, context)
	_assert_rejected_unchanged(
		table, round, (seat + 1) % table.players.size(), PlayerAction.fold_action(), context
	)


func _assert_rejected_unchanged(
	table: Table, round: BettingRound, seat: int, action: PlayerAction, context: String
) -> void:
	var before: Array = _snapshot(table, round)
	var label: String = "null" if action == null else "%d(%d)" % [action.kind, action.amount]
	var replay: String = "%s rejected probe=%d:%s" % [context, seat, label]
	assert_false(round.apply_action(seat, action).is_ok(), replay)
	assert_eq(_snapshot(table, round), before, replay)


func _snapshot(table: Table, round: BettingRound) -> Array:
	var state: Array = [
		round.acting_seat,
		round.current_bet,
		round.minimum_wager_total(),
		round.pending_seats(),
		round.is_complete()
	]
	for player: Player in table.players:
		(
			state
			. append(
				[
					player.stack,
					player.bet_this_round,
					player.total_contribution,
					player.folded,
					player.all_in,
					player.busted,
					player.hole_cards,
					round.can_raise(player.seat),
					round.legal_actions(player.seat),
				]
			)
		)
	return state


func _assert_conservation(players: Array[Player], stacks: Array[int], context: String) -> void:
	var total: int = 0
	var expected: int = 0
	for seat: int in range(players.size()):
		var player: Player = players[seat]
		total += player.stack + player.total_contribution
		expected += stacks[seat]
		assert_gte(player.stack, 0, context)
		assert_gte(player.bet_this_round, 0, context)
		assert_eq(player.stack + player.total_contribution, stacks[seat], context)
		assert_eq(player.all_in, player.stack == 0, context)
	assert_eq(total, expected, context)


func _assert_rights(
	table: Table,
	round: BettingRound,
	rights: Dictionary[int, bool],
	expected_increment: int,
	context: String
) -> void:
	for player: Player in table.players:
		var expected: bool = rights.has(player.seat) and not player.folded and not player.all_in
		assert_eq(round.can_raise(player.seat), expected, context)
		if player.seat == round.acting_seat:
			var maximum: int = player.stack + player.bet_this_round
			var actions: Array[PlayerAction.Kind] = round.legal_actions(player.seat)
			assert_eq(
				PlayerAction.Kind.ALL_IN in actions,
				maximum <= round.current_bet or expected,
				context
			)
			var wager_kind: PlayerAction.Kind = (
				PlayerAction.Kind.BET if round.current_bet == 0 else PlayerAction.Kind.RAISE
			)
			assert_eq(
				wager_kind in actions,
				expected and maximum >= round.current_bet + expected_increment,
				context
			)


func _assert_private_views(table: Table, round: BettingRound, context: String) -> void:
	for recipient: Player in table.players:
		var view := GameView.for_preflop(table, recipient.seat, round, PotManager.new(), [])
		assert_eq(view.minimum_wager_total, round.minimum_wager_total(), context)
		assert_eq(view.maximum_wager_total, recipient.bet_this_round + recipient.stack, context)
		assert_eq(view.call_amount, round.call_amount(recipient.seat), context)
		assert_eq(view.legal_actions, round.legal_actions(recipient.seat), context)
		assert_eq(view.hero_hole_cards, recipient.hole_cards, context)
		assert_true(view.revealed_hole_cards.is_empty(), context)
		assert_true(view.showdown_results.is_empty(), context)
		for public_seat: PlayerView in view.seats:
			assert_false("hole_cards" in public_seat, context)
			assert_false("agent" in public_seat, context)
		var copied: Array[CardData] = view.hero_hole_cards
		copied.clear()
		assert_eq(view.hero_hole_cards.size(), 2, context)
		assert_eq(recipient.hole_cards.size(), 2, context)
