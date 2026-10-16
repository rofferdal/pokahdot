class_name GameView
extends RefCounted

## Recipient-specific read-only snapshot of public hand state and permitted cards.

var street: StringName = &"preflop"
var hand_number: int
var hero_seat: int
var button_seat: int
var small_blind_seat: int
var big_blind_seat: int
var acting_seat: int
var pot_amount: int
var call_amount: int
var minimum_wager_total: int
var maximum_wager_total: int
var tournament_status: StringName = &"running"
var end_reason: StringName
var tournament_winner_seat: int = Table.NO_SEAT
var hand_winner_seat: int = Table.NO_SEAT
var hand_complete: bool

var seats: Array[PlayerView]:
	get:
		return _seats.duplicate()
var hero_hole_cards: Array[CardData]:
	get:
		return _hero_hole_cards.duplicate()
var legal_actions: Array[PlayerAction.Kind]:
	get:
		return _legal_actions.duplicate()
var action_history: Array[PublicActionRecord]:
	get:
		var copied: Array[PublicActionRecord] = []
		for record: PublicActionRecord in _action_history:
			copied.append(record.copy())
		return copied
var community_cards: Array[CardData]:
	get:
		return _community_cards.duplicate()
var pots: Array[PotLayer]:
	get:
		return _pots.duplicate()
var pot_awards: Array[PotAward]:
	get:
		return _pot_awards.duplicate()
var revealed_hole_cards: Dictionary[int, Array]:
	get:
		var copied: Dictionary[int, Array] = {}
		for seat: int in _revealed_hole_cards:
			copied[seat] = _revealed_hole_cards[seat].duplicate()
		return copied
var showdown_results: Dictionary[int, ShowdownResult]:
	get:
		return _showdown_results.duplicate()

var _seats: Array[PlayerView] = []
var _hero_hole_cards: Array[CardData] = []
var _legal_actions: Array[PlayerAction.Kind] = []
var _action_history: Array[PublicActionRecord] = []
var _community_cards: Array[CardData] = []
var _pots: Array[PotLayer] = []
var _pot_awards: Array[PotAward] = []
var _revealed_hole_cards: Dictionary[int, Array] = {}
var _showdown_results: Dictionary[int, ShowdownResult] = {}


static func for_preflop(
	table: Table,
	recipient_seat: int,
	betting_round: BettingRound,
	pot_manager: PotManager,
	public_history: Array[PublicActionRecord],
	current_hand_number: int = 1,
) -> GameView:
	return for_hand(
		table,
		recipient_seat,
		betting_round,
		pot_manager,
		public_history,
		&"preflop",
		[],
		[],
		{},
		current_hand_number,
	)


static func for_hand(
	table: Table,
	recipient_seat: int,
	betting_round: BettingRound,
	pot_manager: PotManager,
	public_history: Array[PublicActionRecord],
	current_street: StringName,
	board: Array[CardData],
	settled_awards: Array[PotAward],
	shown_hole_cards: Dictionary[int, Array],
	current_hand_number: int = 1,
	settled_pots: Array[PotLayer] = [],
	revealed_results: Dictionary[int, ShowdownResult] = {},
) -> GameView:
	assert(table != null, "A game view requires a table.")
	assert(table.get_player(recipient_seat) != null, "The recipient seat must exist.")
	var view := GameView.new()
	view.street = current_street
	view.hand_number = current_hand_number
	view.hero_seat = recipient_seat
	view.button_seat = table.button_seat
	view.small_blind_seat = table.small_blind_seat()
	view.big_blind_seat = table.big_blind_seat()
	view.acting_seat = betting_round.acting_seat if betting_round != null else Table.NO_SEAT
	view.pot_amount = pot_manager.total_amount if pot_manager != null else 0
	view._community_cards = board.duplicate()
	view._pots = settled_pots.duplicate()
	if view._pots.is_empty() and pot_manager != null:
		view._pots = pot_manager.derive_pots(table.players)
	view._pot_awards = settled_awards.duplicate()
	for shown_seat: int in shown_hole_cards:
		var shown_player: Player = table.get_player(shown_seat)
		if shown_player != null and not shown_player.folded:
			view._revealed_hole_cards[shown_seat] = shown_hole_cards[shown_seat].duplicate()
	for result_seat: int in revealed_results:
		var result_player: Player = table.get_player(result_seat)
		if (
			result_player != null
			and not result_player.folded
			and view._revealed_hole_cards.has(result_seat)
		):
			view._showdown_results[result_seat] = revealed_results[result_seat]
	for player: Player in table.players:
		view._seats.append(PlayerView.new(player))
	view._hero_hole_cards = table.get_player(recipient_seat).hole_cards
	if betting_round != null:
		view._legal_actions = betting_round.legal_actions(recipient_seat)
		view.call_amount = betting_round.call_amount(recipient_seat)
		view.minimum_wager_total = betting_round.minimum_wager_total()
		view.maximum_wager_total = betting_round.maximum_wager_total(recipient_seat)
	for record: PublicActionRecord in public_history:
		view._action_history.append(record.copy())
	return view
