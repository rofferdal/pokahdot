class_name GuiVisualStateFixtures
extends RefCounted

## Deterministic, recipient-safe presentation inputs for GUI matrix tests.
##
## Table descriptors contain deliberately synthetic GameView snapshots. They
## model already-resolved public presentation state and do not simulate hands
## or reproduce poker rules. UI-only descriptors make startup and standalone
## keypad states explicit without manufacturing a GameView.

const FIXED_SEED: int = 424242
const DEFAULT_PLAYER_COUNT: int = 6
const SUPPORTED_PLAYER_COUNTS: Array[int] = [2, 4, 6, 7, 9]

const KIND_STARTUP: StringName = &"startup"
const KIND_TABLE: StringName = &"table"
const KIND_TABLE_MODAL: StringName = &"table_modal"
const KIND_UI_ONLY: StringName = &"ui_only"

const STATE_IDS: Array[StringName] = [
	&"startup",
	&"human-turn-preflop",
	&"human-turn-flop",
	&"human-turn-turn",
	&"human-turn-river",
	&"bot-turn",
	&"status-blank",
	&"status-retained-fold",
	&"wager-entry",
	&"all-in-runout",
	&"showdown-long",
	&"elimination",
	&"tournament-winner",
	&"event-history-full",
	&"quit-confirmation",
	&"keypad-open",
]


static func all(player_count: int = DEFAULT_PLAYER_COUNT) -> Array[Dictionary]:
	assert(player_count in SUPPORTED_PLAYER_COUNTS, "Unsupported visual fixture player count.")
	return [
		_ui_descriptor(
			&"startup",
			KIND_STARTUP,
			{
				"player_count_text": "6",
				"starting_stack_text": "1000",
				"small_blind_text": "5",
				"big_blind_text": "10",
			},
		),
		_table_descriptor(&"human-turn-preflop", _human_turn_view(player_count, &"preflop")),
		_table_descriptor(&"human-turn-flop", _human_turn_view(player_count, &"flop")),
		_table_descriptor(&"human-turn-turn", _human_turn_view(player_count, &"turn")),
		_table_descriptor(&"human-turn-river", _human_turn_view(player_count, &"river")),
		_table_descriptor(&"bot-turn", _bot_turn_view(player_count)),
		_table_descriptor(&"status-blank", _blank_status_view(player_count)),
		_table_descriptor(&"status-retained-fold", _retained_fold_status_view(player_count)),
		_table_descriptor(
			&"wager-entry",
			_human_turn_view(player_count, &"preflop"),
			{"wager_input_text": "75", "minimum": 20, "maximum": 1000},
		),
		_table_descriptor(&"all-in-runout", _all_in_runout_view(player_count)),
		_table_descriptor(&"showdown-long", _showdown_view(player_count)),
		_table_descriptor(&"elimination", _elimination_view(player_count)),
		_table_descriptor(&"tournament-winner", _tournament_winner_view(player_count)),
		_table_descriptor(
			&"event-history-full",
			_human_turn_view(player_count, &"river"),
			{},
			_full_event_history(player_count),
		),
		_table_descriptor(
			&"quit-confirmation",
			_human_turn_view(player_count, &"preflop"),
			{
				"overlay": &"quit_confirmation",
				"intentional_overlap_controls": [&"QuitConfirmation"],
			},
			[],
			KIND_TABLE_MODAL,
		),
		_ui_descriptor(
			&"keypad-open",
			KIND_UI_ONLY,
			{
				"overlay": &"numeric_keypad",
				"intentional_overlap_controls": [&"StartupNumberKeypad"],
				"title": "Enter number",
				"input_text": "25",
				"minimum": 0,
				"maximum": 999999,
			},
		),
	]


static func by_id(state_id: StringName, player_count: int = DEFAULT_PLAYER_COUNT) -> Dictionary:
	for descriptor: Dictionary in all(player_count):
		if descriptor.id == state_id:
			return descriptor
	return {}


static func _ui_descriptor(state_id: StringName, kind: StringName, ui: Dictionary) -> Dictionary:
	return {
		"id": state_id,
		"kind": kind,
		"fixed_seed": FIXED_SEED,
		"synthetic": true,
		"player_count": 0,
		"view": null,
		"events": [] as Array[DomainEvent],
		"ui": ui.duplicate(true),
	}


static func _table_descriptor(
	state_id: StringName,
	view: GameView,
	ui: Dictionary = {},
	events: Array[DomainEvent] = [],
	kind: StringName = KIND_TABLE,
) -> Dictionary:
	return {
		"id": state_id,
		"kind": kind,
		"fixed_seed": FIXED_SEED,
		"synthetic": true,
		"player_count": view.seats.size(),
		"view": view,
		"events": events.duplicate(),
		"ui": ui.duplicate(true),
	}


static func _human_turn_view(player_count: int, street: StringName) -> GameView:
	var view: GameView = _base_view(player_count, street, 0)
	view._community_cards = _board_for_street(street)
	view.call_amount = 10
	view.minimum_wager_total = 20
	view.maximum_wager_total = 1000
	view._legal_actions = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CALL,
		PlayerAction.Kind.RAISE,
		PlayerAction.Kind.ALL_IN,
	]
	return view


static func _bot_turn_view(player_count: int) -> GameView:
	return _base_view(player_count, &"preflop", 1)


static func _blank_status_view(player_count: int) -> GameView:
	var view: GameView = _human_turn_view(player_count, &"preflop")
	view._action_history = [] as Array[PublicActionRecord]
	return view


static func _retained_fold_status_view(player_count: int) -> GameView:
	var view: GameView = _base_view(player_count, &"hand_end", Table.NO_SEAT)
	view.hand_complete = true
	view._legal_actions = []
	view._action_history = [] as Array[PublicActionRecord]
	for seat: int in range(player_count):
		view._action_history.append(PublicActionRecord.new(seat, PlayerAction.Kind.FOLD, 0))
	return view


static func _all_in_runout_view(player_count: int) -> GameView:
	var opponent_seat: int = player_count - 1
	var view: GameView = _base_view(player_count, &"turn", Table.NO_SEAT)
	view._community_cards = _board_for_street(&"turn")
	view._seats = _player_views(player_count, -1, [0, opponent_seat])
	view._action_history = [
		PublicActionRecord.new(opponent_seat, PlayerAction.Kind.ALL_IN, 1000),
		PublicActionRecord.new(0, PlayerAction.Kind.ALL_IN, 1000),
	]
	view.pot_amount = 2025
	return view


static func _showdown_view(player_count: int) -> GameView:
	var first_revealed_seat: int = player_count - 2
	var second_revealed_seat: int = player_count - 1
	var view: GameView = _base_view(player_count, &"hand_end", Table.NO_SEAT)
	view.hand_complete = true
	view.hand_winner_seat = second_revealed_seat
	view._community_cards = _board_for_street(&"river")
	var seat_three_cards: Array[CardData] = [
		_card(14, CardData.Suit.SPADES), _card(13, CardData.Suit.HEARTS)
	]
	var seat_four_cards: Array[CardData] = [
		_card(12, CardData.Suit.DIAMONDS), _card(12, CardData.Suit.CLUBS)
	]
	view._revealed_hole_cards = {
		first_revealed_seat: seat_three_cards, second_revealed_seat: seat_four_cards
	}
	view._showdown_results = {
		first_revealed_seat:
		_showdown_result(
			first_revealed_seat, seat_three_cards, HandRank.Category.FULL_HOUSE, [14, 13]
		),
		second_revealed_seat:
		_showdown_result(
			second_revealed_seat, seat_four_cards, HandRank.Category.FOUR_OF_A_KIND, [12, 14]
		),
	}
	return view


static func _elimination_view(player_count: int) -> GameView:
	var eliminated_seat: int = player_count - 1
	var view: GameView = _base_view(player_count, &"hand_end", Table.NO_SEAT)
	view.hand_complete = true
	view._community_cards = _board_for_street(&"river")
	view._seats = _player_views(player_count, eliminated_seat)
	view.active_seats = []
	for seat: int in range(eliminated_seat):
		view.active_seats.append(seat)
	view.eliminated_seats = [eliminated_seat]
	return view


static func _tournament_winner_view(player_count: int) -> GameView:
	var view: GameView = _elimination_view(player_count)
	view.tournament_status = &"finished"
	view.end_reason = &"winner"
	view.tournament_winner_seat = 0
	view._seats = _player_views(player_count, 1)
	view.active_seats = [0]
	view.eliminated_seats = []
	for seat: int in range(1, player_count):
		view.eliminated_seats.append(seat)
	return view


static func _base_view(player_count: int, street: StringName, acting_seat: int) -> GameView:
	var view := GameView.new()
	view.street = street
	view.hand_number = 12
	view.hero_seat = 0
	view.button_seat = player_count - 1
	view.small_blind_seat = 0
	view.big_blind_seat = 1
	view.small_blind = 5
	view.big_blind = 10
	view.blind_level = 3
	view.completed_hands_in_level = 4
	view.hands_until_next_level = 8
	view.active_player_count_at_level_start = player_count
	view.acting_seat = acting_seat
	view.pot_amount = 45
	for seat: int in range(player_count):
		view.active_seats.append(seat)
	view.active_seats_at_hand_start = view.active_seats.duplicate()
	for seat: int in range(player_count):
		view.hand_start_stacks[seat] = 1000
	view._seats = _player_views(player_count)
	view._hero_hole_cards = [_card(14, CardData.Suit.HEARTS), _card(10, CardData.Suit.CLUBS)]
	view._action_history = [
		PublicActionRecord.blind(0, 5, true),
		PublicActionRecord.blind(1, 10, false),
		PublicActionRecord.new(mini(2, player_count - 1), PlayerAction.Kind.CALL, 10),
	]
	return view


static func _player_views(
	player_count: int, eliminated_from_seat: int = -1, all_in_seats: Array[int] = []
) -> Array[PlayerView]:
	var views: Array[PlayerView] = []
	for seat: int in range(player_count):
		var eliminated: bool = eliminated_from_seat >= 0 and seat >= eliminated_from_seat
		var all_in: bool = seat in all_in_seats
		var stack: int = 0 if eliminated or all_in else 1000 - seat * 25
		var agent: Agent = HumanAgent.new() if seat == 0 else null
		var player := (
			Player
			. new(
				StringName("fixture_player_%d" % seat),
				"Fixture Player %d" % (seat + 1),
				seat,
				stack,
				agent,
			)
		)
		player.busted = eliminated
		player.all_in = all_in
		player.bet_this_round = 10 if seat in [0, 1, 2] else 0
		views.append(PlayerView.new(player))
	return views


static func _board_for_street(street: StringName) -> Array[CardData]:
	var full_board: Array[CardData] = [
		_card(2, CardData.Suit.CLUBS),
		_card(7, CardData.Suit.DIAMONDS),
		_card(11, CardData.Suit.HEARTS),
		_card(13, CardData.Suit.SPADES),
		_card(3, CardData.Suit.HEARTS),
	]
	var card_count: int = {&"preflop": 0, &"flop": 3, &"turn": 4, &"river": 5}.get(street, 5)
	var board: Array[CardData] = []
	for index: int in range(card_count):
		board.append(full_board[index])
	return board


static func _showdown_result(
	seat: int,
	hole_cards: Array[CardData],
	category: HandRank.Category,
	tie_break_values: Array[int],
) -> ShowdownResult:
	var selected_cards: Array[CardData] = [
		hole_cards[0],
		hole_cards[1],
		_card(14, CardData.Suit.DIAMONDS),
		_card(13, CardData.Suit.CLUBS),
		_card(12, CardData.Suit.SPADES),
	]
	return ShowdownResult.new(
		seat, hole_cards, HandRank.new(category, tie_break_values, selected_cards)
	)


static func _full_event_history(player_count: int) -> Array[DomainEvent]:
	var third_seat: int = mini(2, player_count - 1)
	var last_seat: int = player_count - 1
	var events: Array[DomainEvent] = [
		DomainEvent.new(DomainEvent.Kind.HAND_STARTED),
		DomainEvent.new(DomainEvent.Kind.BLIND_POSTED, 0, 5),
		DomainEvent.new(DomainEvent.Kind.BLIND_POSTED, 1, 10),
		DomainEvent.new(DomainEvent.Kind.CARDS_DEALT),
		DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, third_seat, 10),
		DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 0, 10),
		DomainEvent.new(DomainEvent.Kind.STREET_CHANGED),
		DomainEvent.new(DomainEvent.Kind.COMMUNITY_CARDS_DEALT),
		DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 1, 20),
		DomainEvent.new(DomainEvent.Kind.ACTION_REJECTED, 0, 1),
		DomainEvent.new(DomainEvent.Kind.STREET_CHANGED),
		DomainEvent.new(DomainEvent.Kind.COMMUNITY_CARDS_DEALT),
		DomainEvent.new(DomainEvent.Kind.STREET_CHANGED),
		DomainEvent.new(DomainEvent.Kind.COMMUNITY_CARDS_DEALT),
		DomainEvent.new(DomainEvent.Kind.SHOWDOWN_STARTED),
		DomainEvent.new(DomainEvent.Kind.POT_AWARDED, last_seat, 85),
		DomainEvent.new(DomainEvent.Kind.HAND_COMPLETED),
		DomainEvent.new(DomainEvent.Kind.HAND_STARTED),
		DomainEvent.new(DomainEvent.Kind.PLAYER_QUIT, last_seat),
	]
	events[9].message = "Wager rejected by the public action boundary."
	return events


static func _card(rank: int, suit: CardData.Suit) -> CardData:
	return CardData.new(rank, suit)
