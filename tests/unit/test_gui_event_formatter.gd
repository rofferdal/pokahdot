extends "res://tests/support/poker_gut_test.gd"

const GuiEventFormatterScript := preload("res://scripts/gui/gui_event_formatter.gd")


func test_formatter_makes_every_game_event_explicit_and_recipient_safe() -> void:
	var view := GameView.new()
	view.hand_number = 3
	view.street = &"river"
	view._seats = [
		_player_view(&"Hero", 0, HumanAgent.new()),
		_player_view(&"River Bot", 1, RandomAgent.new(RandomNumberGenerator.new())),
	]
	var call_record := PublicActionRecord.new(1, PlayerAction.Kind.CALL, 40)
	var expected_text: Dictionary[DomainEvent.Kind, String] = {
		DomainEvent.Kind.HAND_STARTED: "Hand 3 started",
		DomainEvent.Kind.BLIND_POSTED: "Hero (you) posted a blind of 5",
		DomainEvent.Kind.CARDS_DEALT: "Hole cards dealt",
		DomainEvent.Kind.ACTION_APPLIED: "River Bot: Call to 40",
		DomainEvent.Kind.ACTION_REJECTED: "River Bot action was rejected",
		DomainEvent.Kind.STREET_CHANGED: "River begins",
		DomainEvent.Kind.COMMUNITY_CARDS_DEALT: "Community cards dealt",
		DomainEvent.Kind.SHOWDOWN_STARTED: "Showdown",
		DomainEvent.Kind.POT_AWARDED: "River Bot wins 60",
		DomainEvent.Kind.HAND_COMPLETED: "Hand complete",
		DomainEvent.Kind.PLAYER_QUIT: "Player quit",
	}
	for event_kind: DomainEvent.Kind in expected_text:
		var event := DomainEvent.new(event_kind, 1, 60)
		if event_kind == DomainEvent.Kind.BLIND_POSTED:
			event.seat = 0
			event.amount = 5
		assert_eq(
			(
				GuiEventFormatterScript
				. format_event(
					event,
					view,
					call_record if event_kind == DomainEvent.Kind.ACTION_APPLIED else null,
				)
			),
			expected_text[event_kind],
			"event kind %d" % event_kind,
		)
	assert_eq(GuiEventFormatterScript.street_transition_text(0), "Flop begins")
	assert_eq(GuiEventFormatterScript.street_transition_text(1), "Turn begins")
	assert_eq(GuiEventFormatterScript.street_transition_text(2), "River begins")


func _player_view(name: String, seat: int, agent: Agent) -> PlayerView:
	return PlayerView.new(Player.new(&"gui_formatter_%d" % seat, name, seat, 100, agent))
