class_name GuiEventFormatter
extends RefCounted

## Converts recipient-safe domain events into complete player-facing history entries.


static func format_event(
	event: DomainEvent,
	view: GameView,
	action_record: PublicActionRecord = null,
) -> String:
	var player_name: String = player_name_for(view, event.seat)
	match event.kind:
		DomainEvent.Kind.HAND_STARTED:
			return "Hand %d started" % view.hand_number
		DomainEvent.Kind.BLIND_POSTED:
			return "%s posted a blind of %d" % [player_name, event.amount]
		DomainEvent.Kind.CARDS_DEALT:
			return "Hole cards dealt"
		DomainEvent.Kind.ACTION_APPLIED:
			return _format_action(player_name, action_record)
		DomainEvent.Kind.ACTION_REJECTED:
			if event.message.is_empty():
				return "%s action was rejected" % player_name
			return "%s action was rejected: %s" % [player_name, event.message]
		DomainEvent.Kind.STREET_CHANGED:
			return "%s begins" % street_name(view)
		DomainEvent.Kind.COMMUNITY_CARDS_DEALT:
			return "Community cards dealt"
		DomainEvent.Kind.SHOWDOWN_STARTED:
			return "Showdown"
		DomainEvent.Kind.POT_AWARDED:
			return "%s wins %d" % [player_name, event.amount]
		DomainEvent.Kind.HAND_COMPLETED:
			return "Hand complete"
		DomainEvent.Kind.PLAYER_QUIT:
			return "Player quit"
	return "Event"


static func player_name_for(view: GameView, seat: int) -> String:
	if view == null:
		return "Player"
	for player_view: PlayerView in view.seats:
		if player_view.seat == seat:
			return "%s%s" % [player_view.display_name, " (you)" if player_view.is_human else ""]
	return "Player %d" % (seat + 1)


static func street_name(view: GameView) -> String:
	if view == null:
		return "Poker"
	var names: Dictionary[StringName, String] = {
		&"preflop": "Preflop",
		&"flop": "Flop",
		&"turn": "Turn",
		&"river": "River",
		&"showdown": "Showdown",
		&"hand_end": "Hand settlement",
	}
	return names.get(view.street, "Poker")


static func street_transition_text(transition_index: int) -> String:
	var street_names: PackedStringArray = PackedStringArray(["Flop", "Turn", "River"])
	if transition_index < 0 or transition_index >= street_names.size():
		return "Next street begins"
	return "%s begins" % street_names[transition_index]


static func _format_action(player_name: String, action_record: PublicActionRecord) -> String:
	if action_record == null:
		return "%s acted" % player_name
	var action_names: Dictionary[PlayerAction.Kind, String] = {
		PlayerAction.Kind.FOLD: "Fold",
		PlayerAction.Kind.CHECK: "Check",
		PlayerAction.Kind.CALL: "Call to %d" % action_record.amount,
		PlayerAction.Kind.BET: "Bet to %d" % action_record.amount,
		PlayerAction.Kind.RAISE: "Raise to %d" % action_record.amount,
		PlayerAction.Kind.ALL_IN: "All-in to %d" % action_record.amount,
	}
	return "%s: %s" % [player_name, action_names.get(action_record.kind, "Action")]
