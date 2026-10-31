class_name GuiMatchProgressInspector
extends RefCounted

## Reads public domain events to decide GUI-only pacing boundaries.


static func latest_action_seat(events: Array[DomainEvent]) -> int:
	for index: int in range(events.size() - 1, -1, -1):
		if events[index].kind == DomainEvent.Kind.ACTION_APPLIED:
			return events[index].seat
	return Table.NO_SEAT


static func latest_event_is_community_cards_dealt(events: Array[DomainEvent]) -> bool:
	return not events.is_empty() and events[-1].kind == DomainEvent.Kind.COMMUNITY_CARDS_DEALT
