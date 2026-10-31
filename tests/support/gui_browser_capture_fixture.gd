class_name GuiBrowserCaptureFixture
extends RefCounted

## Synthetic recipient-safe state matching the reported six-seat preflop captures.
## Historical browser dimensions and exact avatar assignments are unknown.


static func descriptor(player_count: int = 6, font_stress: bool = false) -> Dictionary:
	player_count = clampi(player_count, 2, 9)
	if player_count > 6:
		var fixture: Dictionary = GuiVisualStateFixtures.replacement_flop(player_count)
		var names: Dictionary[int, String] = {}
		var avatars: Dictionary[int, String] = {}
		var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
		for seat: int in player_count:
			names[seat] = "Human" if seat == 0 else "Annalise"
			avatars[seat] = paths[seat]
		fixture.names = names
		fixture.avatars = avatars
		return fixture
	var view := GameView.new()
	view.hand_number = 1
	view.hero_seat = 0
	view.button_seat = 0
	view.small_blind_seat = 1
	view.big_blind_seat = 2
	view.small_blind = 5
	view.big_blind = 10
	view.acting_seat = 0
	view.pot_amount = 65
	view.call_amount = 1000000 if font_stress else 30
	view.minimum_wager_total = 1000000 if font_stress else 40
	view.maximum_wager_total = 1000
	view.active_player_count_at_level_start = player_count
	view.active_seats.assign(range(player_count))
	view.active_seats_at_hand_start = view.active_seats.duplicate()
	var stacks: Array[int] = []
	stacks.assign(
		(
			[1000000, 1000000, 1000000, 1000000, 1000000, 1000000]
			if font_stress
			else [1000, 995, 990, 980, 1000, 970]
		)
	)
	var wagers: Array[int] = [0, 1000000 if font_stress else 5, 10, 20, 0, 30]
	var names: Dictionary[int, String] = {
		0: "Human",
		1: "Annalise" if font_stress else "Yael",
		2: "Chidi",
		3: "Wei",
		4: "Haruto",
		5: "Youssef"
	}
	var avatars: Dictionary[int, String] = {}
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	for seat: int in range(player_count):
		var agent: Agent = HumanAgent.new() if seat == 0 else null
		var player := Player.new(
			StringName("browser_capture_%d" % seat),
			"Player %d" % (seat + 1),
			seat,
			stacks[seat],
			agent
		)
		player.bet_this_round = wagers[seat]
		player.folded = seat == 4
		player.all_in = font_stress and seat == 1
		view._seats.append(PlayerView.new(player))
		view.hand_start_stacks[seat] = 1000
		avatars[seat] = paths[seat]
	view._hero_hole_cards = [
		CardData.new(4, CardData.Suit.SPADES), CardData.new(8, CardData.Suit.DIAMONDS)
	]
	view._legal_actions = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CALL,
		PlayerAction.Kind.RAISE,
		PlayerAction.Kind.ALL_IN
	]
	view._action_history = [
		PublicActionRecord.blind(1, 5, true),
		PublicActionRecord.blind(2, 10, false),
		PublicActionRecord.new(3, PlayerAction.Kind.RAISE, 20),
		PublicActionRecord.new(4, PlayerAction.Kind.FOLD),
		PublicActionRecord.new(5, PlayerAction.Kind.RAISE, 30)
	]
	if font_stress:
		view._action_history.append(PublicActionRecord.new(1, PlayerAction.Kind.ALL_IN, 1000000))
	var events: Array[DomainEvent] = [
		DomainEvent.new(DomainEvent.Kind.BLIND_POSTED, 1, 5),
		DomainEvent.new(DomainEvent.Kind.BLIND_POSTED, 2, 10),
		DomainEvent.new(DomainEvent.Kind.CARDS_DEALT),
		DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 3, 20),
		DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 4),
		DomainEvent.new(DomainEvent.Kind.ACTION_APPLIED, 5, 30)
	]
	return {
		"id": &"browser-six-seat-preflop",
		"kind": &"table",
		"synthetic": true,
		"player_count": player_count,
		"view": view,
		"events": events,
		"ui": {},
		"names": names,
		"avatars": avatars
	}
