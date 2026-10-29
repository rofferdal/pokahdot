extends "res://tests/support/poker_gut_test.gd"

const Fixtures := preload("res://tests/support/gui_visual_state_fixtures.gd")
const Harness := preload("res://tests/support/gui_scene_harness.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")


class CallingAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		return (
			PlayerAction.check_action()
			if PlayerAction.Kind.CHECK in view.legal_actions
			else PlayerAction.call_action()
		)


func test_supported_numeric_bounds_reflow_without_clipping_at_every_phone_count() -> void:
	for count: int in range(2, 8):
		for state: StringName in [&"human-turn-preflop", &"showdown-long"]:
			var descriptor: Dictionary = _large_descriptor(state, count)
			var harness: Node = Harness.new()
			add_child(harness)
			var rendered: Dictionary = harness.render(descriptor, Vector2i(360, 640))
			assert_true(await harness.settle_layout(), "%s p%d settles" % [state, count])
			_assert_content(rendered, "%s p%d" % [state, count])
			harness.free()


func test_large_values_restore_across_phone_tablet_and_desktop_profiles() -> void:
	var descriptor: Dictionary = _large_descriptor(&"human-turn-preflop", 7)
	var harness: Node = Harness.new()
	add_child(harness)
	var rendered: Dictionary = harness.render(descriptor, Vector2i(360, 640))
	assert_true(await harness.settle_layout())
	for viewport: Vector2i in [Vector2i(768, 1024), Vector2i(1280, 720), Vector2i(360, 640)]:
		harness.resize_viewport(viewport)
		assert_true(await harness.settle_layout(), str(viewport))
		rendered.layout_profile = rendered.table.get_layout_profile()
		_assert_content(rendered, str(viewport))
	harness.free()


func test_large_portrait_feedback_restores_through_landscape_diagnostic_layout() -> void:
	var harness: Node = Harness.new()
	add_child(harness)
	var rendered: Dictionary = harness.render(
		_large_descriptor(&"human-turn-preflop", 7), Vector2i(360, 640)
	)
	assert_true(await harness.settle_layout())
	var table: PokerTableController = rendered.table
	var feedback := table.find_child("PhoneNumericFeedback", true, false) as Control
	assert_true(feedback.visible)
	harness.resize_viewport(Vector2i(640, 360))
	assert_true(await harness.settle_layout())
	assert_false(feedback.visible)
	assert_false(table.find_child("PhoneMoreSpacer", true, false).visible)
	assert_same(
		table.get_node("%PhoneHeroActionBadge").get_parent(), table.get_node("%PhoneHeroSummary")
	)
	assert_false(table.get_node("%ActionStatus").visible)
	harness.resize_viewport(Vector2i(360, 640))
	assert_true(await harness.settle_layout())
	rendered.layout_profile = table.get_layout_profile()
	_assert_content(rendered, "portrait after numeric landscape")
	assert_true(feedback.visible)
	harness.free()


func test_large_values_fit_all_larger_layout_counts() -> void:
	for count: int in [2, 4, 6, 7, 9]:
		for viewport: Vector2i in [
			Vector2i(768, 1024),
			Vector2i(1024, 768),
			Vector2i(950, 532),
			Vector2i(1280, 720),
			Vector2i(1920, 1080)
		]:
			var harness: Node = Harness.new()
			add_child(harness)
			var rendered: Dictionary = harness.render(
				_large_descriptor(&"human-turn-preflop", count), viewport
			)
			assert_true(await harness.settle_layout())
			_assert_content(rendered, "p%d %s" % [count, viewport])
			harness.free()


func test_independent_large_value_triggers_and_blind_detail_remain_readable() -> void:
	for target: String in ["hero", "opponent", "pot", "blinds", "all-in"]:
		var descriptor: Dictionary = Fixtures.by_id(&"human-turn-preflop", 7)
		var view: GameView = descriptor.view
		match target:
			"hero":
				view._seats[0].stack = 6999999
				view._action_history = [PublicActionRecord.new(0, PlayerAction.Kind.RAISE, 6999999)]
			"opponent":
				view._seats[1].stack = 6999999
				view._action_history = [PublicActionRecord.new(1, PlayerAction.Kind.RAISE, 999999)]
			"pot":
				view.pot_amount = 7000000
			"blinds":
				view.small_blind = 500000
				view.big_blind = 1000000
			"all-in":
				view._action_history = [
					PublicActionRecord.new(1, PlayerAction.Kind.ALL_IN, 6999999)
				]
		var harness: Node = Harness.new()
		add_child(harness)
		var rendered: Dictionary = harness.render(descriptor, Vector2i(360, 640))
		assert_true(await harness.settle_layout())
		_assert_content(rendered, target)
		rendered.table.call("_open_phone_overflow_menu")
		assert_true(await harness.settle_layout())
		_assert_content(rendered, target + " menu", [&"menu"])
		harness.free()


func test_web_fallback_font_and_dpr_keep_maximum_numbers_readable() -> void:
	var Geometry := preload("res://scripts/gui/gui_web_viewport_geometry.gd")
	for ratio: float in [1.0, 2.0, 3.0]:
		var logical_size: Vector2i = Geometry.logical_size(Vector2i(360, 640) * int(ratio), ratio)
		var harness: Node = Harness.new()
		add_child(harness)
		var rendered: Dictionary = harness.render(
			_large_descriptor(&"human-turn-preflop", 7), logical_size
		)
		assert_true(await harness.settle_layout())
		assert_eq(
			rendered.table.get_node("%PhoneHeroStack").get_theme_font("font"), ThemeDB.fallback_font
		)
		_assert_content(rendered, "DPR %s" % ratio)
		harness.free()


func test_compact_large_wager_presets_and_keypad_submit_exact_targets() -> void:
	for viewport: Vector2i in [Vector2i(950, 532), Vector2i(768, 1024)]:
		for method: String in ["minimum", "pot", "keypad-minimum", "keypad-pot", "keypad-free"]:
			var match_instance := TournamentMatch.new(
				ResolvedTournamentConfig.new(
					2, 1000000, 50000, 100000, 9123, &"single_table", {0: &"human", 1: &"scripted"}
				),
				{0: HumanAgent.new(), 1: CallingAgent.new()}
			)
			match_instance.start()
			match_instance.advance_until_blocked()
			var before: GameView = match_instance.get_view_for(0)
			assert_eq(before.acting_seat, 0)
			var harness: Node = Harness.new()
			add_child(harness)
			var rendered: Dictionary = harness.render(
				Fixtures.by_id(&"human-turn-preflop", 2), viewport
			)
			var table: PokerTableController = rendered.table
			table.bind_match(match_instance, 0, {})
			assert_true(await harness.settle_layout())
			var pot_target: PotWagerTargetResult = PotWagerTarget.resolve(
				before.pot_amount,
				before.seats[0].bet_this_round,
				before.call_amount,
				before.minimum_wager_total,
				before.maximum_wager_total
			)
			var target: int = before.minimum_wager_total
			match method:
				"minimum":
					table.get_node("%MinWagerButton").emit_signal("pressed")
				"pot":
					target = pot_target.wager_total
					table.get_node("%PotRaiseButton").emit_signal("pressed")
				_:
					table.get_node("%WagerButton").emit_signal("pressed")
					var keypad := table.get_node("WagerKeypad") as WagerKeypad
					assert_true(keypad.visible)
					assert_true(keypad.get_action_control(&"min").visible)
					assert_true(keypad.get_action_control(&"pot").visible)
					if method == "keypad-minimum":
						keypad.get_action_control(&"min").emit_signal("pressed")
					elif method == "keypad-pot":
						target = pot_target.wager_total
						keypad.get_action_control(&"pot").emit_signal("pressed")
					else:
						target = 234567
						keypad.get_action_control(&"clear").emit_signal("pressed")
						for digit: String in str(target):
							keypad.get_action_control(StringName(digit)).emit_signal("pressed")
					keypad.get_action_control(&"done").emit_signal("pressed")
			var after: GameView = match_instance.get_view_for(0)
			var action: PublicActionRecord = after.action_history[-1]
			assert_eq(action.seat, 0, method)
			assert_eq(action.kind, PlayerAction.Kind.RAISE, method)
			assert_eq(action.amount, target, method)
			harness.free()


func test_ordinary_seven_seat_desktops_keep_status_bands_clear() -> void:
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var harness: Node = Harness.new()
		add_child(harness)
		var rendered: Dictionary = harness.render(
			Fixtures.by_id(&"human-turn-preflop", 7), viewport
		)
		assert_true(await harness.settle_layout())
		_assert_content(rendered, "ordinary7 " + str(viewport))
		harness.free()


func test_ordinary_values_restore_compact_tokens_after_large_values() -> void:
	var harness: Node = Harness.new()
	add_child(harness)
	var rendered: Dictionary = harness.render(
		_large_descriptor(&"human-turn-preflop", 7), Vector2i(360, 640)
	)
	assert_true(await harness.settle_layout())
	var seat: Control = rendered.table.get_node("%Seats").get_node("Seat1")
	var large_height: float = seat.size.y
	assert_gte(large_height, 48.0)
	rendered = harness.rerender(Fixtures.by_id(&"human-turn-preflop", 7))
	assert_true(await harness.settle_layout())
	seat = rendered.table.get_node("%Seats").get_node("Seat1")
	assert_lte(seat.size.y, large_height)
	assert_gte(seat.size.y, 48.0)
	_assert_content(rendered, "compact restore")
	harness.free()


func _large_descriptor(state: StringName, count: int) -> Dictionary:
	var descriptor: Dictionary = Fixtures.by_id(state, count if count in [2, 4, 6, 7, 9] else 7)
	if count in [3, 5]:
		descriptor.player_count = count
		descriptor.view._seats.resize(count)
	var view: GameView = descriptor.view
	view.small_blind = 500000
	view.big_blind = 1000000
	view.pot_amount = count * 1000000
	view.call_amount = 999999
	view.minimum_wager_total = 1000000
	view.maximum_wager_total = count * 1000000
	for player: PlayerView in view._seats:
		player.stack = count * 1000000 - 1
		player.bet_this_round = 999999
	view._action_history = [
		PublicActionRecord.new(0, PlayerAction.Kind.RAISE, 6999999),
		PublicActionRecord.new(1, PlayerAction.Kind.RAISE, 999999),
	]
	return descriptor


func _assert_content(
	rendered: Dictionary, context: String, expected_overlays: Array[StringName] = []
) -> void:
	var failures: PackedStringArray = (
		Invariants.validate(rendered)
		if expected_overlays.is_empty()
		else Invariants.validate_snapshot(rendered.root.get_layout_snapshot(), expected_overlays)
	)
	assert_eq(failures, PackedStringArray(), context + "\n" + "\n".join(failures))
	var table: PokerTableController = rendered.table
	for path: String in ["%PotLabel", "%WagerLabel", "%PhoneHeroStack", "%PhoneHeroActionBadge"]:
		var label := table.get_node(path) as Label
		if label.is_visible_in_tree():
			_assert_label(label, context)
	var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
	var portrait: bool = snapshot.profile == GuiLayoutProfile.Kind.PHONE_PORTRAIT
	for seat: GuiSeatSnapshot in snapshot.seats.values():
		for role: StringName in [&"stack", &"action"]:
			var value: GuiLayoutElement = seat.fields[role]
			if not value.visible:
				continue
			assert_gte(value.font_size, 18 if portrait and not seat.hero else 20)
			if not seat.hero:
				assert_true(
					seat.footprint.encloses(value.rect), context + " complete seat footprint"
				)
	for path: String in ["%CheckCallButton", "%MinWagerButton", "%PotRaiseButton"]:
		var button := table.get_node(path) as Button
		if button.is_visible_in_tree():
			var width: float = (
				button
				. get_theme_font("font")
				. get_string_size(
					button.text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					button.get_theme_font_size("font_size")
				)
				. x
			)
			assert_lte(
				width + button.get_theme_stylebox("normal").get_minimum_size().x,
				button.size.x,
				context + " " + button.text
			)


func _assert_label(label: Label, context: String) -> void:
	var font_size: int = label.get_theme_font_size("font_size")
	var text_width: float = (
		label
		. get_theme_font("font")
		. get_string_size(label.text.get_slice("\n", 0), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		. x
	)
	assert_gte(font_size, 20, context + " " + str(label.name))
	assert_lte(text_width, label.size.x, "%s %s: %s" % [context, label.name, label.text])
