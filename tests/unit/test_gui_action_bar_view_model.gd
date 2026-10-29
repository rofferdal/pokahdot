extends GutTest


func test_every_action_kind_drives_only_its_recipient_available_controls() -> void:
	for kind: PlayerAction.Kind in PlayerAction.Kind.values():
		var view: GameView = _view()
		view._legal_actions = [kind]
		var model: ActionBarViewModel = ActionBarViewModel.build(view)
		assert_true(model.valid)
		assert_true(model.is_human_turn)
		assert_eq(model.fold_enabled, kind == PlayerAction.Kind.FOLD)
		assert_eq(
			model.check_call_enabled, kind in [PlayerAction.Kind.CHECK, PlayerAction.Kind.CALL]
		)
		assert_eq(model.can_wager, kind in [PlayerAction.Kind.BET, PlayerAction.Kind.RAISE])
		assert_eq(model.minimum_enabled, model.can_wager)
		assert_eq(model.wager_enabled, model.can_wager)
		assert_eq(model.all_in_enabled, kind == PlayerAction.Kind.ALL_IN)
		assert_eq(model.fold_visible, model.fold_enabled)
		assert_eq(model.wager_visible, model.can_wager)
		assert_false(model.phone_minimum_visible)
		assert_false(model.phone_pot_visible)


func test_out_of_turn_legal_list_cannot_enable_or_show_actions() -> void:
	var view: GameView = _view()
	view._legal_actions = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CHECK,
		PlayerAction.Kind.BET,
		PlayerAction.Kind.ALL_IN
	]
	view.acting_seat = 1
	var model: ActionBarViewModel = ActionBarViewModel.build(view)
	assert_false(model.is_human_turn)
	assert_false(model.fold_enabled)
	assert_false(model.check_call_enabled)
	assert_false(model.minimum_enabled)
	assert_false(model.pot_enabled)
	assert_false(model.wager_enabled)
	assert_false(model.all_in_enabled)
	assert_false(model.fold_visible)
	assert_false(model.check_call_visible)
	assert_false(model.wager_visible)
	assert_false(model.all_in_visible)


func test_exact_pot_contribution_is_distinct_from_street_total() -> void:
	var view: GameView = _view()
	view._seats[0].bet_this_round = 25
	view.pot_amount = 150
	view.call_amount = 40
	view.minimum_wager_total = 120
	view.maximum_wager_total = 1000
	var model: ActionBarViewModel = ActionBarViewModel.build(view)
	assert_true(model.pot_enabled)
	assert_eq(model.pot_contribution, 150)
	assert_eq(model.pot_total, 175)
	assert_eq(model.pot_text, "Pot 150")
	assert_eq(model.pot_reason, PotWagerTarget.AVAILABLE)
	assert_eq(view.pot_amount, 150)
	assert_eq(view.seats[0].bet_this_round, 25)
	assert_eq(ActionBarViewModel.resolve_pot_target(view).wager_total, 175)


func test_pot_total_bounds_are_inclusive_and_short_stack_never_clamps() -> void:
	var view: GameView = _view()
	view.pot_amount = 100
	view.minimum_wager_total = 100
	view.maximum_wager_total = 100
	assert_true(ActionBarViewModel.build(view).pot_enabled)
	view.maximum_wager_total = 99
	view.minimum_wager_total = 20
	var short_stack: ActionBarViewModel = ActionBarViewModel.build(view)
	assert_false(short_stack.pot_enabled)
	assert_eq(short_stack.pot_total, 100)
	assert_eq(short_stack.maximum_total, 99)
	assert_true(short_stack.minimum_enabled)
	view.maximum_wager_total = 1000
	view.minimum_wager_total = 101
	assert_false(ActionBarViewModel.build(view).pot_enabled)
	view._legal_actions = [PlayerAction.Kind.ALL_IN]
	assert_false(ActionBarViewModel.build(view).pot_enabled)


func test_pot_wager_shortcut_respects_legal_action_and_inclusive_total_bounds() -> void:
	var view: GameView = _view()
	view._legal_actions = [PlayerAction.Kind.CHECK, PlayerAction.Kind.BET]
	view.call_amount = 0
	view.minimum_wager_total = 20
	view.maximum_wager_total = 100
	for fixture: Dictionary in [
		{"target": 19, "disabled": true, "label": "below minimum"},
		{"target": 20, "disabled": false, "label": "at minimum"},
		{"target": 100, "disabled": false, "label": "at maximum"},
		{"target": 101, "disabled": true, "label": "above maximum"},
	]:
		view.pot_amount = fixture.target
		var model: ActionBarViewModel = ActionBarViewModel.build(view)
		assert_eq(not model.pot_enabled, fixture.disabled, fixture.label)
	view.pot_amount = 15
	view.maximum_wager_total = 15
	view._legal_actions = [PlayerAction.Kind.CHECK, PlayerAction.Kind.ALL_IN]
	var insufficient: ActionBarViewModel = ActionBarViewModel.build(view)
	assert_false(insufficient.pot_enabled, "insufficient stack")
	assert_eq(insufficient.pot_text, "Pot 0")
	view.pot_amount = 30
	view.minimum_wager_total = 20
	view.maximum_wager_total = 100
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL]
	assert_false(ActionBarViewModel.build(view).pot_enabled, "wager action unavailable")


func test_core_repeated_raise_and_short_stack_views_supply_exact_model_pot_and_bounds() -> void:
	for stack: int in [500, 100]:
		var config := ResolvedTournamentConfig.new(
			2, stack, 5, 10, 9123, &"single_table", {0: &"human", 1: &"scripted"}
		)
		var match_instance := TournamentMatch.new(
			config,
			{
				0: HumanAgent.new(),
				1:
				ScriptedAgent.new(
					[
						PlayerAction.check_action(),
						PlayerAction.check_action(),
						PlayerAction.raise_to(40)
					]
				)
			}
		)
		assert_eq(match_instance.start().status, StepResult.Status.WAITING_FOR_HUMAN)
		assert_eq(
			match_instance.submit_human_action(PlayerAction.call_action()).status,
			StepResult.Status.WAITING_FOR_HUMAN
		)
		assert_eq(
			match_instance.submit_human_action(PlayerAction.bet_to(20)).status,
			StepResult.Status.WAITING_FOR_HUMAN
		)
		var view: GameView = match_instance.get_view_for(0)
		var model: ActionBarViewModel = ActionBarViewModel.build(view)
		assert_eq(model.minimum_total, 60)
		assert_eq(model.maximum_total, stack - 10)
		assert_eq(model.minimum_text, "Min Raise 60")
		assert_eq(model.check_call_text, "Call 20")
		assert_eq(model.pot_contribution, 80)
		assert_eq(model.pot_total, 100)
		assert_eq(model.pot_text, "Pot 80")
		assert_eq(model.pot_enabled, stack == 500)
		assert_true(model.minimum_enabled)
		assert_true(model.wager_enabled)
		assert_true(model.all_in_enabled)
		assert_eq(
			ActionBarViewModel.build(view, {}, GuiFitCandidate.Density.COMPACT).minimum_text,
			"Min 60"
		)


func test_core_short_all_in_views_present_open_and_closed_raise_rights() -> void:
	for unacted_stack: int in [100, 50]:
		var players: Array[Player] = []
		var stacks: Array[int] = [100, 100, 40, unacted_stack]
		for seat: int in 4:
			players.append(
				Player.new(StringName("short_%d" % seat), "Player %d" % seat, seat, stacks[seat])
			)
		var table := Table.new(players, 5, 10)
		var round := BettingRound.new(table, 0, 10)
		assert_true(round.apply_action(0, PlayerAction.raise_to(30)).is_ok())
		assert_true(round.apply_action(1, PlayerAction.call_action()).is_ok())
		assert_true(round.apply_action(2, PlayerAction.all_in_action()).is_ok())
		var open: ActionBarViewModel = ActionBarViewModel.build(_core_raise_view(table, round, 3))
		assert_eq(open.minimum_total, 60)
		assert_eq(open.check_call_text, "Call 40")
		assert_true(open.check_call_enabled)
		assert_true(open.all_in_enabled)
		assert_eq(open.can_wager, unacted_stack >= 60)
		assert_eq(open.minimum_enabled, unacted_stack >= 60)
		assert_eq(open.wager_enabled, unacted_stack >= 60)
		assert_eq(open.pot_enabled, unacted_stack >= 60)
		assert_true(round.apply_action(3, PlayerAction.call_action()).is_ok())
		var closed: ActionBarViewModel = ActionBarViewModel.build(_core_raise_view(table, round, 0))
		assert_eq(closed.minimum_total, 60)
		assert_eq(closed.check_call_text, "Call 10")
		assert_true(closed.check_call_enabled)
		assert_false(closed.can_wager)
		assert_false(closed.minimum_enabled)
		assert_false(closed.pot_enabled)
		assert_false(closed.wager_enabled)
		assert_false(closed.all_in_enabled)


func _core_raise_view(table: Table, round: BettingRound, recipient: int) -> GameView:
	var pots := PotManager.new()
	for player: Player in table.players:
		pots.record_contribution(player.seat, player.total_contribution)
	return GameView.for_preflop(table, recipient, round, pots, [])


func test_repeated_raise_and_short_all_in_use_authoritative_view_bounds() -> void:
	var view: GameView = _view()
	view.minimum_wager_total = 50
	view.maximum_wager_total = 900
	view.call_amount = 30
	var first: ActionBarViewModel = ActionBarViewModel.build(view)
	assert_eq(first.minimum_text, "Min Raise 50")
	assert_eq(first.check_call_text, "Call 30")
	view.minimum_wager_total = 90
	view.call_amount = 60
	var second: ActionBarViewModel = ActionBarViewModel.build(view)
	assert_eq(second.minimum_total, 90)
	assert_eq(second.minimum_text, "Min Raise 90")
	assert_eq(second.check_call_text, "Call 60")
	assert_eq(first.minimum_total, 50)
	view._legal_actions = [PlayerAction.Kind.FOLD, PlayerAction.Kind.CALL, PlayerAction.Kind.ALL_IN]
	assert_false(ActionBarViewModel.build(view).can_wager)


func test_compact_and_full_copy_keep_every_digit() -> void:
	var view: GameView = _view()
	view.minimum_wager_total = 123456789
	view.maximum_wager_total = 999999999
	view.call_amount = 1234567
	view.pot_amount = 234567890
	var full: ActionBarViewModel = ActionBarViewModel.build(view)
	var compact: ActionBarViewModel = ActionBarViewModel.build(
		view, {}, GuiFitCandidate.Density.COMPACT
	)
	assert_eq(full.minimum_text, "Min Raise 123456789")
	assert_eq(compact.minimum_text, "Min 123456789")
	assert_eq(compact.check_call_text, "Call 1234567")
	assert_eq(compact.pot_text, "Pot 234567890")
	assert_eq(full.input_placeholder, "Wager total")
	assert_eq(compact.input_placeholder, "Total")
	view._legal_actions = [PlayerAction.Kind.CHECK, PlayerAction.Kind.BET]
	assert_eq(ActionBarViewModel.build(view).wager_text, "Bet")
	assert_eq(ActionBarViewModel.build(view).check_call_text, "Check")
	view._legal_actions = []
	assert_eq(ActionBarViewModel.build(view).check_call_text, "Check / Call")
	assert_eq(
		ActionBarViewModel.build(view, {}, GuiFitCandidate.Density.MINIMAL).check_call_text, "Call"
	)


func test_status_uses_gui_names_and_preserves_reference_copy_separately() -> void:
	var view: GameView = _view()
	view.acting_seat = 1
	var names: Dictionary[int, String] = {1: "Ada"}
	var model: ActionBarViewModel = ActionBarViewModel.build(view, names)
	assert_eq(model.status_text, "Ada to act — Preflop")
	assert_eq(model.reference_status_text, "Bot to act — Preflop")
	assert_eq(model.status_compact, "Act: Ada")
	view.acting_seat = view.hero_seat
	assert_eq(ActionBarViewModel.build(view).status_text, "Your turn — Preflop.")
	view.acting_seat = Table.NO_SEAT
	view.hand_complete = true
	assert_eq(ActionBarViewModel.build(view).status_text, "Hand complete.")
	view.tournament_status = &"finished"
	view.end_reason = &"winner"
	view.tournament_winner_seat = 1
	assert_eq(ActionBarViewModel.build(view, names).status_text, "Ada wins the tournament!")
	assert_eq(
		ActionBarViewModel.build(view, names, GuiFitCandidate.Density.COMPACT).status_text,
		"Ada wins"
	)
	view.tournament_winner_seat = 0
	assert_eq(ActionBarViewModel.build(view, names).status_text, "Human wins the tournament!")
	view.end_reason = &"player_quit"
	assert_eq(ActionBarViewModel.build(view).status_text, "Tournament ended: player quit.")


func test_null_view_is_explicit_and_no_model_retains_input_resources() -> void:
	var invalid: ActionBarViewModel = ActionBarViewModel.build(null)
	assert_false(invalid.valid)
	assert_false(invalid.error.is_empty())
	assert_false(ActionBarViewModel.resolve_pot_target(null).available)
	var view: GameView = _view()
	var model: ActionBarViewModel = ActionBarViewModel.build(view)
	for property: Dictionary in model.get_property_list():
		if property.name == "script":
			continue
		var value: Variant = model.get(property.name)
		assert_false(value is GameView or value is PlayerView or value is CardData)


func _view() -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	view.acting_seat = 0
	view.pot_amount = 50
	view.minimum_wager_total = 20
	view.maximum_wager_total = 1000
	view.call_amount = 10
	view._legal_actions = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CALL,
		PlayerAction.Kind.RAISE,
		PlayerAction.Kind.ALL_IN
	]
	view._seats = [
		PlayerView.new(Player.new(&"human", "Core Human", 0, 1000, HumanAgent.new())),
		PlayerView.new(Player.new(&"bot", "Bot", 1, 1000)),
	]
	return view
