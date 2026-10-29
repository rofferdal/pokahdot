extends GutTest

const DENSITY := GuiFitCandidate.Density


func test_all_action_kinds_keep_exact_amounts_and_explicit_compact_variants() -> void:
	var view: GameView = _view()
	var full: Array[String] = [
		"Fold",
		"Check",
		"Call to 1234567",
		"Bet to 1234567",
		"Raise to 1234567",
		"All-in to 1234567"
	]
	var compact: Array[String] = ["F", "Chk", "C1234567", "B1234567", "R1234567", "A1234567"]
	for kind: int in PlayerAction.Kind.values():
		var record := PublicActionRecord.new(1, kind, 1234567)
		for density: int in DENSITY.values():
			var model: SeatViewModel = SeatViewModel.build(
				view.seats[1], view, {}, {}, record, null, density
			)
			assert_true(model.valid)
			assert_eq(
				model.latest_action_text,
				full[kind] if density == DENSITY.FULL else full[kind].replace(" to ", " ")
			)
			assert_eq(model.status_text, model.latest_action_text)
			assert_eq(model.compact_action_text, compact[kind])
			assert_eq(model.compact_action_exact_text, compact[kind])
	var thousands := PublicActionRecord.new(1, PlayerAction.Kind.ALL_IN, 1000000)
	var exact: SeatViewModel = SeatViewModel.build(view.seats[1], view, {}, {}, thousands)
	assert_eq(exact.compact_action_text, "A1000k")
	assert_eq(exact.compact_action_exact_text, "A1000000")
	assert_eq(
		SeatViewModel.format_action(
			PublicActionRecord.new(1, PlayerAction.Kind.RAISE, 99999), DENSITY.COMPACT
		),
		"Raise to 99999"
	)


func test_blinds_retained_folds_and_absent_actions_have_correct_lifetimes() -> void:
	var view: GameView = _view()
	for small: bool in [true, false]:
		var blind: PublicActionRecord = PublicActionRecord.blind(1, 1000000, small)
		var model: SeatViewModel = SeatViewModel.build(
			view.seats[1], view, {}, {}, blind, null, DENSITY.MINIMAL
		)
		assert_eq(model.latest_action_text, "%s blind 1000000" % ("Small" if small else "Big"))
		assert_eq(model.compact_action_text, "")
	var fold := PublicActionRecord.new(1, PlayerAction.Kind.FOLD)
	var retained: SeatViewModel = SeatViewModel.build(view.seats[1], view, {}, {}, null, fold)
	assert_eq(retained.status_text, "Fold")
	assert_eq(retained.compact_action_text, "", "compact badges show active-round actions only")
	var none: SeatViewModel = SeatViewModel.build(view.seats[1], view, {}, {})
	assert_eq(none.latest_action_text, "")
	assert_eq(none.status_text, "")
	var wrong := PublicActionRecord.new(2, PlayerAction.Kind.ALL_IN, 123)
	var mismatch: SeatViewModel = SeatViewModel.build(view.seats[1], view, {}, {}, wrong, wrong)
	assert_eq(mismatch.latest_action_text, "")
	assert_eq(mismatch.compact_action_text, "")


func test_assigned_identity_exact_stacks_and_markers_survive_density_and_source_changes() -> void:
	var view: GameView = _view()
	view._seats[0].is_human = true
	view.button_seat = 1
	view.small_blind_seat = 1
	view.big_blind_seat = 2
	view.acting_seat = 1
	view._seats[1].stack = 1000000
	view._seats[1].bet_this_round = 999999
	var names: Dictionary[int, String] = {0: "Wrong human name", 1: "Benjamin"}
	var avatars: Dictionary[int, String] = {1: "res://assets/avatar.svg"}
	for density: int in DENSITY.values():
		var model: SeatViewModel = SeatViewModel.build(
			view.seats[1], view, names, avatars, null, null, density
		)
		assert_eq(model.display_name, "Benjamin")
		assert_eq(model.avatar_path, "res://assets/avatar.svg")
		assert_eq(model.stack_text, "1000000")
		assert_eq(model.stack_value_text, "1000000")
		assert_eq(model.wager_text, "Bet 999999")
		assert_eq(model.markers, "D SB")
		assert_true(model.is_dealer)
		assert_true(model.is_small_blind)
		assert_false(model.is_big_blind)
		assert_eq(model.badge_text, "D SB Turn")
		assert_eq(model.token_badge_text, "DSB T")
		assert_true(model.acting)
		assert_false(model.is_hero)
	var hero: SeatViewModel = SeatViewModel.build(view.seats[0], view, names, {})
	assert_eq(hero.display_name, "Human")
	assert_eq(hero.stack_text, "1000 chips")
	assert_true(hero.is_hero)
	var detached: SeatViewModel = SeatViewModel.build(view.seats[1], view, names, avatars)
	names[1] = "Changed"
	avatars.clear()
	view._seats[1].display_name = "Mutated"
	var reference: WeakRef = weakref(view)
	view = null
	assert_null(reference.get_ref(), "seat models must not retain GameView")
	assert_eq(detached.display_name, "Benjamin")
	assert_eq(detached.avatar_path, "res://assets/avatar.svg")


func test_fold_all_in_busted_and_acting_badge_precedence() -> void:
	var view: GameView = _view()
	view.button_seat = 1
	view.small_blind_seat = 1
	view.acting_seat = 1
	var player: PlayerView = view.seats[1]
	player.all_in = true
	var all_in: SeatViewModel = SeatViewModel.build(player, view, {}, {})
	assert_true(all_in.all_in)
	assert_eq(all_in.token_badge_text, "DSBAI")
	assert_eq(all_in.badge_text, "D SB Turn AI")
	player.folded = true
	var folded: SeatViewModel = SeatViewModel.build(player, view, {}, {})
	assert_true(folded.folded)
	assert_eq(folded.badge_text, "D SB Turn Fold")
	assert_eq(folded.token_badge_text, "DSBF")
	assert_eq(folded.cards.cards[0].state, CardViewModel.State.EMPTY)
	player.all_in = false
	player.folded = false
	player.busted = true
	var busted: SeatViewModel = SeatViewModel.build(player, view, {}, {})
	assert_true(busted.busted)
	assert_eq(busted.token_badge_text, "Out")
	assert_eq(busted.badge_text, "D SB Turn Out")
	assert_eq(busted.cards.cards[0].state, CardViewModel.State.EMPTY)


func test_showdown_variants_and_award_emphasis_cover_main_split_side_and_losing_seats() -> void:
	var view: GameView = _view(4)
	view.hand_complete = true
	for seat: int in 4:
		view._showdown_results[seat] = _full_house(seat)
	view._pot_awards = [
		PotAward.new(0, 101, [0, 1], {0: 51, 1: 50}), PotAward.new(1, 40, [2], {2: 40})
	]
	for seat: int in 4:
		for density: int in DENSITY.values():
			var model: SeatViewModel = SeatViewModel.build(
				view.seats[seat], view, {}, {}, null, null, density
			)
			assert_eq(model.status_full, "Full house: Aces full of Kings")
			assert_eq(model.status_compact, "Full house\nAces / Kings")
			assert_eq(model.status_inline, "Full house: A / K")
			var expected: String = [model.status_full, model.status_compact, model.status_inline][density]
			assert_eq(model.status_text, expected)
			assert_eq(model.winner_emphasis, seat < 3)
			assert_eq(model.main_pot_winner, seat < 2)
			assert_false(model.pre_showdown_winner)


func test_fold_win_uses_exact_winner_copy_and_semantic_emphasis_without_showdown_star() -> void:
	var view: GameView = _view()
	view.hand_complete = true
	view.hand_winner_seat = 1
	for density: int in DENSITY.values():
		var model: SeatViewModel = SeatViewModel.build(
			view.seats[1], view, {}, {}, null, null, density
		)
		assert_true(model.pre_showdown_winner)
		assert_true(model.winner_emphasis)
		assert_false(model.main_pot_winner)
		assert_eq(model.status_text, "Winner")
	assert_eq(SeatViewModel.build(view.seats[2], view, {}, {}).status_text, "")
	view.hand_complete = false
	assert_false(SeatViewModel.build(view.seats[1], view, {}, {}).pre_showdown_winner)


func test_invalid_inputs_return_an_explicit_error_and_no_card_identity() -> void:
	var model: SeatViewModel = SeatViewModel.build(null, null, {}, {})
	assert_false(model.valid)
	assert_false(model.error.is_empty())
	assert_eq(model.seat, Table.NO_SEAT)
	for card: CardViewModel in model.cards.cards:
		assert_eq(card.state, CardViewModel.State.EMPTY)
		assert_eq(card.rank, 0)
	assert_eq(SeatViewModel.format_action(null), "")
	assert_eq(SeatViewModel.format_compact_action(null), "")


func _full_house(seat: int) -> ShowdownResult:
	var cards: Array[CardData] = [CardData.new(14), CardData.new(14, CardData.Suit.DIAMONDS)]
	var selected: Array[CardData] = [
		cards[0],
		cards[1],
		CardData.new(14, CardData.Suit.HEARTS),
		CardData.new(13),
		CardData.new(13, CardData.Suit.DIAMONDS)
	]
	return ShowdownResult.new(
		seat, cards, HandRank.new(HandRank.Category.FULL_HOUSE, [14, 13], selected)
	)


func _view(count: int = 3) -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	view.acting_seat = Table.NO_SEAT
	view.button_seat = Table.NO_SEAT
	view.small_blind_seat = Table.NO_SEAT
	view.big_blind_seat = Table.NO_SEAT
	for seat: int in count:
		view._seats.append(
			PlayerView.new(Player.new(StringName("p%d" % seat), "Player", seat, 1000))
		)
	return view
