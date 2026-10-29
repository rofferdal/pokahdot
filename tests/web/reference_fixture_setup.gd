extends RefCounted

## Reference-scene bootstrap only. Read-only observers use semantic snapshots.
## A replacement scene supplies its own setup without changing measurement code.


static func table(main: Control, show_table: bool = false) -> PokerTableController:
	var result := main.get_node("PokerTable") as PokerTableController
	if show_table:
		main.get_node("Center").hide()
		result.show()
	return result


static func set_wager_input(table_view: PokerTableController, text: String) -> void:
	(table_view.get_node("%WagerInput") as LineEdit).text = text


static func bind_events(table_view: PokerTableController, events: Array[DomainEvent]) -> void:
	table_view._render_events(events)


static func show_completed_hand(table_view: PokerTableController) -> void:
	table_view._advance_after_action_pause()
