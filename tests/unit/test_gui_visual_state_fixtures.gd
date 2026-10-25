extends "res://tests/support/poker_gut_test.gd"

const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const ShowdownHandFormatterScript := preload("res://scripts/gui/showdown_hand_formatter.gd")


func test_catalog_has_unique_stable_ids_and_explicit_ui_only_states() -> void:
	var descriptors: Array[Dictionary] = GuiVisualStateFixturesScript.all()
	var descriptors_by_id: Dictionary = {}
	for descriptor: Dictionary in descriptors:
		assert_false(descriptors_by_id.has(descriptor.id), "duplicate state: %s" % descriptor.id)
		descriptors_by_id[descriptor.id] = descriptor
		assert_eq(descriptor.fixed_seed, GuiVisualStateFixturesScript.FIXED_SEED)
		assert_true(descriptor.synthetic, str(descriptor.id))

	assert_eq(descriptors_by_id.keys(), GuiVisualStateFixturesScript.STATE_IDS)
	for state_id: StringName in [&"startup", &"keypad-open"]:
		var descriptor: Dictionary = descriptors_by_id[state_id]
		assert_null(descriptor.view, str(state_id))
		assert_eq(descriptor.player_count, 0, str(state_id))
		assert_false(descriptor.ui.is_empty(), str(state_id))
	assert_eq(descriptors_by_id[&"startup"].kind, GuiVisualStateFixturesScript.KIND_STARTUP)
	assert_eq(
		descriptors_by_id[&"keypad-open"].kind,
		GuiVisualStateFixturesScript.KIND_UI_ONLY,
	)


func test_table_descriptors_use_recipient_safe_deterministic_snapshots() -> void:
	for player_count: int in GuiVisualStateFixturesScript.SUPPORTED_PLAYER_COUNTS:
		var first: Array[Dictionary] = GuiVisualStateFixturesScript.all(player_count)
		var second: Array[Dictionary] = GuiVisualStateFixturesScript.all(player_count)
		assert_eq(first.size(), second.size())
		for index: int in range(first.size()):
			var first_descriptor: Dictionary = first[index]
			var second_descriptor: Dictionary = second[index]
			if first_descriptor.view == null:
				assert_eq(first_descriptor.player_count, 0, str(first_descriptor.id))
				continue
			var context := "%s at %d players" % [first_descriptor.id, player_count]
			var first_view: GameView = first_descriptor.view
			var second_view: GameView = second_descriptor.view
			assert_eq(first_descriptor.player_count, player_count, context)
			assert_eq(first_descriptor.ui, second_descriptor.ui, context)
			assert_eq(
				_event_signature(first_descriptor.events),
				_event_signature(second_descriptor.events),
				context,
			)
			assert_eq(_view_signature(first_view), _view_signature(second_view), context)
			assert_eq(first_view.seats.size(), player_count, context)
			assert_eq(first_view.hero_seat, 0, context)
			assert_eq(first_view.hero_hole_cards.size(), 2, context)
			for player_view: PlayerView in first_view.seats:
				assert_false(_has_property(player_view, &"hole_cards"), context)
			for revealed_seat: int in first_view.revealed_hole_cards:
				assert_between(revealed_seat, 0, player_count - 1, context)
				assert_eq(first_view.revealed_hole_cards[revealed_seat].size(), 2)


func test_turn_street_and_wager_fixtures_expose_the_expected_public_state() -> void:
	var expected_streets: Dictionary = {
		&"human-turn-preflop": {"street": &"preflop", "cards": 0},
		&"human-turn-flop": {"street": &"flop", "cards": 3},
		&"human-turn-turn": {"street": &"turn", "cards": 4},
		&"human-turn-river": {"street": &"river", "cards": 5},
	}
	for player_count: int in GuiVisualStateFixturesScript.SUPPORTED_PLAYER_COUNTS:
		for state_id: StringName in expected_streets:
			var human_turn: GameView = _view(state_id, player_count)
			var context := "%s at %d players" % [state_id, player_count]
			assert_eq(human_turn.acting_seat, human_turn.hero_seat, context)
			assert_has(human_turn.legal_actions, PlayerAction.Kind.FOLD, context)
			assert_has(human_turn.legal_actions, PlayerAction.Kind.RAISE, context)
			assert_eq(human_turn.street, expected_streets[state_id].street, context)
			assert_eq(human_turn.community_cards.size(), expected_streets[state_id].cards, context)

		var bot_turn: GameView = _view(&"bot-turn", player_count)
		assert_ne(bot_turn.acting_seat, bot_turn.hero_seat, str(player_count))
		assert_between(bot_turn.acting_seat, 0, player_count - 1, str(player_count))
		assert_true(bot_turn.legal_actions.is_empty(), str(player_count))

		var blank_status: GameView = _view(&"status-blank", player_count)
		assert_true(blank_status.action_history.is_empty(), str(player_count))

		var retained_fold: GameView = _view(&"status-retained-fold", player_count)
		assert_true(retained_fold.hand_complete, str(player_count))
		assert_eq(retained_fold.acting_seat, Table.NO_SEAT, str(player_count))
		assert_eq(retained_fold.action_history.size(), player_count, str(player_count))
		for action: PublicActionRecord in retained_fold.action_history:
			assert_eq(action.kind, PlayerAction.Kind.FOLD, str(player_count))

		var wager_entry: Dictionary = GuiVisualStateFixturesScript.by_id(
			&"wager-entry", player_count
		)
		assert_eq(wager_entry.ui.wager_input_text, "75")
		assert_eq(wager_entry.ui.minimum, wager_entry.view.minimum_wager_total)
		assert_eq(wager_entry.ui.maximum, wager_entry.view.maximum_wager_total)


func test_terminal_and_long_content_fixtures_have_explicit_presentation_signals() -> void:
	for player_count: int in GuiVisualStateFixturesScript.SUPPORTED_PLAYER_COUNTS:
		var runout: GameView = _view(&"all-in-runout", player_count)
		assert_eq(runout.acting_seat, Table.NO_SEAT)
		assert_true(runout.legal_actions.is_empty())
		assert_eq(runout.community_cards.size(), 4)
		assert_eq(runout.seats.filter(func(seat: PlayerView) -> bool: return seat.all_in).size(), 2)

		var showdown: GameView = _view(&"showdown-long", player_count)
		assert_eq(showdown.showdown_results.size(), 2)
		for result: ShowdownResult in showdown.showdown_results.values():
			assert_between(result.seat, 0, player_count - 1)
			assert_gt(ShowdownHandFormatterScript.format(result).length(), 20)

		var eliminated_seat: int = player_count - 1
		var elimination: GameView = _view(&"elimination", player_count)
		assert_eq(elimination.eliminated_seats, [eliminated_seat])
		assert_true(elimination.seats[eliminated_seat].busted)

		var winner: GameView = _view(&"tournament-winner", player_count)
		assert_eq(winner.tournament_status, &"finished")
		assert_eq(winner.end_reason, &"winner")
		assert_eq(winner.tournament_winner_seat, winner.hero_seat)
		assert_eq(winner.eliminated_seats.size(), player_count - 1)
		for seat: int in range(1, player_count):
			assert_true(winner.seats[seat].busted)


func test_event_modal_and_keypad_descriptors_are_complete() -> void:
	for player_count: int in GuiVisualStateFixturesScript.SUPPORTED_PLAYER_COUNTS:
		var history: Dictionary = GuiVisualStateFixturesScript.by_id(
			&"event-history-full", player_count
		)
		assert_gte(history.events.size(), 18)
		var event_kinds: Array[DomainEvent.Kind] = []
		for event: DomainEvent in history.events:
			event_kinds.append(event.kind)
			assert_true(event.seat == Table.NO_SEAT or event.seat < player_count)
		for required_kind: DomainEvent.Kind in DomainEvent.Kind.values():
			assert_has(event_kinds, required_kind)

		var quit: Dictionary = GuiVisualStateFixturesScript.by_id(
			&"quit-confirmation", player_count
		)
		assert_eq(quit.kind, GuiVisualStateFixturesScript.KIND_TABLE_MODAL)
		assert_eq(quit.ui.overlay, &"quit_confirmation")
		assert_eq(quit.player_count, player_count)
		assert_not_null(quit.view)

	var keypad: Dictionary = GuiVisualStateFixturesScript.by_id(&"keypad-open")
	assert_eq(keypad.ui.overlay, &"numeric_keypad")
	assert_eq(keypad.ui.input_text, "25")
	assert_lt(keypad.ui.minimum, keypad.ui.maximum)


func _view(
	state_id: StringName, player_count: int = GuiVisualStateFixturesScript.DEFAULT_PLAYER_COUNT
) -> GameView:
	return GuiVisualStateFixturesScript.by_id(state_id, player_count).view as GameView


func _view_signature(view: GameView) -> Array:
	var seat_signature: Array = []
	for seat: PlayerView in view.seats:
		(
			seat_signature
			. append(
				[
					seat.seat,
					seat.player_id,
					seat.is_human,
					seat.stack,
					seat.bet_this_round,
					seat.folded,
					seat.all_in,
					seat.busted,
				]
			)
		)
	var action_signature: Array = []
	for record: PublicActionRecord in view.action_history:
		action_signature.append([record.record_kind, record.seat, record.kind, record.amount])
	var revealed_signature: Array = []
	var revealed_seats: Array[int] = []
	for seat: int in view.revealed_hole_cards:
		revealed_seats.append(seat)
	revealed_seats.sort()
	for seat: int in revealed_seats:
		revealed_signature.append([seat, _card_codes(view.revealed_hole_cards[seat])])
	var showdown_signature: Array = []
	var showdown_seats: Array[int] = []
	for seat: int in view.showdown_results:
		showdown_seats.append(seat)
	showdown_seats.sort()
	for seat: int in showdown_seats:
		var result: ShowdownResult = view.showdown_results[seat]
		showdown_signature.append(
			[seat, result.category, result.tie_break_values, _card_codes(result.hole_cards)]
		)
	return [
		view.street,
		view.hand_number,
		view.hero_seat,
		view.button_seat,
		view.small_blind_seat,
		view.big_blind_seat,
		view.acting_seat,
		view.pot_amount,
		view.call_amount,
		view.minimum_wager_total,
		view.maximum_wager_total,
		view.legal_actions,
		_card_codes(view.hero_hole_cards),
		_card_codes(view.community_cards),
		seat_signature,
		action_signature,
		revealed_signature,
		showdown_signature,
		view.active_seats,
		view.eliminated_seats,
		view.hand_complete,
		view.hand_winner_seat,
		view.tournament_status,
		view.end_reason,
		view.tournament_winner_seat,
	]


func _event_signature(events: Array[DomainEvent]) -> Array:
	var signature: Array = []
	for event: DomainEvent in events:
		signature.append([event.kind, event.seat, event.amount, event.message])
	return signature


func _card_codes(cards: Array[CardData]) -> Array[String]:
	var codes: Array[String] = []
	for card: CardData in cards:
		codes.append(card.code())
	return codes


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.name == property_name:
			return true
	return false
