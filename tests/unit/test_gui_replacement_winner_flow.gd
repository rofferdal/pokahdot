extends "res://tests/support/poker_gut_test.gd"

const Fixtures := preload("res://tests/support/gui_visual_state_fixtures.gd")
const Controller := preload("res://scenes/gui/ReplacementPokerTable.tscn")
const Invariants := preload("res://tests/support/gui_replacement_invariant_assertions.gd")
const PHONE_COUNTS: Array[int] = [2, 4, 6, 7]
const HERO_SEEDS: Dictionary[int, int] = {2: 1, 4: 8, 6: 2, 7: 17}
const OPPONENT_SEEDS: Dictionary[int, int] = {2: 4, 4: 1, 6: 4, 7: 1}
const SPLIT_SEEDS: Dictionary[int, int] = {2: 47, 4: 41, 6: 1, 7: 6}
const SIDE_POT_SEEDS: Dictionary[int, int] = {4: 2, 6: 1, 7: 1}
const NAMES: Array[String] = ["Human", "Leilani", "Haruto", "Youssef", "Chidi", "Yael", "Wei"]

var _viewport: SubViewport
var _table: GuiReplacementTableController


class CallingAgent:
	extends Agent
	var shove_hand: int = 99
	var fold_preflop: bool = false

	func choose_action(view: GameView) -> PlayerAction:
		if fold_preflop and view.street == &"preflop":
			return PlayerAction.fold_action()
		if view.hand_number >= shove_hand and PlayerAction.Kind.ALL_IN in view.legal_actions:
			return PlayerAction.all_in_action()
		return (
			PlayerAction.check_action()
			if PlayerAction.Kind.CHECK in view.legal_actions
			else PlayerAction.call_action()
		)


func _match(
	count: int,
	seed_value: int,
	folded_seat: int = -1,
	shove_hand: int = 99,
	fold_opponents: bool = false,
) -> TournamentMatch:
	var roles: Dictionary[int, StringName] = {0: &"human"}
	var agents: Dictionary[int, Agent] = {0: HumanAgent.new()}
	for seat: int in range(1, count):
		roles[seat] = &"scripted"
		var agent := CallingAgent.new()
		agent.fold_preflop = fold_opponents or seat == folded_seat
		agent.shove_hand = shove_hand
		agents[seat] = agent
	var match_instance := TournamentMatch.new(
		ResolvedTournamentConfig.new(count, 100, 5, 10, seed_value, &"single_table", roles), agents
	)
	assert_ne(match_instance.start(1).status, StepResult.Status.ERROR)
	return match_instance


func _before_settlement(match_instance: TournamentMatch, shove: bool = false) -> GameView:
	for transition: int in range(300):
		var view: GameView = match_instance.get_view_for(0)
		if view.street == &"river" and view.acting_seat == Table.NO_SEAT:
			assert_false(view.hand_complete)
			return view
		if view.hand_complete:
			fail_test("Fixture completed before reaching the river settlement boundary")
			return view
		_step(match_instance, view, shove)
	fail_test("Fixture did not reach settlement within 300 transitions")
	return match_instance.get_view_for(0)


func _before_fold_settlement(match_instance: TournamentMatch) -> void:
	for transition: int in range(50):
		var view: GameView = match_instance.get_view_for(0)
		var remaining: int = 0
		for player: PlayerView in view.seats:
			if not player.folded:
				remaining += 1
		if remaining == 1 and view.acting_seat == Table.NO_SEAT:
			assert_false(view.hand_complete)
			return
		_step(match_instance, view, false)
	fail_test("Fixture did not reach fold settlement within 50 transitions")


func _finish_hand(match_instance: TournamentMatch) -> void:
	for transition: int in range(300):
		var view: GameView = match_instance.get_view_for(0)
		if view.hand_complete:
			return
		_step(match_instance, view, false)
	fail_test("Fixture hand exceeded 300 transitions")


func _step(match_instance: TournamentMatch, view: GameView, shove: bool) -> void:
	var result: StepResult
	if view.acting_seat == 0:
		var action: PlayerAction = (
			PlayerAction.all_in_action()
			if shove and PlayerAction.Kind.ALL_IN in view.legal_actions
			else (
				PlayerAction.check_action()
				if PlayerAction.Kind.CHECK in view.legal_actions
				else PlayerAction.call_action()
			)
		)
		result = match_instance.submit_human_action_without_advance(action)
	else:
		result = match_instance.advance_one_action()
	assert_ne(result.status, StepResult.Status.ERROR)


func after_each() -> void:
	_dispose()
	await wait_process_frames(2)


func test_real_hero_and_opponent_showdowns_publish_named_winners() -> void:
	for count: int in PHONE_COUNTS:
		for hero_wins: bool in [true, false]:
			var game: TournamentMatch = _match(
				count, HERO_SEEDS[count] if hero_wins else OPPONENT_SEEDS[count]
			)
			var before: GameView = _before_settlement(game)
			assert_true(before.revealed_hole_cards.is_empty())
			await _mount(game, count)
			await _settle_hand(game)
			var view: GameView = game.get_view_for(0)
			assert_true(view.hand_complete)
			assert_eq(view.pot_awards.size(), 1)
			assert_eq(view.pot_awards[0].winner_seats.size(), 1)
			assert_eq(view.pot_awards[0].winner_seats[0] == 0, hero_wins)
			await _assert_result(view)
			_dispose()


func test_real_split_pots_publish_every_recipient() -> void:
	for count: int in PHONE_COUNTS:
		var game: TournamentMatch = _match(count, SPLIT_SEEDS[count])
		_before_settlement(game)
		await _mount(game, count)
		await _settle_hand(game)
		var view: GameView = game.get_view_for(0)
		assert_gt(view.pot_awards[0].winner_seats.size(), 1)
		await _assert_result(view)
		_dispose()


func test_real_side_pots_publish_named_recipients_and_exact_shares() -> void:
	for count: int in SIDE_POT_SEEDS:
		var game: TournamentMatch = _match(count, SIDE_POT_SEEDS[count], -1, 3)
		for completed_hand: int in 2:
			_finish_hand(game)
			game.advance_one_action()
		_before_settlement(game, true)
		await _mount(game, count)
		await _settle_hand(game)
		var view: GameView = game.get_view_for(0)
		assert_gte(view.pot_awards.size(), 2)
		await _assert_result(view)
		_dispose()


func test_completed_hand_pause_then_next_hand_resets_result() -> void:
	var game: TournamentMatch = _match(2, HERO_SEEDS[2])
	_before_settlement(game)
	await _mount(game, 2, 0.6)
	await _settle_hand(game)
	var before: GameView = game.get_view_for(0)
	assert_true(before.hand_complete)
	assert_true(_table.get_table_view_model().summary.visible)
	await get_tree().create_timer(0.1).timeout
	assert_eq(game.get_view_for(0).hand_number, before.hand_number)
	await get_tree().create_timer(0.7).timeout
	assert_eq(game.get_view_for(0).hand_number, before.hand_number + 1)
	assert_false(game.get_view_for(0).hand_complete)


func test_seven_named_recipients_and_large_shares_survive_guidance_and_recovery() -> void:
	var game: TournamentMatch = _match(7, SPLIT_SEEDS[7])
	_finish_hand(game)
	var view: GameView = game.get_view_for(0)
	var recipients: Array[int] = [0, 1, 2, 3, 4, 5, 6]
	var shares: Dictionary[int, int] = {}
	for player: PlayerView in view._seats:
		player.stack = 1000000
		player.all_in = false
		player.busted = false
		player.folded = false
		shares[player.seat] = 1000000
	view.pot_amount = 7000000
	view.big_blind = 1000000
	view.small_blind = 500000
	view._pot_awards = [PotAward.new(0, 7000000, recipients, shares)]
	_setup(Vector2i(360, 640))
	assert_true(_table.bind_view(view, {}, _names(7)))
	assert_true(await _settle())
	assert_false(_table.get_layout_snapshot().ready)
	assert_false(_table.get_layout_snapshot().fit_guidance.is_empty())
	for seat: int in recipients:
		assert_string_contains(
			_table.get_table_view_model().summary.text, "%s +1000000" % NAMES[seat]
		)
	_resize(Vector2i(1600, 1400))
	assert_true(await _settle())
	await _assert_result(view)


func test_combined_roles_and_long_names_survive_before_and_after_settlement() -> void:
	for count: int in PHONE_COUNTS:
		var game: TournamentMatch = _match(count, OPPONENT_SEEDS[count])
		_before_settlement(game)
		await _mount(game, count)
		var before: GameView = game.get_view_for(0)
		var model: TableViewModel = _table.get_table_view_model()
		for player: PlayerView in before.seats:
			assert_eq(model.seat_for(player.seat).display_name, NAMES[player.seat])
			assert_eq(model.seat_for(player.seat).is_dealer, player.seat == before.button_seat)
			assert_eq(
				model.seat_for(player.seat).is_small_blind, player.seat == before.small_blind_seat
			)
			assert_eq(
				model.seat_for(player.seat).is_big_blind, player.seat == before.big_blind_seat
			)
		await _settle_hand(game)
		await _assert_result(game.get_view_for(0))
		_dispose()

	# Supplemental stress keeps combined all-in/blind/dealer roles across rebinding.
	for count: int in PHONE_COUNTS:
		var view: GameView = Fixtures.by_id(&"all-in-runout", count).view
		view.button_seat = 1 if count == 2 else 0
		view.small_blind_seat = 1
		view.big_blind_seat = 0 if count == 2 else 2
		view._seats[1].all_in = true
		view._seats[1].stack = 0
		var names: Dictionary[int, String] = {}
		for seat: int in count:
			names[seat] = "Human" if seat == 0 else "Santiago"
		_setup(Vector2i(360, 640))
		assert_true(_table.bind_view(view, {}, names))
		assert_true(await _settle())
		var before: SeatViewModel = _table.get_table_view_model().seat_for(1)
		assert_true(before.all_in and before.is_small_blind)
		assert_eq(before.is_dealer, count == 2)
		view.hand_complete = true
		view.hand_winner_seat = 1
		view._seats[1].stack = count * 1000000
		view._revealed_hole_cards = {1: [CardData.new(10, 0), CardData.new(10, 1)]}
		assert_true(_table.bind_view(view, {}, names))
		for extent: Vector2i in [Vector2i(390, 744), Vector2i(360, 640), Vector2i(1600, 1400)]:
			_resize(extent)
			assert_true(await _settle())
			var after: SeatViewModel = _table.get_table_view_model().seat_for(1)
			assert_true(after.all_in and after.is_small_blind)
			assert_eq(after.is_dealer, count == 2)
			assert_eq(after.stack_value_text, str(count * 1000000))
			assert_eq(Invariants.validate(_table.get_layout_snapshot()), PackedStringArray())
		_dispose()


func test_acting_heads_up_dealer_retains_action_and_role_fields() -> void:
	for stack_value: int in [1000, 1000000]:
		var view: GameView = Fixtures.by_id(&"bot-turn", 2).view
		view.button_seat = 1
		view.small_blind_seat = 1
		view.big_blind_seat = 0
		view.acting_seat = 1
		view._seats[1].stack = stack_value
		view._action_history = [PublicActionRecord.new(1, PlayerAction.Kind.RAISE, stack_value)]
		_setup(Vector2i(390, 844))
		assert_true(_table.bind_view(view, {}, {0: "Human", 1: "Santiago"}))
		assert_true(await _settle())
		var seat: SeatViewModel = _table.get_table_view_model().seat_for(1)
		assert_eq(seat.display_name, "Santiago")
		assert_eq(seat.stack_value_text, str(stack_value))
		assert_true(seat.is_dealer and seat.is_small_blind and seat.acting)
		assert_string_contains(seat.latest_action_text, str(stack_value))
		assert_eq(Invariants.validate(_table.get_layout_snapshot()), PackedStringArray())
		_dispose()


func test_real_fold_wins_never_reveal_opponents() -> void:
	for count: int in PHONE_COUNTS:
		var game: TournamentMatch = _match(count, 1, -1, 99, true)
		_before_fold_settlement(game)
		await _mount(game, count)
		await _settle_hand(game)
		var view: GameView = game.get_view_for(0)
		assert_true(view.hand_complete)
		assert_eq(view.hand_winner_seat, 0)
		assert_true(view.revealed_hole_cards.is_empty())
		assert_true(view.showdown_results.is_empty())
		await _assert_result(view)
		_assert_hidden_cards(view)
		_dispose()


func test_real_showdown_does_not_reveal_folded_opponent() -> void:
	var game: TournamentMatch = _match(4, 1, 3)
	_before_settlement(game)
	await _mount(game, 4)
	await _settle_hand(game)
	var view: GameView = game.get_view_for(0)
	assert_false(view.revealed_hole_cards.has(3))
	assert_false(view.showdown_results.has(3))
	await _assert_result(view)
	_assert_hidden_cards(view)


func _setup(extent: Vector2i) -> void:
	_dispose()
	_viewport = SubViewport.new()
	_viewport.size = extent
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_table = Controller.instantiate()
	_table.touch_entry = true
	_table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_viewport.add_child(_table)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(extent)))
	_table.set_layout_mode_override(GuiSizeClass.LayoutMode.PHONE)


func _resize(extent: Vector2i) -> void:
	_viewport.size = extent
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(extent)))


func _mount(game: TournamentMatch, count: int, pause: float = 60.0) -> void:
	_setup(Vector2i(390, 844))
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 60.0
	timing.showdown_pause_seconds = pause
	_table.set_action_timing_config(timing)
	assert_true(_table.bind_match(game, 0, {}, _names(count)))
	assert_true(await _settle())


func _settle_hand(game: TournamentMatch) -> void:
	if _table.get_layout_snapshot().ready:
		assert_ne(_table.advance_one_action().status, StepResult.Status.ERROR)
	else:
		assert_ne(game.advance_one_action().status, StepResult.Status.ERROR)
		assert_true(_table.refresh_from_match())
	assert_true(await _settle())


func _settle() -> bool:
	for frame: int in 180:
		await wait_process_frames(1)
		var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
		if not snapshot.pending and (snapshot.ready or not snapshot.fit_guidance.is_empty()):
			return true
	return false


func _names(count: int) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	for seat: int in count:
		result[seat] = NAMES[seat]
	return result


func _assert_result(view: GameView) -> void:
	var model: TableViewModel = _table.get_table_view_model()
	assert_true(model.summary.visible)
	for award: PotAward in view.pot_awards:
		assert_string_contains(model.summary.text, str(award.amount))
		for seat: int in award.winner_seats:
			assert_string_contains(model.summary.result_text, NAMES[seat])
			assert_string_contains(
				model.summary.text, "%s +%d" % [NAMES[seat], award.amounts_by_seat[seat]]
			)
	var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
	assert_eq(Invariants.validate(snapshot), PackedStringArray())
	_assert_hidden_cards(view)
	for seat: int in view.revealed_hole_cards:
		if seat == view.hero_seat:
			continue
		var busted: bool = model.seat_for(seat).busted
		for card: CardViewModel in model.seat_for(seat).cards.cards:
			assert_eq(card.state, CardViewModel.State.EMPTY if busted else CardViewModel.State.FACE)
		if snapshot.ready:
			for card: GuiCardSnapshot in snapshot.seats[seat].cards:
				assert_eq(
					card.kind, GuiCardSnapshot.Kind.EMPTY if busted else GuiCardSnapshot.Kind.FACE
				)
				assert_eq(card.authorized, not busted)
	if not snapshot.ready:
		assert_false(snapshot.fit_guidance.is_empty())
		return
	assert_false(_table.get_overlay_host().is_active())
	var status: GuiLayoutElement = snapshot.elements[&"action/status"]
	for name: String in model.summary.winner_names:
		assert_string_contains(status.text, name)
	_table.get_overlay_host().open_summary(model.summary)
	await wait_process_frames(4)
	assert_eq(_table.get_overlay_host().get_active_kind(), &"summary")
	var body: RichTextLabel = (
		_table.get_overlay_host().get_control(&"summary_body") as RichTextLabel
	)
	for award: PotAward in view.pot_awards:
		for seat: int in award.winner_seats:
			assert_string_contains(
				body.get_parsed_text(), "%s +%d" % [NAMES[seat], award.amounts_by_seat[seat]]
			)
	_table.get_overlay_host().close()


func _assert_hidden_cards(view: GameView) -> void:
	var model: TableViewModel = _table.get_table_view_model()
	for player: PlayerView in view.seats:
		if player.seat == view.hero_seat or view.revealed_hole_cards.has(player.seat):
			continue
		for card: CardViewModel in model.seat_for(player.seat).cards.cards:
			assert_ne(card.state, CardViewModel.State.FACE)
		var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
		if snapshot.ready and snapshot.seats.has(player.seat):
			for card: GuiCardSnapshot in snapshot.seats[player.seat].cards:
				assert_ne(card.kind, GuiCardSnapshot.Kind.FACE)
				assert_false(card.authorized)


func _dispose() -> void:
	if is_instance_valid(_table):
		_table.teardown()
	if is_instance_valid(_viewport):
		_viewport.free()
	_table = null
	_viewport = null
