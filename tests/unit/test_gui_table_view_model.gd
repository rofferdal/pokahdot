extends GutTest

const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")


func test_every_density_is_detached_and_keeps_all_seven_or_nine_seats() -> void:
	for count: int in [7, 9]:
		for density: int in GuiFitCandidate.Density.values():
			var view: GameView = _view(count)
			var names: Dictionary[int, String] = {1: "Leilani"}
			var avatars: Dictionary[int, String] = {1: "res://assets/avatars/one.svg"}
			var events: Array[String] = ["Hand 1 started", "Human: Check"]
			var latest: Dictionary[int, PublicActionRecord] = {
				1: PublicActionRecord.new(1, PlayerAction.Kind.CALL, 1234567)
			}
			var model: TableViewModel = TableViewModel.build(
				view, names, avatars, latest, {}, events, density
			)
			assert_true(model.valid)
			assert_eq(model.seats.size(), count)
			assert_eq(model.seat_for(0).display_name, "Human")
			assert_eq(model.seat_for(1).display_name, "Leilani")
			assert_string_contains(model.seat_for(1).latest_action_text, "1234567")
			assert_eq(model.history.text, "Hand 1 started\nHuman: Check")
			assert_eq(model.center.board.cards.size(), 5)
			_assert_values_only(model, {})
			var retained: WeakRef = weakref(view)
			names[1] = "Changed"
			events.clear()
			latest.clear()
			view = null
			assert_null(retained.get_ref())
			assert_eq(model.history.entries.size(), 2)
			assert_eq(model.seat_for(1).display_name, "Leilani")


func test_fold_split_and_side_pot_summary_preserves_names_shares_and_emphasis() -> void:
	var view: GameView = _view(3)
	view.hand_complete = true
	view.hand_winner_seat = 1
	var names: Dictionary[int, String] = {1: "Leilani", 2: "Haruto"}
	var summary: HandSummaryViewModel = HandSummaryViewModel.build(view, names)
	assert_eq(summary.result_text, "Winner: Leilani")
	assert_eq(summary.text, "Leilani wins the hand")
	assert_true(summary.lines[0].winner_emphasis)
	view._pot_awards = [
		PotAward.new(0, 1000001, [0, 1], {0: 500001, 1: 500000}),
		PotAward.new(1, 400, [2], {2: 400}),
	]
	summary = HandSummaryViewModel.build(view, names)
	assert_eq(summary.winner_names, PackedStringArray(["Human", "Leilani", "Haruto"]))
	assert_eq(summary.result_text, "Winners: Human, Leilani, Haruto")
	assert_string_contains(summary.text, "Main pot (1000001): Human +500001, Leilani +500000")
	assert_string_contains(summary.text, "Side pot 1 (400): Haruto +400")
	for line: HandSummaryLineViewModel in summary.lines:
		assert_true(line.winner_emphasis)
	_assert_values_only(summary, {})


func test_controller_consumes_model_and_rebind_drops_previous_recipient_history() -> void:
	var table := TableScene.instantiate() as GuiReplacementTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(1920, 1300)
	add_child_autofree(table)
	table.set_viewport_geometry(GuiViewportGeometry.injected(table.size))
	assert_true(table.bind_view(_view(7), {}, {1: "Leilani"}))
	assert_true(await _settle(table))
	var model: TableViewModel = table.get_table_view_model()
	assert_true(model.valid)
	assert_eq(model.seat_for(1).display_name, "Leilani")
	var next: GameView = _view(2)
	next.hand_complete = true
	next.hand_winner_seat = 1
	assert_true(table.bind_view(next, {}, {1: "Haruto"}))
	assert_true(await _settle(table))
	var rebound: TableViewModel = table.get_table_view_model()
	assert_ne(rebound, model)
	assert_eq(rebound.seats.size(), 2)
	assert_eq(rebound.history.text, "")
	assert_string_contains(rebound.summary.text, "Haruto")
	assert_eq(rebound.seat_for(1).status_text, "Winner")
	_assert_values_only(rebound, {})


func test_invalid_table_inputs_return_explicit_errors() -> void:
	var model: TableViewModel = TableViewModel.build(null, {}, {}, {}, {}, [])
	assert_false(model.valid)
	assert_false(model.error.is_empty())
	var view: GameView = _view(2)
	view._seats.append(view.seats[0])
	assert_false(TableViewModel.build(view, {}, {}, {}, {}, []).valid)
	view = _view(2)
	view.hero_seat = 99
	assert_false(TableViewModel.build(view, {}, {}, {}, {}, []).valid)
	view = _view(2)
	view._seats.append(null)
	assert_false(TableViewModel.build(view, {}, {}, {}, {}, []).valid)


func test_pre_tree_binding_and_rebinding_build_fresh_values_before_controls_exist() -> void:
	var table := TableScene.instantiate() as GuiReplacementTableController
	var view: GameView = _view(7)
	view._action_history = [PublicActionRecord.new(1, PlayerAction.Kind.RAISE, 200)]
	assert_true(table.bind_view(view, {}, {1: "Leilani"}))
	assert_eq(table.get_table_view_model().seat_for(1).latest_action_text, "Raise to 200")
	assert_true(table.bind_view(_view(2), {}, {1: "Haruto"}))
	assert_eq(table.get_table_view_model().seat_for(1).latest_action_text, "")
	assert_eq(table.get_table_view_model().seat_for(1).display_name, "Haruto")
	add_child_autofree(table)
	await wait_process_frames(3)
	assert_true(table.get_table_view_model().valid)
	assert_eq(table.get_table_view_model().seat_for(1).display_name, "Haruto")


func _settle(table: GuiReplacementTableController) -> bool:
	for _frame: int in 180:
		await get_tree().process_frame
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		if snapshot.ready and not snapshot.pending:
			return true
	return false


func _assert_values_only(value: Variant, seen: Dictionary) -> void:
	if value is Array or value is PackedStringArray or value is PackedInt32Array:
		for item: Variant in value:
			_assert_values_only(item, seen)
	elif value is Dictionary:
		for item: Variant in value.values():
			_assert_values_only(item, seen)
	elif value is Object:
		assert_false(
			(
				value is Node
				or value is Resource
				or value is GameView
				or value is PlayerView
				or value is PublicActionRecord
				or value is PotAward
			)
		)
		if seen.has(value.get_instance_id()):
			return
		seen[value.get_instance_id()] = true
		for property: Dictionary in value.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_assert_values_only(value.get(property.name), seen)


func _view(count: int) -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	view.acting_seat = 0
	view.minimum_wager_total = 20
	view.maximum_wager_total = 1000
	view.pot_amount = 30
	view.small_blind = 5
	view.big_blind = 10
	view._legal_actions = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CALL,
		PlayerAction.Kind.RAISE,
		PlayerAction.Kind.ALL_IN
	]
	view._hero_hole_cards = [CardData.new(10), CardData.new(14, CardData.Suit.HEARTS)]
	for seat: int in count:
		view._seats.append(
			PlayerView.new(
				Player.new(
					StringName("p%d" % seat),
					"Player %d" % seat,
					seat,
					1000,
					HumanAgent.new() if seat == 0 else null
				)
			)
		)
	return view
